import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../../../core/services/audit_service.dart';
import '../models/voucher_model.dart';

class VoucherValidationResult {
  final bool isValid;
  final String? voucherId;
  final String? code;
  final String? title;
  final String? discountType;
  final double discountAmount;
  final double finalTotal;
  final String message;
  final bool isFreeItem;
  final String? rewardItemName;
  final VoucherModel? voucher;

  VoucherValidationResult({
    required this.isValid,
    this.voucherId,
    this.code,
    this.title,
    this.discountType,
    this.discountAmount = 0.0,
    this.finalTotal = 0.0,
    required this.message,
    this.isFreeItem = false,
    this.rewardItemName,
    this.voucher,
  });

  factory VoucherValidationResult.fromRpc(Map<String, dynamic> map, double fallbackSubtotal) {
    final valid = map['valid'] as bool? ?? false;
    final discount = (map['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final finalTot = (map['final_total'] as num?)?.toDouble() ?? (fallbackSubtotal - discount);
    final discType = map['discount_type']?.toString();
    final isFree = discType == 'free_item' || map['is_free_item'] == true;

    return VoucherValidationResult(
      isValid: valid,
      voucherId: map['voucher_id']?.toString(),
      code: map['code']?.toString(),
      title: map['title']?.toString(),
      discountType: discType,
      discountAmount: discount,
      finalTotal: finalTot < 0 ? 0 : finalTot,
      isFreeItem: isFree,
      rewardItemName: map['reward_item_name']?.toString(),
      message: map['message']?.toString() ?? (valid ? (isFree ? 'Ganjaran percuma sah!' : 'Baucar sah!') : 'Baucar tidak sah.'),
    );
  }
}

class VoucherStats {
  final int totalCount;
  final int activeCount;
  final int totalRedemptions;
  final double totalDiscountGiven;

  const VoucherStats({
    this.totalCount = 0,
    this.activeCount = 0,
    this.totalRedemptions = 0,
    this.totalDiscountGiven = 0.0,
  });
}

class VoucherService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  VoucherService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getBusinessId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  // ---------------------------------------------------------------------------
  // Fetch & Stream Vouchers
  // ---------------------------------------------------------------------------

  Future<List<VoucherModel>> fetchVouchers({String? businessId}) async {
    final bId = businessId ?? await _getBusinessId();
    if (bId == null) return [];

    final response = await _client
        .from('vouchers')
        .select()
        .eq('business_id', bId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => VoucherModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Stream<List<VoucherModel>> streamVouchers({String? businessId}) async* {
    final bId = businessId ?? await _getBusinessId();
    if (bId == null) {
      yield [];
      return;
    }

    yield* _client
        .from('vouchers')
        .stream(primaryKey: ['id'])
        .eq('business_id', bId)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => VoucherModel.fromJson(json)).toList());
  }

  // ---------------------------------------------------------------------------
  // Create / Update / Delete
  // ---------------------------------------------------------------------------

  Future<VoucherModel> createVoucher({
    required String code,
    required String title,
    String? description,
    required String discountType, // 'percentage' | 'fixed_amount' | 'free_item' | 'buy_x_get_y' | 'points_multiplier' | 'free_shipping'
    required double discountValue,
    double? maxDiscountAmount,
    double minSpend = 0.0,
    int? totalUsageLimit,
    int usageLimitPerUser = 1,
    required DateTime startDate,
    DateTime? endDate,
    String applicableScope = 'all',
    List<String> applicableIds = const [],
    String customerEligibility = 'all',
    bool isActive = true,
    String? rewardItemName,
    String? rewardItemId,
  }) async {
    final businessId = await _getBusinessId();
    if (businessId == null) {
      throw Exception('Profil perniagaan tidak dijumpai.');
    }

    final cleanCode = code.trim().toUpperCase();

    // Check duplicate code within same business
    final existing = await _client
        .from('vouchers')
        .select('id')
        .eq('business_id', businessId)
        .eq('code', cleanCode)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Kod baucar "$cleanCode" sudah wujud. Sila gunakan kod lain.');
    }

    String? effectiveDesc = description?.trim();
    if (rewardItemName != null && rewardItemName.isNotEmpty) {
      final tag = '[Reward: ${rewardItemName.trim()}]';
      if (effectiveDesc == null || effectiveDesc.isEmpty) {
        effectiveDesc = tag;
      } else if (!effectiveDesc.contains('[Reward:')) {
        effectiveDesc = '$tag $effectiveDesc';
      }
    }

    final insertPayload = {
      'business_id': businessId,
      'code': cleanCode,
      'title': title.trim(),
      'description': effectiveDesc,
      'discount_type': discountType,
      'discount_value': discountValue,
      'max_discount_amount': maxDiscountAmount,
      'min_spend': minSpend,
      'total_usage_limit': totalUsageLimit,
      'usage_limit_per_user': usageLimitPerUser,
      'times_used': 0,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'applicable_scope': applicableScope,
      'applicable_ids': applicableIds,
      'customer_eligibility': customerEligibility,
      'is_active': isActive,
    };

    final response = await _client.from('vouchers').insert(insertPayload).select().single();
    final newVoucher = VoucherModel.fromJson(response);

    // Tamper-proof audit logging
    await AuditService.log(
      action: 'voucher_created',
      description: 'Mencipta baucar promosi baru: $cleanCode (${newVoucher.formattedDiscount})',
      severity: 'info',
      targetType: 'voucher',
      targetId: newVoucher.id,
      metadata: {
        'code': cleanCode,
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_spend': minSpend,
      },
    );

    return newVoucher;
  }

  Future<void> updateVoucher(String id, Map<String, dynamic> updates) async {
    final businessId = await _getBusinessId();
    if (businessId == null) throw Exception('Profil perniagaan tidak dijumpai.');

    await _client.from('vouchers').update({
      ...updates,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('business_id', businessId);

    await AuditService.log(
      action: 'voucher_updated',
      description: 'Mengemaskini tetapan baucar: ${updates['code'] ?? id}',
      severity: 'info',
      targetType: 'voucher',
      targetId: id,
      metadata: updates,
    );
  }

  Future<void> toggleVoucherStatus(String id, bool isActive, String code) async {
    final businessId = await _getBusinessId();
    if (businessId == null) return;

    await _client.from('vouchers').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('business_id', businessId);

    await AuditService.log(
      action: isActive ? 'voucher_activated' : 'voucher_deactivated',
      description: isActive ? 'Mengaktifkan baucar promosi $code' : 'Menyahaktifkan / menjeda baucar promosi $code',
      severity: 'info',
      targetType: 'voucher',
      targetId: id,
      metadata: {'code': code, 'is_active': isActive},
    );
  }

  Future<void> deleteVoucher(String id, String code) async {
    final businessId = await _getBusinessId();
    if (businessId == null) throw Exception('Profil perniagaan tidak dijumpai.');

    await _client.from('vouchers').delete().eq('id', id).eq('business_id', businessId);

    await AuditService.log(
      action: 'voucher_deleted',
      description: 'Memadam baucar promosi $code secara kekal',
      severity: 'warning',
      targetType: 'voucher',
      targetId: id,
      metadata: {'code': code},
    );
  }

  // ---------------------------------------------------------------------------
  // Validation RPC (with local fallback)
  // ---------------------------------------------------------------------------

  Future<VoucherValidationResult> validateVoucherCode({
    required String code,
    required double subtotal,
    String? businessId,
    String? userId,
    String? customerPhone,
  }) async {
    final bId = businessId ?? await _getBusinessId();
    if (bId == null) {
      return VoucherValidationResult(
        isValid: false,
        message: 'Maklumat perniagaan tidak sah.',
      );
    }

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return VoucherValidationResult(
        isValid: false,
        message: 'Sila masukkan kod baucar.',
      );
    }

    try {
      // 1. Cuba panggil RPC database Supabase dahulu (server-side atomic validation)
      final rpcRes = await _client.rpc('validate_voucher_discount', params: {
        'p_business_id': bId,
        'p_code': cleanCode,
        'p_subtotal': subtotal,
        'p_user_id': userId,
        'p_customer_phone': customerPhone,
      });

      if (rpcRes is Map<String, dynamic>) {
        return VoucherValidationResult.fromRpc(rpcRes, subtotal);
      }
    } catch (e) {
      if (kDebugMode) {
        print('RPC validate_voucher_discount error, falling back to client query: $e');
      }
    }

    // 2. Fallback bersandar terus pada jadual vouchers jika RPC belum dideploy di Supabase
    try {
      final res = await _client
          .from('vouchers')
          .select()
          .eq('business_id', bId)
          .ilike('code', cleanCode)
          .maybeSingle();

      if (res == null) {
        return VoucherValidationResult(
          isValid: false,
          message: 'Kod baucar "$cleanCode" tidak wujud atau tidak sah.',
        );
      }

      final voucher = VoucherModel.fromJson(res);

      if (!voucher.isActive) {
        return VoucherValidationResult(
          isValid: false,
          message: 'Baucar ini telah dinyahaktifkan.',
        );
      }

      if (voucher.isScheduled) {
        return VoucherValidationResult(
          isValid: false,
          message: 'Baucar ini belum bermula lagi.',
        );
      }

      if (voucher.isExpired) {
        return VoucherValidationResult(
          isValid: false,
          message: 'Baucar ini telah tamat tempoh.',
        );
      }

      if (voucher.isFullyRedeemed) {
        return VoucherValidationResult(
          isValid: false,
          message: 'Kuota penebusan bagi baucar ini telah habis.',
        );
      }

      if (subtotal < voucher.minSpend) {
        return VoucherValidationResult(
          isValid: false,
          message: 'Belanja minimum RM ${voucher.minSpend.toStringAsFixed(2)} diperlukan untuk menebus baucar ini.',
        );
      }

      if (voucher.isFreeItem) {
        return VoucherValidationResult(
          isValid: true,
          voucherId: voucher.id,
          code: voucher.code,
          title: voucher.title,
          discountType: voucher.discountType,
          discountAmount: 0.0,
          finalTotal: subtotal,
          isFreeItem: true,
          rewardItemName: voucher.rewardItemName ?? voucher.title,
          voucher: voucher,
          message: 'Ganjaran Penebusan: Percuma 1x ${voucher.rewardItemName ?? voucher.title}!',
        );
      }

      final discount = voucher.calculateDiscount(subtotal);
      final finalTotal = (subtotal - discount).clamp(0.0, double.infinity);

      return VoucherValidationResult(
        isValid: true,
        voucherId: voucher.id,
        code: voucher.code,
        title: voucher.title,
        discountType: voucher.discountType,
        discountAmount: discount,
        finalTotal: finalTotal,
        voucher: voucher,
        message: 'Baucar ${voucher.code} berjaya digunakan! Jimat RM ${discount.toStringAsFixed(2)}',
      );
    } catch (err) {
      return VoucherValidationResult(
        isValid: false,
        message: 'Gagal mengesahkan baucar: $err',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Record Usage
  // ---------------------------------------------------------------------------

  Future<void> recordVoucherUsage({
    required String voucherId,
    required double discountAmount,
    required double orderSubtotal,
    String? orderId,
    String? customerPhone,
    String? userId,
  }) async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) return;

      // 1. Rekod transaksi penggunaan
      await _client.from('voucher_usages').insert({
        'voucher_id': voucherId,
        'business_id': businessId,
        'discount_amount': discountAmount,
        'order_subtotal': orderSubtotal,
        if (orderId != null) 'order_id': orderId,
        if (customerPhone != null) 'customer_phone': customerPhone,
        if (userId != null) 'user_id': userId,
        'used_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Kemaskini times_used pada jadual vouchers
      final voucherData = await _client.from('vouchers').select('times_used').eq('id', voucherId).maybeSingle();
      final currentTimes = (voucherData?['times_used'] as int?) ?? 0;

      await _client.from('vouchers').update({
        'times_used': currentTimes + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', voucherId);
    } catch (e) {
      if (kDebugMode) {
        print('recordVoucherUsage error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Metrics Calculation
  // ---------------------------------------------------------------------------

  Future<VoucherStats> getVoucherStats() async {
    try {
      final vouchers = await fetchVouchers();
      if (vouchers.isEmpty) return const VoucherStats();

      int totalCount = vouchers.length;
      int activeCount = vouchers.where((v) => v.isCurrentlyValid).length;
      int totalRedemptions = vouchers.fold(0, (sum, v) => sum + v.timesUsed);

      double totalDiscountGiven = 0.0;
      try {
        final bId = await _getBusinessId();
        if (bId != null) {
          final usages = await _client
              .from('voucher_usages')
              .select('discount_amount')
              .eq('business_id', bId);

          for (final row in (usages as List)) {
            totalDiscountGiven += (row['discount_amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (_) {
        // Fallback estimate
        totalDiscountGiven = vouchers.fold(0.0, (sum, v) {
          if (v.isFixedAmount) {
            return sum + (v.timesUsed * v.discountValue);
          }
          return sum;
        });
      }

      return VoucherStats(
        totalCount: totalCount,
        activeCount: activeCount,
        totalRedemptions: totalRedemptions,
        totalDiscountGiven: totalDiscountGiven,
      );
    } catch (e) {
      return const VoucherStats();
    }
  }
}
