// =============================================================================
// OrderModel — represents a POS transaction line item, payment split, held tab, and full order
// =============================================================================

import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;
  final bool isReward;
  final String? rewardDescription;
  String? selectedVariant;
  double variantPriceDelta;
  List<Map<String, dynamic>> selectedModifiers;
  String? itemNote;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isReward = false,
    this.rewardDescription,
    this.selectedVariant,
    this.variantPriceDelta = 0.0,
    List<Map<String, dynamic>>? selectedModifiers,
    this.itemNote,
  }) : selectedModifiers = selectedModifiers ?? [];

  double get modifiersTotal => selectedModifiers.fold(
        0.0,
        (sum, m) => sum + ((m['price'] as num?)?.toDouble() ?? 0.0),
      );

  double get unitPriceWithAddons =>
      isReward ? 0.0 : (product.price + variantPriceDelta + modifiersTotal);

  double get subtotal => isReward ? 0.0 : unitPriceWithAddons * quantity;

  bool get hasCustomizations =>
      (selectedVariant != null && selectedVariant!.trim().isNotEmpty) ||
      selectedModifiers.isNotEmpty ||
      (itemNote != null && itemNote!.trim().isNotEmpty);

  /// Unique key to distinguish same product with different variants/modifiers in the cart
  String get cartLineKey {
    final modNames = selectedModifiers.map((m) => m['name']?.toString() ?? '').toList()..sort();
    return '${product.id}|${selectedVariant ?? ""}|${modNames.join(",")}|${itemNote ?? ""}|$isReward';
  }

  /// Compact summary for POS cart UI
  String get customizationSummary {
    final parts = <String>[];
    if (selectedVariant != null && selectedVariant!.trim().isNotEmpty) {
      parts.add(
        variantPriceDelta > 0
            ? '$selectedVariant (+RM ${variantPriceDelta.toStringAsFixed(2)})'
            : selectedVariant!,
      );
    }
    for (final m in selectedModifiers) {
      final name = m['name']?.toString() ?? '';
      final price = (m['price'] as num?)?.toDouble() ?? 0.0;
      if (name.isNotEmpty) {
        parts.add(price > 0 ? '+$name (RM ${price.toStringAsFixed(2)})' : '+$name');
      }
    }
    if (itemNote != null && itemNote!.trim().isNotEmpty) {
      parts.add('Nota: "${itemNote!.trim()}"');
    }
    return parts.join(' • ');
  }

  /// Formatted product name for KDS, order_items, and Thermal Receipts
  String get formattedOrderItemName {
    final buffer = StringBuffer(product.name);
    if (isReward) {
      buffer.write(' (Ganjaran Percuma)');
    }
    if (selectedVariant != null && selectedVariant!.trim().isNotEmpty) {
      buffer.write(' [$selectedVariant]');
    }
    if (selectedModifiers.isNotEmpty) {
      final mods = selectedModifiers.map((m) => m['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
      if (mods.isNotEmpty) {
        buffer.write(' (+$mods)');
      }
    }
    if (itemNote != null && itemNote!.trim().isNotEmpty) {
      buffer.write(' {Nota: ${itemNote!.trim()}}');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'is_reward': isReward,
        'reward_description': rewardDescription,
        'selected_variant': selectedVariant,
        'variant_price_delta': variantPriceDelta,
        'selected_modifiers': selectedModifiers,
        'item_note': itemNote,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: ProductModel.fromJson(Map<String, dynamic>.from(json['product'] as Map)),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      isReward: json['is_reward'] as bool? ?? false,
      rewardDescription: json['reward_description'] as String?,
      selectedVariant: json['selected_variant'] as String?,
      variantPriceDelta: (json['variant_price_delta'] as num?)?.toDouble() ?? 0.0,
      selectedModifiers: (json['selected_modifiers'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      itemNote: json['item_note'] as String?,
    );
  }
}

class HeldOrderModel {
  final String id;
  final String ticketNumber;
  final String orderType; // 'dine_in' | 'takeaway' | 'delivery'
  final String tableNumber;
  final String? customerName;
  final List<CartItem> items;
  final DateTime heldAt;
  final String? notes;
  final double manualDiscount;
  final String? manualDiscountLabel;

  HeldOrderModel({
    required this.id,
    required this.ticketNumber,
    required this.orderType,
    required this.tableNumber,
    this.customerName,
    required this.items,
    required this.heldAt,
    this.notes,
    this.manualDiscount = 0.0,
    this.manualDiscountLabel,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.subtotal);
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticket_number': ticketNumber,
        'order_type': orderType,
        'table_number': tableNumber,
        'customer_name': customerName,
        'items': items.map((i) => i.toJson()).toList(),
        'held_at': heldAt.toIso8601String(),
        'notes': notes,
        'manual_discount': manualDiscount,
        'manual_discount_label': manualDiscountLabel,
      };

  factory HeldOrderModel.fromJson(Map<String, dynamic> json) {
    return HeldOrderModel(
      id: json['id'] as String? ?? '',
      ticketNumber: json['ticket_number'] as String? ?? '#NG-0000',
      orderType: json['order_type'] as String? ?? 'dine_in',
      tableNumber: json['table_number'] as String? ?? '01',
      customerName: json['customer_name'] as String?,
      items: (json['items'] as List?)
              ?.map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      heldAt: DateTime.tryParse(json['held_at'] as String? ?? '') ?? DateTime.now(),
      notes: json['notes'] as String?,
      manualDiscount: (json['manual_discount'] as num?)?.toDouble() ?? 0.0,
      manualDiscountLabel: json['manual_discount_label'] as String?,
    );
  }
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
