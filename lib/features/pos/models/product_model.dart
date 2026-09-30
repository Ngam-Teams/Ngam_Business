// =============================================================================
// POS & Catalogue Feature Models: Complete Product & Service Attributes
// Modern E-Commerce Standard (Shopify / Square / GrabFood / Fresha inspired)
// =============================================================================

class ProductModel {
  final String id;
  final String name;
  final String itemType; // 'product' or 'service'
  final double price;
  final double? compareAtPrice;
  final double? costPrice;
  final double taxRate;
  final String? category;
  final String? subCategory;
  final String? imageUrl;
  final String? description;
  final String? sku;
  final String? barcode;
  final int stock;
  final bool trackInventory;
  final int lowStockThreshold;
  final String unit; // 'pcs', 'pack', 'kg', 'g', 'portion', 'cup', 'box', 'set'
  final List<String> tags;
  final bool isAvailable;
  final bool isFeatured;
  final bool isHalal;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> modifiers;

  // Service-specific attributes:
  final int durationMinutes;
  final int bufferMinutes;
  final double depositAmount;
  final String serviceLocation; // 'in_store', 'mobile_service', 'online'
  final int maxPax;

  const ProductModel({
    required this.id,
    required this.name,
    this.itemType = 'product',
    required this.price,
    this.compareAtPrice,
    this.costPrice,
    this.taxRate = 0.0,
    this.category,
    this.subCategory,
    this.imageUrl,
    this.description,
    this.sku,
    this.barcode,
    this.stock = 0,
    this.trackInventory = true,
    this.lowStockThreshold = 5,
    this.unit = 'pcs',
    this.tags = const [],
    this.isAvailable = true,
    this.isFeatured = false,
    this.isHalal = false,
    this.variants = const [],
    this.modifiers = const [],
    this.durationMinutes = 30,
    this.bufferMinutes = 0,
    this.depositAmount = 0.0,
    this.serviceLocation = 'in_store',
    this.maxPax = 1,
  });

  bool get isService => itemType == 'service';
  bool get isProduct => itemType != 'service';
  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;
  double? get discountPercent => hasDiscount ? (((compareAtPrice! - price) / compareAtPrice!) * 100) : null;
  double? get profitMargin => (costPrice != null && costPrice! > 0 && price > costPrice!)
      ? (((price - costPrice!) / price) * 100)
      : null;
  bool get isLowStock => isProduct && trackInventory && stock <= lowStockThreshold && stock > 0;
  bool get isOutOfStock => isProduct && trackInventory && stock <= 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Item',
      itemType: json['item_type'] as String? ?? 'product',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (json['compare_at_price'] as num?)?.toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      stock: json['stock'] as int? ?? 0,
      trackInventory: json['track_inventory'] as bool? ?? true,
      lowStockThreshold: json['low_stock_threshold'] as int? ?? 5,
      unit: json['unit'] as String? ?? 'pcs',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isAvailable: json['is_active'] as bool? ?? (json['is_available'] as bool? ?? true),
      isFeatured: json['is_featured'] as bool? ?? false,
      isHalal: json['is_halal'] as bool? ?? false,
      variants: (json['variants'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      modifiers: (json['modifiers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      bufferMinutes: json['buffer_minutes'] as int? ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      serviceLocation: json['service_location'] as String? ?? 'in_store',
      maxPax: json['max_pax'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'item_type': itemType,
        'price': price,
        'compare_at_price': compareAtPrice,
        'cost_price': costPrice,
        'tax_rate': taxRate,
        'category': category,
        'sub_category': subCategory,
        'image_url': imageUrl,
        'description': description,
        'sku': sku,
        'barcode': barcode,
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
      };
}
