// =============================================================================
// POS Feature Models
// =============================================================================

class ProductModel {
  final String id;
  final String name;
  final double price;
  final String? category;
  final String? imageUrl;
  final int stock;
  final bool isAvailable;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.category,
    this.imageUrl,
    this.stock = 0,
    this.isAvailable = true,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Product',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      stock: json['stock'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': category,
        'image_url': imageUrl,
        'stock': stock,
        'is_available': isAvailable,
      };
}
