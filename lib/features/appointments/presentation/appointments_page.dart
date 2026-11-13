import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../settings/data/business_service.dart';
import '../../pos/presentation/widgets/payment_terminal_modal.dart';

// ============================================================
// AppointmentsPage — Merchant Booking & Schedule Management
// ============================================================

enum AppointmentStatus { pending, confirmed, inProgress, completed, cancelled, disputed }

class AppointmentsPage extends StatefulWidget {
  final bool isEmbedded;
  const AppointmentsPage({super.key, this.isEmbedded = false});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Semua', 'Menunggu', 'Disahkan', 'Selesai'];

  late List<Map<String, dynamic>> _appointments;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSub;
  String? _businessId;
  Set<String> _knownBookingIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _appointments = [];
    _subscribeToLiveBookings();
  }

  void _subscribeToLiveBookings() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      _businessId = profile?['id']?.toString();
      if (_businessId == null || _businessId!.isEmpty) return;

      _bookingsSub?.cancel();
      _bookingsSub = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('business_id', _businessId!)
          .order('created_at', ascending: false)
          .listen((data) {
        if (!mounted) return;

        final relevantBookings = data.where((b) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          if (status == 'holding') return false;
          final meta = b['booking_metadata'] is Map ? b['booking_metadata'] as Map : const {};
          final payStatus = (meta['payment_status'] ?? '').toString().toLowerCase();
          if (payStatus == 'pending') return false;
          return b['business_id'] == _businessId;
        }).toList();

        if (relevantBookings.isNotEmpty || (_businessId != null && _businessId!.isNotEmpty)) {
          setState(() {
            final liveList = relevantBookings.map((b) {
              final meta = b['booking_metadata'] as Map<String, dynamic>? ?? {};
              AppointmentStatus apptStatus;
              switch ((b['status'] as String? ?? 'pending').toLowerCase()) {
                case 'confirmed':
                  apptStatus = AppointmentStatus.confirmed;
                  break;
                case 'in_progress':
                case 'preparing':
                  apptStatus = AppointmentStatus.inProgress;
                  break;
                case 'completed':
                  apptStatus = AppointmentStatus.completed;
                  break;
                case 'cancelled':
                  apptStatus = AppointmentStatus.cancelled;
                  break;
                case 'disputed':
                  apptStatus = AppointmentStatus.disputed;
                  break;
                case 'pending':
                default:
                  apptStatus = AppointmentStatus.pending;
                  break;
              }

              double price = 0.0;
              final rawPrice = (b['total_price'] ?? meta['total_price'] ?? '0').toString();
              price = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

              String serviceLabel = b['service_name']?.toString() ?? meta['category']?.toString() ?? 'Perkhidmatan';
              final rawAddons = meta['addons_list'];
              if (rawAddons is List && rawAddons.isNotEmpty) {
                final addonsStr = rawAddons.map((a) => a.toString()).join(', ');
                if (!serviceLabel.contains(addonsStr)) {
                  serviceLabel = '$serviceLabel + $addonsStr';
                }
              }

              final List<String> noteParts = [];
              final String rawNotes = meta['notes']?.toString().trim() ?? '';
              if (rawNotes.isNotEmpty) {
                noteParts.add(rawNotes);
              }
              if (meta['estimated_duration_mins'] != null) {
                noteParts.add('Tempoh: ~${meta['estimated_duration_mins']} min');
              }
              if (meta['payment_method'] != null) {
                noteParts.add('Bayaran: ${meta['payment_method']}');
              }
              if (meta['cancellation_reason'] != null) {
                noteParts.add('Sebab Batal: ${meta['cancellation_reason']}');
              }

              final String payStatus = (meta['payment_status']?.toString() ?? 'unpaid').toLowerCase();
              final bool isPaidOnline = payStatus == 'paid';

              return {
                'db_id': b['id'],
                'id': meta['booking_id'] ?? meta['short_ref'] ?? 'BK-${b['id'].toString().substring(0, b['id'].toString().length > 6 ? 6 : b['id'].toString().length)}',
                'customerName': b['customer_name'] ?? meta['customer_name'] ?? 'Pelanggan Ngam',
                'phone': (meta['phone'] != null && meta['phone'].toString().trim().isNotEmpty)
                    ? meta['phone'].toString().trim()
                    : '-',
                'service': serviceLabel,
                'dateTime': '${b['booking_date'] ?? 'Hari Ini'}, ${b['booking_time'] ?? ''}',
                'staff': meta['provider_name'] ?? 'Staff',
                'price': price,
                'deposit': isPaidOnline ? price : 0.0,
                'payment_status': payStatus,
                'payment_method': meta['payment_method']?.toString() ?? 'Bayar Tunai di Kedai',
                'pax': b['pax'] ?? meta['pax'] ?? 1,
                'raw_meta': meta,
                'status': apptStatus,
                'notes': noteParts.isNotEmpty ? noteParts.join(' • ') : 'Tempahan melalui Aplikasi Ngam',
              };
            }).toList();

            _appointments = liveList;
          });
          _checkForNewBookings(relevantBookings);
        }
      }, onError: (e) {
        debugPrint('Error in bookings subscription: $e');
        if (mounted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _subscribeToLiveBookings();
          });
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to bookings: $e');
    }
  }

  void _checkForNewBookings(List<Map<String, dynamic>> rawBookings) {
    final currentIds = rawBookings.map((b) => b['id'].toString()).toSet();
    if (_isFirstLoad) {
      _knownBookingIds = currentIds;
      _isFirstLoad = false;
      return;
    }

    final newlyAdded = currentIds.difference(_knownBookingIds);
    if (newlyAdded.isNotEmpty) {
      final hasNewPending = rawBookings.any((b) =>
          newlyAdded.contains(b['id'].toString()) &&
          (b['status'] == null ||
              b['status'] == 'pending' ||
              b['status'] == 'confirmed'));

      if (hasNewPending) {
        FlutterRingtonePlayer().playNotification();

        if (mounted) {
          showGlassToast(
            context,
            'Tempahan Baru Diterima!',
            type: GlassToastType.success,
            customIcon: Icons.calendar_month_rounded,
          );
        }
      }
    }
    _knownBookingIds = currentIds;
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_selectedFilterIndex == 0) return _appointments;
    if (_selectedFilterIndex == 2) {
      return _appointments
          .where((a) =>
              a['status'] == AppointmentStatus.confirmed ||
              a['status'] == AppointmentStatus.inProgress)
          .toList();
    }
    final targetStatus = _selectedFilterIndex == 1
        ? AppointmentStatus.pending
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

    final dbId = appt['db_id'];
    if (dbId != null) {
      String statusStr;
      switch (newStatus) {
        case AppointmentStatus.confirmed:
          statusStr = 'confirmed';
          break;
        case AppointmentStatus.inProgress:
          statusStr = 'in_progress';
          break;
        case AppointmentStatus.completed:
          statusStr = 'completed';
          break;
        case AppointmentStatus.cancelled:
          statusStr = 'cancelled';
          break;
        case AppointmentStatus.disputed:
          statusStr = 'disputed';
          break;
        case AppointmentStatus.pending:
          statusStr = 'pending';
          break;
      }
      var query = Supabase.instance.client
          .from('bookings')
          .update({'status': statusStr})
          .eq('id', dbId);
      if (_businessId != null && _businessId!.isNotEmpty) {
        query = query.eq('business_id', _businessId!);
      }
      query.catchError((e) {
        debugPrint('Error updating booking status: $e');
      });
    }

    final statusLabel = newStatus == AppointmentStatus.confirmed
        ? 'Disahkan'
        : newStatus == AppointmentStatus.completed
            ? 'Selesai'
            : 'Dibatalkan';
    showGlassToast(context, 'Tempahan ${appt['id']} ditandakan sebagai $statusLabel');
  }

  Future<void> _payAppointmentAtPos(Map<String, dynamic> appt) async {
    if (appt['payment_status'] == 'paid') {
      showGlassToast(context, 'Tempahan ini sudah dibayar penuh secara atas talian.');
      return;
    }
    final price = (appt['price'] as num?)?.toDouble() ?? 0.0;
    final deposit = (appt['deposit'] as num?)?.toDouble() ?? 0.0;
    final amount = (price - deposit).clamp(0.0, double.infinity);
    if (amount <= 0) {
      showGlassToast(context, 'Tiada baki bayaran tertunggak untuk tempahan ini.');
      return;
    }

    final result = await PaymentTerminalModal.show(
      context: context,
      amount: amount,
      orderTitle: 'Tempahan #${appt['id']} (${appt['service']})',
      customerName: appt['customerName'],
      itemLines: ['1x ${appt['service']} | RM ${amount.toStringAsFixed(2)}'],
      initialStep: TerminalStep.chooseMethod,
    );

    if (result == null || !result.isSuccess || !mounted) return;

    try {
      final rawMeta = (appt['raw_meta'] is Map)
          ? Map<String, dynamic>.from(appt['raw_meta'] as Map)
          : <String, dynamic>{};
      final updatedMeta = <String, dynamic>{
        ...rawMeta,
        'payment_status': 'paid',
        'payment_method': 'POS (${result.paymentMethod.toUpperCase()})',
      };

      setState(() {
        appt['payment_status'] = 'paid';
        appt['payment_method'] = 'POS (${result.paymentMethod.toUpperCase()})';
        appt['deposit'] = price;
        appt['raw_meta'] = updatedMeta;
        appt['status'] = AppointmentStatus.completed;
      });
      final dbId = appt['db_id'];
      if (dbId != null) {
        try {
          var query = Supabase.instance.client.from('bookings').update({
            'status': 'completed',
            'total_price': price,
            'booking_metadata': updatedMeta,
          }).eq('id', dbId);
          if (_businessId != null && _businessId!.isNotEmpty) {
            query = query.eq('business_id', _businessId!);
          }
          await query;
        } catch (_) {}
      }

      if (!mounted) return;
      showGlassToast(
        context,
        'Bayaran Tempahan #${appt['id']} Selesai (RM ${amount.toStringAsFixed(2)})!',
        customColor: const Color(0xFF44CF6C),
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat merekod bayaran tempahan: $e', isError: true);
    }
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> appt) async {
    final rawPhone = appt['phone']?.toString() ?? '';
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '6$cleanPhone';
    } else if (!cleanPhone.startsWith('60') && cleanPhone.length >= 9) {
      cleanPhone = '60$cleanPhone';
    }

    if (cleanPhone.isEmpty || cleanPhone.length < 8) {
      showGlassToast(context, 'Nombor telefon pelanggan tidak sah untuk WhatsApp', isError: true);
      return;
    }

    final message = '''
Salam sejahtera ${appt['customerName']},
Peringatan tempahan anda bersama kami:
📅 Tarikh & Masa: ${appt['dateTime']}
🔖 Perkhidmatan / Meja: ${appt['service']}
👤 Kakitangan / Ruang: ${appt['staff']}
💰 Jumlah: RM ${(appt['price'] as double).toStringAsFixed(2)}

Sila maklumkan sekiranya terdapat sebarang perubahan masa. Terima kasih!
''';

    final waUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: message));
      if (mounted) showGlassToast(context, 'Teks peringatan telah disalin ke papan keratan!');
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Future<void> _reassignStaff(Map<String, dynamic> appt) async {
    if (_businessId == null || _businessId!.isEmpty) return;
    try {
      final staffRows = await Supabase.instance.client
          .from('team_members')
          .select('id, user_id, name, role')
          .eq('business_id', _businessId!)
          .eq('status', 'active');
      final staffList = (staffRows as List).cast<Map<String, dynamic>>();
      if (staffList.isEmpty) {
        if (mounted) showGlassToast(context, 'Tiada krew aktif ditemui untuk ditugaskan.');
        return;
      }

      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF141724),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tugaskan Krew untuk Tempahan',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...staffList.map((s) => ListTile(
                leading: const Icon(Icons.person_pin_rounded, color: Color(0xFF42A5F5)),
                title: Text(s['name'] ?? 'Krew', style: const TextStyle(color: Colors.white)),
                subtitle: Text((s['role'] ?? 'krew').toString().toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, s),
              )),
            ],
          ),
        ),
      );

      if (selected == null || !mounted) return;
      final newStaffName = selected['name'] ?? 'Krew';
      final assignedUserId = selected['user_id']?.toString();

      final rawMeta = (appt['raw_meta'] is Map)
          ? Map<String, dynamic>.from(appt['raw_meta'] as Map)
          : <String, dynamic>{};
      final updatedMeta = <String, dynamic>{
        ...rawMeta,
        'provider_name': newStaffName,
        'assigned_staff_id': selected['id'],
      };

      final dbId = appt['db_id'];
      if (dbId != null) {
        var query = Supabase.instance.client.from('bookings').update({
          'staff_id': selected['id'],
          'booking_metadata': updatedMeta,
        }).eq('id', dbId);
        if (_businessId != null && _businessId!.isNotEmpty) {
          query = query.eq('business_id', _businessId!);
        }
        await query;

        if (assignedUserId != null && assignedUserId.isNotEmpty) {
          try {
            await Supabase.instance.client.from('notifications').insert({
              'user_id': assignedUserId,
              'business_id': _businessId,
              'title': 'Tugasan Tempahan Baharu',
              'message': 'Anda telah ditugaskan untuk tempahan #${appt['id']} (${appt['service']}) pada ${appt['dateTime']}.',
              'type': 'tempahan',
            });
          } catch (_) {}
        }
      }

      setState(() {
        appt['staff'] = newStaffName;
        appt['raw_meta'] = updatedMeta;
      });

      if (mounted) {
        showGlassToast(context, 'Krew $newStaffName berjaya ditugaskan!', customColor: const Color(0xFF10B981));
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'Ralat menugaskan krew: $e', isError: true);
    }
  }

  Future<void> _rejectWithReason(Map<String, dynamic> appt) async {
    String selectedReason = 'Slot penuh pada waktu tersebut';
    final reasons = [
      'Slot penuh pada waktu tersebut',
      'Kakitangan / Pakar sedang bercuti',
      'Kedai tutup awal / kecemasan',
      'Perkhidmatan tidak tersedia buat sementara',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'Sebab Penolakan / Pembatalan',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) {
              final sel = selectedReason == r;
              return RadioListTile<String>(
                value: r,
                groupValue: selectedReason,
                activeColor: Colors.redAccent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  r,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setModal(() => selectedReason = v);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sahkan Batal', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      appt['status'] = AppointmentStatus.cancelled;
    });

    final dbId = appt['db_id'];
    if (dbId != null) {
      final rawMeta = (appt['raw_meta'] is Map)
          ? Map<String, dynamic>.from(appt['raw_meta'] as Map)
          : <String, dynamic>{};
      final isPaid = appt['payment_status'] == 'paid';
      try {
        var query = Supabase.instance.client.from('bookings').update({
          'status': 'cancelled',
          'booking_metadata': {
            ...rawMeta,
            'cancellation_reason': selectedReason,
            'cancelled_by_merchant': true,
            if (isPaid) 'payment_status': 'refund_pending',
          },
        }).eq('id', dbId);
        if (_businessId != null && _businessId!.isNotEmpty) {
          query = query.eq('business_id', _businessId!);
        }
        await query;
      } catch (e) {
        debugPrint('Error rejecting booking: $e');
      }
    }
    if (mounted) {
      showGlassToast(context, 'Tempahan ${appt['id']} telah dibatalkan ($selectedReason).');
    }
  }

  Future<void> _openBookingQrCheckIn() async {
    final codeCtrl = TextEditingController();
    final matched = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Check-In QR Tiket Tempahan',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imbas kod QR tiket pelanggan (ID:RZRV-...) atau masukkan ID Tempahan:',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Cth: RZRV-261101-ABCDE',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              String raw = codeCtrl.text.trim().toUpperCase();
              if (raw.contains('ID:')) {
                final m = RegExp(r'ID:([^|]+)').firstMatch(raw);
                if (m != null) raw = m.group(1)!.trim();
              }
              if (raw.isEmpty) {
                showGlassToast(context, 'Tiket tempahan tidak ditemui.', isError: true);
                return;
              }
              for (final a in _appointments) {
                final aid = (a['id']?.toString() ?? '').toUpperCase();
                if (aid == raw || aid.contains(raw)) {
                  Navigator.pop(ctx, a);
                  return;
                }
              }
              showGlassToast(context, 'Tiket tempahan tidak ditemui.', isError: true);
            },
            child: const Text('Cari & Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    codeCtrl.dispose();

    if (matched != null && mounted) {
      _showBookingDetailsModal(matched);
    }
  }

  void _showBookingDetailsModal(Map<String, dynamic> appt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final status = appt['status'] as AppointmentStatus;
          final color = _statusColor(status);
          final price = (appt['price'] as num?)?.toDouble() ?? 0.0;
          final phone = appt['phone']?.toString() ?? '';
          final bookingId = appt['id']?.toString() ?? '';
          final customerName = appt['customerName']?.toString() ?? 'Pelanggan Ngam';
          final service = appt['service']?.toString() ?? 'Perkhidmatan';
          final dateTime = appt['dateTime']?.toString() ?? '';
          final staff = appt['staff']?.toString() ?? 'Staff';
          final notes = appt['notes']?.toString() ?? '';
          final paymentMethod = appt['payment_method']?.toString() ?? 'Bayar Tunai di Kedai';
          final pax = appt['pax']?.toString() ?? '1';

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF141724),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top Header: Title, ID & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Butiran Tempahan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: bookingId));
                              showGlassToast(context, 'ID Tempahan disalin!');
                            },
                            child: Row(
                              children: [
                                Text(
                                  bookingId,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF42A5F5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF42A5F5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Customer Profile Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.person_rounded, color: Color(0xFF42A5F5), size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_outlined, color: Colors.blueAccent, size: 20),
                          tooltip: 'Panggil Telefon',
                          onPressed: () => _callCustomer(phone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 20),
                          tooltip: 'WhatsApp Peringatan',
                          onPressed: () => _sendWhatsAppReminder(appt),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Booking Info Box (Key-Value rows)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Perkhidmatan',
                          value: service,
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Tarikh & Masa',
                          value: dateTime,
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Kakitangan / Staf',
                          value: staff,
                          trailing: InkWell(
                            onTap: () async {
                              Navigator.pop(modalCtx);
                              await _reassignStaff(appt);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
                              ),
                              child: const Text('Tukar', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDetailRow(
                          icon: Icons.group_outlined,
                          label: 'Bilangan Pax',
                          value: '$pax Orang',
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDetailRow(
                          icon: Icons.payments_outlined,
                          label: 'Jumlah Harga',
                          value: 'RM ${price.toStringAsFixed(2)}',
                          valueColor: const Color(0xFF44CF6C),
                          isBold: true,
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDetailRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Kaedah Bayaran',
                          value: paymentMethod,
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDetailRow(
                          icon: Icons.verified_outlined,
                          label: 'Status Bayaran',
                          value: appt['payment_status'] == 'paid'
                              ? 'SUDAH DIBAYAR PENUH ONLINE'
                              : (appt['payment_status'] == 'refund_pending'
                                  ? 'PEMULANGAN WANG DIPROSES'
                                  : 'BELUM DIBAYAR BAYAR DI KEDAI'),
                          valueColor: appt['payment_status'] == 'paid'
                              ? const Color(0xFF44CF6C)
                              : Colors.orangeAccent,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.notes_rounded, size: 16, color: Colors.white54),
                              SizedBox(width: 6),
                              Text(
                                'Catatan / Nota Pelanggan:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notes,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (status == AppointmentStatus.disputed) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pelanggan telah memfailkan pertikaian. Sila hubungi pelanggan melalui WhatsApp untuk menyelesaikan isu.',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Bottom Action Buttons in Modal
                  Row(
                    children: [
                      if (status == AppointmentStatus.pending) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              _rejectWithReason(appt);
                            },
                            child: const Text('Tolak / Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              _updateStatus(appt, AppointmentStatus.confirmed);
                            },
                            child: const Text('Terima Tempahan', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else if (status == AppointmentStatus.confirmed || status == AppointmentStatus.inProgress) ...[
                        if (appt['payment_status'] != 'paid') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFED1164),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                _payAppointmentAtPos(appt);
                              },
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: const Text('Bayar POS', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else if (status == AppointmentStatus.confirmed) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9C27B0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                _updateStatus(appt, AppointmentStatus.inProgress);
                              },
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                              label: const Text('Check-In Hadir', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF44CF6C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              _updateStatus(appt, AppointmentStatus.completed);
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Tanda Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(modalCtx),
                            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openNewAppointmentModal() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    final staffCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '50.00');
    final depositCtrl = TextEditingController(text: '0.00');
    final notesCtrl = TextEditingController();

    String selectedDateText = 'Hari Ini';
    String selectedTimeText = '02:30 PM';

    final sampleServices = [
      'Konsultasi / Khidmat',
      'Servis / Rawatan',
      'Tempahan Meja / Bilik',
      'Penyelenggaraan / Baik Pulih',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: Color(0xFF141724),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Cipta Tempahan / Temu Janji Baharu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sesuai untuk sebarang khidmat, konsultasi, meja, ruang atau slot servis',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 20),

                  // 1. Nama Pelanggan
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan *',
                      hintText: 'Cth: Amirul Hakim / Syarikat ABC',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Nombor Telefon (WhatsApp)
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nombor Telefon WhatsApp *',
                      hintText: 'Cth: 01115892468',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF25D366), size: 18),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Nama Servis / Perkhidmatan / Meja
                  TextField(
                    controller: serviceCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Servis / Perkhidmatan / Meja *',
                      hintText: 'Cth: Konsultasi / Servis Kereta / Gunting Rambut / Meja VIP',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick service suggestions chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: sampleServices.map((sample) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(sample, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            side: const BorderSide(color: Colors.white12),
                            onPressed: () {
                              setModalState(() {
                                serviceCtrl.text = sample;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Staf / Meja / Bilik
                  TextField(
                    controller: staffCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Penyedia Khidmat Meja Bilik Pilihan',
                      hintText: 'Cth: En. Farid / Meja 04 / Bilik 2 / Mana-mana staf sedia ada',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Tarikh & Masa Row
                  const Text('Tarikh & Masa Slot', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Hari Ini', 'Esok', 'Lusa'].map((d) {
                        final isSel = selectedDateText == d;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(d, style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: isSel,
                            selectedColor: const Color(0xFF42A5F5),
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            onSelected: (_) => setModalState(() => selectedDateText = d),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time Slots
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['10:00 AM', '11:30 AM', '02:30 PM', '04:00 PM', '05:30 PM', '08:00 PM'].map((t) {
                        final isSel = selectedTimeText == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(t, style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: isSel,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            onSelected: (_) => setModalState(() => selectedTimeText = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. Harga Penuh & Deposit Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Harga Servis RM *',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixText: 'RM ',
                            prefixStyle: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: depositCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Deposit Diterima RM',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixText: 'RM ',
                            prefixStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 7. Catatan
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Catatan Tambahan Pilihan',
                      hintText: 'Cth: Permintaan khas pelanggan / sebarang butiran penting',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        final service = serviceCtrl.text.trim();
                        final staff = staffCtrl.text.trim().isEmpty ? 'Kakitangan Bertugas' : staffCtrl.text.trim();
                        final priceVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                        final deposit = double.tryParse(depositCtrl.text.trim()) ?? 0.0;
                        final notes = notesCtrl.text.trim();

                        if (name.isEmpty) {
                          showGlassToast(context, 'Sila masukkan nama pelanggan', isError: true);
                          return;
                        }
                        if (service.isEmpty) {
                          showGlassToast(context, 'Sila masukkan jenis servis / perkhidmatan / meja', isError: true);
                          return;
                        }

                        final bookingId = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        final dateTimeStr = '$selectedDateText, $selectedTimeText';
                        final int addDays = selectedDateText == 'Hari Ini' ? 0 : (selectedDateText == 'Esok' ? 1 : 2);
                        final String bookingDateIso = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: addDays)));

                        final rawMeta = <String, dynamic>{
                          'booking_id': bookingId,
                          'phone': phone,
                          'provider_name': staff,
                          'total_price': priceVal,
                          'deposit': deposit,
                          'payment_status': 'unpaid',
                          'notes': notes,
                        };

                        final newBookingMap = <String, dynamic>{
                          'db_id': null,
                          'id': bookingId,
                          'customerName': name,
                          'phone': phone.isEmpty ? 'Walk-in' : phone,
                          'service': service,
                          'dateTime': dateTimeStr,
                          'staff': staff,
                          'price': priceVal,
                          'deposit': deposit,
                          'payment_status': 'unpaid',
                          'raw_meta': rawMeta,
                          'status': AppointmentStatus.confirmed,
                          'notes': notes,
                        };

                        // 1. Persist directly to Supabase bookings table
                        try {
                          final profile = await BusinessService().getBusinessProfile();
                          final bId = profile?['id']?.toString() ?? _businessId;
                          if (bId == null || bId.isEmpty) {
                            showGlassToast(context, 'Profil perniagaan tidak dijumpai.', isError: true);
                            return;
                          }
                          await Supabase.instance.client.from('bookings').insert({
                            'business_id': bId,
                            'customer_name': name,
                            'service_name': service,
                            'booking_date': bookingDateIso,
                            'booking_time': selectedTimeText,
                            'total_price': priceVal,
                            'status': 'confirmed',
                            'booking_metadata': rawMeta,
                          }).select().single();

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            showGlassToast(context, 'Tempahan #$bookingId berjaya didaftarkan!', customColor: const Color(0xFF10B981));
                          }
                        } catch (e) {
                          if (mounted) {
                            showGlassToast(context, 'Ralat mendaftar tempahan: $e', isError: true);
                          }
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Sahkan Tempahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    serviceCtrl.dispose();
    staffCtrl.dispose();
    priceCtrl.dispose();
    depositCtrl.dispose();
    notesCtrl.dispose();
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
      case AppointmentStatus.disputed:
        return const Color(0xFFF97316);
    }
  }

  String _statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Menunggu';
      case AppointmentStatus.confirmed:
        return 'Disahkan';
      case AppointmentStatus.inProgress:
        return 'Sedang Berjalan';
      case AppointmentStatus.completed:
        return 'Selesai';
      case AppointmentStatus.cancelled:
        return 'Dibatalkan';
      case AppointmentStatus.disputed:
        return 'Pertikaian';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: widget.isEmbedded ? Colors.transparent : const Color(0xFF0A0A14),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        onPressed: _openNewAppointmentModal,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Tempahan Baharu', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        top: !widget.isEmbedded,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: widget.isEmbedded ? 0 : 68),
              child: Column(
                children: [
                  // QR Check-In Bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(widget.isEmbedded ? 0 : 20, 4, widget.isEmbedded ? 0 : 20, 10),
                    child: InkWell(
                      onTap: _openBookingQrCheckIn,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Imbas Sahkan QR Tiket Tempahan RZRV',
                              style: TextStyle(
                                color: Color(0xFF42A5F5),
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Filter Chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: widget.isEmbedded ? 0 : 20),
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
                            'Tiada tempahan dijumpai',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tempahan pelanggan baharu akan dipaparkan di sini.',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(widget.isEmbedded ? 0 : 20, 0, widget.isEmbedded ? 0 : 20, 80),
                      itemCount: _filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appt = _filteredAppointments[index];
                        final status = appt['status'] as AppointmentStatus;
                        final color = _statusColor(status);

                        return GestureDetector(
                          onTap: () => _showBookingDetailsModal(appt),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
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
                                    Row(
                                      children: [
                                        Text(
                                          appt['id'],
                                          style: const TextStyle(
                                            color: Color(0xFF42A5F5),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white38),
                                      ],
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
                                  const Icon(Icons.bookmark_border_rounded, size: 15, color: Color(0xFF42A5F5)),
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
                                    'Catatan: ${appt['notes']}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],

                              if (status == AppointmentStatus.disputed) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Pelanggan telah memfailkan pertikaian. Dana ditahan oleh Ngam. Sila hubungi pelanggan melalui WhatsApp untuk selesaikan isu.',
                                          style: TextStyle(color: Colors.orangeAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
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
                                        'Jumlah: RM ${(appt['price'] as double).toStringAsFixed(2)}',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.phone_outlined, color: Colors.blueAccent, size: 19),
                                        onPressed: () => _callCustomer(appt['phone']),
                                        tooltip: 'Panggil Telefon',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 19),
                                        onPressed: () => _sendWhatsAppReminder(appt),
                                        tooltip: 'Hantar WhatsApp Peringatan',
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
                                          child: const Text('Terima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ] else if (status == AppointmentStatus.confirmed || status == AppointmentStatus.inProgress) ...[
                                        if (appt['payment_status'] != 'paid') ...[
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFED1164),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              elevation: 0,
                                            ),
                                            onPressed: () => _payAppointmentAtPos(appt),
                                            icon: const Icon(Icons.bolt_rounded, size: 15),
                                            label: const Text('Bayar POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF44CF6C),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () => _updateStatus(appt, AppointmentStatus.completed),
                                          child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
                ],
              ),
            ),
            if (!widget.isEmbedded)
              const FloatingTopBar(
                title: 'Tempahan & Temu Janji',
                subtitle: 'Slot temu janji & servis',
                fallbackRoute: '/home',
              ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) return scaffold;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        GlassNavButton.safeNavBack(context, fallbackRoute: '/home');
      },
      child: scaffold,
    );
  }
}
