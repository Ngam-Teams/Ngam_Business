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

  // Local preset members list for instant cashier lookup & offline stability
  final List<CustomerMember> _presetMembers = [
    const CustomerMember(
      id: 'CUST-01',
      name: 'Danish Irfan',
      phone: '01123456789',
      tier: 'Gold VIP',
      stamps: 4,
      totalStampsRequired: 5,
      points: 250,
      visits: 18,
      totalSpent: 740.00,
      lastVisit: '3 hari lepas',
      qrCode: 'NGAM-MEM-01123456789',
    ),
    const CustomerMember(
      id: 'CUST-02',
      name: 'Haziq Aiman',
      phone: '01798765432',
      tier: 'Silver VIP',
      stamps: 3,
      totalStampsRequired: 5,
      points: 150,
      visits: 12,
      totalSpent: 480.00,
      lastVisit: '1 minggu lepas',
      qrCode: 'NGAM-MEM-01798765432',
    ),
    const CustomerMember(
      id: 'CUST-03',
      name: 'Melissa Tan',
      phone: '01233445566',
      tier: 'Silver VIP',
      stamps: 5, // Reward ready to redeem!
      totalStampsRequired: 5,
      points: 90,
      visits: 9,
      totalSpent: 395.00,
      lastVisit: '2 minggu lepas',
      qrCode: 'NGAM-MEM-01233445566',
    ),
    const CustomerMember(
      id: 'CUST-04',
      name: 'Luqman Hakim',
      phone: '01344556677',
      tier: 'Regular',
      stamps: 2,
      totalStampsRequired: 5,
      points: 50,
      visits: 5,
      totalSpent: 175.00,
      lastVisit: 'Semalam',
      qrCode: 'NGAM-MEM-01344556677',
    ),
    const CustomerMember(
      id: 'CUST-05',
      name: 'Suresh Kumar',
      phone: '01488990011',
      tier: 'Regular',
      stamps: 1,
      totalStampsRequired: 5,
      points: 30,
      visits: 3,
      totalSpent: 105.00,
      lastVisit: '1 bulan lepas',
      qrCode: 'NGAM-MEM-01488990011',
    ),
  ];

  Future<String?> _getBusinessId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Normalizes phone numbers (e.g. '+60 11-2345 6789' -> '01123456789')
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('60')) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  /// List of all members (presets + registered)
  List<CustomerMember> getAllPresetMembers() => List.unmodifiable(_presetMembers);

  /// Find member by phone, QR code, or member ID
  Future<CustomerMember?> findMember(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    final normPhone = normalizePhone(cleanInput);

    // 1. Check local preset/cached members first for blazing speed
    for (final m in _presetMembers) {
      if (m.phone == normPhone ||
          m.id.toLowerCase() == cleanInput.toLowerCase() ||
          (m.qrCode != null && m.qrCode!.toLowerCase() == cleanInput.toLowerCase()) ||
          m.name.toLowerCase().contains(cleanInput.toLowerCase())) {
        return m;
      }
    }

    // 2. Query Supabase customer_loyalty_cards table
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) return null;

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
        print('[MembershipService] findMember error, falling back: $e');
      }
    }

    // 3. Fallback: If it's a valid Malaysian phone number, auto-recognize as a walk-in member
    if (normPhone.length >= 10 && normPhone.startsWith('01')) {
      return CustomerMember(
        id: 'MEM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: 'Pelanggan ($normPhone)',
        phone: normPhone,
        tier: 'Member',
        stamps: 1,
        totalStampsRequired: 5,
        points: 10,
        visits: 1,
        qrCode: 'NGAM-MEM-$normPhone',
      );
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

    final newMember = CustomerMember(
      id: 'MEM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      name: cleanName.isNotEmpty ? cleanName : 'Pelanggan Baru',
      phone: normPhone.isNotEmpty ? normPhone : phone,
      tier: 'Member',
      stamps: 1,
      totalStampsRequired: 5,
      points: 10,
      visits: 1,
      totalSpent: 0.0,
      lastVisit: 'Baru didaftarkan',
      qrCode: 'NGAM-MEM-$normPhone',
    );

    // Save to local cache
    _presetMembers.insert(0, newMember);

    // Try persisting to Supabase customer_loyalty_cards if loyalty program exists
    try {
      final businessId = await _getBusinessId();
      if (businessId != null) {
        // Find or create default program_id
        final progRes = await _client
            .from('loyalty_programs')
            .select('id')
            .eq('business_id', businessId)
            .limit(1)
            .maybeSingle();

        String? programId = progRes?['id'];
        if (programId == null) {
          final newProg = await _client.from('loyalty_programs').insert({
            'business_id': businessId,
            'title': 'Kad Cop Kesetiaan Ngam',
            'total_stamps': 5,
            'reward_title': 'Ganjaran Percuma',
            'min_spend_per_stamp': 10.0,
          }).select('id').single();
          programId = newProg['id'];
        }

        await _client.from('customer_loyalty_cards').insert({
          'program_id': programId,
          'business_id': businessId,
          'customer_name': newMember.name,
          'customer_phone': newMember.phone,
          'current_stamps': 1,
          'total_stamps_required': 5,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MembershipService] registerWalkInMember DB insert fallback: $e');
      }
    }

    return newMember;
  }

  /// Records visit / stamp after payment
  Future<void> recordVisit({
    required String phone,
    required double amountSpent,
  }) async {
    final norm = normalizePhone(phone);
    final idx = _presetMembers.indexWhere((m) => m.phone == norm);
    if (idx != -1) {
      final current = _presetMembers[idx];
      final newStamps = current.stamps + 1;
      final newPoints = current.points + (amountSpent / 1.0).floor(); // 1 point per RM 1
      final newVisits = current.visits + 1;
      final newSpent = current.totalSpent + amountSpent;
      final newTier = newSpent >= 700
          ? 'Gold VIP'
          : (newSpent >= 350 ? 'Silver VIP' : 'Member');

      _presetMembers[idx] = CustomerMember(
        id: current.id,
        name: current.name,
        phone: current.phone,
        tier: newTier,
        stamps: newStamps > current.totalStampsRequired ? 1 : newStamps,
        totalStampsRequired: current.totalStampsRequired,
        points: newPoints,
        visits: newVisits,
        totalSpent: newSpent,
        lastVisit: 'Hari ini',
        qrCode: current.qrCode,
      );
    }
  }
}
