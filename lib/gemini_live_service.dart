import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// LIRIDGE CORE NETWORK: Gemini Live API WebSocket Bridge
class GeminiLiveService {
  WebSocketChannel? _channel;
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  final StreamController<List<int>> _audioStreamController = StreamController<List<int>.broadcast();

  Stream<String> get textStream => _textStreamController.stream;
  Stream<List<int>> get audioStream => _audioStreamController.stream;

  bool get isConnected => _channel != null;

  /// Gemini Live API (BidiGenerateContent) への接続シーケンス開始
  Future<void> connect(String apiKey) async {
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\$apiKey');
    _channel = WebSocketChannel.connect(uri);

    // [INITIAL SETUP] 生体リンク確立時の初期設定（音声・テキストの双方向出力を要求）
    final setupMsg = {
      "setup": {
        "model": "models/gemini-2.0-flash-exp",
        "generationConfig": {
          "responseModalities": ["AUDIO", "TEXT"],
          "speechConfig": {
            "voiceConfig": {
              "prebuiltVoiceConfig": {
                "voiceName": "Aoede" // 指定の音声モデル（Sci-Fiライクな冷徹かつクリアな声帯）
              }
            }
          }
        }
      }
    };
    _channel!.sink.add(jsonEncode(setupMsg));

    // 着弾データの監視ループ
    _channel!.stream.listen((message) {
      _handleServerMessage(message);
    }, onDone: () {
      disconnect();
    }, onError: (error) {
      print('[SYSTEM ERROR] CONNECTION LOST: \$error');
      disconnect();
    });
  }

  /// サーバーから降ってくるリアルタイムデータの解読
  void _handleServerMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        
        // serverContentが存在する場合、テキストと音声チャンクを分離してストリームへ流す
        if (data['serverContent'] != null && data['serverContent']['modelTurn'] != null) {
          final parts = data['serverContent']['modelTurn']['parts'] as List<dynamic>;
          for (var part in parts) {
            // ① テキストデータの抽出
            if (part['text'] != null) {
              _textStreamController.add(part['text']);
            }
            // ② 音声データ（Base64 PCM）の抽出とデコード
            if (part['inlineData'] != null && part['inlineData']['data'] != null) {
              final audioBytes = base64Decode(part['inlineData']['data']);
              _audioStreamController.add(audioBytes);
            }
          }
        }
      } catch (e) {
        print('[SYSTEM ERROR] DATA PARSE FAILED: \$e');
      }
    }
  }

  /// ユーザーの音声（24kHz PCM）をBase64に変換し、Geminiの脳髄へ直接撃ち込む
  void sendPcmAudio(List<int> pcmBytes) {
    if (!isConnected) return;
    
    final base64Audio = base64Encode(pcmBytes);
    final msg = {
      "realtimeInput": {
        "mediaChunks": [
          {
            "mimeType": "audio/pcm;rate=24000",
            "data": base64Audio
          }
        ]
      }
    };
    _channel!.sink.add(jsonEncode(msg));
  }

  /// リンク切断
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// リソースの完全解放
  void dispose() {
    disconnect();
    _textStreamController.close();
    _audioStreamController.close();
  }
}
