// =============================================================================
// QueueTicketModel — represents a walk-in queue ticket in Ngam Business & TV
// =============================================================================

class QueueTicketModel {
  final String id;
  final String businessId;
  final String ticketNumber; // e.g. 'A001', 'A002'
  final String customerName;
  final String? phoneNumber;
  final String? serviceName;
  final String? serviceId;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String? stationOrChair; // e.g. 'Kerusi 1', 'Kaunter 2'
  final String status; // 'waiting' | 'calling' | 'serving' | 'completed' | 'cancelled' | 'no_show'
  final String? notes;
  final int estimatedWaitMinutes;
  final DateTime? calledAt;
  final DateTime? servingAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  const QueueTicketModel({
    required this.id,
    required this.businessId,
    required this.ticketNumber,
    required this.customerName,
    this.phoneNumber,
    this.serviceName,
    this.serviceId,
    this.assignedStaffId,
    this.assignedStaffName,
    this.stationOrChair,
    required this.status,
    this.notes,
    this.estimatedWaitMinutes = 15,
    this.calledAt,
    this.servingAt,
    this.completedAt,
    required this.createdAt,
  });

  factory QueueTicketModel.fromJson(Map<String, dynamic> json) {
    return QueueTicketModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      ticketNumber: json['ticket_number'] as String? ?? 'A001',
      customerName: json['customer_name'] as String? ?? 'Pelanggan Walk-In',
      phoneNumber: json['phone_number'] as String?,
      serviceName: json['service_name'] as String?,
      serviceId: json['service_id'] as String?,
      assignedStaffId: json['assigned_staff_id'] as String?,
      assignedStaffName: json['assigned_staff_name'] as String?,
      stationOrChair: json['station_or_chair'] as String?,
      status: json['status'] as String? ?? 'waiting',
      notes: json['notes'] as String?,
      estimatedWaitMinutes: (json['estimated_wait_minutes'] as num?)?.toInt() ?? 15,
      calledAt: json['called_at'] != null ? DateTime.tryParse(json['called_at'] as String) : null,
      servingAt: json['serving_at'] != null ? DateTime.tryParse(json['serving_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'ticket_number': ticketNumber,
    'customer_name': customerName,
    'phone_number': phoneNumber,
    'service_name': serviceName,
    'service_id': serviceId,
    'assigned_staff_id': assignedStaffId,
    'assigned_staff_name': assignedStaffName,
    'station_or_chair': stationOrChair,
    'status': status,
    'notes': notes,
    'estimated_wait_minutes': estimatedWaitMinutes,
    'called_at': calledAt?.toIso8601String(),
    'serving_at': servingAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  QueueTicketModel copyWith({
    String? status,
    String? stationOrChair,
    String? assignedStaffId,
    String? assignedStaffName,
    DateTime? calledAt,
    DateTime? servingAt,
    DateTime? completedAt,
    String? notes,
  }) {
    return QueueTicketModel(
      id: id,
      businessId: businessId,
      ticketNumber: ticketNumber,
      customerName: customerName,
      phoneNumber: phoneNumber,
      serviceName: serviceName,
      serviceId: serviceId,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      stationOrChair: stationOrChair ?? this.stationOrChair,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      estimatedWaitMinutes: estimatedWaitMinutes,
      calledAt: calledAt ?? this.calledAt,
      servingAt: servingAt ?? this.servingAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }
}
