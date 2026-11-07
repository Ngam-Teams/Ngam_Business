import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../models/loyalty_model.dart';

class LoyaltyService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  // Local in-memory seed / fallback
  static LoyaltyProgramModel? _localProgram;
  static final List<CustomerLoyaltyCardModel> _localCards = [];

  /// Reset in-memory cached program and loyalty cards (e.g. on sign out)
  static void reset() {
    _localProgram = null;
    _localCards.clear();
  }

  LoyaltyService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Fetches the active loyalty program for this business
  Future<LoyaltyProgramModel> fetchProgram() async {
    final businessId = await _getShopId() ?? 'local_shop';

    if (_localProgram != null) return _localProgram!;

    try {
      final res = await _client
          .from('loyalty_programs')
          .select()
          .eq('business_id', businessId)
          .maybeSingle();

      if (res != null) {
        _localProgram = LoyaltyProgramModel.fromJson(res);
        return _localProgram!;
      }
    } catch (_) {}

    // Default program preset
    _localProgram = LoyaltyProgramModel(
      id: 'prog_default',
      businessId: businessId,
      title: 'Kad Cop Gunting Rambut VIP',
      totalStamps: 5,
      rewardTitle: 'Percuma 1x Gunting Rambut & Cuci',
      minSpendPerStamp: 20.0,
      createdAt: DateTime.now(),
    );
    return _localProgram!;
  }

  /// Updates or saves the loyalty program settings
  Future<void> saveProgram(LoyaltyProgramModel program) async {
    _localProgram = program;

    try {
      final businessId = await _getShopId();
      if (businessId == null) return;

      await _client.from('loyalty_programs').upsert({
        ...program.toJson(),
        'business_id': businessId,
      });
    } catch (_) {}
  }

  /// Fetches customer cards
  Future<List<CustomerLoyaltyCardModel>> fetchCustomerCards() async {
// Only fetch real customer loyalty cards from database

    try {
      final businessId = await _getShopId();
      if (businessId != null) {
        final res = await _client
            .from('customer_loyalty_cards')
            .select()
            .eq('business_id', businessId)
            .order('last_stamped_at', ascending: false);

        if (res.isNotEmpty) {
          final loaded = res
              .map((j) => CustomerLoyaltyCardModel.fromJson(j))
              .toList();
          _localCards
            ..clear()
            ..addAll(loaded);
          return loaded;
        }
      }
    } catch (_) {}

    return List.from(_localCards);
  }

  /// Chops 1 stamp for a customer by phone number
  Future<CustomerLoyaltyCardModel> chopStamp({
    required String customerPhone,
    String? customerName,
    int stampsToAdd = 1,
  }) async {
    final program = await fetchProgram();
    final cleanPhone = customerPhone.trim();

    // Check existing
    final idx = _localCards.indexWhere(
        (c) => c.customerPhone.replaceAll(RegExp(r'\D'), '') == cleanPhone.replaceAll(RegExp(r'\D'), ''));

    CustomerLoyaltyCardModel updated;

    if (idx != -1) {
      final old = _localCards[idx];
      updated = old.copyWith(
        currentStamps: old.currentStamps + stampsToAdd,
        lastStampedAt: DateTime.now(),
      );
      _localCards[idx] = updated;
    } else {
      updated = CustomerLoyaltyCardModel(
        id: 'card_${DateTime.now().millisecondsSinceEpoch}',
        programId: program.id,
        businessId: program.businessId,
        customerName: customerName ?? 'Pelanggan Setia',
        customerPhone: cleanPhone,
        currentStamps: stampsToAdd,
        totalStampsRequired: program.totalStamps,
        lastStampedAt: DateTime.now(),
      );
      _localCards.insert(0, updated);
    }

    try {
      final businessId = await _getShopId();
      if (businessId != null) {
        final existing = await _client
            .from('customer_loyalty_cards')
            .select('id, current_stamps')
            .eq('business_id', businessId)
            .eq('customer_phone', updated.customerPhone)
            .maybeSingle();
        if (existing != null) {
          final newCount = ((existing['current_stamps'] as num?)?.toInt() ?? 0) + stampsToAdd;
          await _client.from('customer_loyalty_cards').update({
            'current_stamps': newCount,
            'last_stamped_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
        } else {
          await _client.from('customer_loyalty_cards').insert({
            'program_id': program.id,
            'business_id': businessId,
            'customer_name': updated.customerName,
            'customer_phone': updated.customerPhone,
            'current_stamps': updated.currentStamps,
            'total_stamps_required': updated.totalStampsRequired,
            'last_stamped_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (_) {}

    return updated;
  }

  /// Redeems the reward once customer has collected required stamps
  Future<CustomerLoyaltyCardModel> redeemReward(String cardId) async {
    final idx = _localCards.indexWhere((c) => c.id == cardId);
    if (idx == -1) throw Exception('Kad cop tidak ditemui');

    final old = _localCards[idx];
    if (old.currentStamps < old.totalStampsRequired) {
      throw Exception('Cop belum cukup untuk tebus ganjaran');
    }

    final updated = old.copyWith(
      currentStamps: old.currentStamps - old.totalStampsRequired,
      totalRewardsRedeemed: old.totalRewardsRedeemed + 1,
      lastStampedAt: DateTime.now(),
    );

    _localCards[idx] = updated;

    try {
      await _client.from('customer_loyalty_cards').update({
        'current_stamps': updated.currentStamps,
        'total_rewards_redeemed': updated.totalRewardsRedeemed,
        'last_stamped_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);
    } catch (_) {}

    return updated;
  }
}
