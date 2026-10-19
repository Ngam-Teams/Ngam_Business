import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

// =============================================================================
// SoundService
// Cross-platform audio chime generator & player for Ngam Business.
// Generates a melodic dual-tone chime in memory (PCM WAV) with zero network
// overhead, guaranteed to play on Web, Android, iOS, Windows, and Mac.
// =============================================================================

class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal();

  AudioPlayer? _player;
  static Uint8List? _cachedChimeWav;

  static Uint8List _getDingDongChimeWav() {
    if (_cachedChimeWav != null) return _cachedChimeWav!;

    const sampleRate = 44100;
    const duration = 0.8; // 0.8 seconds total
    final numSamples = (sampleRate * duration).toInt();
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57);  // W
    buffer.setUint8(9, 0x41);  // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt subchunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // subchunk1Size = 16 for PCM
    buffer.setUint16(20, 1, Endian.little);  // PCM = 1
    buffer.setUint16(22, 1, Endian.little);  // 1 channel (mono)
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);

    // data subchunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    // Tone 1: 0.0s - 0.32s -> 784 Hz (G5)
    // Tone 2: 0.32s - 0.8s -> 1046.5 Hz (C6)
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sample = 0;

      if (t < 0.32) {
        final decay = exp(-t * 7.5);
        sample = sin(2 * pi * 783.99 * t) * decay;
      } else {
        final t2 = t - 0.32;
        final decay = exp(-t2 * 5.5);
        sample = sin(2 * pi * 1046.50 * t2) * decay;
      }

      final int16Val = (sample * 26000).clamp(-32768, 32767).toInt();
      buffer.setInt16(44 + i * 2, int16Val, Endian.little);
    }

    _cachedChimeWav = buffer.buffer.asUint8List();
    return _cachedChimeWav!;
  }

  /// Plays a pleasant dual-tone chime for incoming orders
  Future<void> playOrderChime() async {
    try {
      _player ??= AudioPlayer();
      final wavBytes = _getDingDongChimeWav();
      await _player!.play(BytesSource(wavBytes), volume: 1.0);
    } catch (e) {
      debugPrint('[SoundService] AudioPlayer chime error: $e');
    }

    // On non-web native mobile platforms, also trigger native notification ringtone as fallback
    if (!kIsWeb) {
      try {
        FlutterRingtonePlayer().playNotification();
      } catch (_) {}
    }
  }

  void stop() {
    try {
      _player?.stop();
    } catch (_) {}
    if (!kIsWeb) {
      try {
        FlutterRingtonePlayer().stop();
      } catch (_) {}
    }
  }
}
