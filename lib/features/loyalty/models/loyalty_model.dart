// =============================================================================
// LoyaltyModel — Digital Loyalty Stamp Card Program & Customer Cards
// =============================================================================

class LoyaltyProgramModel {
  final String id;
  final String businessId;
  final String title; // e.g. "Kad Cop Gunting Rambut VIP"
  final int totalStamps; // e.g. 5, 8, 10
  final String rewardTitle; // e.g. "Percuma 1x Haircut & Cuci"
  final double minSpendPerStamp; // e.g. RM 20.00
  final bool isActive;
  final DateTime createdAt;

  const LoyaltyProgramModel({
    required this.id,
    required this.businessId,
    required this.title,
    this.totalStamps = 5,
    required this.rewardTitle,
    this.minSpendPerStamp = 0.0,
    this.isActive = true,
    required this.createdAt,
  });

  factory LoyaltyProgramModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyProgramModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      title: json['title'] as String? ?? 'Kad Cop Kesetiaan',
      totalStamps: (json['total_stamps'] as num?)?.toInt() ?? 5,
      rewardTitle: json['reward_title'] as String? ?? 'Ganjaran Percuma',
      minSpendPerStamp: (json['min_spend_per_stamp'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'title': title,
    'total_stamps': totalStamps,
    'reward_title': rewardTitle,
    'min_spend_per_stamp': minSpendPerStamp,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  LoyaltyProgramModel copyWith({
    String? title,
    int? totalStamps,
    String? rewardTitle,
    double? minSpendPerStamp,
    bool? isActive,
  }) {
    return LoyaltyProgramModel(
      id: id,
      businessId: businessId,
      title: title ?? this.title,
      totalStamps: totalStamps ?? this.totalStamps,
      rewardTitle: rewardTitle ?? this.rewardTitle,
      minSpendPerStamp: minSpendPerStamp ?? this.minSpendPerStamp,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

class CustomerLoyaltyCardModel {
  final String id;
  final String programId;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final int currentStamps;
  final int totalStampsRequired;
  final int totalRewardsRedeemed;
  final DateTime lastStampedAt;

  const CustomerLoyaltyCardModel({
    required this.id,
    required this.programId,
    required this.businessId,
    required this.customerName,
    required this.customerPhone,
    required this.currentStamps,
    this.totalStampsRequired = 5,
    this.totalRewardsRedeemed = 0,
    required this.lastStampedAt,
  });

  bool get isRewardReady => currentStamps >= totalStampsRequired;

  int get stampsRemaining =>
      (totalStampsRequired - currentStamps).clamp(0, totalStampsRequired);

  factory CustomerLoyaltyCardModel.fromJson(Map<String, dynamic> json) {
    return CustomerLoyaltyCardModel(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      businessId: json['business_id'] as String,
      customerName: json['customer_name'] as String? ?? 'Pelanggan',
      customerPhone: json['customer_phone'] as String? ?? '',
      currentStamps: (json['current_stamps'] as num?)?.toInt() ?? 0,
      totalStampsRequired: (json['total_stamps_required'] as num?)?.toInt() ?? 5,
      totalRewardsRedeemed: (json['total_rewards_redeemed'] as num?)?.toInt() ?? 0,
      lastStampedAt: json['last_stamped_at'] != null
          ? DateTime.parse(json['last_stamped_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'program_id': programId,
    'business_id': businessId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'current_stamps': currentStamps,
    'total_stamps_required': totalStampsRequired,
    'total_rewards_redeemed': totalRewardsRedeemed,
    'last_stamped_at': lastStampedAt.toIso8601String(),
  };

  CustomerLoyaltyCardModel copyWith({
    int? currentStamps,
    int? totalRewardsRedeemed,
    DateTime? lastStampedAt,
  }) {
    return CustomerLoyaltyCardModel(
      id: id,
      programId: programId,
      businessId: businessId,
      customerName: customerName,
      customerPhone: customerPhone,
      currentStamps: currentStamps ?? this.currentStamps,
      totalStampsRequired: totalStampsRequired,
      totalRewardsRedeemed: totalRewardsRedeemed ?? this.totalRewardsRedeemed,
      lastStampedAt: lastStampedAt ?? this.lastStampedAt,
    );
  }
}
