import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

// =============================================================================
// VideoCompressionService — Pemampat Video Pintar (Auto 720p H.264 Compressor)
// Mengurangkan saiz fail video sehingga 70%-90% untuk kelajuan muat naik
// dan penstriman pantas tanpa sekat di suapan TikTok/Reels.
// =============================================================================

class CompressionResult {
  final Uint8List bytes;
  final int originalSize;
  final int compressedSize;
  final String path;
  final double reductionPercent;

  CompressionResult({
    required this.bytes,
    required this.originalSize,
    required this.compressedSize,
    required this.path,
    required this.reductionPercent,
  });
}

class VideoCompressionService {
  static final VideoCompressionService _instance =
      VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  Subscription? _progressSub;

  /// Memampatkan fail video kepada resolusi 720p H.264
  Future<CompressionResult> compressVideo({
    required String filePath,
    required Uint8List originalBytes,
    void Function(double progress)? onProgress,
  }) async {
    final originalSize = originalBytes.lengthInBytes;

    // Pada Web / Desktop emulator, VideoCompress tidak mempunyai pemacu natif
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!isMobile) {
      debugPrint('[VideoCompress] Platform bukan Android/iOS (Web/Desktop). Pemampatan perkakasan dilangkau.');
      if (onProgress != null) onProgress(1.0);
      return CompressionResult(
        bytes: originalBytes,
        originalSize: originalSize,
        compressedSize: originalSize,
        path: filePath,
        reductionPercent: 0.0,
      );
    }

    try {
      // Langgan perkembangan pemampatan
      _progressSub?.unsubscribe();
      _progressSub = VideoCompress.compressProgress$.subscribe((p) {
        if (onProgress != null) {
          onProgress(p / 100.0);
        }
      });

      debugPrint('[VideoCompress] Mula memampatkan video dari: $filePath (Saiz: ${(originalSize / (1024 * 1024)).toStringAsFixed(1)} MB)');

      final info = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.MediumQuality, // 720p H.264
        deleteOrigin: false,
        includeAudio: true,
      );

      _progressSub?.unsubscribe();

      if (info != null && info.file != null) {
        final compressedBytes = await info.file!.readAsBytes();
        final compressedSize = compressedBytes.lengthInBytes;
        final reduction = originalSize > 0
            ? ((originalSize - compressedSize) / originalSize) * 100.0
            : 0.0;

        debugPrint(
            '[VideoCompress] Selesai mampat! ${(originalSize / (1024 * 1024)).toStringAsFixed(1)} MB -> ${(compressedSize / (1024 * 1024)).toStringAsFixed(1)} MB (Jimat ${reduction.toStringAsFixed(1)}%)');

        return CompressionResult(
          bytes: compressedBytes,
          originalSize: originalSize,
          compressedSize: compressedSize,
          path: info.file!.path,
          reductionPercent: reduction,
        );
      }
    } catch (e) {
      debugPrint('[VideoCompress] Ralat semasa memampatkan video: $e. Menggunakan fail asal.');
    } finally {
      _progressSub?.unsubscribe();
    }

    // Fallback sekiranya pemampatan gagal
    return CompressionResult(
      bytes: originalBytes,
      originalSize: originalSize,
      compressedSize: originalSize,
      path: filePath,
      reductionPercent: 0.0,
    );
  }

  /// Bersihkan fail-fail sementara dalam memori peranti
  Future<void> disposeCache() async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        await VideoCompress.deleteAllCache();
      }
    } catch (_) {}
  }
}
