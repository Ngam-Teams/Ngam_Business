import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/queue_service.dart';
import '../models/queue_ticket_model.dart';
import 'widgets/issue_ticket_modal.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/glass_nav_button.dart';

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
      showGlassToast(context, 'queue.no_waiting_title'.tr());
      return;
    }

    try {
      await _queueService.callTicket(next.id);
      if (!mounted) return;
      showGlassToast(
        context,
        'queue.calling_toast'.tr(args: [next.ticketNumber, next.customerName]),
        customColor: const Color(0xFF42A5F5),
      );
      if (next.phoneNumber != null && next.phoneNumber!.isNotEmpty) {
        _sendWhatsAppReminder(next);
      }
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
        'queue.start_service_toast'.tr(args: [ticket.ticketNumber]),
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
        'queue.ticket_completed_toast'.tr(args: [ticket.ticketNumber]),
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
        isNoShow ? 'queue.no_show_toast'.tr() : 'queue.ticket_cancelled_toast'.tr(),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  void _sendWhatsAppReminder(QueueTicketModel ticket) async {
    if (ticket.phoneNumber == null || ticket.phoneNumber!.isEmpty) {
      showGlassToast(context, 'queue.no_phone_error'.tr(), isError: true);
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
      showGlassToast(context, 'queue.wa_open_failed'.tr(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'queue.title'.tr(),
      subtitle: 'queue.subtitle'.tr(),
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedQrCode,
          tooltip: 'queue.qr_standee'.tr(),
          onTap: () => context.push('/qr'),
        ),
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedTv01,
          tooltip: 'queue.open_tv_display'.tr(),
          onTap: () => context.push('/queue/tv'),
        ),
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedTicket01,
          tooltip: 'queue.issue_ticket'.tr(),
          onTap: () => IssueTicketModal.show(context: context, queueService: _queueService),
        ),
      ],
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
                padding: const EdgeInsets.fromLTRB(16, 68, 16, 24),
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
        label: Text(
          'queue.issue_ticket'.tr(),
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
            label: 'common.pending'.tr(),
            value: '$_waitingCount',
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'queue.ticket_called'.tr(),
            value: '$_callingCount',
            icon: Icons.campaign_rounded,
            color: const Color(0xFF42A5F5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'queue.serve'.tr(),
            value: '$_servingCount',
            icon: Icons.content_cut_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'common.completed'.tr(),
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
                      child: Text(
                        'queue.next_turn_badge'.tr(),
                        style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 10, fontWeight: FontWeight.w900),
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
                    '${next.serviceName ?? "queue.service_general".tr()} • ${'queue.waiting_min'.tr(args: [DateTime.now().difference(next.createdAt).inMinutes.toString()])}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ] else ...[
                  Text(
                    'queue.no_waiting_title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'queue.no_waiting_subtitle'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: next == null ? null : _callNextTicket,
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: Text('queue.call_action'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
      {'key': 'waiting', 'label': '${'common.pending'.tr()} $_waitingCount'},
      {'key': 'calling', 'label': '${'queue.ticket_called'.tr()} $_callingCount'},
      {'key': 'serving', 'label': '${'queue.serve'.tr()} $_servingCount'},
      {'key': 'completed', 'label': 'common.completed'.tr()},
      {'key': 'all', 'label': '${'common.all'.tr()} ${_tickets.length}'},
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
                      '${ticket.serviceName ?? "queue.service_general".tr()} • ${ticket.stationOrChair ?? "queue.station_counter".tr()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'queue.waiting_min'.tr(args: [waitMinutes.toString()]),
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
                  child: Text('queue.mark_no_show_action'.tr(), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _queueService.callTicket(ticket.id);
                    if (ticket.phoneNumber != null && ticket.phoneNumber!.isNotEmpty) {
                      _sendWhatsAppReminder(ticket);
                    }
                  },
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: Text('queue.call_action'.tr(), style: const TextStyle(fontSize: 12)),
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
                  child: Text('queue.recall_action'.tr(), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _startServing(ticket),
                  icon: const Icon(Icons.content_cut_rounded, size: 16),
                  label: Text('queue.start_serve_action'.tr(), style: const TextStyle(fontSize: 12)),
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
                  label: Text('queue.mark_complete_action'.tr(), style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF44CF6C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ] else ...[
                Text(
                  'queue.completed_at'.tr(args: [ticket.completedAt != null ? DateFormat("hh:mm a").format(ticket.completedAt!) : "-"]),
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
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.confirmation_number_outlined, color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          Text(
            'queue.no_waiting'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'queue.empty_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/qr'),
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Color(0xFF42A5F5), size: 16),
            label: Text(
              'queue.qr_standee'.tr(),
              style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF42A5F5).withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
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
        return 'queue.status_waiting'.tr();
      case 'calling':
        return 'queue.status_calling'.tr();
      case 'serving':
        return 'queue.status_serving'.tr();
      case 'completed':
        return 'queue.status_completed'.tr();
      case 'no_show':
        return 'queue.status_no_show'.tr();
      case 'cancelled':
        return 'queue.status_cancelled'.tr();
      default:
        return status.toUpperCase();
    }
  }
}
