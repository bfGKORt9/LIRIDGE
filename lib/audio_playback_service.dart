// ignore_for_file: type=lint
import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _player.setAudioSource(_playlist);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio: $e');
    }
  }

  Future<void> playAudioChunk(List<int> pcmBytes) async {
    if (!_isInitialized || pcmBytes.isEmpty) return;
    try {
      final wavBytes = _convertToWav(Uint8List.fromList(pcmBytes), 24000, 1, 16);
      final source = _BufferAudioSource(wavBytes);
      await _playlist.add(source);
      if (!_player.playing) {
        _player.play();
      }
    } catch (e) {
      print('Error playing chunk: $e');
    }
  }

  Future<void> stopPlayback() async {
    if (!_isInitialized) return;
    await _player.stop();
    await _playlist.clear();
  }

  void dispose() {
    stopPlayback();
    _player.dispose();
    _isInitialized = false;
  }

  Uint8List _convertToWav(Uint8List pcmData, int sampleRate, int numChannels, int bitsPerSample) {
    final int subChunk2Size = pcmData.length;
    final int chunkSize = 36 + subChunk2Size;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;

    final ByteData header = ByteData(44);
    
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6d); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); 
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, subChunk2Size, Endian.little);

    final Uint8List wavFile = Uint8List(44 + pcmData.length);
    wavFile.setRange(0, 44, header.buffer.asUint8List());
    wavFile.setRange(44, wavFile.length, pcmData);
    
    return wavFile;
  }
}

class _BufferAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  _BufferAudioSource(this._buffer) : super(tag: 'PcmWavChunk');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final int actualStart = start ?? 0;
    final int actualEnd = end ?? _buffer.length;
    
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: actualEnd - actualStart,
      offset: actualStart,
      stream: Stream.value(_buffer.sublist(actualStart, actualEnd)),
      contentType: 'audio/wav',
    );
  }
}
