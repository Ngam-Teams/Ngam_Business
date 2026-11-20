import 'dart:async';
import 'dart:typed_data';
import '../../../core/services/cache_service.dart';
import '../../../core/services/image_compression_service.dart';
import '../../../core/services/r2_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pos/models/product_model.dart';
import '../../settings/data/business_service.dart';

class ProductGalleryDraftUpload {
  final Uint8List? localBytes;
  final String? localName;
  final String? existingUrl;

  const ProductGalleryDraftUpload({
    this.localBytes,
    this.localName,
    this.existingUrl,
  });
}

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

  /// Streams all products for the catalogue real-time updates (dilengkapi cache pantas SWR 0-saat)
  Stream<List<ProductModel>> streamAllProducts() async* {
    final shopId = await _getShopId();
    if (shopId == null) {
      yield [];
      return;
    }

    final cacheKey = 'catalogue_products_$shopId';

    // 1. Pancarkan data cache serta-merta (0 ms)
    final cached = await CacheService.get<List<ProductModel>>(
      key: cacheKey,
      fromJson: (jsonList) => (jsonList as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    if (cached != null && cached.isNotEmpty) {
      yield cached;
    }

    // 2. Sambungkan stream realtime Supabase & simpan ke cache
    yield* _client
        .from('business_products')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .map((list) {
          final products = list
              .map((json) => ProductModel.fromJson(json))
              .toList();

          unawaited(CacheService.set<List<ProductModel>>(
            key: cacheKey,
            data: products,
            toJson: (prods) => prods.map((p) => p.toJson()).toList(),
          ));

          return products;
        });
  }

  Future<String> _uploadProductImage(Uint8List rawBytes, {String? fileName}) async {
    final compressed = await ImageCompressionService.compress(
      bytes: rawBytes,
      type: ImageCompressionType.product,
    );
    final safeName = 'prod_${DateTime.now().millisecondsSinceEpoch}.${compressed.extension}';
    return R2StorageService().uploadMedia(
      bytes: compressed.bytes,
      fileName: fileName != null && fileName.isNotEmpty ? '${DateTime.now().millisecondsSinceEpoch}_${compressed.extension}.$safeName' : safeName,
      folder: 'products/images',
      mimeType: compressed.mimeType,
    );
  }

  Future<String> _uploadProductVideo(Uint8List bytes, {String? fileName}) async {
    final name = (fileName ?? 'product_video.mp4').trim();
    final lower = name.toLowerCase();
    String mime = 'video/mp4';
    if (lower.endsWith('.mov')) {
      mime = 'video/quicktime';
    } else if (lower.endsWith('.webm')) {
      mime = 'video/webm';
    } else if (lower.endsWith('.m4v')) {
      mime = 'video/x-m4v';
    }
    return R2StorageService().uploadMedia(
      bytes: bytes,
      fileName: name.isNotEmpty ? name : 'product_video.mp4',
      folder: 'products/videos',
      mimeType: mime,
    );
  }

  Future<List<String>> _resolveGalleryUrls(
    List<ProductGalleryDraftUpload> galleryItems, {
    Uint8List? legacyImageBytes,
    String? legacyImageExt,
  }) async {
    final urls = <String>[];
    if (galleryItems.isNotEmpty) {
      for (final item in galleryItems) {
        if (item.existingUrl != null && item.existingUrl!.trim().isNotEmpty) {
          urls.add(item.existingUrl!.trim());
        } else if (item.localBytes != null) {
          final uploaded = await _uploadProductImage(
            item.localBytes!,
            fileName: item.localName,
          );
          urls.add(uploaded);
        }
      }
    } else if (legacyImageBytes != null) {
      final uploaded = await _uploadProductImage(
        legacyImageBytes,
        fileName: legacyImageExt != null ? 'cover.$legacyImageExt' : null,
      );
      urls.add(uploaded);
    }
    return urls;
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
    List<ProductGalleryDraftUpload> galleryItems = const [],
    Uint8List? videoBytes,
    String? videoFileName,
  }) async {
    try {
      final shopId = await _getShopId();
      if (shopId == null) return null;

      final resolvedGallery = await _resolveGalleryUrls(
        galleryItems,
        legacyImageBytes: imageBytes,
        legacyImageExt: imageExt,
      );

      String? uploadedVideoUrl;
      if (videoBytes != null) {
        uploadedVideoUrl = await _uploadProductVideo(videoBytes, fileName: videoFileName);
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
        if (resolvedGallery.isNotEmpty) 'image_url': resolvedGallery.first,
        'image_urls': resolvedGallery,
        if (uploadedVideoUrl != null) 'video_url': uploadedVideoUrl,
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
    List<ProductGalleryDraftUpload>? galleryItems,
    Uint8List? newVideoBytes,
    String? newVideoFileName,
    String? existingVideoUrl,
    bool updateMedia = false,
  }) async {
    try {
      if (updateMedia && galleryItems != null) {
        final resolvedGallery = await _resolveGalleryUrls(galleryItems);
        updates['image_url'] = resolvedGallery.isNotEmpty ? resolvedGallery.first : null;
        updates['image_urls'] = resolvedGallery;

        if (newVideoBytes != null) {
          updates['video_url'] = await _uploadProductVideo(
            newVideoBytes,
            fileName: newVideoFileName,
          );
        } else {
          updates['video_url'] = (existingVideoUrl != null && existingVideoUrl.trim().isNotEmpty)
              ? existingVideoUrl.trim()
              : null;
        }
      } else if (imageBytes != null) {
        final imageUrl = await _uploadProductImage(
          imageBytes,
          fileName: imageExt != null ? 'cover.$imageExt' : null,
        );
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

  /// Updates stock level for a product
  Future<bool> updateStock(String productId, int newStock) async {
    try {
      final safeStock = newStock < 0 ? 0 : newStock;
      await _client.from('business_products').update({
        'stock': safeStock,
      }).eq('id', productId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deducts stock in batch when an order is completed
  Future<void> deductStockBatch(Map<String, int> productQuantities) async {
    for (final entry in productQuantities.entries) {
      try {
        final current = await _client
            .from('business_products')
            .select('stock, track_inventory')
            .eq('id', entry.key)
            .maybeSingle();

        if (current != null && (current['track_inventory'] as bool? ?? true)) {
          final currentStock = (current['stock'] as int?) ?? 0;
          final newStock = (currentStock - entry.value).clamp(0, 999999);
          await _client
              .from('business_products')
              .update({'stock': newStock})
              .eq('id', entry.key);
        }
      } catch (_) {}
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
