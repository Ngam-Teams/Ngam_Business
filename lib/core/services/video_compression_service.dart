import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

import 'web_compressor_stub.dart'
    if (dart.library.html) 'web_compressor_web.dart' as web_comp;

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

  /// Memampatkan fail video kepada resolusi 720p H.264 (Mobile & Web)
  Future<CompressionResult> compressVideo({
    required String filePath,
    required Uint8List originalBytes,
    void Function(double progress)? onProgress,
  }) async {
    final originalSize = originalBytes.lengthInBytes;

    // 1. Pemampatan pada Platform Web (Browser)
    if (kIsWeb) {
      debugPrint('[VideoCompress] Mula pemampatan Web (MediaRecorder 720p)... (Saiz asal: ${(originalSize / (1024 * 1024)).toStringAsFixed(1)} MB)');
      try {
        final webBytes = await web_comp.compressVideoWeb(
          blobUrl: filePath,
          originalBytes: originalBytes,
          onProgress: onProgress,
        );

        if (webBytes != null && webBytes.isNotEmpty) {
          final compressedSize = webBytes.lengthInBytes;
          final reduction = originalSize > 0
              ? ((originalSize - compressedSize) / originalSize) * 100.0
              : 0.0;

          debugPrint(
              '[VideoCompress] Web transcode siap! ${(originalSize / (1024 * 1024)).toStringAsFixed(1)} MB -> ${(compressedSize / (1024 * 1024)).toStringAsFixed(1)} MB (Jimat ${reduction.toStringAsFixed(1)}%)');

          return CompressionResult(
            bytes: webBytes,
            originalSize: originalSize,
            compressedSize: compressedSize,
            path: filePath,
            reductionPercent: reduction,
          );
        }
      } catch (err) {
        debugPrint('[VideoCompress] Ralat pemampatan Web: $err');
      }

      if (onProgress != null) onProgress(1.0);
      return CompressionResult(
        bytes: originalBytes,
        originalSize: originalSize,
        compressedSize: originalSize,
        path: filePath,
        reductionPercent: 0.0,
      );
    }

    // 2. Pemampatan pada Platform Natif (Android & iOS)
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobile) {
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

      // Guna kualiti 720p (Res1280x720Quality) pada 30fps
      var info = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      // Jika masih besar melebihi 15MB, mampatkan lagi kepada 540p (qHD)
      if (info != null && info.file != null && info.filesize != null && info.filesize! > 15 * 1024 * 1024) {
        debugPrint('[VideoCompress] Saiz masih melebihi 15MB (${(info.filesize! / (1024 * 1024)).toStringAsFixed(1)} MB). Mengoptimumkan kepada 540p...');
        final secondPass = await VideoCompress.compressVideo(
          info.file!.path,
          quality: VideoQuality.Res960x540Quality,
          deleteOrigin: true,
          includeAudio: true,
          frameRate: 30,
        );
        if (secondPass != null && secondPass.file != null) {
          info = secondPass;
        }
      }

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
