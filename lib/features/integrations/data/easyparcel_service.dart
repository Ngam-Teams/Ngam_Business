import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';

/// Standard EasyParcel Malaysia state codes (Appendix III)
const List<Map<String, String>> kMalaysiaStates = [
  {'code': 'kul', 'name': 'W.P. Kuala Lumpur'},
  {'code': 'sgr', 'name': 'Selangor'},
  {'code': 'pjy', 'name': 'W.P. Putrajaya'},
  {'code': 'jhr', 'name': 'Johor'},
  {'code': 'png', 'name': 'Pulau Pinang'},
  {'code': 'prk', 'name': 'Perak'},
  {'code': 'kdh', 'name': 'Kedah'},
  {'code': 'pls', 'name': 'Perlis'},
  {'code': 'nsn', 'name': 'Negeri Sembilan'},
  {'code': 'mlk', 'name': 'Melaka'},
  {'code': 'phg', 'name': 'Pahang'},
  {'code': 'trg', 'name': 'Terengganu'},
  {'code': 'ktn', 'name': 'Kelantan'},
  {'code': 'srw', 'name': 'Sarawak'},
  {'code': 'sbh', 'name': 'Sabah'},
  {'code': 'lbn', 'name': 'W.P. Labuan'},
];

class EasyParcelConfig {
  final bool isConnected;
  final String mode; // 'platform' (Ngam managed, default) | 'custom' (merchant own key)
  final String environment; // 'demo' | 'live'
  final String apiKey;
  final String senderName;
  final String senderPhone;
  final String senderAddr1;
  final String senderAddr2;
  final String senderCity;
  final String senderPostcode;
  final String senderState; // EasyParcel state code e.g. 'sgr', 'kul'
  final bool autoSync;

  const EasyParcelConfig({
    this.isConnected = false,
    this.mode = 'platform',
    this.environment = 'demo',
    this.apiKey = '',
    this.senderName = '',
    this.senderPhone = '',
    this.senderAddr1 = '',
    this.senderAddr2 = '',
    this.senderCity = '',
    this.senderPostcode = '',
    this.senderState = 'sgr',
    this.autoSync = true,
  });

  bool get isPlatformMode => mode != 'custom';

  factory EasyParcelConfig.fromRow(Map<String, dynamic> row) {
    final cfg = row['config'] is Map
        ? Map<String, dynamic>.from(row['config'] as Map)
        : <String, dynamic>{};
    return EasyParcelConfig(
      isConnected: row['is_connected'] == true,
      mode: (cfg['mode']?.toString() == 'custom') ? 'custom' : 'platform',
      environment: (row['environment']?.toString() == 'live') ? 'live' : 'demo',
      apiKey: row['api_key']?.toString() ?? '',
      senderName: cfg['sender_name']?.toString() ?? '',
      senderPhone: cfg['sender_phone']?.toString() ?? '',
      senderAddr1: cfg['sender_addr1']?.toString() ?? '',
      senderAddr2: cfg['sender_addr2']?.toString() ?? '',
      senderCity: cfg['sender_city']?.toString() ?? '',
      senderPostcode: cfg['sender_postcode']?.toString() ?? '',
      senderState: cfg['sender_state']?.toString() ?? 'sgr',
      autoSync: cfg['auto_sync'] != false,
    );
  }

  Map<String, dynamic> toConfigJson() => {
        'mode': mode,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'sender_addr1': senderAddr1,
        'sender_addr2': senderAddr2,
        'sender_city': senderCity,
        'sender_postcode': senderPostcode,
        'sender_state': senderState,
        'auto_sync': autoSync,
      };
}

class EasyParcelRate {
  final String rateId;
  final String serviceId;
  final String serviceName;
  final String serviceDetail; // pickup, dropoff, dropoff/pickup
  final String serviceType;
  final String courierId;
  final String courierName;
  final String courierLogo;
  final String pickupDate;
  final String delivery;
  final double price;

  const EasyParcelRate({
    required this.rateId,
    required this.serviceId,
    required this.serviceName,
    required this.serviceDetail,
    required this.serviceType,
    required this.courierId,
    required this.courierName,
    required this.courierLogo,
    required this.pickupDate,
    required this.delivery,
    required this.price,
  });

  static String _formatDelivery(dynamic raw) {
    if (raw == null) return '1-3 working day(s)';
    Map<String, dynamic>? obj;
    if (raw is Map) {
      obj = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return '1-3 working day(s)';
      if (t.startsWith('{')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) obj = Map<String, dynamic>.from(decoded);
        } catch (_) {
          return t;
        }
      } else {
        return t;
      }
    }
    if (obj != null && obj['value'] != null) {
      final val = obj['value'].toString().trim();
      final type = (obj['type'] ?? 'days').toString().toLowerCase();
      if (type.contains('hour')) return '$val hour(s)';
      return '$val working day(s)';
    }
    return raw.toString();
  }

  factory EasyParcelRate.fromJson(Map<String, dynamic> json) {
    return EasyParcelRate(
      rateId: json['rate_id']?.toString() ?? '',
      serviceId: json['service_id']?.toString() ?? '',
      serviceName: json['service_name']?.toString() ?? '',
      serviceDetail: json['service_detail']?.toString() ?? 'pickup',
      serviceType: json['service_type']?.toString() ?? 'parcel',
      courierId: json['courier_id']?.toString() ?? '',
      courierName: json['courier_name']?.toString() ?? '',
      courierLogo: json['courier_logo']?.toString() ?? '',
      pickupDate: json['pickup_date']?.toString() ?? '',
      delivery: _formatDelivery(json['delivery']),
      price: (json['price'] as num?)?.toDouble() ??
          double.tryParse(json['price']?.toString() ?? '0') ??
          0.0,
    );
  }
}

class OrderShipmentModel {
  final String id;
  final String orderId;
  final String provider;
  final String environment;
  final String? epOrderNo;
  final String? epParcelNo;
  final String? courierName;
  final String? serviceName;
  final String? awbNumber;
  final String? awbPdfUrl;
  final String? trackingUrl;
  final double shippingCost;
  final double weightKg;
  final String status;
  final String? latestTrackingStatus;
  final List<Map<String, dynamic>> trackingEvents;
  final DateTime createdAt;

  const OrderShipmentModel({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.environment,
    this.epOrderNo,
    this.epParcelNo,
    this.courierName,
    this.serviceName,
    this.awbNumber,
    this.awbPdfUrl,
    this.trackingUrl,
    required this.shippingCost,
    required this.weightKg,
    required this.status,
    this.latestTrackingStatus,
    this.trackingEvents = const [],
    required this.createdAt,
  });

  factory OrderShipmentModel.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['tracking_events'];
    final events = <Map<String, dynamic>>[];
    if (rawEvents is List) {
      for (final e in rawEvents) {
        if (e is Map) events.add(Map<String, dynamic>.from(e));
      }
    }
    return OrderShipmentModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'easyparcel',
      environment: json['environment']?.toString() ?? 'demo',
      epOrderNo: json['ep_order_no']?.toString(),
      epParcelNo: json['ep_parcel_no']?.toString(),
      courierName: json['courier_name']?.toString(),
      serviceName: json['service_name']?.toString(),
      awbNumber: json['awb_number']?.toString(),
      awbPdfUrl: json['awb_pdf_url']?.toString(),
      trackingUrl: json['tracking_url']?.toString(),
      shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 1.0,
      status: json['status']?.toString() ?? 'created',
      latestTrackingStatus: json['latest_tracking_status']?.toString(),
      trackingEvents: events,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class EasyParcelService {
  final SupabaseClient _client;

  EasyParcelService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String?> _resolveBusinessId() async {
    final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
    final id = profile?['id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  /// Guess EasyParcel state code from a free-text address or state string
  static String guessStateCode(String? raw) {
    final text = (raw ?? '').toLowerCase();
    if (text.contains('kuala lumpur') || text.contains('kl')) return 'kul';
    if (text.contains('putrajaya')) return 'pjy';
    if (text.contains('selangor') || text.contains('shah alam') || text.contains('petaling') || text.contains('subang') || text.contains('klang')) return 'sgr';
    if (text.contains('johor')) return 'jhr';
    if (text.contains('penang') || text.contains('pulau pinang')) return 'png';
    if (text.contains('perak') || text.contains('ipoh')) return 'prk';
    if (text.contains('kedah') || text.contains('alor setar')) return 'kdh';
    if (text.contains('perlis')) return 'pls';
    if (text.contains('negeri sembilan') || text.contains('seremban')) return 'nsn';
    if (text.contains('melaka') || text.contains('malacca')) return 'mlk';
    if (text.contains('pahang') || text.contains('kuantan')) return 'phg';
    if (text.contains('terengganu')) return 'trg';
    if (text.contains('kelantan') || text.contains('kota bharu')) return 'ktn';
    if (text.contains('sarawak') || text.contains('kuching')) return 'srw';
    if (text.contains('sabah') || text.contains('kota kinabalu')) return 'sbh';
    if (text.contains('labuan')) return 'lbn';
    return 'sgr';
  }

  /// Extract a 5-digit Malaysian postcode from an address string if present
  static String extractPostcode(String? address) {
    if (address == null || address.isEmpty) return '';
    final match = RegExp(r'\b\d{5}\b').firstMatch(address);
    return match?.group(0) ?? '';
  }

  /// Extract clean delivery address from Ngam order notes (e.g. `(Alamat: No 12, ... 43000 Kajang, Selangor)`)
  static String extractDeliveryAddress(String? notes) {
    if (notes == null || notes.trim().isEmpty) return '';
    final alamatMatch = RegExp(r'\(Alamat:\s*([^)]+)\)', caseSensitive: false).firstMatch(notes);
    if (alamatMatch != null) {
      return alamatMatch.group(1)?.trim() ?? '';
    }
    return '';
  }

  /// Guess city name from a Malaysian address (typically right after the 5-digit postcode)
  static String extractCity(String? address) {
    if (address == null || address.isEmpty) return '';
    final match = RegExp(r'\b\d{5}\s+([A-Za-z\s]{2,30})').firstMatch(address);
    if (match != null) {
      final raw = (match.group(1) ?? '').split(',').first.trim();
      if (raw.isNotEmpty) return raw;
    }
    return '';
  }

  /// Fetch saved customer address/phone from `public.users` if order notes had no address
  Future<Map<String, String>> fetchCustomerAddress(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return {};
    try {
      final row = await _client
          .from('users')
          .select('user_address, user_phone, user_name')
          .eq('id', customerId)
          .maybeSingle();
      if (row == null) return {};
      return {
        'address': row['user_address']?.toString().trim() ?? '',
        'phone': row['user_phone']?.toString().trim() ?? '',
        'name': row['user_name']?.toString().trim() ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  /// Fetch saved EasyParcel configuration from Supabase (with local cache fallback)
  Future<EasyParcelConfig> getConfig({String? businessId}) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) return const EasyParcelConfig();

    try {
      final row = await _client
          .from('business_integrations')
          .select()
          .eq('business_id', bizId)
          .eq('provider', 'easyparcel')
          .maybeSingle();

      if (row != null) {
        final cfg = EasyParcelConfig.fromRow(Map<String, dynamic>.from(row));
        await _cacheLocal(bizId, cfg);
        return cfg;
      }
    } catch (e) {
      debugPrint('[EasyParcelService] getConfig Supabase fallback: $e');
    }

    // Local SharedPreferences fallback if table not yet migrated or offline
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ngam_easyparcel_cfg_$bizId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return EasyParcelConfig.fromRow(decoded);
      }
    } catch (_) {}

    return const EasyParcelConfig();
  }

  Future<void> _cacheLocal(String bizId, EasyParcelConfig cfg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ngam_easyparcel_cfg_$bizId',
        jsonEncode({
          'is_connected': cfg.isConnected,
          'environment': cfg.environment,
          'api_key': cfg.apiKey,
          'config': cfg.toConfigJson(),
        }),
      );
    } catch (_) {}
  }

  /// Save EasyParcel configuration to Supabase `business_integrations`
  Future<void> saveConfig(EasyParcelConfig cfg, {String? businessId}) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) throw Exception('Business ID not found');

    await _cacheLocal(bizId, cfg);

    await _client.from('business_integrations').upsert(
      {
        'business_id': bizId,
        'provider': 'easyparcel',
        'is_connected': cfg.isConnected,
        'environment': cfg.environment,
        'api_key': cfg.isPlatformMode ? null : cfg.apiKey,
        'config': cfg.toConfigJson(),
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'business_id,provider',
    );
  }

  /// Disconnect EasyParcel
  Future<void> disconnect({String? businessId}) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) return;

    final current = await getConfig(businessId: bizId);
    final updated = EasyParcelConfig(
      isConnected: false,
      mode: current.mode,
      environment: current.environment,
      apiKey: current.apiKey,
      senderName: current.senderName,
      senderPhone: current.senderPhone,
      senderAddr1: current.senderAddr1,
      senderAddr2: current.senderAddr2,
      senderCity: current.senderCity,
      senderPostcode: current.senderPostcode,
      senderState: current.senderState,
      autoSync: current.autoSync,
    );
    await saveConfig(updated, businessId: bizId);
  }

  Map<String, String> _authHeaders() {
    final token = _client.auth.currentSession?.accessToken;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Verify an API key & environment via Edge Function `easyparcel-proxy`
  Future<Map<String, dynamic>> verifyConnection({
    required String apiKey,
    required String environment,
    String? businessId,
  }) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) {
      return {'success': false, 'error': 'Business ID not found'};
    }

    final res = await _client.functions.invoke(
      'easyparcel-proxy',
      headers: _authHeaders(),
      body: {
        'action': 'verify_connection',
        'business_id': bizId,
        'api_key': apiKey.trim(),
        'environment': environment,
      },
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return {'success': false, 'error': 'Invalid response from EasyParcel proxy'};
  }

  /// Check EasyParcel credit balance using saved API key
  Future<Map<String, dynamic>> checkBalance({String? businessId}) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) return {'success': false, 'error': 'Business ID not found'};

    final res = await _client.functions.invoke(
      'easyparcel-proxy',
      headers: _authHeaders(),
      body: {
        'action': 'check_balance',
        'business_id': bizId,
      },
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return {'success': false, 'error': 'Failed to check balance'};
  }

  /// Check available courier rates (`EPRateCheckingBulk`)
  Future<({List<EasyParcelRate> rates, String? error})> checkRates({
    required String pickCode,
    required String pickState,
    required String sendCode,
    required String sendState,
    required double weight,
    String? dateColl,
    String? businessId,
  }) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) return (rates: <EasyParcelRate>[], error: 'Business ID not found');

    try {
      final res = await _client.functions.invoke(
        'easyparcel-proxy',
        headers: _authHeaders(),
        body: {
          'action': 'check_rates',
          'business_id': bizId,
          'pick_code': pickCode.trim(),
          'pick_state': pickState.trim().toLowerCase(),
          'send_code': sendCode.trim(),
          'send_state': sendState.trim().toLowerCase(),
          'weight': weight,
          if (dateColl != null && dateColl.isNotEmpty) 'date_coll': dateColl,
        },
      );

      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
      if (data['success'] != true) {
        return (
          rates: <EasyParcelRate>[],
          error: data['error']?.toString() ?? 'Rate check failed',
        );
      }

      final rawList = (data['rates'] as List?) ?? [];
      final rates = rawList
          .whereType<Map>()
          .map((e) => EasyParcelRate.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      return (rates: rates, error: null);
    } catch (e) {
      return (rates: <EasyParcelRate>[], error: e.toString());
    }
  }

  /// Create & pay EasyParcel shipment (`EPSubmitOrderBulk` + `EPPayOrderBulk`)
  Future<Map<String, dynamic>> bookAndPay({
    required String orderId,
    required EasyParcelRate rate,
    required double weight,
    required String content,
    required double value,
    required String reference,
    required Map<String, String> sender,
    required Map<String, String> receiver,
    String? collectDate,
    bool autoPay = true,
    String? businessId,
  }) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) return {'success': false, 'error': 'Business ID not found'};

    final res = await _client.functions.invoke(
      'easyparcel-proxy',
      headers: _authHeaders(),
      body: {
        'action': 'book_and_pay',
        'business_id': bizId,
        'order_id': orderId,
        'service_id': rate.serviceId,
        'courier_id': rate.courierId,
        'courier_name': rate.courierName,
        'service_name': rate.serviceName,
        'quoted_price': rate.price,
        'weight': weight,
        'content': content,
        'value': value,
        'reference': reference,
        'collect_date': collectDate ?? rate.pickupDate,
        'auto_pay': autoPay,
        'sender': sender,
        'receiver': receiver,
      },
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return {'success': false, 'error': 'Invalid response from EasyParcel proxy'};
  }

  /// Track parcel live status (`EPTrackingBulk`)
  Future<Map<String, dynamic>> trackParcel({
    required String awbNumber,
    String? shipmentId,
    String? businessId,
  }) async {
    final bizId = businessId ?? await _resolveBusinessId();
    if (bizId == null) return {'success': false, 'error': 'Business ID not found'};

    final res = await _client.functions.invoke(
      'easyparcel-proxy',
      headers: _authHeaders(),
      body: {
        'action': 'track_parcel',
        'business_id': bizId,
        'awb_number': awbNumber.trim(),
        if (shipmentId != null && shipmentId.isNotEmpty) 'shipment_id': shipmentId,
      },
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return {'success': false, 'error': 'Failed to track parcel'};
  }

  /// Fetch existing shipment record for a specific order
  Future<OrderShipmentModel?> getOrderShipment(String orderId) async {
    try {
      final row = await _client
          .from('order_shipments')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return OrderShipmentModel.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('[EasyParcelService] getOrderShipment error: $e');
      return null;
    }
  }
}
