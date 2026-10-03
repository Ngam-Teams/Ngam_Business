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

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  // ---------------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------------

  /// Fetches all available products for the current tenant's business.
  Future<List<ProductModel>> fetchProducts() async {
    try {
      final businessId = await _getShopId();
      if (businessId == null) return [];

      final response = await _client
          .from('business_products')
          .select()
          .eq('shop_id', businessId)
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      return [];
    }
  }

  /// Streams available products for real-time updates for the current tenant.
  Stream<List<ProductModel>> streamProducts() async* {
    final businessId = await _getShopId();
    if (businessId == null) {
      yield [];
      return;
    }

    yield* _client
        .from('business_products')
        .stream(primaryKey: ['id'])
        .eq('shop_id', businessId)
        .order('name')
        .map((list) => list
            .map((json) => ProductModel.fromJson(json))
            .where((p) => p.isAvailable)
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
      final businessId = await _getShopId();
      if (businessId == null) {
        throw Exception('Sila pastikan profil perniagaan wujud sebelum membuat pesanan.');
      }
      final user = _client.auth.currentUser;

      final orderData = {
        'total': total,
        'status': 'completed',
        'source': 'pos',
        'business_id': businessId,
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
      final businessId = await _getShopId();
      if (businessId == null) return [];

      final response = await _client
          .from('orders')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException {
      return [];
    }
  }
}
