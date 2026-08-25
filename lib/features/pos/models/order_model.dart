// =============================================================================
// OrderModel — represents a POS transaction line item and full order
// =============================================================================

import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

class OrderModel {
  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final double total;
  final String status; // 'pending' | 'completed' | 'cancelled'
  final String? customerName;
  final String? notes;

  const OrderModel({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.total,
    required this.status,
    this.customerName,
    this.notes,
  });
}
