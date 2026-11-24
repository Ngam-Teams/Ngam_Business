// =============================================================================
// modal_back_observer.dart
// Tracks active ModalBottomSheetRoute & DialogRoute instances globally on
// rootNavigatorKey so pressing Back (Android, iOS, or Web/Chrome PWA) always
// dismisses the open BottomSheet / Dialog first instead of navigating the
// page underneath.
// =============================================================================

import 'package:flutter/material.dart';

import 'modal_back_web_stub.dart'
    if (dart.library.html) 'modal_back_web.dart';

class ModalBackNavigatorObserver extends NavigatorObserver {
  ModalBackNavigatorObserver._() {
    registerWebModalBackListener(_handleWebBrowserBack);
  }

  static final ModalBackNavigatorObserver instance =
      ModalBackNavigatorObserver._();

  int _nextModalId = 1;
  bool _dismissingViaBrowserBack = false;
  final List<({Route<dynamic> route, int id})> _activeModals = [];

  bool get hasActiveModal => _activeModals.isNotEmpty;

  bool _isTrackedModal(Route<dynamic> route) {
    return route is ModalBottomSheetRoute ||
        route is DialogRoute ||
        route is RawDialogRoute;
  }

  /// Dismisses the topmost active modal (BottomSheet / Dialog) if any is open.
  /// Returns `true` if a modal was open and dismissal was triggered.
  bool dismissTopModal() {
    if (_activeModals.isEmpty) return false;
    final nav = navigator;
    if (nav == null) return false;
    nav.maybePop();
    return true;
  }

  bool _handleWebBrowserBack() {
    if (_activeModals.isEmpty) return false;
    final nav = navigator;
    if (nav == null) return false;

    final topEntry = _activeModals.last;
    _dismissingViaBrowserBack = true;
    nav.maybePop().then((didPop) {
      _dismissingViaBrowserBack = false;
      // If a non-dismissible dialog/sheet blocked the pop, re-push its sentinel
      // so the next Back press still won't navigate the background page.
      if (!didPop && _activeModals.any((e) => e.id == topEntry.id)) {
        pushWebModalHistorySentinel(topEntry.id);
      }
    }).catchError((_) {
      _dismissingViaBrowserBack = false;
    });
    return true;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isTrackedModal(route)) {
      final id = _nextModalId++;
      _activeModals.add((route: route, id: id));
      pushWebModalHistorySentinel(id);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final idx = _activeModals.lastIndexWhere((e) => e.route == route);
    if (idx >= 0) {
      final entry = _activeModals.removeAt(idx);
      if (!_dismissingViaBrowserBack) {
        popWebModalHistorySentinelIfTop(entry.id);
      }
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    final idx = _activeModals.lastIndexWhere((e) => e.route == route);
    if (idx >= 0) {
      final entry = _activeModals.removeAt(idx);
      if (!_dismissingViaBrowserBack) {
        popWebModalHistorySentinelIfTop(entry.id);
      }
    }
  }
}
