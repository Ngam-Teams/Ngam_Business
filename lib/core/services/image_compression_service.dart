import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Kategori pemampatan imej mengikut fungsi UI
enum ImageCompressionType {
  /// Logo kedai / avatar (512x512 max, mengekalkan alpha sekiranya PNG lutsinar)
  logo,

  /// Banner muka depan (1920x1080 max, Full HD panorama, 82% quality)
  cover,

  /// Gambar produk (1080x1440 max, menyokong nisbah 1:1 persegi & 3:4 potret Shopee/TikTok Shop, 80% quality)
  product,

  /// Avatar pengguna (512x512 max, 85% quality)
  avatar,

  /// Kod QR DuitNow / Bank (800x800 max, tajam & berkontras tinggi)
  qrCode,

  /// Logo resit pencetak terma (400x400 max)
  receiptLogo,

  /// Imej am (1280x1280 max, 80% quality)
  general,
}

/// Hasil pemampatan imej dengan statistik penjimatan data
class CompressedImageResult {
  final Uint8List bytes;
  final String extension; // 'jpg' atau 'png'
  final String mimeType; // 'image/jpeg' atau 'image/png'
  final int originalSize; // saiz asal dalam bait
  final int compressedSize; // saiz termampat dalam bait
  final int width;
  final int height;

  const CompressedImageResult({
    required this.bytes,
    required this.extension,
    required this.mimeType,
    required this.originalSize,
    required this.compressedSize,
    required this.width,
    required this.height,
  });

  /// Peratusan data yang dijimatkan (0% - 100%)
  double get reductionPercent => originalSize > 0
      ? (((originalSize - compressedSize) / originalSize) * 100).clamp(0, 100)
      : 0.0;

  String get originalSizeFormatted => _formatBytes(originalSize);
  String get compressedSizeFormatted => _formatBytes(compressedSize);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _CompressParams {
  final Uint8List bytes;
  final ImageCompressionType type;
  final int? customMaxWidth;
  final int? customMaxHeight;
  final int? customQuality;

  _CompressParams({
    required this.bytes,
    required this.type,
    this.customMaxWidth,
    this.customMaxHeight,
    this.customQuality,
  });
}

/// Top-level worker untuk `compute` (berjalan dalam Background Isolate)
CompressedImageResult _compressIsolateWorker(_CompressParams params) {
  final originalSize = params.bytes.lengthInBytes;

  try {
    // 1. Nyahkod imej (JPG, PNG, WebP, GIF, BMP, etc.)
    final decoded = img.decodeImage(params.bytes);
    if (decoded == null) {
      debugPrint('[ImageCompression] Gagal menyahkod fail imej. Menggunakan fail asal.');
      return CompressedImageResult(
        bytes: params.bytes,
        extension: 'jpg',
        mimeType: 'image/jpeg',
        originalSize: originalSize,
        compressedSize: originalSize,
        width: 0,
        height: 0,
      );
    }

    // 2. Tentukan had saiz & kualiti mengikut ImageCompressionType
    int maxWidth;
    int maxHeight;
    int quality;

    switch (params.type) {
      case ImageCompressionType.logo:
        maxWidth = params.customMaxWidth ?? 512;
        maxHeight = params.customMaxHeight ?? 512;
        quality = params.customQuality ?? 85;
        break;
      case ImageCompressionType.cover:
        maxWidth = params.customMaxWidth ?? 1920;
        maxHeight = params.customMaxHeight ?? 1080;
        quality = params.customQuality ?? 82;
        break;
      case ImageCompressionType.product:
        maxWidth = params.customMaxWidth ?? 1080;
        maxHeight = params.customMaxHeight ?? 1440;
        quality = params.customQuality ?? 80;
        break;
      case ImageCompressionType.avatar:
        maxWidth = params.customMaxWidth ?? 512;
        maxHeight = params.customMaxHeight ?? 512;
        quality = params.customQuality ?? 85;
        break;
      case ImageCompressionType.qrCode:
        maxWidth = params.customMaxWidth ?? 800;
        maxHeight = params.customMaxHeight ?? 800;
        quality = params.customQuality ?? 88;
        break;
      case ImageCompressionType.receiptLogo:
        maxWidth = params.customMaxWidth ?? 400;
        maxHeight = params.customMaxHeight ?? 400;
        quality = params.customQuality ?? 80;
        break;
      case ImageCompressionType.general:
        maxWidth = params.customMaxWidth ?? 1280;
        maxHeight = params.customMaxHeight ?? 1280;
        quality = params.customQuality ?? 80;
        break;
    }

    // 3. Ubah saiz secara berkadar (proportional aspect ratio)
    img.Image resized = decoded;
    if (decoded.width > maxWidth || decoded.height > maxHeight) {
      final double aspect = decoded.width / decoded.height;
      final double targetAspect = maxWidth / maxHeight;

      if (aspect > targetAspect) {
        // Lebar melebihi nisbah sasaran
        resized = img.copyResize(
          decoded,
          width: maxWidth,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      } else {
        // Tinggi melebihi nisbah sasaran
        resized = img.copyResize(
          decoded,
          height: maxHeight,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 4. Pengekodan Pintar (Smart Encoding)
    // Sekiranya logo mengandungi transparansi (alpha channel), kekalkan sebagai PNG
    final bool preserveTransparency =
        (params.type == ImageCompressionType.logo || params.type == ImageCompressionType.receiptLogo) &&
            resized.hasAlpha;

    Uint8List encodedBytes;
    String extension;
    String mimeType;

    if (preserveTransparency) {
      encodedBytes = Uint8List.fromList(img.encodePng(resized, level: 6));
      extension = 'png';
      mimeType = 'image/png';
    } else {
      encodedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      extension = 'jpg';
      mimeType = 'image/jpeg';
    }

    // 5. Sekiranya fail termampat lebih besar daripada fail asal (kes luar biasa imej kecil),
    // kekalkan fail asal
    if (encodedBytes.lengthInBytes >= originalSize && originalSize > 0) {
      return CompressedImageResult(
        bytes: params.bytes,
        extension: extension,
        mimeType: mimeType,
        originalSize: originalSize,
        compressedSize: originalSize,
        width: decoded.width,
        height: decoded.height,
      );
    }

    return CompressedImageResult(
      bytes: encodedBytes,
      extension: extension,
      mimeType: mimeType,
      originalSize: originalSize,
      compressedSize: encodedBytes.lengthInBytes,
      width: resized.width,
      height: resized.height,
    );
  } catch (e, stack) {
    debugPrint('[ImageCompression] Ralat semasa pemampatan imej: $e\n$stack');
    // Fallback selamat kepada fail asal
    return CompressedImageResult(
      bytes: params.bytes,
      extension: 'jpg',
      mimeType: 'image/jpeg',
      originalSize: originalSize,
      compressedSize: originalSize,
      width: 0,
      height: 0,
    );
  }
}

/// Servis Pemampat Imej Pintar — Menjamin logo, cover dan produk tidak membazir storan cloud
class ImageCompressionService {
  ImageCompressionService._();

  /// Mampatkan imej dalam latar belakang (*Background Isolate*) supaya UI tidak tersangkut.
  static Future<CompressedImageResult> compress({
    required Uint8List bytes,
    required ImageCompressionType type,
    int? customMaxWidth,
    int? customMaxHeight,
    int? customQuality,
  }) async {
    if (bytes.isEmpty) {
      return CompressedImageResult(
        bytes: bytes,
        extension: 'jpg',
        mimeType: 'image/jpeg',
        originalSize: 0,
        compressedSize: 0,
        width: 0,
        height: 0,
      );
    }

    return await compute(
      _compressIsolateWorker,
      _CompressParams(
        bytes: bytes,
        type: type,
        customMaxWidth: customMaxWidth,
        customMaxHeight: customMaxHeight,
        customQuality: customQuality,
      ),
    );
  }
}
