// =============================================================================
// OrderModel — represents a POS transaction line item, payment split, and full order
// =============================================================================

import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

class PaymentSplit {
  final String method; // 'cash' | 'duitnow' | 'card' | 'ewallet'
  final double amount;
  final double? tenderedAmount; // e.g. paid RM50 for RM35 (change = RM15)
  final double? changeAmount;
  final String? reference;

  PaymentSplit({
    required this.method,
    required this.amount,
    this.tenderedAmount,
    this.changeAmount,
    this.reference,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'amount': amount,
    if (tenderedAmount != null) 'tendered_amount': tenderedAmount,
    if (changeAmount != null) 'change_amount': changeAmount,
    if (reference != null) 'reference': reference,
  };

  factory PaymentSplit.fromJson(Map<String, dynamic> json) => PaymentSplit(
    method: json['method'] as String? ?? 'cash',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    tenderedAmount: (json['tendered_amount'] as num?)?.toDouble(),
    changeAmount: (json['change_amount'] as num?)?.toDouble(),
    reference: json['reference'] as String?,
  );

  String get displayName {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai (Cash)';
      case 'duitnow':
        return 'DuitNow QR';
      case 'card':
        return 'Kad (Debit/Credit)';
      case 'ewallet':
        return 'E-Wallet (TnG/Grab)';
      default:
        return method.toUpperCase();
    }
  }
}

class OrderModel {
  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final double total;
  final String status; // 'pending' | 'completed' | 'cancelled'
  final String? customerName;
  final String? notes;
  final String? paymentMethod;
  final List<PaymentSplit>? paymentSplits;

  const OrderModel({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.total,
    required this.status,
    this.customerName,
    this.notes,
    this.paymentMethod,
    this.paymentSplits,
  });
}
