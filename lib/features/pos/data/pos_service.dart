import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class PosService {
  final SupabaseClient _client;

  PosService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------------

  /// Fetches all available products for the current tenant's business.
  Future<List<ProductModel>> fetchProducts() async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('is_available', true)
          .order('name');

      return (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  /// Submits a new order to Supabase.
  Future<void> submitOrder({
    required List<CartItem> items,
    required double total,
    String? customerName,
    String? notes,
  }) async {
    try {
      final orderData = {
        'total': total,
        'status': 'completed',
        'source': 'pos',
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final order = await _client
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderItems = items.map((item) => {
            'order_id': order['id'],
            'product_id': item.product.id,
            'product_name': item.product.name,
            'quantity': item.quantity,
            'unit_price': item.product.price,
            'subtotal': item.subtotal,
          }).toList();

      await _client.from('order_items').insert(orderItems);
    } on PostgrestException {
      // Silently fail if table doesn't exist — mock mode
    }
  }

  /// Fetches recent orders.
  Future<List<Map<String, dynamic>>> fetchRecentOrders({int limit = 20}) async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException {
      return [];
    }
  }
}
