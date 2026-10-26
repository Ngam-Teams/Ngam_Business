import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/cache_service.dart';

import '../../settings/data/business_service.dart';

class OrderModel {
  final String id;
  final String ownerUserId;
  final double total;
  final String status;
  final String source;
  final String? customerName;
  final String? customerPhone;
  final String? notes;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.ownerUserId,
    required this.total,
    required this.status,
    required this.source,
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
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      source: json['source'] as String? ?? 'pos',
      customerName: json['customer_name'] as String?,
      customerPhone: phone,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'total': total,
    'status': status,
    'source': source,
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

  /// Fetch all orders for the current business
  Future<List<OrderModel>> fetchOrders() async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final businessId = profile?['id'];

      var query = _client.from('orders').select();
      if (businessId != null) {
        query = query.eq('business_id', businessId);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream orders for real-time updates (dilengkapi cache pantas SWR 0-saat)
  Stream<List<OrderModel>> streamOrders() async* {
    const cacheKey = 'orders_list_cache';

    // 1. Tunjuk data cache pesanan serta-merta jika ada (0 ms)
    final cached = await CacheService.get<List<OrderModel>>(
      key: cacheKey,
      fromJson: (jsonList) => (jsonList as List)
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    if (cached != null && cached.isNotEmpty) {
      yield cached;
    }

    // 2. Dengar stream realtime Supabase & simpan ke cache
    yield* _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) {
          final orders = list
              .map((json) => OrderModel.fromJson(json))
              .toList();

          unawaited(CacheService.set<List<OrderModel>>(
            key: cacheKey,
            data: orders,
            toJson: (items) => items.map((o) => o.toJson()).toList(),
          ));

          return orders;
        });
  }

  /// Update the status of an order
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      try {
        await _client
            .from('orders')
            .update({
              'status': newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
        return true;
      } catch (_) {
        await _client
            .from('orders')
            .update({'status': newStatus})
            .eq('id', orderId);
        return true;
      }
    } catch (e) {
      debugPrint('[OrdersService] updateOrderStatus error ($orderId -> $newStatus): $e');
      return false;
    }
  }
}
