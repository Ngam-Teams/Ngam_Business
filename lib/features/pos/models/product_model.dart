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
  final List<String> imageUrls;
  final String? videoUrl;
  final String? description;
  final String? sku;
  final String? barcode;
  final int stock;
  final bool trackInventory;
  final int lowStockThreshold;
  final String unit; // 'pcs', 'pack', 'kg', 'g', 'portion', 'cup', 'box', 'set'
  final double weightKg;
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
    this.imageUrls = const [],
    this.videoUrl,
    this.description,
    this.sku,
    this.barcode,
    this.stock = 0,
    this.trackInventory = true,
    this.lowStockThreshold = 5,
    this.unit = 'pcs',
    this.weightKg = 0.5,
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
  bool get isProduct => !isService;

  /// Standalone exact price for a variant; falls back to product `price` if unset.
  double variantEffectivePrice(Map<String, dynamic> v) {
    final vp = (v['price'] as num?)?.toDouble() ??
        double.tryParse(v['price']?.toString() ?? '') ??
        0.0;
    return vp > 0 ? vp : price;
  }

  /// Per-variant stock if stored on the variant, else null.
  int? variantStock(Map<String, dynamic> v) {
    final raw = v['stock'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  /// Smart-parse weight in kg from text like `400g` -> 0.4, `2kg` -> 2.0, `10 kg` -> 10.0.
  static double? parseWeightKgFromName(String rawName) {
    final name = rawName.toLowerCase();
    final kgMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kg\b').firstMatch(name);
    if (kgMatch != null) {
      final parsed = double.tryParse(kgMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final gMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g(?:m|ram|rams)?\b').firstMatch(name);
    if (gMatch != null) {
      final parsed = double.tryParse(gMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) return (parsed / 1000.0).clamp(0.05, 500.0);
    }
    return null;
  }

  /// Per-variant shipping weight (kg): explicit `weight_kg` -> name parse -> product `weightKg`.
  double variantWeightKg(Map<String, dynamic> v) {
    final raw = v['weight_kg'];
    final explicit = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (explicit != null && explicit > 0) return explicit;
    final fromName = parseWeightKgFromName((v['name'] ?? '').toString());
    if (fromName != null) return fromName;
    return weightKg > 0 ? weightKg : 0.5;
  }

  bool get hasVariants => variants.isNotEmpty;

  double get minPrice {
    if (variants.isEmpty) return price;
    final prices = variants.map(variantEffectivePrice).where((p) => p > 0).toList();
    if (prices.isEmpty) return price;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return price;
    final prices = variants.map(variantEffectivePrice).where((p) => p > 0).toList();
    if (prices.isEmpty) return price;
    return prices.reduce((a, b) => a > b ? a : b);
  }

  bool get hasPriceRange => variants.isNotEmpty && (maxPrice - minPrice).abs() >= 0.005;

  /// Clean single lowest price for front catalogue & POS cards (`RM 17.90`).
  String get formattedMinPrice => 'RM ${minPrice.toStringAsFixed(2)}';

  /// Compact Shopee-style price range (`RM 17.90 - 280.80` when variants span a range).
  String get formattedPriceRange {
    if (hasPriceRange) {
      return 'RM ${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)}';
    }
    return 'RM ${minPrice.toStringAsFixed(2)}';
  }

  bool get hasVariantStock => variants.any((v) => variantStock(v) != null);

  int get effectiveTotalStock {
    if (variants.isNotEmpty && hasVariantStock) {
      return variants.fold<int>(0, (sum, v) => sum + ((variantStock(v) ?? 0).clamp(0, 999999)));
    }
    return stock;
  }

  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > minPrice && minPrice > 0;
  double? get discountPercent => hasDiscount ? (((compareAtPrice! - minPrice) / compareAtPrice!) * 100) : null;
  double? get profitMargin => (costPrice != null && costPrice! > 0 && minPrice > costPrice!)
      ? (((minPrice - costPrice!) / minPrice) * 100)
      : null;
  bool get isLowStock =>
      isProduct && trackInventory && effectiveTotalStock <= lowStockThreshold && effectiveTotalStock > 0;
  bool get isOutOfStock => isProduct && trackInventory && effectiveTotalStock <= 0;

  List<String> get galleryImages {
    final out = <String>[];
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      out.add(imageUrl!.trim());
    }
    for (final u in imageUrls) {
      final clean = u.trim();
      if (clean.isNotEmpty && !out.contains(clean)) {
        out.add(clean);
      }
    }
    return out;
  }

  static List<String> _parseImageList(Map<String, dynamic> json) {
    final out = <String>[];
    final primary = json['image_url']?.toString().trim() ?? '';
    if (primary.isNotEmpty) out.add(primary);
    final raw = json['image_urls'];
    if (raw is List) {
      for (final item in raw) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty && !out.contains(s)) {
          out.add(s);
        }
      }
    }
    return out;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final gallery = _parseImageList(json);
    final rawVideo = json['video_url']?.toString().trim();
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? 'Unnamed Item',
      itemType: json['item_type'] as String? ?? 'product',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (json['compare_at_price'] as num?)?.toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      imageUrl: gallery.isNotEmpty ? gallery.first : (json['image_url'] as String?),
      imageUrls: gallery,
      videoUrl: (rawVideo != null && rawVideo.isNotEmpty) ? rawVideo : null,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      trackInventory: json['track_inventory'] as bool? ?? true,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 5,
      unit: json['unit'] as String? ?? 'pcs',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.5,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isAvailable: json['is_active'] as bool? ?? (json['is_available'] as bool? ?? true),
      isFeatured: json['is_featured'] as bool? ?? false,
      isHalal: json['is_halal'] as bool? ?? false,
      variants: (json['variants'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      modifiers: (json['modifiers'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      serviceLocation: json['service_location'] as String? ?? 'in_store',
      maxPax: (json['max_pax'] as num?)?.toInt() ?? 1,
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
        'image_urls': imageUrls,
        'video_url': videoUrl,
        'description': description,
        'sku': sku,
        'barcode': barcode,
        'stock': stock,
        'track_inventory': trackInventory,
        'low_stock_threshold': lowStockThreshold,
        'unit': unit,
        'weight_kg': weightKg,
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
