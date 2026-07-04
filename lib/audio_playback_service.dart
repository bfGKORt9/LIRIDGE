import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// LIRIDGE CORE NETWORK: Audio Playback Engine (Native Hybrid Ver.)
/// Geminiから受信した生PCM（24kHz/16bit/Mono）音声ストリームにWAVヘッダを動的付与し、
/// `just_audio` を用いてバックグラウンド（TikTok裏）でも低遅延で連続再生する機構。
class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  
  // 音声チャンクを途切れなく滑らかに連続再生するための連結ソース（再生キュー）
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  /// オーディオエンジンの起動シーケンス
  Future<void> init() async {
    if (_isInitialized) return;
    print('[SYSTEM] Booting Audio Playback Engine (just_audio)...');

    try {
      // 内部プレイヤーに動的プレイリストを直結
      await _player.setAudioSource(_playlist);
      _isInitialized = true;
      print('[SYSTEM] Audio Playback Engine Initialized. Ready for output.');
    } catch (e) {
      print('[SYSTEM ERROR] Failed to initialize Audio Playback Engine: $e');
    }
  }

  /// Geminiから受信した音声チャンク（生PCMデータ）を再生キューに投入
  Future<void> playAudioChunk(List<int> pcmBytes) async {
    if (!_isInitialized || pcmBytes.isEmpty) return;

    try {
      // 1. 生PCMデータにWAVヘッダ（44バイト）を高速付与し、OS標準デコーダーが読める形式に偽装
      final wavBytes = _convertToWav(Uint8List.fromList(pcmBytes), 24000, 1, 16);
      
      // 2. メモリ上のWAVデータからjust_audio用の軽量ソースを生成
      final source = _BufferAudioSource(wavBytes);
      
      // 3. 再生キューの末尾にチャンクを追加
      await _playlist.add(source);

      // 4. 再生が停止している（最初のチャンク、または無音を挟んだ後）なら自動点火
      if (!_player.playing) {
        _player.play();
      }
      print('[SYSTEM] Injected audio chunk into playlist. (Size: ${pcmBytes.length} bytes)');
    } catch (e) {
      print('[SYSTEM WARNING] Failed to play audio chunk: $e');
    }
  }

  /// 再生の強制停止とバッファの完全フラッシュ（ユーザー割り込み時・次発話開始時）
  Future<void> stopPlayback() async {
    if (!_isInitialized) return;
    await _player.stop();
    await _playlist.clear(); // 溜まっている音声チャンクを全て消去
    print('[SYSTEM] Audio Playback Interrupted and Playlist Flushed.');
  }

  /// リソースの完全解放
  void dispose() {
    stopPlayback();
    _player.dispose();
    _isInitialized = false;
    print('[SYSTEM] Audio Playback Engine Offline.');
  }

  /// 【超高速処理】生PCM（Linear PCM）にWAVヘッダを動的付与するヘルパー関数
  Uint8List _convertToWav(Uint8List pcmData, int sampleRate, int numChannels, int bitsPerSample) {
    final int subChunk2Size = pcmData.length;
    final int chunkSize = 36 + subChunk2Size;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;

    final ByteData header = ByteData(44);
    
    // RIFFコンテナ構造の定義
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt チャンク（フォーマット情報）
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // 
    header.setUint32(16, 16, Endian.little); 
    header.setUint16(20, 1, Endian.little); // 1 = 圧縮なしPCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data チャンク（波形データ本体のサイズ指定）
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, subChunk2Size, Endian.little);

    final Uint8List wavFile = Uint8List(44 + pcmData.length);
    wavFile.setRange(0, 44, header.buffer.asUint8List());
    wavFile.setRange(44, wavFile.length, pcmData);
    
    return wavFile;
  }
}

/// メモリ内のWAVバイト配列をそのままjust_audioに引き渡すためのカスタムストリームソース
class _BufferAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  _BufferAudioSource(this._buffer) : super(tag: 'PcmWavChunk');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final int actualStart = start ?? 0;
    final int actualEnd = end ?? _buffer.length;
    return StreamAudioResponse(
      source: Stream.value(_buffer.sublist(actualStart, actualEnd)),
      contentType: 'audio/wav',
      contentLength: actualEnd - actualStart,
      offset: actualStart,
    );
  }
}
