import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/queue_service.dart';
import '../models/queue_ticket_model.dart';
import 'widgets/issue_ticket_modal.dart';
import '../../../widgets/glass_toast.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  final QueueService _queueService = QueueService();
  List<QueueTicketModel> _tickets = [];
  bool _loading = true;
  String _selectedTab = 'waiting'; // 'all' | 'waiting' | 'calling' | 'serving' | 'completed'
  StreamSubscription<List<QueueTicketModel>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _initStream() {
    setState(() => _loading = true);
    _subscription = _queueService.streamQueueTickets().listen((tickets) {
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  int get _waitingCount => _tickets.where((t) => t.status == 'waiting').length;
  int get _callingCount => _tickets.where((t) => t.status == 'calling').length;
  int get _servingCount => _tickets.where((t) => t.status == 'serving').length;
  int get _completedCount => _tickets.where((t) => t.status == 'completed').length;

  List<QueueTicketModel> get _filteredTickets {
    if (_selectedTab == 'all') return _tickets;
    return _tickets.where((t) => t.status == _selectedTab).toList();
  }

  QueueTicketModel? get _nextWaitingTicket {
    final waiting = _tickets.where((t) => t.status == 'waiting').toList();
    return waiting.isNotEmpty ? waiting.first : null;
  }

  Future<void> _callNextTicket() async {
    final next = _nextWaitingTicket;
    if (next == null) {
      showGlassToast(context, 'Tiada pelanggan menunggu dalam senarai.');
      return;
    }

    try {
      await _queueService.callTicket(next.id);
      if (!mounted) return;
      showGlassToast(
        context,
        'Memanggil ${next.ticketNumber} - ${next.customerName}',
        customColor: const Color(0xFF42A5F5),
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  Future<void> _startServing(QueueTicketModel ticket) async {
    try {
      await _queueService.startServingTicket(ticket.id);
      if (!mounted) return;
      showGlassToast(
        context,
        'Mula servis untuk ${ticket.ticketNumber}',
        customColor: const Color(0xFF10B981),
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  Future<void> _completeTicket(QueueTicketModel ticket) async {
    try {
      await _queueService.completeTicket(ticket.id);
      if (!mounted) return;
      showGlassToast(
        context,
        'Tiket ${ticket.ticketNumber} selesai!',
        customColor: const Color(0xFF44CF6C),
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  Future<void> _cancelTicket(QueueTicketModel ticket, {bool isNoShow = false}) async {
    try {
      await _queueService.cancelTicket(ticket.id, isNoShow: isNoShow);
      if (!mounted) return;
      showGlassToast(
        context,
        isNoShow ? 'Ditandakan sebagai No-Show' : 'Tiket dibatalkan',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  void _sendWhatsAppReminder(QueueTicketModel ticket) async {
    if (ticket.phoneNumber == null || ticket.phoneNumber!.isEmpty) {
      showGlassToast(context, 'Tiada nombor telefon direkodkan', isError: true);
      return;
    }

    String phone = ticket.phoneNumber!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = '6$phone';

    final chairInfo = ticket.stationOrChair != null ? ' di ${ticket.stationOrChair}' : '';
    final message = Uri.encodeComponent(
      'Salam ${ticket.customerName}! Nombor giliran anda *${ticket.ticketNumber}*$chairInfo telah dipanggil. Sila masuk ke kedai sekarang.',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      showGlassToast(context, 'Tidak dapat membuka WhatsApp', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengurusan Giliran (Queue)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Papan kawalan giliran walk-in & TV',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Open TV Display Mode button
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedTv01, color: Color(0xFF42A5F5), size: 22),
            tooltip: 'Buka Paparan TV Kedai',
            onPressed: () => context.push('/queue/tv'),
          ),
          // Issue Ticket Button
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF44CF6C), size: 26),
            tooltip: 'Keluarkan Tiket Walk-In',
            onPressed: () => IssueTicketModal.show(context: context, queueService: _queueService),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : RefreshIndicator(
              onRefresh: () async {
                final t = await _queueService.fetchQueueTickets();
                setState(() => _tickets = t);
              },
              color: const Color(0xFF42A5F5),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metrics Row
                    _buildMetricsGrid(),
                    const SizedBox(height: 16),

                    // Call Next Hero Banner
                    _buildCallNextBanner(),
                    const SizedBox(height: 18),

                    // Filter Tabs
                    _buildFilterTabs(),
                    const SizedBox(height: 14),

                    // Tickets List
                    if (_filteredTickets.isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredTickets.map(_buildTicketCard),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => IssueTicketModal.show(context: context, queueService: _queueService),
        backgroundColor: const Color(0xFF42A5F5),
        icon: const Icon(Icons.confirmation_number_outlined, color: Colors.white),
        label: const Text(
          '+ Tiket Walk-In',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Menunggu',
            value: '$_waitingCount',
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'Dipanggil',
            value: '$_callingCount',
            icon: Icons.campaign_rounded,
            color: const Color(0xFF42A5F5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'Sedang Servis',
            value: '$_servingCount',
            icon: Icons.content_cut_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'Selesai',
            value: '$_completedCount',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFFA78BFA),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCallNextBanner() {
    final next = _nextWaitingTicket;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF42A5F5).withValues(alpha: 0.25),
            const Color(0xFF141424),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'GILIRAN SETERUSNYA',
                        style: TextStyle(color: Color(0xFF42A5F5), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (next != null) ...[
                  Text(
                    '${next.ticketNumber} — ${next.customerName}',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Servis: ${next.serviceName ?? "Servis Am"} • Menunggu ${DateTime.now().difference(next.createdAt).inMinutes} min',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ] else ...[
                  const Text(
                    'Tiada giliran menunggu',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Keluarkan tiket baru untuk mula melayan pelanggan',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: next == null ? null : _callNextTicket,
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: const Text('Panggil', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'key': 'waiting', 'label': 'Menunggu ($_waitingCount)'},
      {'key': 'calling', 'label': 'Dipanggil ($_callingCount)'},
      {'key': 'serving', 'label': 'Sedang Servis ($_servingCount)'},
      {'key': 'completed', 'label': 'Selesai'},
      {'key': 'all', 'label': 'Semua (${_tickets.length})'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSel = _selectedTab == t['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t['label']!, style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12)),
              selected: isSel,
              selectedColor: const Color(0xFF42A5F5),
              backgroundColor: const Color(0xFF141424),
              side: BorderSide(color: isSel ? const Color(0xFF42A5F5) : Colors.white12),
              onSelected: (val) {
                if (val) setState(() => _selectedTab = t['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTicketCard(QueueTicketModel ticket) {
    final waitMinutes = DateTime.now().difference(ticket.createdAt).inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusBorderColor(ticket.status),
          width: ticket.status == 'calling' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ticket badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(ticket.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor(ticket.status)),
                ),
                child: Text(
                  ticket.ticketNumber,
                  style: TextStyle(
                    color: _getStatusColor(ticket.status),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusColor(ticket.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getStatusText(ticket.status),
                  style: TextStyle(
                    color: _getStatusColor(ticket.status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.customerName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ticket.serviceName ?? "Servis Am"} • ${ticket.stationOrChair ?? "Kaunter"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Menunggu $waitMinutes m',
                    style: TextStyle(
                      color: waitMinutes > 20 ? Colors.redAccent : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(ticket.createdAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          if (ticket.notes != null && ticket.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Nota: ${ticket.notes}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ],

          const Divider(height: 20, color: Colors.white12),

          // Action Buttons Bar
          Row(
            children: [
              // WhatsApp reminder
              if (ticket.phoneNumber != null && ticket.phoneNumber!.isNotEmpty)
                IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedWhatsapp, color: Color(0xFF25D366), size: 20),
                  tooltip: 'WhatsApp Pelanggan',
                  onPressed: () => _sendWhatsAppReminder(ticket),
                ),

              const Spacer(),

              // Contextual stage buttons
              if (ticket.status == 'waiting') ...[
                OutlinedButton(
                  onPressed: () => _cancelTicket(ticket, isNoShow: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('No-Show', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _queueService.callTicket(ticket.id),
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: const Text('Panggil', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else if (ticket.status == 'calling') ...[
                OutlinedButton(
                  onPressed: () => _queueService.callTicket(ticket.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    side: const BorderSide(color: Color(0xFF42A5F5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Ulang Panggil', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _startServing(ticket),
                  icon: const Icon(Icons.content_cut_rounded, size: 16),
                  label: const Text('Mula Servis', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else if (ticket.status == 'serving') ...[
                ElevatedButton.icon(
                  onPressed: () => _completeTicket(ticket),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Tandakan Selesai', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF44CF6C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ] else ...[
                Text(
                  'Selesai pada ${ticket.completedAt != null ? DateFormat("hh:mm a").format(ticket.completedAt!) : "-"}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Center(
        child: Column(
          children: [
            const Icon(Icons.confirmation_number_outlined, color: Colors.white24, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Tiada Tiket Giliran',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekan "+ Tiket Walk-In" untuk daftar pelanggan baharu',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
      ).alignment,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return const Color(0xFFF59E0B);
      case 'calling':
        return const Color(0xFF42A5F5);
      case 'serving':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFFA78BFA);
      default:
        return Colors.white54;
    }
  }

  Color _getStatusBorderColor(String status) {
    if (status == 'calling') return const Color(0xFF42A5F5);
    if (status == 'serving') return const Color(0xFF10B981).withValues(alpha: 0.4);
    return Colors.white.withValues(alpha: 0.08);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
        return 'MENUNGGU';
      case 'calling':
        return 'SEDANG DIPANGGIL';
      case 'serving':
        return 'SEDANG DILAYAN';
      case 'completed':
        return 'SELESAI';
      case 'no_show':
        return 'NO-SHOW';
      case 'cancelled':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }
}
