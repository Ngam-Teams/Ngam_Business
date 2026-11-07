// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveAndDownloadFile({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  String mime = mimeType ?? _resolveMimeType(fileName);

  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);

  return 'Folder Downloads Pelayar Web';
}

String _resolveMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.csv')) {
    return 'text/csv;charset=utf-8';
  } else if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  } else if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  } else if (lower.endsWith('.png')) {
    return 'image/png';
  } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  } else if (lower.endsWith('.txt')) {
    return 'text/plain;charset=utf-8';
  }
  return 'application/octet-stream';
}
