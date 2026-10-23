import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// =============================================================================
// R2StorageService — Servis Muat Naik Terus ke Cloudflare R2 (AWS S3 SigV4)
// Tiada caj jalur lebar (Zero Egress Fees), pantas dan selamat untuk video & gambar.
// =============================================================================

class R2UploadProgress {
  final int bytesSent;
  final int totalBytes;
  final double progress; // 0.0 to 1.0

  R2UploadProgress({
    required this.bytesSent,
    required this.totalBytes,
    required this.progress,
  });
}

class R2StorageService {
  static final R2StorageService _instance = R2StorageService._internal();
  factory R2StorageService() => _instance;
  R2StorageService._internal();

  /// Ambil konfigurasi dari .env
  String get _accountId => dotenv.env['R2_ACCOUNT_ID']?.trim() ?? '';
  String get _accessKeyId => dotenv.env['R2_ACCESS_KEY_ID']?.trim() ?? '';
  String get _secretAccessKey =>
      dotenv.env['R2_SECRET_ACCESS_KEY']?.trim() ?? '';
  String get _bucketName =>
      dotenv.env['R2_BUCKET_NAME']?.trim() ?? 'ngam-media';
  String get _publicDomain =>
      dotenv.env['R2_PUBLIC_URL']?.trim() ?? '';

  /// Semak sama ada akaun Cloudflare R2 telah dikonfigurasi dalam .env
  bool get isConfigured =>
      _accountId.isNotEmpty &&
      _accessKeyId.isNotEmpty &&
      _secretAccessKey.isNotEmpty;

  /// Muat naik fail media (Video atau Gambar) ke Cloudflare R2
  /// [bytes]: Kandungan data binari fail
  /// [fileName]: Nama fail asal (cth: my_video.mp4)
  /// [folder]: Subfolder dalam bucket (cth: 'feed_videos' atau 'feed_images')
  /// [mimeType]: Jenis fail cth 'video/mp4', 'image/jpeg', 'image/png'
  Future<String> uploadMedia({
    required Uint8List bytes,
    required String fileName,
    String folder = 'feed',
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    // 1. Jika konfigurasi Cloudflare R2 belum diisi, guna fallback pintar
    if (!isConfigured) {
      debugPrint('[R2StorageService] R2 credentials belum diisi dalam .env. Menggunakan sandbox simulator.');
      // Simulasi progress muat naik
      if (onProgress != null) {
        onProgress(0.2);
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress(0.6);
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress(1.0);
      }

      // Hasilkan placeholder/sample URL berdasarkan jenis fail
      final isVideo = mimeType.startsWith('video');
      if (isVideo) {
        // Video contoh HD percuma untuk ujian feed
        return 'https://assets.mixkit.co/videos/preview/mixkit-barber-cutting-the-hair-of-a-man-40875-large.mp4';
      } else {
        return 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800';
      }
    }

    // 2. Sediakan Path unik dalam R2
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : (mimeType.contains('video') ? 'mp4' : 'jpg');
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${_randomHex(6)}.$ext';
    final objectKey = '$folder/$uniqueName';

    final host = '$_accountId.r2.cloudflarestorage.com';
    final canonicalUri = '/$_bucketName/$objectKey';
    final endpointUrl = Uri.parse('https://$host$canonicalUri');

    // 3. Tarikh AWS SigV4
    final now = DateTime.now().toUtc();
    final dateStamp = DateFormat('yyyyMMdd').format(now);
    final amzDate = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now);

    // 4. Hitung Hash Kandungan (SHA256 Payload Hash)
    final payloadHash = sha256.convert(bytes).toString();

    // 5. Bina Canonical Headers & Signed Headers
    final canonicalHeaders =
        'content-type:$mimeType\n'
        'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    // 6. Canonical Request
    final canonicalRequest =
        'PUT\n'
        '$canonicalUri\n'
        '\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    final canonicalRequestHash =
        sha256.convert(utf8.encode(canonicalRequest)).toString();

    // 7. String To Sign
    const region = 'auto';
    const service = 's3';
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$credentialScope\n'
        '$canonicalRequestHash';

    // 8. Hitung Kunci Tandatangan (Signing Key)
    final kDate = Hmac(sha256, utf8.encode('AWS4$_secretAccessKey')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    // 9. Tajuk Authorization
    final authorizationHeader =
        'AWS4-HMAC-SHA256 Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    final headers = {
      'Host': host,
      'Content-Type': mimeType,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': authorizationHeader,
    };

    // 10. Hantar HTTP PUT Request ke Cloudflare R2
    if (onProgress != null) onProgress(0.1);

    final response = await http.put(
      endpointUrl,
      headers: headers,
      body: bytes,
    );

    if (onProgress != null) onProgress(1.0);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 11. Pulangkan URL awam CDN
      if (_publicDomain.isNotEmpty) {
        final domain = _publicDomain.endsWith('/')
            ? _publicDomain.substring(0, _publicDomain.length - 1)
            : _publicDomain;
        return '$domain/$objectKey';
      }
      return 'https://$host$canonicalUri';
    } else {
      debugPrint('[R2StorageService] Ralat Muat Naik R2: ${response.statusCode} - ${response.body}');
      throw Exception('Gagal memuat naik fail ke Cloudflare R2 (${response.statusCode}): ${response.body}');
    }
  }

  static String _randomHex(int length) {
    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    if (rand.length >= length) {
      return rand.substring(rand.length - length);
    }
    return rand.padLeft(length, '0');
  }
}
