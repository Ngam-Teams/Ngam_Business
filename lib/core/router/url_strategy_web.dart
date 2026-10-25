// =============================================================================
// url_strategy_web.dart
// Web implementation – removes '#' from URL and enables HTML5 path routing.
// =============================================================================

// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

void configureUrlStrategy() {
  usePathUrlStrategy();
}
