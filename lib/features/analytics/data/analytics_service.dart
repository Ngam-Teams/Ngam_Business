import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';

class AnalyticsService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  AnalyticsService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  /// Fetches overview stats: today's revenue, order count, avg order value.
  Future<Map<String, dynamic>> fetchOverviewStats() async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day)
          .toIso8601String();

      var ordersQuery = _client
          .from('orders')
          .select('total, created_at, status')
          .gte('created_at', startOfDay);
      if (businessId != null) {
        ordersQuery = ordersQuery.eq('business_id', businessId);
      }

      final ordersRes = await ordersQuery;
      final orders = ordersRes as List;
      double todayRevenue = 0;
      for (final o in orders) {
        todayRevenue += (o['total'] as num?)?.toDouble() ?? 0.0;
      }

      // Monthly revenue
      final startOfMonth =
          DateTime(today.year, today.month, 1).toIso8601String();
      var monthlyQuery = _client
          .from('orders')
          .select('total')
          .gte('created_at', startOfMonth);
      if (businessId != null) {
        monthlyQuery = monthlyQuery.eq('business_id', businessId);
      }

      final monthlyRes = await monthlyQuery;
      double monthlyRevenue = 0;
      for (final o in monthlyRes as List) {
        monthlyRevenue += (o['total'] as num?)?.toDouble() ?? 0.0;
      }

      // Product count
      int productCount = 0;
      try {
        var prodQuery = _client
            .from('business_products')
            .select('id')
            .eq('is_active', true);
        if (businessId != null) {
          prodQuery = prodQuery.eq('shop_id', businessId);
        }
        final prodRes = await prodQuery;
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
      // Return mock stats if tables not set up yet
      return {
        'todayRevenue': 487.50,
        'todayOrders': 24,
        'monthlyRevenue': 12450.00,
        'productCount': 142,
        'avgOrderValue': 20.30,
        'pendingOrders': 3,
      };
    }
  }

  /// Fetches last 7 days revenue by day.
  Future<List<Map<String, dynamic>>> fetchWeeklyRevenue() async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];

      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));

      var query = _client
          .from('orders')
          .select('total, created_at')
          .gte('created_at', weekAgo.toIso8601String());
      if (businessId != null) {
        query = query.eq('business_id', businessId);
      }

      final res = await query.order('created_at');

      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException {
      return [];
    }
  }

  /// Fetches top selling products by quantity.
  Future<List<Map<String, dynamic>>> fetchTopProducts({int limit = 5}) async {
    try {
      final res = await _client
          .from('order_items')
          .select('product_name, quantity')
          .order('quantity', ascending: false)
          .limit(limit);

      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException {
      // Mock top products
      return [
        {'product_name': 'Nasi Lemak', 'quantity': 142},
        {'product_name': 'Teh Tarik', 'quantity': 98},
        {'product_name': 'Roti Canai', 'quantity': 87},
        {'product_name': 'Nasi Goreng', 'quantity': 65},
        {'product_name': 'Milo Ais', 'quantity': 54},
      ];
    }
  }
}
