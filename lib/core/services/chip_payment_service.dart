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

  static const String _defaultBrandId = '844a8f74-4426-4285-9a90-3c39e1259e75';
  static const String _baseUrl = 'https://gate.chip-in.asia/api/v1';

  String get _brandId => dotenv.env['CHIP_BRAND_ID'] ?? _defaultBrandId;
  String get _apiKey => dotenv.env['CHIP_API_KEY'] ?? '';
  String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://rsueaoglsdxhzpupjljd.supabase.co';
  String get _edgeFunctionUrl => '$_supabaseUrl/functions/v1/payment-webhook';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  /// Create a dynamic DuitNow QR purchase on CHIP
  Future<ChipPurchaseResult> createDuitNowPurchase({
    required double amount,
    required String orderTitle,
    String? reference,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) async {
    // 1. Try Supabase Edge Function proxy first (solves Flutter Web CORS and links webhook)
    try {
      final edgeRes = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'create_purchase',
          'amount': amount,
          'order_title': orderTitle,
          'reference': reference ?? '',
          'order_id': reference ?? '',
          'client_name': (clientName != null && clientName.isNotEmpty) ? clientName : 'Pelanggan Kaunter',
          'client_email': (clientEmail != null && clientEmail.isNotEmpty) ? clientEmail : 'customer@ngam.dev',
          'client_phone': (clientPhone != null && clientPhone.isNotEmpty) ? clientPhone : '+601115892468',
          'brand_id': _brandId,
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

        return ChipPurchaseResult(
          id: id,
          checkoutUrl: checkoutUrl,
          duitNowUrl: duitNowUrl,
          amount: amount,
          status: status,
          raw: data,
        );
      } else {
        debugPrint('[ChipPaymentService] Edge function return ${edgeRes.statusCode}: ${edgeRes.body}');
      }
    } catch (e) {
      debugPrint('[ChipPaymentService] Edge function proxy error, falling back to direct CHIP API: $e');
    }

    // 2. Fallback to direct CHIP API
    final cents = (amount * 100).round();
    final url = Uri.parse('$_baseUrl/purchases/');

    final payload = {
      'brand_id': _brandId,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      'client': {
        'email': (clientEmail != null && clientEmail.isNotEmpty)
            ? clientEmail
            : 'customer@ngam.dev',
        'full_name': (clientName != null && clientName.isNotEmpty)
            ? clientName
            : 'Pelanggan Kaunter',
        'phone': (clientPhone != null && clientPhone.isNotEmpty)
            ? clientPhone
            : '+601115892468',
      },
      'purchase': {
        'currency': 'MYR',
        'products': [
          {
            'name': orderTitle,
            'price': cents,
            'quantity': 1,
          }
        ],
      },
      'payment_method_whitelist': ['duitnow_qr'],
      'success_callback': _edgeFunctionUrl,
      'success_redirect': 'https://ngam.dev/payment-success',
      'failure_redirect': 'https://ngam.dev/payment-failure',
    };

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final id = data['id'] as String;
        final checkoutUrl = (data['checkout_url'] as String?) ??
            'https://gate.chip-in.asia/p/$id/';
        final duitNowUrl = '$checkoutUrl?preferred=duitnow_qr';
        final status = (data['status'] as String?) ?? 'created';

        return ChipPurchaseResult(
          id: id,
          checkoutUrl: checkoutUrl,
          duitNowUrl: duitNowUrl,
          amount: amount,
          status: status,
          raw: data,
        );
      } else {
        debugPrint('[ChipPaymentService] Create error: ${response.statusCode} - ${response.body}');
        throw Exception('Gagal menjana DuitNow QR: ${response.body}');
      }
    } catch (e) {
      if (kIsWeb) {
        debugPrint('[ChipPaymentService] Browser CORS active on Web. Activating Web Sandbox Simulator for RM ${amount.toStringAsFixed(2)}: $e');
        final mockId = 'web-${DateTime.now().millisecondsSinceEpoch}';
        final mockQrData = 'duitnow://pay?brand=NGAM&amount=${amount.toStringAsFixed(2)}&orderRef=$mockId';
        return ChipPurchaseResult(
          id: mockId,
          checkoutUrl: '',
          duitNowUrl: mockQrData,
          amount: amount,
          status: 'created',
          raw: {'id': mockId, 'is_web_fallback': true, 'amount': amount},
        );
      }
      rethrow;
    }
  }

  /// Poll or check status of a purchase
  Future<String> checkPurchaseStatus(String purchaseId) async {
    if (purchaseId.startsWith('web-')) {
      return 'created';
    }

    // 1. Try checking status via Supabase Edge Function
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
    } catch (_) {}

    // 2. Fallback to direct CHIP API
    try {
      final url = Uri.parse('$_baseUrl/purchases/$purchaseId/');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'unknown';
        return status.toLowerCase();
      } else {
        debugPrint('[ChipPaymentService] Status check error: ${response.statusCode}');
        return 'unknown';
      }
    } catch (_) {
      return 'unknown';
    }
  }
}
