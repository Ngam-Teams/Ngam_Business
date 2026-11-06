import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';
import 'order_alert_service.dart';
import 'sound_service.dart';
import 'notification_bridge.dart';
import '../../widgets/glass_notification_banner.dart';

// =============================================================================
// MerchantNotificationService
// Unified notification engine for Ngam Business (Mobile, Web, & PWA).
// Manages real-time listeners for Orders, Bookings, and Customer Messages,
// with audio chimes, native browser push alerts, and in-app glass banners.
// =============================================================================

class MerchantNotificationService {
  static final MerchantNotificationService instance =
      MerchantNotificationService._internal();

  MerchantNotificationService._internal();

  String? _businessId;
  RealtimeChannel? _bookingsChannel;
  RealtimeChannel? _messagesChannel;
  StreamSubscription? _bookingsStreamSub;
  final Set<String> _knownBookingIds = {};
  final Set<String> _knownMessageIds = {};
  void Function(int index)? onSwitchTab;

  bool _isInitialized = false;

  /// Check whether browser / push notifications are supported on this platform
  Future<bool> isSupported() async {
    return await isWebNotificationSupported();
  }

  /// Request browser notification permission on Web/PWA
  Future<String> requestPermission() async {
    return await requestWebNotificationPermission();
  }

  /// Current permission status ('granted', 'denied', 'default', 'unsupported')
  Future<String> getPermissionStatus() async {
    return await getWebNotificationPermission();
  }

  /// Initializes all notification channels for the active merchant business
  Future<void> initialize({
    required String businessId,
    void Function(int index)? onTabSwitch,
  }) async {
    if (_isInitialized && _businessId == businessId) return;

    _businessId = businessId;
    if (onTabSwitch != null) {
      onSwitchTab = onTabSwitch;
    }

    // 1. Initialize Order Alerts (Audio Chimes + Incoming Order Dialog)
    await OrderAlertService.instance.initialize(
      businessId: businessId,
      onTabSwitch: onTabSwitch,
    );

    // Auto-request web notification permission if default/prompt
    try {
      final status = await getPermissionStatus();
      if (status == 'default') {
        // Will prompt browser
        await requestPermission();
      }
    } catch (_) {}

    // 2. Prefetch recent bookings to avoid alerting on already existing records (kecuali yang masih 'holding' / belum selesai bayar)
    try {
      final existingBookings = await Supabase.instance.client
          .from('bookings')
          .select('id, status, booking_metadata')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(40);

      for (final b in existingBookings) {
        final status = (b['status'] ?? '').toString().toLowerCase();
        final meta = b['booking_metadata'] is Map ? b['booking_metadata'] as Map : const {};
        final payStatus = (meta['payment_status'] ?? '').toString().toLowerCase();
        if (b['id'] != null && status != 'holding' && payStatus != 'pending') {
          _knownBookingIds.add(b['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('[MerchantNotif] Error prefetching bookings: $e');
    }

    // 3. Subscribe to Realtime Bookings Changes
    _setupBookingsListener(businessId);

    // 4. Subscribe to Realtime Messages Changes
    _setupMessagesListener(businessId);

    _isInitialized = true;
    debugPrint('[MerchantNotif] Initialized for business: $businessId');
  }

  void _setupBookingsListener(String businessId) {
    try {
      _bookingsChannel?.unsubscribe();
      _bookingsChannel = Supabase.instance.client
          .channel('public:bookings:biz_$businessId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: businessId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                _onNewBookingReceived(newRecord);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: businessId,
            ),
            callback: (payload) {
              final updated = payload.newRecord;
              if (updated.isNotEmpty) {
                _onBookingUpdated(updated);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[MerchantNotif] Bookings channel error: $e');
    }

    // Fallback stream listener for robust connectivity
    _bookingsStreamSub?.cancel();
    _bookingsStreamSub = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .listen(
      (rows) {
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id != null && !_knownBookingIds.contains(id)) {
            _onNewBookingReceived(row);
          }
        }
      },
      onError: (err) {
        debugPrint('[MerchantNotif] Bookings stream error: $err');
      },
    );
  }

  void _onNewBookingReceived(Map<String, dynamic> booking) {
    final id = booking['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (_knownBookingIds.contains(id)) return;

    final status = (booking['status'] ?? '').toString().toLowerCase();
    final meta = booking['booking_metadata'] is Map
        ? booking['booking_metadata'] as Map
        : const {};
    final payStatus = (meta['payment_status'] ?? '').toString().toLowerCase();

    // JANGAN beri alert jika pelanggan baru berada di Step 1 ('holding') atau masih di skrin bayaran online ('pending')!
    if (status == 'holding' || status == 'cancelled' || payStatus == 'pending') {
      return;
    }

    _knownBookingIds.add(id);

    final customerName =
        booking['customer_name']?.toString() ??
        booking['user_name']?.toString() ??
        'Pelanggan';
    final serviceName =
        booking['service_name']?.toString() ??
        booking['category']?.toString() ??
        'Slot Perkhidmatan';
    final date = (booking['booking_date'] ?? booking['date'])?.toString() ?? 'Hari ini';
    final time = (booking['booking_time'] ?? booking['time'])?.toString() ?? '';

    // Play chime audio
    SoundService.instance.playOrderChime();

    // Show Native Browser / OS Push Notification
    showWebNotification(
      title: '📅 Tempahan Baharu!',
      body: '$customerName menempah $serviceName ($date ${time.isNotEmpty ? "jam $time" : ""}).',
      tag: 'booking_$id',
      url: '/appointments',
    );

    // Show In-App Liquid Glass Banner
    showInAppNotificationBanner(
      title: 'Tempahan Baharu!',
      body: '$customerName menempah $serviceName ($date ${time.isNotEmpty ? "jam $time" : ""}).',
      category: NotificationBannerCategory.booking,
      onTap: () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          appRouter.go('/appointments');
        }
      },
    );
  }

  void _onBookingUpdated(Map<String, dynamic> booking) {
    final id = booking['id']?.toString() ?? '';
    final status = booking['status']?.toString().toLowerCase();

    // Apabila tempahan bertukar daripada 'holding' kepada 'pending' selepas pelanggan sahkan & selesai bayar:
    if (status == 'pending' && id.isNotEmpty && !_knownBookingIds.contains(id)) {
      _onNewBookingReceived(booking);
      return;
    }

    // Hanya paparkan notifikasi pembatalan jika tempahan tersebut pernah disahkan (bukan pelepasan slot 'holding' Step 1)
    if (status == 'cancelled' && id.isNotEmpty && _knownBookingIds.contains(id)) {
      _knownBookingIds.remove(id);
      final customerName =
          booking['customer_name']?.toString() ??
          booking['user_name']?.toString() ??
          'Pelanggan';

      showInAppNotificationBanner(
        title: 'Tempahan Dibatalkan',
        body: '$customerName telah membatalkan temujanji.',
        category: NotificationBannerCategory.booking,
        onTap: () {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) {
            appRouter.go('/appointments');
          }
        },
      );
    }
  }

  void _setupMessagesListener(String businessId) {
    try {
      _messagesChannel?.unsubscribe();
      _messagesChannel = Supabase.instance.client
          .channel('public:merchant_messages:$businessId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                _onNewMessageReceived(newRecord);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[MerchantNotif] Messages channel error: $e');
    }
  }

  void _onNewMessageReceived(Map<String, dynamic> message) {
    final id = message['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (_knownMessageIds.contains(id)) return;
    _knownMessageIds.add(id);

    // If message is sent by current merchant user, ignore
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final senderId = message['sender_id']?.toString();
    if (currentUserId != null && senderId == currentUserId) return;

    final content = message['content']?.toString() ?? 'Mesej baharu';
    final senderName = message['sender_name']?.toString() ?? 'Pelanggan';

    // Play chime sound
    SoundService.instance.playOrderChime();

    // Show Native Browser / OS Push Notification
    showWebNotification(
      title: '💬 $senderName',
      body: content,
      tag: 'msg_$id',
      url: '/inbox',
    );

    // Show In-App Liquid Glass Banner
    showInAppNotificationBanner(
      title: 'Mesej daripada $senderName',
      body: content,
      category: NotificationBannerCategory.message,
      onTap: () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          appRouter.go('/inbox');
        }
      },
    );
  }

  /// Dispatch an alert for new incoming order
  void notifyOrder({
    required String orderId,
    required double total,
    required String customerName,
    required String source,
  }) {
    showWebNotification(
      title: '🔔 Pesanan Baharu #$orderId',
      body: '$customerName membuat pesanan senilai RM ${total.toStringAsFixed(2)}.',
      tag: 'order_$orderId',
      url: '/orders',
    );
  }

  void dispose() {
    _bookingsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _bookingsStreamSub?.cancel();
    OrderAlertService.instance.dispose();
    _isInitialized = false;
  }
}
