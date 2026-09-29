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

  /// Adds a new product
  Future<ProductModel?> addProduct({
    required String name,
    required double price,
    String? category,
    String? description,
    String? sku,
    int stock = 0,
    bool isAvailable = true,
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
        'price': price,
        'category': category,
        'description': description,
        'sku': sku,
        'stock': stock,
        'is_active': isAvailable,
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
