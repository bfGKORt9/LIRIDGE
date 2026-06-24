pub mod core;

use crate::core::LiridgeAudioCore;
use std::sync::OnceLock;
use std::sync::Mutex;

// LIRIDGEの音声コアを安全にグローバル保持するための静的コンテナ
// これにより、Flutter側から「開始」「停止」の命令をいつでも同一のインスタンスに対して安全に送ることができる
static AUDIO_CORE: OnceLock<Mutex<LiridgeAudioCore>> = OnceLock::new();

/// 内部的にオーディオコアのシングルトンインスタンスを取得する
fn get_core() -> &'static Mutex<LiridgeAudioCore> {
    AUDIO_CORE.get_or_init(|| Mutex::new(LiridgeAudioCore::new()))
}

/// 【Flutter専用窓口】LIRIDGEのCI2I音声パイプラインを起動する
/// * `model_bytes`: Flutter側のアセットから読み込まれた Silero VAD (.onnx) のバイナリデータ
/// * `flutter_sink`: Rustが検知した発話音声（i16 PCM）を、Dart側へ遅延ゼロでリアルタイム逆流させるためのストリーム
pub fn start_liridge_pipeline(
    model_bytes: Vec<u8>,
    flutter_sink: flutter_rust_bridge::StreamSink<Vec<i16>>,
) -> String {
    let mut core = get_core().lock().unwrap();
    match core.start_pipeline(&model_bytes, flutter_sink) {
        Ok(_) => "SUCCESS".to_string(),
        Err(e) => format!("ERROR: {}", e),
    }
}

/// 【Flutter専用窓口】LIRIDGEの音声パイプラインを安全に完全停止し、マイク等のハードウェア資源を解放する
pub fn stop_liridge_pipeline() -> String {
    let mut core = get_core().lock().unwrap();
    match core.stop_pipeline() {
        Ok(_) => "SUCCESS".to_string(),
        Err(e) => format!("ERROR: {}", e),
    }
}
