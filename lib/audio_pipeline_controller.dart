import 'dart:async';
import 'gemini_live_service.dart';
import 'audio_playback_service.dart';

/// LIRIDGE CORE NETWORK: Audio Pipeline Controller
/// 音声の入力（マイク/Rust）と出力（Gemini/スピーカー）を統括するメインコントローラー
class AudioPipelineController {
  final GeminiLiveService _geminiService;
  final AudioPlaybackService _audioService;
  
  StreamSubscription<List<int>>? _geminiAudioSub;
  StreamSubscription<String>? _geminiTextSub;

  AudioPipelineController({
    required GeminiLiveService geminiService,
    required AudioPlaybackService audioService,
  })  : _geminiService = geminiService,
        _audioService = audioService;

  /// パイプラインの初期化と各モジュールのリンク接続
  Future<void> initialize(String apiKey) async {
    print('[SYSTEM] Booting Audio Pipeline...');
    
    // 1. スピーカー側の初期化
    await _audioService.init();

    // 2. Gemini Live APIへの接続
    await _geminiService.connect(apiKey);

    // 3. 神経網の結合（Geminiからの出力チャンクをそのまま再生エンジンへ流し込む）
    _geminiAudioSub = _geminiService.audioStream.listen((audioChunk) {
      _audioService.playAudioChunk(audioChunk);
    });

    // 4. テキストストリームの監視（UIコンソール表示用）
    _geminiTextSub = _geminiService.textStream.listen((text) {
      print('[GEMINI] \$text');
    });

    print('[SYSTEM] Audio Pipeline Linked and Operational.');
  }

  /// ユーザーの音声入力ストリーム（マイク・Rustコア側から）をGeminiの脳髄へ直接送信
  void processUserInput(List<int> pcmData) {
    if (_geminiService.isConnected) {
      _geminiService.sendPcmAudio(pcmData);
    } else {
      print('[SYSTEM WARNING] Connection offline. Cannot send audio.');
    }
  }

  /// パイプラインの完全停止と全リソースのパージ
  void shutdown() {
    print('[SYSTEM] Shutting down Audio Pipeline...');
    _geminiAudioSub?.cancel();
    _geminiTextSub?.cancel();
    _geminiService.dispose();
    _audioService.dispose();
    print('[SYSTEM] Pipeline Offline.');
  }
}
