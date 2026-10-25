import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../models/queue_ticket_model.dart';

class QueueService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  // Local fallback cache for smooth offline/in-memory demo if table not migrated yet
  static final List<QueueTicketModel> _localDemoTickets = [
    QueueTicketModel(
      id: 'demo-queue-1',
      businessId: 'demo-shop',
      ticketNumber: 'A001',
      customerName: 'Ahmad (Walk-In)',
      stationOrChair: 'Kaunter 1',
      status: 'calling',
      notes: 'Gunting Rambut & Cuci',
      calledAt: DateTime.now().subtract(const Duration(minutes: 2)),
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    QueueTicketModel(
      id: 'demo-queue-2',
      businessId: 'demo-shop',
      ticketNumber: 'A002',
      customerName: 'Siti Nurhaliza',
      stationOrChair: 'Sedang Menunggu',
      status: 'waiting',
      notes: 'Rawatan Rambut',
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
  ];
  static int _ticketSequence = 3;

  /// Reset in-memory queue demo tickets and sequence (e.g. on sign out)
  static void reset() {
    _localDemoTickets.clear();
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
      final status = (r['status'] ?? '').toString().toLowerCase();
      // Only active orders appear in queue and smart TV display
      if (status != 'pending' &&
          status != 'preparing' &&
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
      final queueStatus = isReady ? 'calling' : 'waiting';
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
        if (businessId == null) {
          controller.add(List.from(_localDemoTickets));
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
                  latestQueueTickets = rows.map((j) => QueueTicketModel.fromJson(j)).toList();
                  emitMerged();
                },
                onError: (_) {
                  latestQueueTickets = List.from(_localDemoTickets);
                  emitMerged();
                },
              );
        } catch (_) {
          latestQueueTickets = List.from(_localDemoTickets);
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
      if (businessId == null) return List.from(_localDemoTickets);

      final List<QueueTicketModel> result = [];

      // Fetch queue tickets
      try {
        final response = await _client
            .from('queue_tickets')
            .select()
            .eq('business_id', businessId)
            .order('created_at', ascending: true);
        result.addAll(
          (response as List).map((json) => QueueTicketModel.fromJson(json as Map<String, dynamic>)),
        );
      } catch (_) {
        result.addAll(_localDemoTickets);
      }

      // Fetch active orders
      try {
        final ordersRes = await _client
            .from('orders')
            .select()
            .eq('business_id', businessId)
            .inFilter('status', ['pending', 'preparing', 'cooking', 'ready'])
            .order('created_at', ascending: true);
        result.addAll(_convertOrdersToQueueTickets((ordersRes as List).cast<Map<String, dynamic>>(), businessId));
      } catch (_) {}

      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return result;
    } catch (_) {
      return List.from(_localDemoTickets);
    }
  }

  /// Issues a new walk-in ticket
  Future<QueueTicketModel> issueTicket({
    required String customerName,
    String? phoneNumber,
    String? serviceName,
    String? serviceId,
    String? stationOrChair,
    String? assignedStaffName,
    String? notes,
  }) async {
    final businessId = await _getShopId() ?? 'local_shop';

    // Generate next ticket number (e.g. A001, A002)
    final numStr = _ticketSequence.toString().padLeft(3, '0');
    final ticketNumber = 'A$numStr';
    _ticketSequence++;

    final newTicketData = {
      'business_id': businessId,
      'ticket_number': ticketNumber,
      'customer_name': customerName,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
      if (serviceName != null && serviceName.isNotEmpty) 'service_name': serviceName,
      if (serviceId != null) 'service_id': serviceId,
      if (stationOrChair != null) 'station_or_chair': stationOrChair,
      if (assignedStaffName != null) 'assigned_staff_name': assignedStaffName,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'status': 'waiting',
      'estimated_wait_minutes': 15,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await _client
          .from('queue_tickets')
          .insert(newTicketData)
          .select()
          .single();
      return QueueTicketModel.fromJson(response);
    } catch (_) {
      // Fallback local creation
      final ticket = QueueTicketModel(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        businessId: businessId,
        ticketNumber: ticketNumber,
        customerName: customerName,
        phoneNumber: phoneNumber,
        serviceName: serviceName,
        serviceId: serviceId,
        stationOrChair: stationOrChair,
        assignedStaffName: assignedStaffName,
        status: 'waiting',
        notes: notes,
        createdAt: DateTime.now(),
      );
      _localDemoTickets.add(ticket);
      return ticket;
    }
  }

  /// Calls a ticket or live order to station / pickup counter
  Future<void> callTicket(
    String ticketId, {
    String? stationOrChair,
    String? assignedStaffName,
  }) async {
    final updates = {
      'status': 'calling',
      'called_at': DateTime.now().toIso8601String(),
      if (stationOrChair != null) 'station_or_chair': stationOrChair,
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

    final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(
        status: 'calling',
        stationOrChair: stationOrChair ?? 'Sedia Diambil',
        assignedStaffName: assignedStaffName,
        calledAt: DateTime.now(),
      );
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
      } catch (_) {}
    }

    final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(
        status: 'serving',
        servingAt: DateTime.now(),
      );
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

    final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(
        status: 'completed',
        completedAt: DateTime.now(),
      );
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
      try {
        await _client.from('orders').update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
      } catch (_) {
        try {
          await _client.from('orders').update({'status': 'cancelled'}).eq('id', ticketId);
        } catch (_) {}
      }
    }

    final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(status: status);
    }
  }
}
