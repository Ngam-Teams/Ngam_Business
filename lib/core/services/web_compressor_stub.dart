import 'dart:typed_data';

Future<Uint8List?> compressVideoWeb({
  required String blobUrl,
  required Uint8List originalBytes,
  void Function(double progress)? onProgress,
}) async {
  // Stub for non-web platforms
  return null;
}
