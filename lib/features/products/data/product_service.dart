import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pos/models/product_model.dart';

class ProductService {
  final SupabaseClient _client;

  ProductService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetches all products (including unavailable ones) for the catalogue
  Future<List<ProductModel>> fetchAllProducts() async {
    try {
      final response = await _client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      return [];
    }
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
      String? imageUrl;
      if (imageBytes != null && imageExt != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$imageExt';
        final path = 'products/$fileName';
        await _client.storage.from('business-assets').uploadBinary(path, imageBytes);
        imageUrl = _client.storage.from('business-assets').getPublicUrl(path);
      }

      final data = {
        'name': name,
        'price': price,
        'category': category,
        'description': description,
        'sku': sku,
        'stock': stock,
        'is_available': isAvailable,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      final response = await _client
          .from('products')
          .insert(data)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Updates an existing product
  Future<bool> updateProduct(String productId, Map<String, dynamic> updates) async {
    try {
      await _client.from('products').update(updates).eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a product
  Future<bool> deleteProduct(String productId) async {
    try {
      await _client.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
