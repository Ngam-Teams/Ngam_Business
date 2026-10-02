import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';

// =============================================================================
// OrderAlertService
// Global real-time listener for incoming customer orders across Ngam Business.
// Plays audio ringtone alerts and displays an actionable modal popup.
// =============================================================================

class OrderAlertService {
  static final OrderAlertService instance = OrderAlertService._internal();

  OrderAlertService._internal();

  RealtimeChannel? _channel;
  StreamSubscription? _streamSub;
  String? _businessId;
  final Set<String> _knownOrderIds = {};
  bool _isPlayingSound = false;
  bool _isModalShowing = false;
  void Function(int index)? onSwitchTab;

  /// Initializes the listener for incoming orders
  Future<void> initialize({
    required String businessId,
    void Function(int index)? onTabSwitch,
  }) async {
    if (_businessId == businessId && (_channel != null || _streamSub != null)) {
      return; // Already initialized for this business
    }

    _businessId = businessId;
    if (onTabSwitch != null) {
      onSwitchTab = onTabSwitch;
    }

    // 1. Seed existing order IDs to avoid alerting on app startup
    try {
      final existing = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(60);

      for (final item in existing) {
        if (item['id'] != null) {
          _knownOrderIds.add(item['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('[OrderAlertService] Error prefetching orders: $e');
    }

    // 2. Realtime Postgres Changes Subscription
    try {
      _channel?.unsubscribe();
      _channel = Supabase.instance.client
          .channel('public:orders:biz_$businessId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: businessId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                _onNewOrderReceived(newRecord);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[OrderAlertService] Realtime channel subscription error: $e');
    }

    // 3. Fallback Stream listener using Supabase Stream
    _streamSub?.cancel();
    _streamSub = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .listen(
      (rows) {
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id != null && !_knownOrderIds.contains(id)) {
            _onNewOrderReceived(row);
          }
        }
      },
      onError: (err) {
        debugPrint('[OrderAlertService] Stream error: $err');
      },
    );
  }

  void _onNewOrderReceived(Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (_knownOrderIds.contains(id)) return;
    _knownOrderIds.add(id);

    final status = order['status']?.toString().toLowerCase();
    // Only alert for pending online or pre-order orders
    if (status != 'pending') return;

    // Start Ringtone Audio
    _playAlertSound();

    // Show Interactive Alert Dialog / Sheet
    _showIncomingOrderAlert(order);
  }

  Future<void> _playAlertSound() async {
    if (_isPlayingSound) return;
    _isPlayingSound = true;
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
    } catch (e) {
      try {
        FlutterRingtonePlayer().playNotification();
      } catch (_) {}
    }
  }

  void stopAlertSound() {
    _isPlayingSound = false;
    try {
      FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('[OrderAlertService] Error stopping ringtone: $e');
    }
  }

  void _showIncomingOrderAlert(Map<String, dynamic> order) {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    if (_isModalShowing) {
      // If another alert is already active, don't overlap modals
      return;
    }
    _isModalShowing = true;

    final String orderId = order['id']?.toString() ?? '';
    final String customerName = order['customer_name']?.toString() ?? 'Pelanggan Ngam';
    final double total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final String source = order['source']?.toString().toLowerCase() ?? 'online';
    final bool isPreOrder = source == 'pre_order';
    final String? notes = order['notes']?.toString();

    showDialog(
      context: navContext,
      barrierDismissible: false, // Force interaction so order isn't ignored
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            stopAlertSound();
            _isModalShowing = false;
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isPreOrder
                      ? Colors.purpleAccent.withValues(alpha: 0.6)
                      : const Color(0xFF42A5F5).withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPreOrder
                        ? Colors.purpleAccent.withValues(alpha: 0.25)
                        : const Color(0xFF42A5F5).withValues(alpha: 0.25),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Animated / Pulsing Icon
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: (isPreOrder ? Colors.purpleAccent : const Color(0xFF42A5F5))
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: isPreOrder
                            ? HugeIcons.strokeRoundedCalendar03
                            : HugeIcons.strokeRoundedNotification03,
                        color: isPreOrder ? Colors.purpleAccent : const Color(0xFF42A5F5),
                        size: 36,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPreOrder ? Colors.purpleAccent : const Color(0xFF42A5F5))
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPreOrder ? '📅 PESANAN AWAL (PRE-ORDER)' : '🔔 PESANAN ONLINE BARU',
                      style: TextStyle(
                        color: isPreOrder ? Colors.purpleAccent : const Color(0xFF42A5F5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'RM ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Daripada: $customerName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (notes != null && notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'Nota: $notes',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      // Accept Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            stopAlertSound();
                            _isModalShowing = false;
                            Navigator.of(ctx, rootNavigator: true).pop();

                            // Mark as completed/accepted in Supabase
                            try {
                              await Supabase.instance.client
                                  .from('orders')
                                  .update({'status': 'completed'})
                                  .eq('id', orderId);
                            } catch (e) {
                              debugPrint('[OrderAlertService] Error accepting order: $e');
                            }
                          },
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Terima',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // View Orders Tab Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            stopAlertSound();
                            _isModalShowing = false;
                            Navigator.of(ctx, rootNavigator: true).pop();
                            onSwitchTab?.call(1); // Navigate to Orders Tab
                          },
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedInvoice01,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Buka Order',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dismiss / Silence button
                  TextButton(
                    onPressed: () {
                      stopAlertSound();
                      _isModalShowing = false;
                      Navigator.of(ctx, rootNavigator: true).pop();
                    },
                    child: const Text(
                      'Senyapkan / Tutup',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      stopAlertSound();
      _isModalShowing = false;
    });
  }

  void dispose() {
    stopAlertSound();
    _channel?.unsubscribe();
    _channel = null;
    _streamSub?.cancel();
    _streamSub = null;
  }
}
