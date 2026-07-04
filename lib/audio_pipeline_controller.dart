import 'dart:async';
import 'gemini_live_service.dart';
import 'audio_playback_service.dart';

/// LIRIDGE CORE NETWORK: Audio Pipeline Controller (Native Hybrid Ver.)
/// マイクからの入力と、Geminiからの出力（音声・テキスト）を統括し、
/// iOS/AndroidのネイティブUIへデータを流し込む中枢神経
class AudioPipelineController {
  final GeminiLiveService _geminiService;
  final AudioPlaybackService _audioService;
  
  // 【追加】ネイティブUI（PiP/ダイナミックアイランド/フローティング）へ字幕を転送するためのバイパス
  final void Function(String text)? onTextReceived;
  
  StreamSubscription<List<int>>? _geminiAudioSub;
  StreamSubscription<String>? _geminiTextSub;

  AudioPipelineController({
    required GeminiLiveService geminiService,
    required AudioPlaybackService audioService,
    this.onTextReceived, // UI層からの口（コールバック）を受け取る
  })  : _geminiService = geminiService,
        _audioService = audioService;

  /// パイプラインの初期化（ネイティブ環境に最適化）
  Future<void> initialize(String apiKey) async {
    print('[SYSTEM] Booting Audio Pipeline for Native Environment...');
    
    // 1. スピーカー（音声再生エンジン）の初期化
    await _audioService.init();

    // 2. Gemini Live APIへのWebSocket接続
    await _geminiService.connect(apiKey);

    // 3. 【出力分岐 A：聴覚】Geminiからの音声チャンクを再生エンジンへ直結
    _geminiAudioSub = _geminiService.audioStream.listen((audioChunk) {
      _audioService.playAudioChunk(audioChunk);
    });

    // 4. 【出力分岐 B：視覚】Geminiからのテキストを監視し、ネイティブUI側へ転送
    _geminiTextSub = _geminiService.textStream.listen((text) {
      print('[GEMINI CONSOLE] $text');
      // 登録されたネイティブUI（iOS App GroupやAndroid MethodChannel等）へデータを流す
      if (onTextReceived != null) {
        onTextReceived!(text);
      }
    });

    print('[SYSTEM] Audio Pipeline Linked and Operational.');
  }

  /// ユーザーの音声入力（マイクからのPCMデータ）をGeminiの脳髄へ直接送信
  void processUserInput(List<int> pcmData) {
    if (_geminiService.isConnected) {
      _geminiService.sendPcmAudio(pcmData);
    } else {
      print('[SYSTEM WARNING] Connection offline. Dropping audio frame.');
    }
  }

  /// バックグラウンド移行時やアプリ終了時のリソース完全パージ（メモリリーク防止）
  void shutdown() {
    print('[SYSTEM] Shutting down Audio Pipeline...');
    _geminiAudioSub?.cancel();
    _geminiTextSub?.cancel();
    _geminiService.dispose();
    _audioService.dispose();
    print('[SYSTEM] Pipeline Offline.');
  }
}
