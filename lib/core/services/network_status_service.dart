import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// NetworkStatusService monitors real-time internet connectivity status
/// across Web, Android, iOS, and Desktop.
class NetworkStatusService {
  NetworkStatusService._();
  static final NetworkStatusService instance = NetworkStatusService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Check initial state
    checkConnectivity();

    // Listen to network state changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  Future<void> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      debugPrint('[NetworkStatusService] Error checking connectivity: $e');
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnlineNotifier.value != isOnline) {
      isOnlineNotifier.value = isOnline;
      debugPrint('[NetworkStatusService] Connection changed: isOnline=$isOnline');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
