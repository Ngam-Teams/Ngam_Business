// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

void reloadWebPwaImpl([String? versionTag]) {
  final ver = (versionTag != null && versionTag.isNotEmpty)
      ? versionTag
      : DateTime.now().millisecondsSinceEpoch.toString();

  try {
    if (js.context.hasProperty('ngamReloadPwa')) {
      js.context.callMethod('ngamReloadPwa', [ver]);
      return;
    }
  } catch (_) {}

  Future<void>(() async {
    try {
      final sw = html.window.navigator.serviceWorker;
      if (sw != null) {
        final regs = await sw.getRegistrations();
        for (final r in regs) {
          await r.unregister();
        }
      }
    } catch (_) {}
    try {
      final uri = Uri.parse(html.window.location.href);
      final params = Map<String, String>.from(uri.queryParameters);
      params['_v'] = ver;
      html.window.location.replace(uri.replace(queryParameters: params).toString());
    } catch (_) {
      html.window.location.reload();
    }
  });
}
