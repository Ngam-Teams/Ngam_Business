import 'package:supabase_flutter/supabase_flutter.dart';

class OrderModel {
  final String id;
  final String ownerUserId;
  final double total;
  final String status;
  final String source;
  final String? customerName;
  final String? notes;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.ownerUserId,
    required this.total,
    required this.status,
    required this.source,
    this.customerName,
    this.notes,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      source: json['source'] as String? ?? 'pos',
      customerName: json['customer_name'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OrdersService {
  final SupabaseClient _client;

  OrdersService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch all orders for the current business
  Future<List<OrderModel>> fetchOrders() async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream orders for real-time updates
  Stream<List<OrderModel>> streamOrders() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list
            .map((json) => OrderModel.fromJson(json))
            .toList());
  }

  /// Update the status of an order
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _client
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
