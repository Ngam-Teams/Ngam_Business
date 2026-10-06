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

  /// Submits a new order to Supabase with optional split payments.
  Future<void> submitOrder({
    required List<CartItem> items,
    required double total,
    String? customerName,
    String? notes,
    List<PaymentSplit>? paymentSplits,
  }) async {
    try {
      final businessId = await _getShopId();
      if (businessId == null) {
        throw Exception('Sila pastikan profil perniagaan wujud sebelum membuat pesanan.');
      }
      final user = _client.auth.currentUser;

      String? combinedNotes = notes;
      String paymentMethodName = 'cash';

      if (paymentSplits != null && paymentSplits.isNotEmpty) {
        if (paymentSplits.length == 1) {
          paymentMethodName = paymentSplits.first.method;
        } else {
          paymentMethodName = 'split';
        }

        final splitSummaries = paymentSplits.map((s) {
          final amtStr = 'RM ${s.amount.toStringAsFixed(2)}';
          if (s.method == 'cash' && s.tenderedAmount != null && s.tenderedAmount! > s.amount) {
            final change = s.changeAmount ?? (s.tenderedAmount! - s.amount);
            return '${s.displayName}: $amtStr (Diterima: RM ${s.tenderedAmount!.toStringAsFixed(2)}, Baki: RM ${change.toStringAsFixed(2)})';
          }
          return '${s.displayName}: $amtStr';
        }).join(' + ');

        final paymentTag = '[Bayaran: $splitSummaries]';
        combinedNotes = (combinedNotes == null || combinedNotes.trim().isEmpty)
            ? paymentTag
            : '$combinedNotes | $paymentTag';
      }

      final baseOrderData = {
        'total': total,
        'status': 'completed',
        'source': 'pos',
        'business_id': businessId,
        if (user != null) 'owner_user_id': user.id,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (combinedNotes != null && combinedNotes.isNotEmpty)
          'notes': combinedNotes,
      };

      Map<String, dynamic> order;
      try {
        final fullData = {
          ...baseOrderData,
          'payment_method': paymentMethodName,
          if (paymentSplits != null && paymentSplits.isNotEmpty)
            'payment_splits': paymentSplits.map((s) => s.toJson()).toList(),
        };
        order = await _client.from('orders').insert(fullData).select().single();
      } catch (_) {
        order = await _client.from('orders').insert(baseOrderData).select().single();
      }

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
