// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

Future<Uint8List?> compressVideoWeb({
  required String blobUrl,
  required Uint8List originalBytes,
  void Function(double progress)? onProgress,
}) async {
  // If original file is already lightweight (under 6MB), no need to re-encode
  if (originalBytes.lengthInBytes <= 6 * 1024 * 1024) {
    debugPrint('[WebCompress] File is already under 6MB, using original bytes.');
    return originalBytes;
  }

  final completer = Completer<Uint8List?>();

  try {
    js.context.callMethod('compressVideoWeb', [
      blobUrl,
      720, // maxW
      1280, // maxH
      1500000, // 1.5 Mbps
      js.allowInterop((dynamic p) {
        if (onProgress != null && p is num) {
          onProgress(p.toDouble());
        }
      }),
      js.allowInterop((dynamic bytes, dynamic mime) {
        if (bytes is Uint8List) {
          completer.complete(bytes);
        } else if (bytes is List) {
          completer.complete(Uint8List.fromList(bytes.cast<int>()));
        } else {
          completer.complete(originalBytes);
        }
      }),
      js.allowInterop((dynamic err) {
        debugPrint('[WebCompress] Transcode error: $err');
        completer.complete(null);
      }),
    ]);
  } catch (e) {
    debugPrint('[WebCompress] JS call failed: $e');
    completer.complete(null);
  }

  return completer.future;
}
