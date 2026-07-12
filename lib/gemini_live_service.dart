// ignore_for_file: type=lint
import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// LIRIDGE CORE NETWORK: Gemini Live API WebSocket Bridge (Native Hybrid Ver.)
/// Geminiの双方向ストリーミングAPI（BidiGenerateContent）と直結し、
/// ユーザーの音声送信と、Geminiからの音声・テキストの超低遅延受信を統括する。
class GeminiLiveService {
  WebSocketChannel? _channel;
  
  // ストリームコントローラーのブロードキャスト型エラーを修正
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  final StreamController<List<int>> _audioStreamController = StreamController<List<int>>.broadcast();

  Stream<String> get textStream => _textStreamController.stream;
  Stream<List<int>> get audioStream => _audioStreamController.stream;

  bool get isConnected => _channel != null;

  /// Gemini Live API への接続シーケンス開始
  Future<void> connect(String apiKey) async {
    if (isConnected) return;
    print('[SYSTEM] Initializing Neural Link to Gemini Live API...');

    // 2026年現在も最速を誇るリアルタイムAPIエンドポイント
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey');
    
    try {
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
      print('[SYSTEM] Setup message dispatched. Synapse connection initialized.');

      // 着弾データの監視ループ
      _channel!.stream.listen((message) {
        _handleServerMessage(message);
      }, onDone: () {
        print('[SYSTEM] Connection closed by server.');
        disconnect();
      }, onError: (error) {
        print('[SYSTEM ERROR] CONNECTION LOST: $error');
        disconnect();
      });
    } catch (e) {
      print('[SYSTEM ERROR] Failed to connect to Gemini Neural Network: $e');
      disconnect();
    }
  }

  /// サーバーから降ってくるリアルタイムデータの解読
  void _handleServerMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        
        // 安全な型チェックにより、空のデータや構造変化によるクラッシュを物理的に防ぐ
        if (data is Map && data['serverContent'] != null && data['serverContent']['modelTurn'] != null) {
          final modelTurn = data['serverContent']['modelTurn'];
          if (modelTurn['parts'] != null && modelTurn['parts'] is List) {
            final parts = modelTurn['parts'] as List;
            for (var part in parts) {
              if (part is Map) {
                // ① テキストデータの抽出（字幕・翻訳UIへパス）
                if (part['text'] != null && part['text'].toString().isNotEmpty) {
                  _textStreamController.add(part['text'].toString());
                }
                // ② 音声データ（Base64 PCM）の抽出とデコード（オーディオエンジンへパス）
                if (part['inlineData'] != null && part['inlineData']['data'] != null) {
                  final audioBytes = base64Decode(part['inlineData']['data'].toString());
                  _audioStreamController.add(audioBytes);
                }
              }
            }
          }
        }
      } catch (e) {
        print('[SYSTEM ERROR] DATA PARSE FAILED: $e');
      }
    }
  }

  /// ユーザーの音声（24kHz PCM）をBase64に変換し、Geminiの脳髄へ直接撃ち込む
  void sendPcmAudio(List<int> pcmBytes) {
    if (!isConnected || pcmBytes.isEmpty) return;
    
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
    _channel?.sink.add(jsonEncode(msg));
  }

  /// リンク切断
  void disconnect() {
    if (_channel != null) {
      _channel?.sink.close();
      _channel = null;
      print('[SYSTEM] Neural Link Disconnected.');
    }
  }

  /// リソースの完全解放
  void dispose() {
    disconnect();
    _textStreamController.close();
    _audioStreamController.close();
    print('[SYSTEM] Gemini Service Completely Purged.');
  }
}
