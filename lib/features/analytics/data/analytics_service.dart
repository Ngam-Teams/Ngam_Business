import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';

class AnalyticsService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  static Map<String, dynamic>? _cachedOverviewStats;
  static Map<String, dynamic>? get cachedOverviewStats => _cachedOverviewStats;

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

      // Run queries concurrently with an 8-second total timeout
      final responses = await Future.wait([
        _client
            .from('orders')
            .select('total, created_at, status')
            .eq('business_id', businessId)
            .gte('created_at', startOfDay),
        _client
            .from('orders')
            .select('total')
            .eq('business_id', businessId)
            .gte('created_at', startOfMonth),
        _client
            .from('business_products')
            .select('id')
            .eq('shop_id', businessId)
            .eq('is_active', true),
      ]).timeout(const Duration(seconds: 8));

      final orders = (responses[0] as List?) ?? [];
      final monthlyOrders = (responses[1] as List?) ?? [];
      final products = (responses[2] as List?) ?? [];

      double todayRevenue = 0.0;
      int pendingOrders = 0;
      for (final o in orders) {
        todayRevenue += (o['total'] as num?)?.toDouble() ?? 0.0;
        if (o['status'] == 'pending') {
          pendingOrders++;
        }
      }

      double monthlyRevenue = 0.0;
      for (final o in monthlyOrders) {
        monthlyRevenue += (o['total'] as num?)?.toDouble() ?? 0.0;
      }

      final stats = {
        'todayRevenue': todayRevenue,
        'todayOrders': orders.length,
        'monthlyRevenue': monthlyRevenue,
        'productCount': products.length,
        'avgOrderValue': orders.isEmpty ? 0.0 : todayRevenue / orders.length,
        'pendingOrders': pendingOrders,
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
          .select('total, created_at')
          .eq('business_id', businessId)
          .gte('created_at', weekAgo.toIso8601String())
          .order('created_at')
          .timeout(const Duration(seconds: 8));

      return (res as List).cast<Map<String, dynamic>>();
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
          .select('id')
          .eq('business_id', businessId)
          .limit(100)
          .timeout(const Duration(seconds: 8));

      final orderIds = (ordersRes as List)
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
