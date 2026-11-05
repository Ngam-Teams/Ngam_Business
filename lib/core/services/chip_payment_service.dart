import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChipPurchaseResult {
  final String id;
  final String checkoutUrl;
  final String duitNowUrl;
  final double amount;
  final String status;
  final Map<String, dynamic> raw;

  ChipPurchaseResult({
    required this.id,
    required this.checkoutUrl,
    required this.duitNowUrl,
    required this.amount,
    required this.status,
    required this.raw,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isWebFallback => raw['is_web_fallback'] == true;
}

class ChipPaymentService {
  static final ChipPaymentService instance = ChipPaymentService._internal();
  ChipPaymentService._internal();

  String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://rsueaoglsdxhzpupjljd.supabase.co';
  String get _edgeFunctionUrl => '$_supabaseUrl/functions/v1/payment-webhook';

  /// Create a dynamic DuitNow QR purchase on CHIP strictly via Server-Side Edge Function
  Future<ChipPurchaseResult> createDuitNowPurchase({
    required double amount,
    required String orderTitle,
    String? reference,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) async {
    try {
      final edgeRes = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'create_purchase',
          'order_title': orderTitle,
          'reference': reference ?? '',
          'order_id': reference ?? '',
          'payment_channel': 'duitnow_qr',
          'client_name': (clientName != null && clientName.isNotEmpty) ? clientName : 'Pelanggan Kaunter',
          'client_email': (clientEmail != null && clientEmail.isNotEmpty) ? clientEmail : 'customer@ngam.dev',
          'client_phone': (clientPhone != null && clientPhone.isNotEmpty) ? clientPhone : '+601115892468',
          'payment_method_whitelist': ['duitnow_qr'],
        }),
      );

      if (edgeRes.statusCode >= 200 && edgeRes.statusCode < 300) {
        final data = jsonDecode(edgeRes.body) as Map<String, dynamic>;
        final id = data['id']?.toString() ?? '';
        final checkoutUrl = (data['checkout_url'] as String?) ?? 'https://gate.chip-in.asia/p/$id/';
        final duitNowUrl = data['payment_methods']?['duitnow']?['qr_code_url']?.toString() ??
            '$checkoutUrl?preferred=duitnow_qr';
        final status = (data['status'] as String?) ?? 'created';
        final serverCents = (data['purchase']?['total'] as num?)?.toInt();
        final verifiedAmount = serverCents != null ? serverCents / 100.0 : amount;

        return ChipPurchaseResult(
          id: id,
          checkoutUrl: checkoutUrl,
          duitNowUrl: duitNowUrl,
          amount: verifiedAmount,
          status: status,
          raw: data,
        );
      } else {
        debugPrint('[ChipPaymentService] Edge function return ${edgeRes.statusCode}: ${edgeRes.body}');
        throw Exception('Gagal mengesahkan sesi pembayaran selamat di pelayan: ${edgeRes.body}');
      }
    } catch (e) {
      debugPrint('[ChipPaymentService] Edge function error: $e');
      rethrow;
    }
  }

  /// Poll or check status of a purchase strictly via Server-Side Edge Function
  Future<String> checkPurchaseStatus(String purchaseId) async {
    if (purchaseId.isEmpty || purchaseId.startsWith('web-')) {
      return 'created';
    }

    try {
      final edgeRes = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'check_status',
          'purchase_id': purchaseId,
        }),
      );
      if (edgeRes.statusCode == 200) {
        final data = jsonDecode(edgeRes.body) as Map<String, dynamic>;
        final status = (data['status'] as String?)?.toLowerCase();
        if (status != null && status.isNotEmpty) {
          return status;
        }
      }
    } catch (e) {
      debugPrint('[ChipPaymentService] Status check error: $e');
    }

    return 'unknown';
  }
}
