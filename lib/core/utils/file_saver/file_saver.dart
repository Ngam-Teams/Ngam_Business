import 'dart:convert';
import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart' as impl;

Future<String?> saveAndDownloadFile({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) =>
    impl.saveAndDownloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );

/// Saves a CSV string with a UTF-8 BOM so Microsoft Excel and LibreOffice
/// automatically recognize Malay/Unicode text without formatting errors.
Future<String?> saveAndDownloadCsv({
  required String csvContent,
  required String fileName,
}) async {
  // Prepend UTF-8 BOM (0xEF, 0xBB, 0xBF)
  final bom = [0xEF, 0xBB, 0xBF];
  final encoded = utf8.encode(csvContent);
  final bytes = Uint8List.fromList([...bom, ...encoded]);
  return impl.saveAndDownloadFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: 'text/csv;charset=utf-8',
  );
}

/// Saves plain text or ASCII thermal receipt slips
Future<String?> saveAndDownloadText({
  required String textContent,
  required String fileName,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(textContent));
  return impl.saveAndDownloadFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: 'text/plain;charset=utf-8',
  );
}

/// Backward compatibility alias
Future<String?> downloadStandeeImage({
  required Uint8List bytes,
  required String fileName,
}) =>
    impl.saveAndDownloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'image/png',
    );
