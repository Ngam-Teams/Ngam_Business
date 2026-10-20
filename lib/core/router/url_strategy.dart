// =============================================================================
// url_strategy.dart
// Conditional export / router config to configure clean HTML5 URLs on web.
// =============================================================================

import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart'
    if (dart.library.html) 'url_strategy_web.dart';

void setCleanUrlStrategy() {
  configureUrlStrategy();
}
