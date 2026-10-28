import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/cache_service.dart';
import '../../settings/data/business_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class PosService {
  static const String _offlineQueueKey = 'pos_offline_orders_queue_v1';
  static const String _heldOrdersKey = 'pos_held_orders_v1';

  final SupabaseClient _client;
  final BusinessService _businessService;

  PosService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ??
            BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  // ---------------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------------

  /// Fetches all available products for the current tenant's business.
  Future<List<ProductModel>> fetchProducts() async {
    try {
      final businessId = await _getShopId();
      if (businessId == null) return [];

      final response = await _client
          .from('business_products')
          .select()
          .eq('shop_id', businessId)
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      return [];
    }
  }

  /// Streams available products for real-time updates (dilengkapi cache pantas SWR 0-saat)
  Stream<List<ProductModel>> streamProducts() async* {
    final businessId = await _getShopId();
    if (businessId == null) {
      yield [];
      return;
    }

    const cacheKey = 'pos_products_';

    // 1. Pancarkan data produk POS dari cache serta-merta (0 ms)
    final cached = await CacheService.get<List<ProductModel>>(
      key: cacheKey,
      fromJson: (jsonList) => (jsonList as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    if (cached != null && cached.isNotEmpty) {
      yield cached;
    }

    // 2. Sambungkan stream realtime Supabase & simpan ke cache
    yield* _client
        .from('business_products')
        .stream(primaryKey: ['id'])
        .eq('shop_id', businessId)
        .order('name')
        .map((list) {
          final products = list
              .map((json) => ProductModel.fromJson(json))
              .where((p) => p.isAvailable)
              .toList();

          unawaited(CacheService.set<List<ProductModel>>(
            key: cacheKey,
            data: products,
            toJson: (prods) => prods.map((p) => p.toJson()).toList(),
          ));

          return products;
        });
  }

  // ---------------------------------------------------------------------------
  // Held Orders (Open Tabs / Park Order)
  // ---------------------------------------------------------------------------

  Future<List<HeldOrderModel>> loadHeldOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_heldOrdersKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => HeldOrderModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHeldOrders(List<HeldOrderModel> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(orders.map((o) => o.toJson()).toList());
      await prefs.setString(_heldOrdersKey, encoded);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Offline Order Queue & Sync
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOfflineQueuedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_offlineQueueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueueOfflineOrder(Map<String, dynamic> payload) async {
    final current = await getOfflineQueuedOrders();
    current.add(payload);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineQueueKey, jsonEncode(current));
  }

  /// Syncs all offline queued orders to Supabase when connection is restored.
  /// Returns number of successfully synced orders.
  Future<int> syncOfflineOrders() async {
    final queue = await getOfflineQueuedOrders();
    if (queue.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    int syncedCount = 0;

    for (final entry in queue) {
      try {
        final itemsRaw = (entry['items'] as List?) ?? [];
        final items = itemsRaw
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final splitsRaw = (entry['payment_splits'] as List?) ?? [];
        final splits = splitsRaw
            .map((e) => PaymentSplit.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        await _submitOrderToSupabase(
          items: items,
          total: (entry['total'] as num?)?.toDouble() ?? 0.0,
          customerName: entry['customer_name'] as String?,
          notes: entry['notes'] as String?,
          paymentSplits: splits,
          initialStatus: entry['initial_status'] as String? ?? 'pending',
        );
        syncedCount++;
      } catch (_) {
        remaining.add(entry);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineQueueKey, jsonEncode(remaining));
    return syncedCount;
  }

  // ---------------------------------------------------------------------------
  // Orders (Online + Offline Fallback)
  // ---------------------------------------------------------------------------

  /// Submits a new order to Supabase with automatic Offline Queue fallback.
  /// Returns true if synced immediately online, or false if saved to Offline Queue.
  Future<bool> submitOrder({
    required List<CartItem> items,
    required double total,
    String? customerName,
    String? notes,
    List<PaymentSplit>? paymentSplits,
    String initialStatus = 'pending',
  }) async {
    try {
      await _submitOrderToSupabase(
        items: items,
        total: total,
        customerName: customerName,
        notes: notes,
        paymentSplits: paymentSplits,
        initialStatus: initialStatus,
      );
      return true;
    } catch (e) {
      // Fallback: Save to Offline Order Queue so counter operations never stop
      await _enqueueOfflineOrder({
        'queued_at': DateTime.now().toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'customer_name': customerName,
        'notes': notes != null ? '$notes | [OFFLINE-SYNC]' : '[OFFLINE-SYNC]',
        'payment_splits': paymentSplits?.map((s) => s.toJson()).toList() ?? [],
        'initial_status': initialStatus,
      });
      return false;
    }
  }

  Future<void> _submitOrderToSupabase({
    required List<CartItem> items,
    required double total,
    String? customerName,
    String? notes,
    List<PaymentSplit>? paymentSplits,
    String initialStatus = 'pending',
  }) async {
    final businessId = await _getShopId();
    if (businessId == null) {
      throw Exception('Sila pastikan profil perniagaan wujud sebelum membuat pesanan.');
    }
    final user = _client.auth.currentUser;

    String? combinedNotes = notes;
    String paymentMethodName = 'cash';

    if (paymentSplits != null && paymentSplits.isNotEmpty) {
      if (paymentSplits.length == 1) {
        paymentMethodName = paymentSplits.first.method;
      } else {
        paymentMethodName = 'split';
      }

      final splitSummaries = paymentSplits.map((s) {
        final amtStr = 'RM ${s.amount.toStringAsFixed(2)}';
        if (s.method == 'cash' &&
            s.tenderedAmount != null &&
            s.tenderedAmount! > s.amount) {
          final change = s.changeAmount ?? (s.tenderedAmount! - s.amount);
          return '${s.displayName}: $amtStr (Diterima: RM ${s.tenderedAmount!.toStringAsFixed(2)}, Baki: RM ${change.toStringAsFixed(2)})';
        }
        return '${s.displayName}: $amtStr';
      }).join(' + ');

      final paymentTag = '[Bayaran: $splitSummaries]';
      combinedNotes = (combinedNotes == null || combinedNotes.trim().isEmpty)
          ? paymentTag
          : '$combinedNotes | $paymentTag';
    }

    final baseOrderData = {
      'total': total,
      'status': initialStatus,
      'source': 'pos',
      'business_id': businessId,
      if (user != null) 'owner_user_id': user.id,
      if (customerName != null && customerName.isNotEmpty)
        'customer_name': customerName,
      if (combinedNotes != null && combinedNotes.isNotEmpty)
        'notes': combinedNotes,
    };

    Map<String, dynamic> order;
    try {
      final fullData = {
        ...baseOrderData,
        'payment_method': paymentMethodName,
        if (paymentSplits != null && paymentSplits.isNotEmpty)
          'payment_splits': paymentSplits.map((s) => s.toJson()).toList(),
      };
      order = await _client.from('orders').insert(fullData).select().single();
    } catch (_) {
      order = await _client.from('orders').insert(baseOrderData).select().single();
    }

    final orderItems = items
        .map((item) => {
              'order_id': order['id'],
              'product_id': item.product.id,
              'product_name': item.formattedOrderItemName,
              'quantity': item.quantity,
              'unit_price': item.unitPriceWithAddons,
              'subtotal': item.subtotal,
            })
        .toList();

    await _client.from('order_items').insert(orderItems);

    // Auto-deduct inventory stock for physical products that track stock
    for (final item in items) {
      if (item.product.isProduct && item.product.trackInventory) {
        try {
          final current = await _client
              .from('business_products')
              .select('stock')
              .eq('id', item.product.id)
              .maybeSingle();

          if (current != null) {
            final currentStock = (current['stock'] as int?) ?? item.product.stock;
            final newStock = (currentStock - item.quantity).clamp(0, 999999);
            await _client
                .from('business_products')
                .update({'stock': newStock})
                .eq('id', item.product.id);
          }
        } catch (_) {
          // Ignore individual stock deduction failures to not block order creation
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Recent Orders & Void / Refund Management
  // ---------------------------------------------------------------------------

  /// Fetches recent orders for the current business including their items.
  Future<List<Map<String, dynamic>>> fetchRecentOrders({int limit = 25}) async {
    try {
      final businessId = await _getShopId();
      if (businessId == null) return [];

      final response = await _client
          .from('orders')
          .select('*, order_items(*)')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        final businessId = await _getShopId();
        if (businessId == null) return [];
        final fallback = await _client
            .from('orders')
            .select()
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(limit);
        return (fallback as List).cast<Map<String, dynamic>>();
      } catch (_) {
        return [];
      }
    }
  }

  /// Voids / Refunds an order and restores physical inventory stock.
  Future<void> voidOrder({
    required String orderId,
    required String reason,
    String? existingNotes,
  }) async {
    final voidTag = '[BATAL/REFUND: $reason pada ${DateTime.now().toIso8601String().substring(0, 16)}]';
    final updatedNotes = (existingNotes == null || existingNotes.trim().isEmpty)
        ? voidTag
        : '$existingNotes | $voidTag';

    await _client.from('orders').update({
      'status': 'cancelled',
      'notes': updatedNotes,
    }).eq('id', orderId);

    // Restore stock for items in the voided order
    try {
      final items = await _client
          .from('order_items')
          .select('product_id, quantity')
          .eq('order_id', orderId);

      for (final row in (items as List)) {
        final prodId = row['product_id'] as String?;
        final qty = (row['quantity'] as num?)?.toInt() ?? 0;
        if (prodId != null && qty > 0) {
          final prod = await _client
              .from('business_products')
              .select('stock, track_inventory, item_type')
              .eq('id', prodId)
              .maybeSingle();

          if (prod != null &&
              prod['item_type'] != 'service' &&
              (prod['track_inventory'] as bool? ?? true)) {
            final curStock = (prod['stock'] as int?) ?? 0;
            await _client
                .from('business_products')
                .update({'stock': curStock + qty})
                .eq('id', prodId);
          }
        }
      }
    } catch (_) {}
  }
}
