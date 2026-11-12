import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/cache_service.dart';

import '../../settings/data/business_service.dart';

class OrderModel {
  final String id;
  final String ownerUserId;
  final String? businessId;
  final double total;
  final String status;
  final String source;
  final String paymentStatus;
  final String paymentMethod;
  final String? customerName;
  final String? customerPhone;
  final String? notes;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.ownerUserId,
    this.businessId,
    required this.total,
    required this.status,
    required this.source,
    this.paymentStatus = 'paid',
    this.paymentMethod = 'online',
    this.customerName,
    this.customerPhone,
    this.notes,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String? phone = json['customer_phone'] as String?;
    if (phone == null && json['users'] is Map) {
      phone = json['users']['user_phone'] as String?;
    }
    return OrderModel(
      id: json['id'] as String,
      ownerUserId: (json['owner_user_id'] as String?) ?? '',
      businessId: json['business_id']?.toString(),
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      source: json['source'] as String? ?? 'pos',
      paymentStatus: (json['payment_status'] as String?) ?? 'paid',
      paymentMethod: (json['payment_method'] as String?) ?? 'online',
      customerName: json['customer_name'] as String?,
      customerPhone: phone,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'business_id': businessId,
    'total': total,
    'status': status,
    'source': source,
    'payment_status': paymentStatus,
    'payment_method': paymentMethod,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };
}

class OrdersService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  OrdersService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  static bool isOrderReadyForMerchant(Map<String, dynamic> json) {
    final source = (json['source'] ?? 'pos').toString().toLowerCase();
    final payMethod = (json['payment_method'] ?? 'cash').toString().toLowerCase();
    final payStatus = (json['payment_status'] ?? '').toString().toLowerCase();
    final status = (json['status'] ?? '').toString().toLowerCase();

    // Sembunyikan draf pesanan online yang masih belum dibayar di gerbang CHIP
    if (source != 'pos' && payMethod != 'cash' && payStatus == 'pending') {
      return false;
    }
    // Sembunyikan draf pesanan online yang dibatalkan sebelum bayaran dibuat
    if (status == 'cancelled' && payStatus == 'pending') {
      return false;
    }
    return true;
  }

  /// Fetch all orders for the current business
  Future<List<OrderModel>> fetchOrders() async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];
      if (businessId == null || businessId.toString().isEmpty) {
        return [];
      }

      final response = await _client
          .from('orders')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false);

      return (response as List)
          .where((json) => isOrderReadyForMerchant(json as Map<String, dynamic>))
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream orders for real-time updates (ditapis mengikut business_id peniaga)
  /// Dilengkapi perlindungan cache, HTTP fallback, dan auto-reconnect automatik
  Stream<List<OrderModel>> streamOrders() {
    late StreamController<List<OrderModel>> controller;
    StreamSubscription? realtimeSubscription;
    Timer? reconnectTimer;
    List<OrderModel> lastEmittedOrders = [];
    bool isCancelled = false;

    Future<void> emitData(List<OrderModel> orders, String cacheKey) async {
      if (isCancelled || controller.isClosed) return;
      lastEmittedOrders = orders;
      controller.add(orders);
      unawaited(CacheService.set<List<OrderModel>>(
        key: cacheKey,
        data: orders,
        toJson: (items) => items.map((o) => o.toJson()).toList(),
      ));
    }

    Future<void> connect(String? businessId, String cacheKey) async {
      if (isCancelled || controller.isClosed) return;

      // 1. Dapatkan cache terkini serta-merta (L1 / L2, benarkan expired jika offline)
      try {
        final cached = await CacheService.get<List<OrderModel>>(
          key: cacheKey,
          fromJson: (jsonList) => (jsonList as List)
              .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
              .toList(),
          allowExpired: true,
        );
        if (cached != null && cached.isNotEmpty && lastEmittedOrders.isEmpty) {
          await emitData(cached, cacheKey);
        }
      } catch (e) {
        debugPrint('[OrdersService] Error reading orders cache: $e');
      }

      // 2. HTTP Fetch fallback (SWR - pastikan data segar dari REST API)
      try {
        final httpOrders = await fetchOrders();
        if (businessId != null && businessId.isNotEmpty) {
          await emitData(httpOrders, cacheKey);
        } else if (httpOrders.isNotEmpty) {
          await emitData(httpOrders, cacheKey);
        }
      } catch (e) {
        debugPrint('[OrdersService] HTTP fallback fetch error: $e');
      }

      // 3. Pasang sambungan Supabase Realtime Stream
      try {
        await realtimeSubscription?.cancel();

        if (businessId == null || businessId.isEmpty) {
          return;
        }

        final baseStream = _client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('business_id', businessId)
            .order('created_at', ascending: false);

        realtimeSubscription = baseStream.listen(
          (list) {
            final orders = list
                .where((json) => isOrderReadyForMerchant(json))
                .map((json) => OrderModel.fromJson(json))
                .toList();
            emitData(orders, cacheKey);
          },
          onError: (error) async {
            debugPrint('[OrdersService] Realtime stream error: $error');

            // Cuba ambil data melalui REST jika socket gagal
            try {
              final httpOrders = await fetchOrders();
              if (businessId != null && businessId.isNotEmpty) {
                await emitData(httpOrders, cacheKey);
              } else if (httpOrders.isNotEmpty) {
                await emitData(httpOrders, cacheKey);
              }
            } catch (_) {}

            // Jika benar-benar tiada data (cache kosong, HTTP gagal, socket gagal)
            if (lastEmittedOrders.isEmpty && !controller.isClosed) {
              controller.addError(error);
            }

            // Auto-reconnect automatik setiap 5 saat
            if (!isCancelled && (reconnectTimer == null || !reconnectTimer!.isActive)) {
              reconnectTimer = Timer(const Duration(seconds: 5), () {
                if (!isCancelled && !controller.isClosed) {
                  connect(businessId, cacheKey);
                }
              });
            }
          },
          cancelOnError: false,
        );
      } catch (e) {
        debugPrint('[OrdersService] Error establishing realtime stream: $e');
        if (lastEmittedOrders.isEmpty && !controller.isClosed) {
          controller.addError(e);
        }
        if (!isCancelled && (reconnectTimer == null || !reconnectTimer!.isActive)) {
          reconnectTimer = Timer(const Duration(seconds: 5), () {
            if (!isCancelled && !controller.isClosed) {
              connect(businessId, cacheKey);
            }
          });
        }
      }
    }

    controller = StreamController<List<OrderModel>>.broadcast(
      onListen: () async {
        isCancelled = false;
        String? businessId = BusinessService.cachedProfile?['id']?.toString();
        if (businessId == null || businessId.isEmpty) {
          try {
            final profile = await _businessService.getBusinessProfile();
            businessId = profile?['id']?.toString();
          } catch (_) {}
        }
        final cacheKey = 'orders_list_cache_${businessId ?? "default"}';
        await connect(businessId, cacheKey);
      },
      onCancel: () {
        isCancelled = true;
        reconnectTimer?.cancel();
        realtimeSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Update the status of an order
  Future<bool> updateOrderStatus(String orderId, String newStatus, {String? paymentStatus}) async {
    String? effectivePaymentStatus = paymentStatus;
    // Jika pesanan dibatalkan, pulihkan semula stok inventori bagi produk fizikal
    if (newStatus.toLowerCase() == 'cancelled') {
      try {
        final existingOrder = await _client
            .from('orders')
            .select('status, source, payment_method, payment_status')
            .eq('id', orderId)
            .maybeSingle();

        if (existingOrder != null) {
          final existingStatus = (existingOrder['status'] ?? '').toString().toLowerCase();
          if (existingStatus == 'cancelled') {
            return true;
          }

          final source = (existingOrder['source'] ?? 'pos').toString().toLowerCase();
          final payMethod = (existingOrder['payment_method'] ?? 'cash').toString().toLowerCase();
          final existingPayStatus = (existingOrder['payment_status'] ?? '').toString().toLowerCase();

          if (existingPayStatus == 'paid' && effectivePaymentStatus == null) {
            effectivePaymentStatus = 'refund_pending';
          }

          if (!(source != 'pos' && payMethod != 'cash' && existingPayStatus == 'pending')) {
            final items = await _client
                .from('order_items')
                .select('product_id, quantity')
                .eq('order_id', orderId);
            for (final row in (items as List)) {
              final prodId = row['product_id']?.toString();
              final qty = (row['quantity'] as num?)?.toInt() ?? 0;
              if (prodId != null && prodId.isNotEmpty && qty > 0) {
                final prod = await _client
                    .from('business_products')
                    .select('stock, track_inventory, item_type')
                    .eq('id', prodId)
                    .maybeSingle();
                if (prod != null &&
                    prod['item_type'] != 'service' &&
                    (prod['track_inventory'] as bool? ?? true)) {
                  final curStock = (prod['stock'] as num?)?.toInt() ?? 0;
                  await _client
                      .from('business_products')
                      .update({'stock': curStock + qty})
                      .eq('id', prodId);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    try {
      final payload = <String, dynamic>{
        'status': newStatus,
        if (effectivePaymentStatus != null) 'payment_status': effectivePaymentStatus,
      };
      try {
        await _client
            .from('orders')
            .update({
              ...payload,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
        return true;
      } catch (_) {
        await _client.from('orders').update(payload).eq('id', orderId);
        return true;
      }
    } catch (e) {
      debugPrint('[OrdersService] updateOrderStatus error ($orderId -> $newStatus): $e');
      return false;
    }
  }

  /// Ambil senarai item pesanan daripada table order_items
  Future<List<Map<String, dynamic>>> fetchOrderItems(String orderId) async {
    try {
      final res = await _client
          .from('order_items')
          .select()
          .eq('order_id', orderId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[OrdersService] fetchOrderItems error ($orderId): $e');
      return [];
    }
  }
}
