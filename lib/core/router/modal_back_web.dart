// =============================================================================
// modal_back_web.dart
// Web/PWA implementation that intercepts browser/Android-Chrome Back gestures
// in capture phase so open BottomSheets & Dialogs close BEFORE GoRouter
// navigates away from the underlying page.
// =============================================================================

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

const String _kModalStateKey = 'ngam_modal_id';

bool _listenerRegistered = false;
int _ignoreNextPopStates = 0;
bool Function()? _onBrowserBackCallback;

int? _readCurrentSentinelId() {
  try {
    final state = html.window.history.state;
    if (state is Map && state.containsKey(_kModalStateKey)) {
      final raw = state[_kModalStateKey];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
  } catch (_) {}
  return null;
}

void registerWebModalBackListener(bool Function() onBrowserBack) {
  _onBrowserBackCallback = onBrowserBack;
  if (_listenerRegistered) return;
  _listenerRegistered = true;

  // Use capture phase (useCapture: true) so we run BEFORE Flutter's
  // BrowserHistory / GoRouter popstate listener.
  html.window.addEventListener('popstate', (html.Event event) {
    if (_ignoreNextPopStates > 0) {
      _ignoreNextPopStates--;
      event.stopImmediatePropagation();
      return;
    }

    final handled = _onBrowserBackCallback?.call() ?? false;
    if (handled) {
      // Stop GoRouter from navigating the background page!
      event.stopImmediatePropagation();
    }
  }, true);
}

void pushWebModalHistorySentinel(int modalId) {
  try {
    html.window.history.pushState(
      <String, dynamic>{_kModalStateKey: modalId},
      '',
      html.window.location.href,
    );
  } catch (_) {}
}

void popWebModalHistorySentinelIfTop(int modalId) {
  // Run in microtask so if the same tap handler also called context.push/go,
  // window.history.state will already belong to the new route and we won't
  // accidentally pop the new route.
  Future.microtask(() {
    try {
      if (_readCurrentSentinelId() == modalId) {
        _ignoreNextPopStates++;
        html.window.history.back();
      }
    } catch (_) {}
  });
}
