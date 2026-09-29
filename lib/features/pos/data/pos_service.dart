import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class PosService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  PosService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  // ---------------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------------

  /// Fetches all available products for the current tenant's business.
  Future<List<ProductModel>> fetchProducts() async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];

      var query = _client.from('business_products').select().eq('is_active', true);
      if (businessId != null) {
        query = query.eq('shop_id', businessId);
      }

      final response = await query.order('name');

      return (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      return [];
    }
  }

  /// Streams available products for real-time updates.
  Stream<List<ProductModel>> streamProducts() {
    return _client
        .from('business_products')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('name')
        .map((list) => list
            .map((json) => ProductModel.fromJson(json))
            .toList());
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
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];
      final user = _client.auth.currentUser;

      final orderData = {
        'total': total,
        'status': 'completed',
        'source': 'pos',
        if (businessId != null) 'business_id': businessId,
        if (user != null) 'owner_user_id': user.id,
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
    } catch (e) {
      // Re-throw so the UI can show the error
      rethrow;
    }
  }

  /// Fetches recent orders for the current business.
  Future<List<Map<String, dynamic>>> fetchRecentOrders({int limit = 20}) async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];

      var query = _client.from('orders').select();
      if (businessId != null) {
        query = query.eq('business_id', businessId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException {
      return [];
    }
  }
}
