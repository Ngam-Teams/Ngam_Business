import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/r2_storage_service.dart';

// =============================================================================
// Ngam Business — Merchant Dispute & 3-Way Mediation Service
// =============================================================================

class MerchantDisputeCase {
  final String id;
  final String caseNumber;
  final String targetType; // 'order' | 'booking'
  final String? orderId;
  final String? bookingId;
  final String? bookingRef;
  final String? conversationId;
  final String businessId;
  final String customerId;
  final String customerName;
  final String businessName;
  final String? itemSummary;
  final String reasonCode;
  final String reasonText;
  final double orderTotalAmount;
  final double requestedRefundAmount;
  final double? approvedRefundAmount;
  final String status;
  final String? businessResponseText;
  final List<String> customerEvidenceUrls;
  final List<String> businessEvidenceUrls;
  final String? moderatorNote;
  final String? moderatorResolution;
  final DateTime? businessResponseDeadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  MerchantDisputeCase({
    required this.id,
    required this.caseNumber,
    required this.targetType,
    this.orderId,
    this.bookingId,
    this.bookingRef,
    this.conversationId,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.businessName,
    this.itemSummary,
    required this.reasonCode,
    required this.reasonText,
    required this.orderTotalAmount,
    required this.requestedRefundAmount,
    this.approvedRefundAmount,
    required this.status,
    this.businessResponseText,
    required this.customerEvidenceUrls,
    required this.businessEvidenceUrls,
    this.moderatorNote,
    this.moderatorResolution,
    this.businessResponseDeadline,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  bool get isResolved =>
      status.startsWith('resolved_') || status == 'withdrawn';

  bool get isEscalated =>
      status == 'escalated' || status == 'under_review';

  factory MerchantDisputeCase.fromJson(Map<String, dynamic> j) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    DateTime? parseDt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    return MerchantDisputeCase(
      id: (j['id'] ?? '').toString(),
      caseNumber: (j['case_number'] ?? '').toString(),
      targetType: (j['target_type'] ?? 'order').toString(),
      orderId: j['order_id']?.toString(),
      bookingId: j['booking_id']?.toString(),
      bookingRef: j['booking_ref']?.toString(),
      conversationId: j['conversation_id']?.toString(),
      businessId: (j['business_id'] ?? '').toString(),
      customerId: (j['customer_id'] ?? '').toString(),
      customerName: (j['customer_name'] ?? 'Pelanggan Ngam').toString(),
      businessName: (j['business_name'] ?? 'Kedai Ngam').toString(),
      itemSummary: j['item_summary']?.toString(),
      reasonCode: (j['reason_code'] ?? 'other').toString(),
      reasonText: (j['reason_text'] ?? '').toString(),
      orderTotalAmount:
          double.tryParse((j['order_total_amount'] ?? 0).toString()) ?? 0.0,
      requestedRefundAmount:
          double.tryParse((j['requested_refund_amount'] ?? 0).toString()) ?? 0.0,
      approvedRefundAmount: j['approved_refund_amount'] != null
          ? double.tryParse(j['approved_refund_amount'].toString())
          : null,
      status: (j['status'] ?? 'open').toString(),
      businessResponseText: j['business_response_text']?.toString(),
      customerEvidenceUrls: parseList(j['customer_evidence_urls']),
      businessEvidenceUrls: parseList(j['business_evidence_urls']),
      moderatorNote: j['moderator_note']?.toString(),
      moderatorResolution: j['moderator_resolution']?.toString(),
      businessResponseDeadline: parseDt(j['business_response_deadline']),
      createdAt: parseDt(j['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(j['updated_at']) ?? DateTime.now(),
      resolvedAt: parseDt(j['resolved_at']),
    );
  }
}

class MerchantDisputeMessage {
  final String id;
  final String disputeId;
  final String? senderId;
  final String senderRole; // 'customer' | 'business' | 'moderator' | 'system'
  final String senderName;
  final String message;
  final List<String> attachments;
  final DateTime createdAt;

  MerchantDisputeMessage({
    required this.id,
    required this.disputeId,
    this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.message,
    required this.attachments,
    required this.createdAt,
  });

  factory MerchantDisputeMessage.fromJson(Map<String, dynamic> j) {
    final rawAtt = j['attachments'];
    final list = rawAtt is List
        ? rawAtt.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    return MerchantDisputeMessage(
      id: (j['id'] ?? '').toString(),
      disputeId: (j['dispute_id'] ?? '').toString(),
      senderId: j['sender_id']?.toString(),
      senderRole: (j['sender_role'] ?? 'customer').toString(),
      senderName: (j['sender_name'] ?? '').toString(),
      message: (j['message'] ?? '').toString(),
      attachments: list,
      createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
    );
  }
}

class MerchantDisputeService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<String> uploadEvidenceImage(
    Uint8List bytes,
    String fileName,
  ) async {
    final lower = fileName.toLowerCase();
    final ext = lower.endsWith('.png') ? 'png' : 'jpg';
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final cleanName =
        'biz_dispute_${DateTime.now().millisecondsSinceEpoch}.$ext';
    return await R2StorageService().uploadMedia(
      bytes: bytes,
      fileName: cleanName,
      folder: 'disputes',
      mimeType: mime,
    );
  }

  static Future<List<MerchantDisputeCase>> fetchBusinessDisputes(
    String businessId,
  ) async {
    try {
      final rows = await _db
          .from('disputes')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => MerchantDisputeCase.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Stream<List<MerchantDisputeCase>> watchBusinessDisputes(
    String businessId,
  ) {
    return _db
        .from('disputes')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => MerchantDisputeCase.fromJson(Map<String, dynamic>.from(r)))
            .toList())
        .handleError((_) {});
  }

  static Future<MerchantDisputeCase?> fetchDisputeByOrder(String orderId) async {
    try {
      final row = await _db
          .from('disputes')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return MerchantDisputeCase.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<MerchantDisputeCase?> fetchDisputeByBooking({
    String? bookingId,
    String? bookingRef,
  }) async {
    try {
      if (bookingId != null && bookingId.isNotEmpty) {
        final row = await _db
            .from('disputes')
            .select()
            .eq('booking_id', bookingId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row != null) {
          return MerchantDisputeCase.fromJson(Map<String, dynamic>.from(row));
        }
      }
      if (bookingRef != null && bookingRef.isNotEmpty) {
        final row = await _db
            .from('disputes')
            .select()
            .eq('booking_ref', bookingRef)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row != null) {
          return MerchantDisputeCase.fromJson(Map<String, dynamic>.from(row));
        }
      }
    } catch (_) {}
    return null;
  }

  static Stream<MerchantDisputeCase> watchDispute(String disputeId) {
    return _db
        .from('disputes')
        .stream(primaryKey: ['id'])
        .eq('id', disputeId)
        .map((rows) => MerchantDisputeCase.fromJson(
            Map<String, dynamic>.from(rows.first)));
  }

  static Stream<List<MerchantDisputeMessage>> watchMessages(String disputeId) {
    return _db
        .from('dispute_messages')
        .stream(primaryKey: ['id'])
        .eq('dispute_id', disputeId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .map((r) => MerchantDisputeMessage.fromJson(
                Map<String, dynamic>.from(r)))
            .toList())
        .handleError((_) {});
  }

  static Future<void> sendMessage({
    required String disputeId,
    required String message,
    required String senderName,
    List<String> attachments = const [],
  }) async {
    final uid = _db.auth.currentUser?.id;
    await _db.from('dispute_messages').insert({
      'dispute_id': disputeId,
      'sender_id': uid,
      'sender_role': 'business',
      'sender_name': senderName,
      'message': message.trim(),
      'attachments': attachments,
    });
  }

  static Future<void> respondDispute({
    required String disputeId,
    required String decision, // 'agree_refund' | 'counter_evidence' | 'counter' | 'escalate'
    String? responseText,
    List<String> evidenceUrls = const [],
  }) async {
    final action = decision == 'counter_evidence' ? 'counter' : decision;
    await _db.rpc('respond_dispute_case', params: {
      'p_dispute_id': disputeId,
      'p_action': action,
      'p_response_text': responseText ?? '',
      'p_evidence_urls': evidenceUrls,
    });
  }

  static Future<void> escalateToAdmin(String disputeId, {String? note}) async {
    await _db.rpc('escalate_dispute_case', params: {
      'p_dispute_id': disputeId,
      'p_note': note,
    });
  }
}
