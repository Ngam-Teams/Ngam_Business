import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';

class AnalyticsService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  AnalyticsService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getBusinessId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Fetches overview stats: today's revenue, order count, avg order value.
  Future<Map<String, dynamic>> fetchOverviewStats() async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {
          'todayRevenue': 0.0,
          'todayOrders': 0,
          'monthlyRevenue': 0.0,
          'productCount': 0,
          'avgOrderValue': 0.0,
          'pendingOrders': 0,
        };
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day)
          .toIso8601String();

      final ordersRes = await _client
          .from('orders')
          .select('total, created_at, status')
          .eq('business_id', businessId)
          .gte('created_at', startOfDay);

      final orders = ordersRes as List;
      double todayRevenue = 0;
      for (final o in orders) {
        todayRevenue += (o['total'] as num?)?.toDouble() ?? 0.0;
      }

      // Monthly revenue
      final startOfMonth =
          DateTime(today.year, today.month, 1).toIso8601String();
      final monthlyRes = await _client
          .from('orders')
          .select('total')
          .eq('business_id', businessId)
          .gte('created_at', startOfMonth);

      double monthlyRevenue = 0;
      for (final o in monthlyRes as List) {
        monthlyRevenue += (o['total'] as num?)?.toDouble() ?? 0.0;
      }

      // Product count
      int productCount = 0;
      try {
        final prodRes = await _client
            .from('business_products')
            .select('id')
            .eq('shop_id', businessId)
            .eq('is_active', true);
        productCount = (prodRes as List).length;
      } on PostgrestException {
        productCount = 0;
      }

      // Pending Orders
      int pendingOrders = 0;
      for (final o in orders) {
        if (o['status'] == 'pending') {
          pendingOrders++;
        }
      }

      return {
        'todayRevenue': todayRevenue,
        'todayOrders': orders.length,
        'monthlyRevenue': monthlyRevenue,
        'productCount': productCount,
        'avgOrderValue': orders.isEmpty ? 0.0 : todayRevenue / orders.length,
        'pendingOrders': pendingOrders,
      };
    } on PostgrestException {
      return {
        'todayRevenue': 0.0,
        'todayOrders': 0,
        'monthlyRevenue': 0.0,
        'productCount': 0,
        'avgOrderValue': 0.0,
        'pendingOrders': 0,
      };
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
          .order('created_at');

      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException {
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
          .limit(100);

      final orderIds = (ordersRes as List)
          .map((o) => o['id']?.toString())
          .whereType<String>()
          .toList();

      if (orderIds.isEmpty) return [];

      final res = await _client
          .from('order_items')
          .select('product_name, quantity')
          .filter('order_id', 'in', orderIds);

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
    } on PostgrestException {
      return [];
    }
  }
}
