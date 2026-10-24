import 'package:intl/intl.dart';

enum VoucherDiscountType { percentage, fixedAmount }

enum CustomerEligibility { all, newCustomers, membersOnly }

class VoucherModel {
  final String id;
  final String businessId;
  final String code;
  final String title;
  final String? description;
  final String discountType; // 'percentage' | 'fixed_amount'
  final double discountValue;
  final double? maxDiscountAmount;
  final double minSpend;
  final int? totalUsageLimit;
  final int usageLimitPerUser;
  final int timesUsed;
  final DateTime startDate;
  final DateTime? endDate;
  final String applicableScope; // 'all' | 'category' | 'specific_products'
  final List<String> applicableIds;
  final String customerEligibility; // 'all' | 'new_customers' | 'members_only'
  final bool isActive;
  final String? rewardItemName; // E.g. 'Kopi Latte Ais' or 'Servis Potong Rambut'
  final String? rewardItemId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VoucherModel({
    required this.id,
    required this.businessId,
    required this.code,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minSpend = 0.0,
    this.totalUsageLimit,
    this.usageLimitPerUser = 1,
    this.timesUsed = 0,
    required this.startDate,
    this.endDate,
    this.applicableScope = 'all',
    this.applicableIds = const [],
    this.customerEligibility = 'all',
    this.isActive = true,
    this.rewardItemName,
    this.rewardItemId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPercentage => discountType == 'percentage';
  bool get isFixedAmount => discountType == 'fixed_amount';
  bool get isFreeItem => discountType == 'free_item';
  bool get isBuyXGetY => discountType == 'buy_x_get_y';
  bool get isPointsMultiplier => discountType == 'points_multiplier';
  bool get isFreeShipping => discountType == 'free_shipping';

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  bool get isScheduled {
    return DateTime.now().isBefore(startDate);
  }

  bool get isFullyRedeemed {
    if (totalUsageLimit == null) return false;
    return timesUsed >= totalUsageLimit!;
  }

  bool get isCurrentlyValid {
    return isActive && !isExpired && !isScheduled && !isFullyRedeemed;
  }

  String get statusKey {
    if (!isActive) return 'inactive';
    if (isScheduled) return 'scheduled';
    if (isExpired) return 'expired';
    if (isFullyRedeemed) return 'depleted';
    return 'active';
  }

  String get statusLabel {
    switch (statusKey) {
      case 'active':
        return 'Aktif';
      case 'scheduled':
        return 'Akan Datang';
      case 'expired':
        return 'Tamat Tempoh';
      case 'depleted':
        return 'Habis Ditebus';
      case 'inactive':
      default:
        return 'Dinyahaktifkan';
    }
  }

  String get formattedDiscount {
    final currencyFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    if (isPercentage) {
      final pctStr = discountValue % 1 == 0
          ? '${discountValue.toInt()}% OFF'
          : '${discountValue.toStringAsFixed(1)}% OFF';
      if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
        return '$pctStr (Maks ${currencyFmt.format(maxDiscountAmount)})';
      }
      return pctStr;
    } else if (isFixedAmount) {
      return '${currencyFmt.format(discountValue)} OFF';
    } else if (isFreeItem) {
      return '🎁 Percuma: ${rewardItemName ?? title}';
    } else if (isBuyXGetY) {
      return '🛍️ Beli 2 Percuma 1 (BOGO)';
    } else if (isPointsMultiplier) {
      return '⭐ ${discountValue % 1 == 0 ? discountValue.toInt() : discountValue.toStringAsFixed(1)}x Poin Ganjaran';
    } else if (isFreeShipping) {
      return '🚚 Percuma Caj Servis';
    } else {
      return '${currencyFmt.format(discountValue)} OFF';
    }
  }

  String get shortDiscountBadge {
    if (isPercentage) {
      return discountValue % 1 == 0
          ? '${discountValue.toInt()}%'
          : '${discountValue.toStringAsFixed(1)}%';
    } else if (isFixedAmount) {
      return 'RM ${discountValue % 1 == 0 ? discountValue.toInt() : discountValue.toStringAsFixed(2)}';
    } else if (isFreeItem) {
      return 'HADIAH';
    } else if (isBuyXGetY) {
      return 'BOGO';
    } else if (isPointsMultiplier) {
      return '${discountValue.toInt()}X POIN';
    } else if (isFreeShipping) {
      return 'PERCUMA';
    } else {
      return 'RM ${discountValue.toStringAsFixed(0)}';
    }
  }

  String get formattedMinSpend {
    final currencyFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    if (minSpend <= 0) return 'Tanpa Belanja Min.';
    return 'Min. Belanja ${currencyFmt.format(minSpend)}';
  }

  String get formattedValidity {
    final dateFmt = DateFormat('d MMM yyyy');
    final startStr = dateFmt.format(startDate.toLocal());
    if (endDate == null) {
      return 'Bermula $startStr (Tiada Tarikh Tamat)';
    }
    final endStr = dateFmt.format(endDate!.toLocal());
    return '$startStr - $endStr';
  }

  String get formattedEligibility {
    switch (customerEligibility) {
      case 'new_customers':
        return 'Pelanggan Baru';
      case 'members_only':
        return 'Ahli Sahaja';
      case 'all':
      default:
        return 'Semua Pelanggan';
    }
  }

  int? get remainingQuota {
    if (totalUsageLimit == null) return null;
    final rem = totalUsageLimit! - timesUsed;
    return rem < 0 ? 0 : rem;
  }

  double get quotaProgress {
    if (totalUsageLimit == null || totalUsageLimit! <= 0) return 0.0;
    return (timesUsed / totalUsageLimit!).clamp(0.0, 1.0);
  }

  /// Calculates potential discount for given subtotal in pure Dart
  double calculateDiscount(double subtotal) {
    if (!isCurrentlyValid) return 0.0;
    if (subtotal < minSpend) return 0.0;

    double calculated = 0.0;
    if (isPercentage) {
      final raw = subtotal * (discountValue / 100.0);
      if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
        calculated = raw > maxDiscountAmount! ? maxDiscountAmount! : raw;
      } else {
        calculated = raw;
      }
    } else if (isFixedAmount) {
      calculated = discountValue;
    } else if (isFreeItem) {
      // Free item is inserted into cart with price RM 0.00 directly
      calculated = 0.0;
    } else if (isFreeShipping) {
      calculated = discountValue > 0 ? discountValue : 0.0;
    } else {
      calculated = discountValue;
    }

    if (calculated > subtotal) calculated = subtotal;
    return double.parse(calculated.toStringAsFixed(2));
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    List<String> parseApplicableIds(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return const [];
    }

    String? rewardName = json['reward_item_name']?.toString();
    if (rewardName == null || rewardName.isEmpty) {
      final desc = json['description']?.toString() ?? '';
      final match = RegExp(r'\[Reward:\s*(.+?)\]').firstMatch(desc);
      if (match != null) {
        rewardName = match.group(1)?.trim();
      }
    }

    return VoucherModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      code: (json['code']?.toString() ?? '').toUpperCase(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: json['discount_type']?.toString() ?? 'percentage',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
      minSpend: (json['min_spend'] as num?)?.toDouble() ?? 0.0,
      totalUsageLimit: json['total_usage_limit'] as int?,
      usageLimitPerUser: (json['usage_limit_per_user'] as int?) ?? 1,
      timesUsed: (json['times_used'] as int?) ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      applicableScope: json['applicable_scope']?.toString() ?? 'all',
      applicableIds: parseApplicableIds(json['applicable_ids']),
      customerEligibility: json['customer_eligibility']?.toString() ?? 'all',
      isActive: json['is_active'] as bool? ?? true,
      rewardItemName: rewardName,
      rewardItemId: json['reward_item_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    String? effectiveDesc = description?.trim();
    if (rewardItemName != null && rewardItemName!.isNotEmpty) {
      final tag = '[Reward: ${rewardItemName!.trim()}]';
      if (effectiveDesc == null || effectiveDesc.isEmpty) {
        effectiveDesc = tag;
      } else if (!effectiveDesc.contains('[Reward:')) {
        effectiveDesc = '$tag $effectiveDesc';
      }
    }

    return {
      'business_id': businessId,
      'code': code.toUpperCase().trim(),
      'title': title.trim(),
      'description': effectiveDesc,
      'discount_type': discountType,
      'discount_value': discountValue,
      'max_discount_amount': maxDiscountAmount,
      'min_spend': minSpend,
      'total_usage_limit': totalUsageLimit,
      'usage_limit_per_user': usageLimitPerUser,
      'times_used': timesUsed,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'applicable_scope': applicableScope,
      'applicable_ids': applicableIds,
      'customer_eligibility': customerEligibility,
      'is_active': isActive,
    };
  }

  VoucherModel copyWith({
    String? id,
    String? businessId,
    String? code,
    String? title,
    String? description,
    String? discountType,
    double? discountValue,
    double? maxDiscountAmount,
    double? minSpend,
    int? totalUsageLimit,
    int? usageLimitPerUser,
    int? timesUsed,
    DateTime? startDate,
    DateTime? endDate,
    String? applicableScope,
    List<String>? applicableIds,
    String? customerEligibility,
    bool? isActive,
    String? rewardItemName,
    String? rewardItemId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      minSpend: minSpend ?? this.minSpend,
      totalUsageLimit: totalUsageLimit ?? this.totalUsageLimit,
      usageLimitPerUser: usageLimitPerUser ?? this.usageLimitPerUser,
      timesUsed: timesUsed ?? this.timesUsed,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      applicableScope: applicableScope ?? this.applicableScope,
      applicableIds: applicableIds ?? this.applicableIds,
      customerEligibility: customerEligibility ?? this.customerEligibility,
      isActive: isActive ?? this.isActive,
      rewardItemName: rewardItemName ?? this.rewardItemName,
      rewardItemId: rewardItemId ?? this.rewardItemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
