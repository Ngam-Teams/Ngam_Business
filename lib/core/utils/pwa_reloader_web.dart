// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void reloadWebPwaImpl([String? versionTag]) {
  try {
    js.context.callMethod('ngamReloadPwa', [versionTag ?? '']);
  } catch (_) {}
}
