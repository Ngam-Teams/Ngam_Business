import 'pwa_reloader_stub.dart' if (dart.library.js) 'pwa_reloader_web.dart';

void reloadWebPwa([String? versionTag]) {
  reloadWebPwaImpl(versionTag);
}
