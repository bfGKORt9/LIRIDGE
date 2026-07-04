import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// LIRIDGE CORE NETWORK: Gemini Live API WebSocket Bridge (Native Hybrid Ver.)
/// GeminiのMultimodal Live API（BidiGenerateContent）との双方向リアルタイム通信を管理するコア
class GeminiLiveService {
  WebSocketChannel? _channel;
  
  // 【修正済】構文エラーを修正し、複数のUIウィジェットから監視できるbroadcastストリームに統一
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  final StreamController<List<int>> _audioStreamController = StreamController<List<int>>.broadcast();

  Stream<String> get textStream => _textStreamController.stream;
  Stream<List<int>> get audioStream => _audioStreamController.stream;

  bool get isConnected => _channel != null;

  /// Gemini Live APIへの接続シーケンス開始
  Future<void> connect(String apiKey) async {
    if (isConnected) return;
    print('[SYSTEM] Initializing WebSocket link to Gemini Brain...');

    try {
      final uri = Uri.parse(
          'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey');
      
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
      print('[SYSTEM] WebSocket Link Established. Setup protocol sent.');

      // 着弾データの監視ループ（ネイティブ環境のエラーハンドリングを強化）
      _channel!.stream.listen(
        (message) {
          _handleServerMessage(message);
        },
        onDone: () {
          print('[SYSTEM WARNING] WebSocket connection closed by server.');
          disconnect();
        },
        onError: (error) {
          print('[SYSTEM ERROR] WebSocket connection lost: $error');
          disconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('[SYSTEM CRITICAL] Failed to connect WebSocket: $e');
      disconnect();
    }
  }

  /// サーバーから降ってくるリアルタイムデータの解読と振り分け
  void _handleServerMessage(dynamic message) {
    if (message is! String) return;

    try {
      final data = jsonDecode(message);
      
      // serverContentが存在する場合、テキストと音声チャンクを分離してストリームへ流す
      if (data['serverContent'] != null && data['serverContent']['modelTurn'] != null) {
        final parts = data['serverContent']['modelTurn']['parts'] as List<dynamic>;
        
        for (var part in parts) {
          // ① テキストデータの抽出
          if (part['text'] != null) {
            _textStreamController.add(part['text'].toString());
          }
          
          // ② 音声データ（Base64 PCM）の抽出とデコード
          if (part['inlineData'] != null && part['inlineData']['data'] != null) {
            final String base64String = part['inlineData']['data'];
            // 欠落やパディング異常を防ぐための安全なデコード
            final audioBytes = base64Decode(base64String.replaceAll(RegExp(r'\s+'), ''));
            _audioStreamController.add(audioBytes);
          }
        }
      }
    } catch (e) {
      print('[SYSTEM ERROR] Data parse failed during server message handling: $e');
    }
  }

  /// ユーザーの音声（24kHz PCM）をBase64に変換し、Geminiの脳髄へ直接送信
  void sendPcmAudio(List<int> pcmBytes) {
    if (!isConnected) {
      print('[SYSTEM WARNING] Cannot send audio. Link is offline.');
      return;
    }
    
    try {
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
    } catch (e) {
      print('[SYSTEM ERROR] Failed to encode and send audio frame: $e');
    }
  }

  /// リンク切断
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      print('[SYSTEM] WebSocket Link Offline.');
    }
  }

  /// リソースの完全解放（アプリ終了時）
  void dispose() {
    disconnect();
    _textStreamController.close();
    _audioStreamController.close();
    print('[SYSTEM] Gemini Service Disposed.');
  }
}
