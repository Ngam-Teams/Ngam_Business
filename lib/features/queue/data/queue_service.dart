import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../orders/data/orders_service.dart';
import '../../settings/data/business_service.dart';
import '../models/queue_ticket_model.dart';

class QueueService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  static int _ticketSequence = 1;

  /// Reset in-memory queue sequence (e.g. on sign out)
  static void reset() {
    _ticketSequence = 1;
  }

  QueueService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Converts active database order rows into unified QueueTicketModel objects
  List<QueueTicketModel> _convertOrdersToQueueTickets(
    List<Map<String, dynamic>> orderRows,
    String businessId,
  ) {
    final List<QueueTicketModel> list = [];
    for (final r in orderRows) {
      if (!OrdersService.isOrderReadyForMerchant(r)) {
        continue;
      }
      final status = (r['status'] ?? '').toString().toLowerCase();
      // Only active orders appear in queue and smart TV display
      if (status != 'pending' &&
          status != 'preparing' &&
          status != 'in_progress' &&
          status != 'cooking' &&
          status != 'ready') {
        continue;
      }

      final id = r['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      // Format ticket number (e.g. '#4031' or '#1001')
      final rawOrderNum = r['order_number'];
      final String ticketNumber;
      if (rawOrderNum != null && rawOrderNum.toString().trim().isNotEmpty) {
        ticketNumber = '#${rawOrderNum.toString().trim()}';
      } else {
        final clean = id.replaceAll('-', '').toUpperCase();
        final short = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
        ticketNumber = '#$short';
      }

      final customerName = (r['customer_name'] != null && r['customer_name'].toString().trim().isNotEmpty)
          ? r['customer_name'].toString().trim()
          : (r['source'] == 'takeaway' ? 'Pesanan Bungkus' : 'Pesanan Kaunter');

      final isReady = status == 'ready';
      final isServing = status == 'preparing' || status == 'in_progress' || status == 'cooking';
      final String queueStatus;
      if (isReady) {
        queueStatus = 'calling';
      } else if (isServing) {
        queueStatus = 'serving';
      } else {
        queueStatus = 'waiting';
      }
      final stationOrChair = isReady ? 'Sedia Diambil' : 'Sedang Disediakan';

      final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now();
      final calledAt = isReady
          ? (DateTime.tryParse(r['updated_at']?.toString() ?? '') ?? DateTime.now())
          : null;

      list.add(
        QueueTicketModel(
          id: id,
          businessId: businessId,
          ticketNumber: ticketNumber,
          customerName: customerName,
          stationOrChair: stationOrChair,
          status: queueStatus,
          notes: r['notes']?.toString(),
          createdAt: createdAt,
          calledAt: calledAt,
        ),
      );
    }
    return list;
  }

  /// Streams active queue tickets synchronized with live orders for the current business
  Stream<List<QueueTicketModel>> streamQueueTickets([String? explicitBusinessId]) {
    late StreamController<List<QueueTicketModel>> controller;
    StreamSubscription? queueSub;
    StreamSubscription? orderSub;
    List<QueueTicketModel> latestQueueTickets = [];
    List<QueueTicketModel> latestOrderTickets = [];

    void emitMerged() {
      if (controller.isClosed) return;
      final Map<String, QueueTicketModel> map = {};
      for (final t in latestQueueTickets) {
        map[t.id] = t;
      }
      for (final t in latestOrderTickets) {
        map[t.id] = t;
      }
      final merged = map.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      controller.add(merged);
    }

    controller = StreamController<List<QueueTicketModel>>.broadcast(
      onListen: () async {
        final businessId = explicitBusinessId ?? await _getShopId();
        if (businessId == null || businessId.isEmpty) {
          controller.add([]);
          return;
        }

        // 1. Listen to walk-in queue tickets
        try {
          queueSub = _client
              .from('queue_tickets')
              .stream(primaryKey: ['id'])
              .eq('business_id', businessId)
              .order('created_at', ascending: true)
              .listen(
                (rows) {
                  final now = DateTime.now();
                  final startOfToday = DateTime(now.year, now.month, now.day);
                  latestQueueTickets = rows
                      .map((j) => QueueTicketModel.fromJson(j))
                      .where((t) => t.createdAt.isAfter(startOfToday))
                      .toList();
                  emitMerged();
                },
                onError: (err) {
                  debugPrint('[QueueService] Queue stream error: $err');
                  latestQueueTickets = [];
                  emitMerged();
                },
              );
        } catch (e) {
          debugPrint('[QueueService] Queue stream setup error: $e');
          latestQueueTickets = [];
          emitMerged();
        }

        // 2. Listen to live orders from POS / KDS / Ngam App in real-time
        try {
          orderSub = _client
              .from('orders')
              .stream(primaryKey: ['id'])
              .eq('business_id', businessId)
              .order('created_at', ascending: true)
              .listen(
                (rows) {
                  latestOrderTickets = _convertOrdersToQueueTickets(rows, businessId);
                  emitMerged();
                },
                onError: (err) {
                  debugPrint('[QueueService] Orders stream error: $err');
                },
              );
        } catch (e) {
          debugPrint('[QueueService] Orders stream setup error: $e');
        }
      },
      onCancel: () {
        queueSub?.cancel();
        orderSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Fetches queue tickets for today merged with active live orders
  Future<List<QueueTicketModel>> fetchQueueTickets([String? explicitBusinessId]) async {
    try {
      final businessId = explicitBusinessId ?? await _getShopId();
      if (businessId == null || businessId.isEmpty) return [];

      final List<QueueTicketModel> result = [];

      // Fetch queue tickets
      try {
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfTodayIso = startOfToday.toUtc().toIso8601String();
        final response = await _client
            .from('queue_tickets')
            .select()
            .eq('business_id', businessId)
            .gte('created_at', startOfTodayIso)
            .order('created_at', ascending: true);
        result.addAll(
          (response as List)
              .map((json) => QueueTicketModel.fromJson(json as Map<String, dynamic>))
              .where((t) => t.createdAt.isAfter(startOfToday)),
        );
      } catch (e) {
        debugPrint('[QueueService] Fetch queue tickets error: $e');
      }

      // Fetch active orders
      try {
        final ordersRes = await _client
            .from('orders')
            .select()
            .eq('business_id', businessId)
            .inFilter('status', ['pending', 'preparing', 'in_progress', 'cooking', 'ready'])
            .order('created_at', ascending: true);
        result.addAll(_convertOrdersToQueueTickets((ordersRes as List).cast<Map<String, dynamic>>(), businessId));
      } catch (e) {
        debugPrint('[QueueService] Fetch orders error: $e');
      }

      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Issues a new walk-in ticket
  Future<QueueTicketModel> issueTicket({
    required String customerName,
    String? phoneNumber,
    String? serviceName,
    String? serviceId,
    String? stationOrChair,
    String? assignedStaffId,
    String? assignedStaffName,
    String? notes,
  }) async {
    final profile = await _businessService.getBusinessProfile();
    final businessId = profile?['id']?.toString();
    if (businessId == null || businessId.isEmpty) {
      throw Exception('Profil perniagaan tidak dijumpai.');
    }

    int baseWaitMins = 15;
    int totalChairs = 1;
    if (profile?['settings'] is Map) {
      final settings = profile!['settings'] as Map;
      totalChairs = (settings['total_chairs'] as num?)?.toInt() ?? 1;
      if (totalChairs < 1) totalChairs = 1;
      final op = settings['operating_hours'];
      if (op is Map && op['estimated_wait_minutes'] != null) {
        baseWaitMins = (op['estimated_wait_minutes'] as num?)?.toInt() ?? 15;
      }
    }

    int nextSeq = _ticketSequence;
    int activeWaitingCount = 0;

    try {
      final now = DateTime.now();
      final startOfTodayIso = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayRows = await _client
          .from('queue_tickets')
          .select('ticket_number, status')
          .eq('business_id', businessId)
          .gte('created_at', startOfTodayIso);

      final list = todayRows as List;
      int maxNum = list.length;
      for (final r in list) {
        final st = r['status']?.toString() ?? '';
        if (st == 'waiting' || st == 'calling') {
          activeWaitingCount++;
        }
        final tNum = (r['ticket_number']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final parsed = int.tryParse(tNum);
        if (parsed != null && parsed > maxNum) {
          maxNum = parsed;
        }
      }
      nextSeq = maxNum + 1;
      _ticketSequence = nextSeq + 1;
    } catch (_) {
      nextSeq = _ticketSequence++;
    }

    // Generate next ticket number (e.g. A001, A002)
    final numStr = nextSeq.toString().padLeft(3, '0');
    final ticketNumber = 'A$numStr';
    final estimatedWait = ((activeWaitingCount ~/ totalChairs) + 1) * baseWaitMins;

    final newTicketData = {
      'business_id': businessId,
      'ticket_number': ticketNumber,
      'customer_name': customerName,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
      if (serviceName != null && serviceName.isNotEmpty) 'service_name': serviceName,
      if (serviceId != null) 'service_id': serviceId,
      if (stationOrChair != null) 'station_or_chair': stationOrChair,
      if (assignedStaffId != null) 'assigned_staff_id': assignedStaffId,
      if (assignedStaffName != null) 'assigned_staff_name': assignedStaffName,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'status': 'waiting',
      'estimated_wait_minutes': estimatedWait,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('queue_tickets')
        .insert(newTicketData)
        .select()
        .single();
    return QueueTicketModel.fromJson(response);
  }

  /// Calls a ticket or live order to station / pickup counter
  Future<void> callTicket(
    String ticketId, {
    String? stationOrChair,
    String? assignedStaffId,
    String? assignedStaffName,
  }) async {
    final updates = {
      'status': 'calling',
      'called_at': DateTime.now().toIso8601String(),
      if (stationOrChair != null) 'station_or_chair': stationOrChair,
      if (assignedStaffId != null) 'assigned_staff_id': assignedStaffId,
      if (assignedStaffName != null) 'assigned_staff_name': assignedStaffName,
    };

    bool updatedInQueue = false;
    try {
      final res = await _client.from('queue_tickets').update(updates).eq('id', ticketId).select();
      if ((res as List).isNotEmpty) {
        updatedInQueue = true;
      }
    } catch (_) {}

    // If not a queue_ticket, it is an active order in orders table
    if (!updatedInQueue) {
      try {
        await _client.from('orders').update({
          'status': 'ready',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
      } catch (_) {
        try {
          await _client.from('orders').update({'status': 'ready'}).eq('id', ticketId);
        } catch (_) {}
      }
    }
  }

  /// Marks a ticket or order as currently serving / in preparation
  Future<void> startServingTicket(String ticketId) async {
    final updates = {
      'status': 'serving',
      'serving_at': DateTime.now().toIso8601String(),
    };

    bool updatedInQueue = false;
    try {
      final res = await _client.from('queue_tickets').update(updates).eq('id', ticketId).select();
      if ((res as List).isNotEmpty) {
        updatedInQueue = true;
      }
    } catch (_) {}

    if (!updatedInQueue) {
      try {
        await _client.from('orders').update({
          'status': 'preparing',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
      } catch (_) {
        try {
          await _client.from('orders').update({'status': 'preparing'}).eq('id', ticketId);
        } catch (_) {}
      }
    }
  }

  /// Completes a ticket or order service
  Future<void> completeTicket(String ticketId) async {
    final updates = {
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    };

    bool updatedInQueue = false;
    try {
      final res = await _client.from('queue_tickets').update(updates).eq('id', ticketId).select();
      if ((res as List).isNotEmpty) {
        updatedInQueue = true;
      }
    } catch (_) {}

    if (!updatedInQueue) {
      try {
        await _client.from('orders').update({
          'status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
      } catch (_) {
        try {
          await _client.from('orders').update({'status': 'completed'}).eq('id', ticketId);
        } catch (_) {}
      }
    }
  }

  /// Cancels or marks ticket or order as cancelled / no-show
  Future<void> cancelTicket(String ticketId, {bool isNoShow = false}) async {
    final status = isNoShow ? 'no_show' : 'cancelled';
    bool updatedInQueue = false;
    try {
      final res = await _client.from('queue_tickets').update({'status': status}).eq('id', ticketId).select();
      if ((res as List).isNotEmpty) {
        updatedInQueue = true;
      }
    } catch (_) {}

    if (!updatedInQueue) {
      await OrdersService(
        client: _client,
        businessService: _businessService,
      ).updateOrderStatus(ticketId, 'cancelled');
    }
  }
}
