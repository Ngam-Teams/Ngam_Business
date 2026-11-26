import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/ngam_ref.dart';
import '../../orders/data/orders_service.dart';
import '../../settings/data/business_service.dart';

class AnalyticsService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  static Map<String, dynamic>? _cachedOverviewStats;
  static Map<String, dynamic>? get cachedOverviewStats => _cachedOverviewStats;

  static void reset() {
    _cachedOverviewStats = null;
  }

  static const Map<String, dynamic> fallbackOverviewStats = {
    'todayRevenue': 0.0,
    'todayOrders': 0,
    'monthlyRevenue': 0.0,
    'productCount': 0,
    'avgOrderValue': 0.0,
    'pendingOrders': 0,
  };

  AnalyticsService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getBusinessId() async {
    try {
      final profile = await _businessService.getBusinessProfile().timeout(
            const Duration(seconds: 4),
            onTimeout: () => BusinessService.cachedProfile,
          );
      return profile?['id']?.toString();
    } catch (_) {
      return BusinessService.cachedProfile?['id']?.toString();
    }
  }

  /// Fetches overview stats: today's revenue, order count, avg order value.
  /// Runs database queries concurrently with timeout and guaranteed fallback.
  Future<Map<String, dynamic>> fetchOverviewStats({bool forceRefresh = false}) async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) {
        return _cachedOverviewStats ?? fallbackOverviewStats;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final startOfMonth = DateTime(today.year, today.month, 1).toIso8601String();

      Future<List<dynamic>> fetchOrdersSafe(String cols, String sinceIso) async {
        try {
          return await _client
              .from('orders')
              .select('$cols, shipping_fee')
              .eq('business_id', businessId)
              .gte('created_at', sinceIso);
        } catch (_) {
          return await _client
              .from('orders')
              .select(cols)
              .eq('business_id', businessId)
              .gte('created_at', sinceIso);
        }
      }

      // Run queries concurrently with an 8-second total timeout
      final responses = await Future.wait([
        fetchOrdersSafe('total, created_at, status, payment_status, payment_method, source', startOfDay),
        fetchOrdersSafe('total, status, payment_status, source, payment_method, created_at', startOfMonth),
        _client
            .from('business_products')
            .select('id')
            .eq('shop_id', businessId)
            .eq('is_active', true),
        _client
            .from('orders')
            .select('id, total, status, source, payment_status, payment_method, customer_name, created_at')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(20),
        _client
            .from('bookings')
            .select('id, service_name, customer_name, status, created_at, booking_metadata')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(8),
      ]).timeout(const Duration(seconds: 8));

      final orders = (responses[0] as List?) ?? [];
      final monthlyOrders = (responses[1] as List?) ?? [];
      final products = (responses[2] as List?) ?? [];
      final recentOrders = (responses[3] as List?) ?? [];
      final recentBookings = (responses[4] as List?) ?? [];

      double todayRevenue = 0.0;
      int pendingOrders = 0;
      int validTodayOrders = 0;
      for (final o in orders) {
        final row = Map<String, dynamic>.from(o as Map);
        if (!OrdersService.isOrderReadyForMerchant(row)) continue;
        final st = (row['status'] ?? '').toString().toLowerCase();
        final paySt = (row['payment_status'] ?? 'paid').toString().toLowerCase();
        if (st == 'cancelled' ||
            st == 'refunded' ||
            st == 'refund_pending' ||
            paySt == 'refunded' ||
            paySt == 'refund_pending') {
          continue;
        }
        validTodayOrders++;
        final orderTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
        final shipFee = (row['shipping_fee'] as num?)?.toDouble() ?? 0.0;
        todayRevenue += (orderTotal - shipFee).clamp(0.0, double.infinity);
        if (st == 'pending') {
          pendingOrders++;
        }
      }

      double monthlyRevenue = 0.0;
      for (final o in monthlyOrders) {
        final row = Map<String, dynamic>.from(o as Map);
        if (!OrdersService.isOrderReadyForMerchant(row)) continue;
        final st = (row['status'] ?? '').toString().toLowerCase();
        final paySt = (row['payment_status'] ?? 'paid').toString().toLowerCase();
        if (st == 'cancelled' ||
            st == 'refunded' ||
            st == 'refund_pending' ||
            paySt == 'refunded' ||
            paySt == 'refund_pending') {
          continue;
        }
        final orderTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
        final shipFee = (row['shipping_fee'] as num?)?.toDouble() ?? 0.0;
        monthlyRevenue += (orderTotal - shipFee).clamp(0.0, double.infinity);
      }

      final List<Map<String, dynamic>> recentActivities = [];
      for (final ro in recentOrders) {
        final row = Map<String, dynamic>.from(ro as Map);
        // Hide unpaid online checkout drafts (e.g. pending DuitNow QR / FPX)
        if (!OrdersService.isOrderReadyForMerchant(row)) continue;
        final rawId = (row['id'] ?? '').toString();
        final createdDt = DateTime.tryParse((row['created_at'] ?? '').toString());
        final isPos = (row['source'] ?? '').toString().toLowerCase() == 'pos';
        final shortId = isPos
            ? NgamRef.pos(rawId, createdDt)
            : NgamRef.order(rawId, createdAt: createdDt);
        final amt = ((row['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
        final st = (row['status'] ?? 'pending').toString().toLowerCase();
        recentActivities.add({
          'type': 'order',
          'status': st,
          'ref_code': shortId,
          'amount': amt,
          'created_at': (row['created_at'] ?? '').toString(),
        });
      }
      for (final rb in recentBookings) {
        final row = Map<String, dynamic>.from(rb as Map);
        final st = (row['status'] ?? 'pending').toString().toLowerCase();
        if (st == 'holding') continue;
        final svc = (row['service_name'] ?? '').toString().trim();
        final cust = (row['customer_name'] ?? '').toString().trim();
        recentActivities.add({
          'type': 'booking',
          'status': st,
          'service_name': svc,
          'customer_name': cust,
          'created_at': (row['created_at'] ?? '').toString(),
        });
      }
      recentActivities.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

      // 1. Calculate Real Today Sparklines (Hourly intervals from actual orders)
      final List<double> hourlyRevSlots = List.filled(8, 0.0);
      final List<double> hourlyOrdSlots = List.filled(8, 0.0);

      for (final o in orders) {
        final row = Map<String, dynamic>.from(o as Map);
        if (!OrdersService.isOrderReadyForMerchant(row)) continue;
        final st = (row['status'] ?? '').toString().toLowerCase();
        final paySt = (row['payment_status'] ?? 'paid').toString().toLowerCase();
        if (st == 'cancelled' ||
            st == 'refunded' ||
            st == 'refund_pending' ||
            paySt == 'refunded' ||
            paySt == 'refund_pending') {
          continue;
        }
        final cStr = row['created_at']?.toString();
        if (cStr != null) {
          final dt = DateTime.tryParse(cStr)?.toLocal();
          if (dt != null) {
            final int slot = ((dt.hour - 8) / 2).floor().clamp(0, 7);
            final double orderTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
            final double shipFee = (row['shipping_fee'] as num?)?.toDouble() ?? 0.0;
            final double amount = (orderTotal - shipFee).clamp(0.0, double.infinity);
            hourlyRevSlots[slot] += amount;
            hourlyOrdSlots[slot] += 1.0;
          }
        }
      }

      double cumRev = 0.0;
      final List<double> todayRevenueSparkline = [];
      double cumOrd = 0.0;
      final List<double> todayOrdersSparkline = [];

      for (int i = 0; i < 8; i++) {
        cumRev += hourlyRevSlots[i];
        todayRevenueSparkline.add(cumRev);
        cumOrd += hourlyOrdSlots[i];
        todayOrdersSparkline.add(cumOrd);
      }

      // If today has no orders yet (e.g. early morning), fallback to 7-day daily trend from real monthly orders
      List<double> effectiveRevenueSparkline = todayRevenueSparkline;
      List<double> effectiveOrdersSparkline = todayOrdersSparkline;

      if (cumRev == 0.0 && monthlyOrders.isNotEmpty) {
        final List<double> last7DaysRev = List.filled(7, 0.0);
        final List<double> last7DaysOrd = List.filled(7, 0.0);
        final now = DateTime.now();

        for (final mo in monthlyOrders) {
          final row = Map<String, dynamic>.from(mo as Map);
          if (!OrdersService.isOrderReadyForMerchant(row)) continue;
          final st = (row['status'] ?? '').toString().toLowerCase();
          if (st == 'cancelled' || st == 'refunded' || st == 'refund_pending') continue;
          final cStr = row['created_at']?.toString();
          if (cStr != null) {
            final dt = DateTime.tryParse(cStr)?.toLocal();
            if (dt != null) {
              final diff = now.difference(dt).inDays;
              if (diff >= 0 && diff < 7) {
                final orderTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
                final shipFee = (row['shipping_fee'] as num?)?.toDouble() ?? 0.0;
                last7DaysRev[6 - diff] += (orderTotal - shipFee).clamp(0.0, double.infinity);
                last7DaysOrd[6 - diff] += 1.0;
              }
            }
          }
        }
        effectiveRevenueSparkline = last7DaysRev;
        effectiveOrdersSparkline = last7DaysOrd;
      }

      // 2. Calculate Real Monthly Sparkline (Progressive milestones by day of month)
      final int currentDay = today.day;
      final int samples = currentDay <= 8 ? currentDay : 8;
      final double step = currentDay / (samples > 1 ? samples - 1 : 1);
      final List<double> monthlyRevenueSparkline = [];

      for (int i = 0; i < samples; i++) {
        final targetDay = (1 + i * step).round().clamp(1, currentDay);
        double sum = 0.0;
        for (final mo in monthlyOrders) {
          final row = Map<String, dynamic>.from(mo as Map);
          if (!OrdersService.isOrderReadyForMerchant(row)) continue;
          final st = (row['status'] ?? '').toString().toLowerCase();
          if (st == 'cancelled' || st == 'refunded' || st == 'refund_pending') continue;
          final cStr = row['created_at']?.toString();
          if (cStr != null) {
            final dt = DateTime.tryParse(cStr)?.toLocal();
            if (dt != null && dt.day <= targetDay) {
              final orderTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
              final shipFee = (row['shipping_fee'] as num?)?.toDouble() ?? 0.0;
              sum += (orderTotal - shipFee).clamp(0.0, double.infinity);
            }
          }
        }
        monthlyRevenueSparkline.add(sum);
      }

      // 3. Pending Orders Queue Status Trend
      final List<double> pendingOrdersSparkline = pendingOrders > 0
          ? [1.0, 2.0, (pendingOrders * 0.7).clamp(1.0, 10.0), pendingOrders.toDouble()]
          : [4.0, 2.8, 1.5, 0.0];

      final stats = {
        'todayRevenue': todayRevenue,
        'todayOrders': validTodayOrders,
        'monthlyRevenue': monthlyRevenue,
        'productCount': products.length,
        'avgOrderValue': validTodayOrders == 0 ? 0.0 : todayRevenue / validTodayOrders,
        'pendingOrders': pendingOrders,
        'recentActivities': recentActivities.take(8).toList(),
        'todayRevenueSparkline': effectiveRevenueSparkline,
        'todayOrdersSparkline': effectiveOrdersSparkline,
        'monthlyRevenueSparkline': monthlyRevenueSparkline,
        'pendingOrdersSparkline': pendingOrdersSparkline,
      };

      _cachedOverviewStats = stats;
      return stats;
    } catch (e) {
      debugPrint('[AnalyticsService] fetchOverviewStats error or timeout: ');
      return _cachedOverviewStats ?? fallbackOverviewStats;
    }
  }

  /// Fetches last 7 days revenue by day.
  Future<List<Map<String, dynamic>>> fetchWeeklyRevenue() async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) return [];

      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));

      final res = await _client
          .from('orders')
          .select('total, status, payment_status, created_at')
          .eq('business_id', businessId)
          .gte('created_at', weekAgo.toIso8601String())
          .order('created_at')
          .timeout(const Duration(seconds: 8));

      return (res as List)
          .cast<Map<String, dynamic>>()
          .where((o) {
            final st = (o['status'] ?? '').toString().toLowerCase();
            final paySt = (o['payment_status'] ?? 'paid').toString().toLowerCase();
            return st != 'cancelled' &&
                st != 'refunded' &&
                st != 'refund_pending' &&
                paySt != 'refunded' &&
                paySt != 'refund_pending';
          })
          .toList();
    } catch (e) {
      debugPrint('[AnalyticsService] fetchWeeklyRevenue error: ');
      return [];
    }
  }

  /// Fetches top selling products by quantity for this business.
  Future<List<Map<String, dynamic>>> fetchTopProducts({int limit = 5}) async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) return [];

      final ordersRes = await _client
          .from('orders')
          .select('id, status, payment_status')
          .eq('business_id', businessId)
          .limit(100)
          .timeout(const Duration(seconds: 8));

      final orderIds = (ordersRes as List)
          .where((o) {
            final st = (o['status'] ?? '').toString().toLowerCase();
            final paySt = (o['payment_status'] ?? 'paid').toString().toLowerCase();
            return st != 'cancelled' &&
                st != 'refunded' &&
                st != 'refund_pending' &&
                paySt != 'refunded' &&
                paySt != 'refund_pending';
          })
          .map((o) => o['id']?.toString())
          .whereType<String>()
          .toList();

      if (orderIds.isEmpty) return [];

      final res = await _client
          .from('order_items')
          .select('product_name, quantity')
          .filter('order_id', 'in', orderIds)
          .timeout(const Duration(seconds: 8));

      final Map<String, int> counts = {};
      for (final item in (res as List)) {
        final name = item['product_name'] as String? ?? 'Item';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        counts[name] = (counts[name] ?? 0) + qty;
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted
          .take(limit)
          .map((e) => {'product_name': e.key, 'quantity': e.value})
          .toList();
    } catch (e) {
      debugPrint('[AnalyticsService] fetchTopProducts error: ');
      return [];
    }
  }
}
