import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// AppointmentsPage — Merchant Booking & Schedule Management
// ============================================================

enum AppointmentStatus { pending, confirmed, inProgress, completed, cancelled }

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Pending', 'Confirmed', 'Completed'];

  late List<Map<String, dynamic>> _appointments;

  @override
  void initState() {
    super.initState();
    _appointments = [
      {
        'id': 'BK-1082',
        'customerName': 'Amirul Hakim',
        'phone': '+60 17-234 5678',
        'service': 'Premium Haircut & Beard Trim',
        'dateTime': 'Today, 2:30 PM',
        'staff': 'Farid (Master Barber)',
        'price': 50.00,
        'deposit': 15.00,
        'status': AppointmentStatus.pending,
        'notes': 'Prefers fade cut on sides.',
      },
      {
        'id': 'BK-1081',
        'customerName': 'Sarah Lee',
        'phone': '+60 12-889 1234',
        'service': 'Facial Rejuvenation Treatment',
        'dateTime': 'Today, 4:00 PM',
        'staff': 'Nurul (Therapist)',
        'price': 85.00,
        'deposit': 25.00,
        'status': AppointmentStatus.confirmed,
        'notes': 'Sensitive skin, requested natural oils.',
      },
      {
        'id': 'BK-1080',
        'customerName': 'Zulhilmi Rahman',
        'phone': '+60 19-334 9988',
        'service': 'Classic Haircut',
        'dateTime': 'Today, 11:00 AM',
        'staff': 'Farid (Master Barber)',
        'price': 35.00,
        'deposit': 10.00,
        'status': AppointmentStatus.completed,
        'notes': 'Customer paid remaining in cash.',
      },
      {
        'id': 'BK-1079',
        'customerName': 'Jessica Wong',
        'phone': '+60 16-555 4321',
        'service': 'Full Hair Coloring',
        'dateTime': 'Tomorrow, 10:30 AM',
        'staff': 'Alex (Senior Stylist)',
        'price': 120.00,
        'deposit': 30.00,
        'status': AppointmentStatus.confirmed,
        'notes': 'Reference photo attached in booking.',
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_selectedFilterIndex == 0) return _appointments;
    final targetStatus = _selectedFilterIndex == 1
        ? AppointmentStatus.pending
        : _selectedFilterIndex == 2
            ? AppointmentStatus.confirmed
            : AppointmentStatus.completed;
    return _appointments.where((a) => a['status'] == targetStatus).toList();
  }

  void _callCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) showGlassToast(context, 'Could not launch phone dialer', isError: true);
    }
  }

  void _updateStatus(Map<String, dynamic> appt, AppointmentStatus newStatus) {
    setState(() {
      appt['status'] = newStatus;
    });
    final statusLabel = newStatus == AppointmentStatus.confirmed
        ? 'Confirmed'
        : newStatus == AppointmentStatus.completed
            ? 'Completed'
            : 'Cancelled';
    showGlassToast(context, 'Booking ${appt['id']} marked as $statusLabel');
  }

  void _openNewAppointmentModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final serviceCtrl = TextEditingController(text: 'Walk-in Haircut');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF14171F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add Walk-in Appointment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Customer Name',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serviceCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Service Name',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    showGlassToast(context, 'Please enter customer name', isError: true);
                    return;
                  }
                  setState(() {
                    _appointments.insert(0, {
                      'id': 'WK-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      'customerName': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim().isEmpty ? 'Walk-in' : phoneCtrl.text.trim(),
                      'service': serviceCtrl.text.trim(),
                      'dateTime': 'Today (Immediate)',
                      'staff': 'Any Available Staff',
                      'price': 35.00,
                      'deposit': 0.00,
                      'status': AppointmentStatus.confirmed,
                      'notes': 'Walk-in customer entry',
                    });
                  });
                  Navigator.pop(ctx);
                  showGlassToast(context, 'Walk-in appointment recorded!');
                },
                child: const Text('Confirm Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return const Color(0xFFF9C80E);
      case AppointmentStatus.confirmed:
        return const Color(0xFF42A5F5);
      case AppointmentStatus.inProgress:
        return const Color(0xFF9C27B0);
      case AppointmentStatus.completed:
        return const Color(0xFF44CF6C);
      case AppointmentStatus.cancelled:
        return Colors.redAccent;
    }
  }

  String _statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Pending Approval';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.inProgress:
        return 'In Progress';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        onPressed: _openNewAppointmentModal,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New Walk-in', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookings & Appointments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manage salon, spa, clinic & table slots',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                itemBuilder: (context, idx) {
                  final isSelected = _selectedFilterIndex == idx;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF42A5F5)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _filters[idx],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Appointments List
            Expanded(
              child: _filteredAppointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          const Text(
                            'No appointments found',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Upcoming customer bookings will appear here.',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: _filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appt = _filteredAppointments[index];
                        final status = appt['status'] as AppointmentStatus;
                        final color = _statusColor(status);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Header: ID & Status Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    appt['id'],
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: color.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Customer & Service
                              Text(
                                appt['customerName'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.content_cut_rounded, size: 14, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      appt['service'],
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Text(
                                    appt['dateTime'],
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Text(
                                    appt['staff'],
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),

                              if ((appt['notes'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Note: ${appt['notes']}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),
                              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                              const SizedBox(height: 14),

                              // Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Deposit: RM ${(appt['deposit'] as double).toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF44CF6C), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Total: RM ${(appt['price'] as double).toStringAsFixed(2)}',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.phone_outlined, color: Colors.blueAccent, size: 20),
                                        onPressed: () => _callCustomer(appt['phone']),
                                        tooltip: 'Call Customer',
                                      ),
                                      if (status == AppointmentStatus.pending) ...[
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF42A5F5),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () => _updateStatus(appt, AppointmentStatus.confirmed),
                                          child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ] else if (status == AppointmentStatus.confirmed) ...[
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF44CF6C),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () => _updateStatus(appt, AppointmentStatus.completed),
                                          child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
