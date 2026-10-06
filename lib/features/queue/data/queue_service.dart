import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../models/queue_ticket_model.dart';

class QueueService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  // Local fallback cache for smooth offline/in-memory demo if table not migrated yet
  static final List<QueueTicketModel> _localDemoTickets = [];
  static int _ticketSequence = 1;

  QueueService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Streams active queue tickets for the current business
  Stream<List<QueueTicketModel>> streamQueueTickets() async* {
    final businessId = await _getShopId();
    if (businessId == null) {
      yield _localDemoTickets;
      return;
    }

    try {
      yield* _client
          .from('queue_tickets')
          .stream(primaryKey: ['id'])
          .eq('business_id', businessId)
          .order('created_at', ascending: true)
          .map((list) => list.map((json) => QueueTicketModel.fromJson(json)).toList());
    } catch (_) {
      // Fallback to local stream controller if table does not exist yet
      yield _localDemoTickets;
    }
  }

  /// Fetches queue tickets for today
  Future<List<QueueTicketModel>> fetchQueueTickets() async {
    try {
      final businessId = await _getShopId();
      if (businessId == null) return _localDemoTickets;

      final response = await _client
          .from('queue_tickets')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => QueueTicketModel.fromJson(json as Map<String, dynamic>))
          .toList();
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

  /// Calls a ticket to station / chair
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

    try {
      await _client.from('queue_tickets').update(updates).eq('id', ticketId);
    } catch (_) {
      final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(
          status: 'calling',
          stationOrChair: stationOrChair,
          assignedStaffName: assignedStaffName,
          calledAt: DateTime.now(),
        );
      }
    }
  }

  /// Marks a ticket as currently serving
  Future<void> startServingTicket(String ticketId) async {
    final updates = {
      'status': 'serving',
      'serving_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client.from('queue_tickets').update(updates).eq('id', ticketId);
    } catch (_) {
      final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(
          status: 'serving',
          servingAt: DateTime.now(),
        );
      }
    }
  }

  /// Completes a ticket service
  Future<void> completeTicket(String ticketId) async {
    final updates = {
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client.from('queue_tickets').update(updates).eq('id', ticketId);
    } catch (_) {
      final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
        );
      }
    }
  }

  /// Cancels or marks ticket as no-show
  Future<void> cancelTicket(String ticketId, {bool isNoShow = false}) async {
    final status = isNoShow ? 'no_show' : 'cancelled';
    try {
      await _client.from('queue_tickets').update({'status': status}).eq('id', ticketId);
    } catch (_) {
      final idx = _localDemoTickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _localDemoTickets[idx] = _localDemoTickets[idx].copyWith(status: status);
      }
    }
  }
}
