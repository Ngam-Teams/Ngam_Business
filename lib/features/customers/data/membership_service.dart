import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';

// =============================================================================
// CustomerMember Model
// =============================================================================

class CustomerMember {
  final String id;
  final String name;
  final String phone;
  final String tier; // 'Gold VIP' | 'Silver VIP' | 'Member' | 'Regular'
  final int stamps;
  final int totalStampsRequired;
  final int points;
  final int visits;
  final double totalSpent;
  final String? lastVisit;
  final String? qrCode;

  const CustomerMember({
    required this.id,
    required this.name,
    required this.phone,
    this.tier = 'Member',
    this.stamps = 0,
    this.totalStampsRequired = 5,
    this.points = 0,
    this.visits = 1,
    this.totalSpent = 0.0,
    this.lastVisit,
    this.qrCode,
  });

  bool get isVip => tier.contains('VIP');
  bool get hasFreeRewardAvailable => stamps >= totalStampsRequired;

  String get tierBadge {
    switch (tier) {
      case 'Gold VIP':
        return '👑 Gold VIP';
      case 'Silver VIP':
        return '⭐ Silver VIP';
      case 'Regular':
        return '🌱 Pelanggan Biasa';
      default:
        return '✨ Ahli Ngam';
    }
  }

  factory CustomerMember.fromJson(Map<String, dynamic> json) {
    return CustomerMember(
      id: json['id']?.toString() ?? '',
      name: json['customer_name']?.toString() ?? json['name']?.toString() ?? 'Pelanggan',
      phone: json['customer_phone']?.toString() ?? json['phone']?.toString() ?? '',
      tier: json['tier']?.toString() ?? 'Member',
      stamps: (json['current_stamps'] as num?)?.toInt() ?? (json['stamps'] as num?)?.toInt() ?? 0,
      totalStampsRequired: (json['total_stamps_required'] as num?)?.toInt() ?? 5,
      points: (json['points'] as num?)?.toInt() ?? 0,
      visits: (json['visits'] as num?)?.toInt() ?? (json['total_visits'] as num?)?.toInt() ?? 1,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      lastVisit: json['lastVisit']?.toString() ?? json['last_stamped_at']?.toString(),
      qrCode: json['qr_code']?.toString() ?? 'NGAM-MEM-${json['id']?.toString().substring(0, 8)}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_name': name,
    'customer_phone': phone,
    'tier': tier,
    'current_stamps': stamps,
    'total_stamps_required': totalStampsRequired,
    'points': points,
    'visits': visits,
    'total_spent': totalSpent,
    'qr_code': qrCode,
  };
}

// =============================================================================
// MembershipService
// =============================================================================

class MembershipService {
  static final MembershipService instance = MembershipService._internal();
  MembershipService._internal({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  factory MembershipService() => instance;

  final SupabaseClient _client;
  final BusinessService _businessService;

  Future<String?> _getBusinessId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id']?.toString();
  }

  /// Normalizes phone numbers (e.g. '+60 11-2345 6789' -> '01123456789')
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('60')) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  /// Fetch loyalty members from database for current business
  Future<List<CustomerMember>> getLoyaltyMembers([String? explicitBusinessId]) async {
    try {
      final businessId = explicitBusinessId ?? await _getBusinessId();
      if (businessId == null || businessId.isEmpty) return [];

      final rows = await _client
          .from('customer_loyalty_cards')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List).map((r) => CustomerMember.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[MembershipService] getLoyaltyMembers error: $e');
      }
      return [];
    }
  }

  /// For backwards compatibility: returns empty list
  List<CustomerMember> getAllPresetMembers() => const [];

  /// Find member by phone, QR code, or member ID
  Future<CustomerMember?> findMember(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    final normPhone = normalizePhone(cleanInput);

    // Query Supabase customer_loyalty_cards table
    try {
      final businessId = await _getBusinessId();
      if (businessId == null || businessId.isEmpty) return null;

      final res = await _client
          .from('customer_loyalty_cards')
          .select()
          .eq('business_id', businessId)
          .or('customer_phone.eq.$normPhone,customer_phone.eq.$cleanInput,id.eq.$cleanInput,customer_name.ilike.%$cleanInput%')
          .maybeSingle();

      if (res != null) {
        return CustomerMember.fromJson(res);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MembershipService] findMember error: $e');
      }
    }

    return null;
  }

  /// Registers a walk-in customer on the spot at POS counter
  Future<CustomerMember> registerWalkInMember({
    required String name,
    required String phone,
  }) async {
    final normPhone = normalizePhone(phone);
    final cleanName = name.trim();

    final businessId = await _getBusinessId();
    if (businessId == null || businessId.isEmpty) {
      throw Exception('Profil perniagaan tidak dijumpai.');
    }

    // Find or create default program_id
    final progRes = await _client
        .from('loyalty_programs')
        .select('id')
        .eq('business_id', businessId)
        .limit(1)
        .maybeSingle();

    String? programId = progRes?['id']?.toString();
    if (programId == null || programId.isEmpty) {
      final newProg = await _client.from('loyalty_programs').insert({
        'business_id': businessId,
        'title': 'Kad Cop Kesetiaan Ngam',
        'total_stamps': 5,
        'reward_title': 'Ganjaran Percuma',
        'min_spend_per_stamp': 10.0,
      }).select('id').single();
      programId = newProg['id']?.toString();
    }

    final inserted = await _client.from('customer_loyalty_cards').insert({
      'program_id': programId,
      'business_id': businessId,
      'customer_name': cleanName.isNotEmpty ? cleanName : 'Pelanggan Baru',
      'customer_phone': normPhone.isNotEmpty ? normPhone : phone,
      'current_stamps': 1,
      'total_stamps_required': 5,
    }).select().single();

    return CustomerMember.fromJson(inserted);
  }

  /// Records visit / stamp after payment
  Future<void> recordVisit({
    required String phone,
    required double amountSpent,
  }) async {
    final norm = normalizePhone(phone);
    final businessId = await _getBusinessId();
    if (businessId == null || businessId.isEmpty || norm.isEmpty) return;

    try {
      final existing = await _client
          .from('customer_loyalty_cards')
          .select()
          .eq('business_id', businessId)
          .eq('customer_phone', norm)
          .maybeSingle();
      if (existing != null) {
        final curStamps = (existing['current_stamps'] as num?)?.toInt() ?? 0;
        final reqStamps = (existing['total_stamps_required'] as num?)?.toInt() ?? 5;
        final nextStamps = (curStamps + 1) > reqStamps ? 1 : (curStamps + 1);
        await _client
            .from('customer_loyalty_cards')
            .update({
              'current_stamps': nextStamps,
              'last_stamped_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', existing['id'])
            .eq('business_id', businessId);
      }
    } catch (_) {}
  }
}
