import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveAndDownloadFile({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  Directory? targetDir;
  try {
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        targetDir = downloadDir;
      } else {
        targetDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }
  } catch (_) {
    targetDir = await getApplicationDocumentsDirectory();
  }

  final file = File('${targetDir!.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  try {
    await OpenFilex.open(file.path);
  } catch (_) {}

  return file.path;
}
