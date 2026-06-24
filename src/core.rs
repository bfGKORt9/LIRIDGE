use anyhow::{anyhow, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use ort::{GraphOptimizationLevel, Session};
use rubato::{FftFixedInOut, Resampler};
use std::sync::{arc::Arc, Mutex};
use tokio::sync::mpsc;

// Gemini 3.5 Flash Live API の厳格な要求仕様
const TARGET_SAMPLE_RATE: usize = 24000;
const CHANNELS: u16 = 1;

// Silero VAD v4 が 24kHz 時に要求する最小フレームサイズ (512サンプル = 約21.3ms)
const VAD_FRAME_SIZE: usize = 512;

/// LIRIDGEの音声処理コアの状態を管理する構造体
pub struct LiridgeAudioCore {
    stream: Option<cpal::Stream>,
    is_recording: Arc<Mutex<bool>>,
}

impl LiridgeAudioCore {
    /// 新しいオーディオコアのインスタンスを生成
    pub fn new() -> Self {
        Self {
            stream: None,
            is_recording: Arc::new(Mutex::new(false)),
        }
    }

    /// 音声キャプチャおよびVADパイプラインを開始する
    /// `model_bytes`: アプリ内に同梱した Silero VAD の .onnx モデルデータ
    /// `flutter_sink`: Flutter(Dart)側にデータを即時転送するためのストリーム窓口
    pub fn start_pipeline(
        &mut self,
        model_bytes: &[u8],
        flutter_sink: flutter_rust_bridge::StreamSink<Vec<i16>>,
    ) -> Result<()> {
        let mut is_recording = self.is_recording.lock().unwrap();
        if *is_recording {
            return Err(anyhow!("Pipeline is already running"));
        }
        *is_recording = true;

        // 1. ONNX Runtime を使用して Silero VAD セッションを初期化
        let vad_session = Session::builder()?
            .with_optimization_level(GraphOptimizationLevel::Level3)?
            .with_intra_threads(1)? // エッジ側でのCPU負荷を最小化
            .commit_from_memory(model_bytes)?;

        // ONNXモデル内部の状態（隠れ状態 h と c）を初期化 (Silero VADの仕様)
        let mut _h = vec![0.0f32; 2 * 1 * 64];
        let mut _c = vec![0.0f32; 2 * 1 * 64];

        // 2. スマホのデフォルトマイク（オーディオ入力デバイス）を取得
        let host = cpal::default_host();
        let device = host
            .default_input_device()
            .ok_or_else(|| anyhow!("Failed to find default input device"))?;

        let config = device.default_input_config()?;
        let input_sample_rate = config.sample_rate().0 as usize;

        // 3. 内部スレッド間通信用の非同期チャネルを構築
        let (tx, mut rx) = mpsc::channel::<Vec<f32>>(32);
        let is_recording_clone = Arc::clone(&self.is_recording);

        // --- 核心：VAD推論 & Gemini向け最適化を行うバックグラウンドタスク ---
        tokio::spawn(async move {
            let mut audio_buffer = Vec::new();
            
            // マイクのサンプリングレートが 24kHz でない場合の超低遅延レサンプラー設定
            let mut resampler = if input_sample_rate != TARGET_SAMPLE_RATE {
                Some(FftFixedInOut::<f32>::new(
                    input_sample_rate,
                    TARGET_SAMPLE_RATE,
                    VAD_FRAME_SIZE,
                    1,
                ).unwrap())
            } else {
                None
            };

            while *is_recording_clone.lock().unwrap() {
                if let Some(mut raw_samples) = rx.recv().await {
                    // 必要に応じて 24kHz へリアルタイムダウンサンプリング
                    let mut processed_samples = if let Some(ref mut resampler) = resampler {
                        let dummy_input = vec![raw_samples];
                        let resampled = resampler.process(&dummy_input, None).unwrap();
                        resampled[0].clone()
                    } else {
                        raw_samples
                    };

                    audio_buffer.append(&mut processed_samples);

                    // VADが要求する 512 サンプル溜まるごとに処理を実行
                    while audio_buffer.len() >= VAD_FRAME_SIZE {
                        let frame: Vec<f32> = audio_buffer.drain(0..VAD_FRAME_SIZE).collect();

                        // --- Silero VAD 推論実行 ---
                        // 入力テンソルの作成 (現在のフレーム、サンプリングレート、隠れ状態)
                        let input_tensor = ort::inputs![
                            "input" => ort::Tensor::from_array(([1, VAD_FRAME_SIZE], frame.clone()))?,
                            "sr" => ort::Tensor::from_array(([], [TARGET_SAMPLE_RATE as i64]))?,
                            "h" => ort::Tensor::from_array(([2, 1, 64], _h.clone()))?,
                            "c" => ort::Tensor::from_array(([2, 1, 64], _c.clone()))?
                        ]?;

                        let outputs = vad_session.run(input_tensor)?;
                        
                        // 話者確率 (Speech Probability) の抽出
                        let output_tensor = outputs.get("output").unwrap();
                        let speech_prob = output_tensor.try_extract_tensor::<f32>()?[0];

                        // 隠れ状態の更新 (次のフレームへの文脈引き継ぎ)
                        if let Some(h_out) = outputs.get("hn") {
                            _h = h_out.try_extract_tensor::<f32>()?.to_owned().into_raw_vec();
                        }
                        if let Some(c_out) = outputs.get("cn") {
                            _c = c_out.try_extract_tensor::<f32>()?.to_owned().into_raw_vec();
                        }

                        // 発話検知閾値（0.5以上で人間が話していると判定）
                        if speech_prob > 0.5 {
                            // Gemini Live API が要求する 16-bit PCM (i16) へ最速変換
                            let pcm_data: Vec<i16> = frame
                                .iter()
                                .map(|&s| (s * i16::MAX as f32).clamp(i16::MIN as f32, i16::MAX as f32) as i16)
                                .collect();
                            
                            // Dart(Flutter)層へ遅延ゼロでストリーミング送出
                            if flutter_sink.add(pcm_data).is_err() {
                                break; // Flutter側がストリームを閉じたら終了
                            }
                        } else {
                            // 無音区間と判定された場合はデータを破棄（間引き）
                            // ※ 必要に応じて、完全に通信を絶つのではなく無音フレーム（ゼロデータ）を
                            // 固定周期で送ることで、Gemini Live 側のセッション切断を防ぐ処理をここに挟む
                        }
                    }
                }
            }
        });

        // --- マイク入力ストリームの構築（ハードウェア直結） ---
        let stream = device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                let _ = tx.try_send(data.to_vec());
            },
            |err| {
                log::error!("Audio input stream error: {}", err);
            },
            None,
        )?;

        stream.play()?;
        self.stream = Some(stream);

        Ok(())
    }

    /// 音声キャプチャを安全に停止し、ハードウェア資源を解放する
    pub fn stop_pipeline(&mut self) -> Result<()> {
        let mut is_recording = self.is_recording.lock().unwrap();
        *is_recording = false;
        if let Some(stream) = self.stream.take() {
            stream.pause()?;
        }
        Ok(())
    }
}
