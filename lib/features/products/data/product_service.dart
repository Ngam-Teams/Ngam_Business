import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pos/models/product_model.dart';
import '../../settings/data/business_service.dart';

class ProductService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  ProductService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Fetches all products (including unavailable ones) for the catalogue
  Future<List<ProductModel>> fetchAllProducts() async {
    try {
      final shopId = await _getShopId();
      if (shopId == null) return [];

      final response = await _client
          .from('business_products')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      return [];
    }
  }

  /// Streams all products for the catalogue real-time updates
  Stream<List<ProductModel>> streamAllProducts() async* {
    final shopId = await _getShopId();
    if (shopId == null) {
      yield [];
      return;
    }

    yield* _client
        .from('business_products')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .map((list) => list
            .map((json) => ProductModel.fromJson(json))
            .toList());
  }

  /// Adds a new product or service
  Future<ProductModel?> addProduct({
    required String name,
    required double price,
    String itemType = 'product',
    double? compareAtPrice,
    double? costPrice,
    double taxRate = 0.0,
    String? category,
    String? subCategory,
    String? description,
    String? sku,
    String? barcode,
    int stock = 0,
    bool trackInventory = true,
    int lowStockThreshold = 5,
    String unit = 'pcs',
    List<String> tags = const [],
    bool isAvailable = true,
    bool isFeatured = false,
    bool isHalal = false,
    List<Map<String, dynamic>> variants = const [],
    List<Map<String, dynamic>> modifiers = const [],
    int durationMinutes = 30,
    int bufferMinutes = 0,
    double depositAmount = 0.0,
    String serviceLocation = 'in_store',
    int maxPax = 1,
    Uint8List? imageBytes,
    String? imageExt,
  }) async {
    try {
      final shopId = await _getShopId();
      if (shopId == null) return null;

      String? imageUrl;
      if (imageBytes != null && imageExt != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$imageExt';
        final path = 'products/$fileName';
        await _client.storage.from('business-assets').uploadBinary(path, imageBytes);
        imageUrl = _client.storage.from('business-assets').getPublicUrl(path);
      }

      final data = {
        'shop_id': shopId,
        'name': name,
        'item_type': itemType,
        'price': price,
        if (compareAtPrice != null) 'compare_at_price': compareAtPrice,
        if (costPrice != null) 'cost_price': costPrice,
        'tax_rate': taxRate,
        if (category != null) 'category': category,
        if (subCategory != null) 'sub_category': subCategory,
        if (description != null) 'description': description,
        if (sku != null) 'sku': sku,
        if (barcode != null) 'barcode': barcode,
        'stock': stock,
        'track_inventory': trackInventory,
        'low_stock_threshold': lowStockThreshold,
        'unit': unit,
        'tags': tags,
        'is_active': isAvailable,
        'is_featured': isFeatured,
        'is_halal': isHalal,
        'variants': variants,
        'modifiers': modifiers,
        'duration_minutes': durationMinutes,
        'buffer_minutes': bufferMinutes,
        'deposit_amount': depositAmount,
        'service_location': serviceLocation,
        'max_pax': maxPax,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      final response = await _client
          .from('business_products')
          .insert(data)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Updates an existing product
  Future<bool> updateProduct(
    String productId, 
    Map<String, dynamic> updates, {
    Uint8List? imageBytes,
    String? imageExt,
  }) async {
    try {
      if (imageBytes != null && imageExt != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$imageExt';
        final path = 'products/$fileName';
        await _client.storage.from('business-assets').uploadBinary(path, imageBytes);
        final imageUrl = _client.storage.from('business-assets').getPublicUrl(path);
        updates['image_url'] = imageUrl;
      }

      // Ensure any 'is_available' key is translated to 'is_active'
      if (updates.containsKey('is_available')) {
        updates['is_active'] = updates.remove('is_available');
      }

      await _client.from('business_products').update(updates).eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a product
  Future<bool> deleteProduct(String productId) async {
    try {
      await _client.from('business_products').delete().eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
