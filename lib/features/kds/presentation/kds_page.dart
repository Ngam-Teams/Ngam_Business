import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// KdsPage — Kitchen Display System & Order Preparation Screen
// ============================================================

enum KdsStage { incoming, cooking, ready, served }

class KdsPage extends StatefulWidget {
  const KdsPage({super.key});

  @override
  State<KdsPage> createState() => _KdsPageState();
}

class _KdsPageState extends State<KdsPage> {
  String _filterType = 'All'; // All, Dine-In, Takeaway
  bool _soundEnabled = true;

  late List<Map<String, dynamic>> _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = [
      {
        'id': '#4031',
        'table': 'Table 04',
        'type': 'Dine-In',
        'minutesAgo': 4,
        'stage': KdsStage.incoming,
        'server': 'Ahmad',
        'items': [
          {'name': '2x Nasi Lemak Rendang Daging', 'notes': 'Extra sambal asing', 'done': false},
          {'name': '1x Mee Goreng Mamak Special', 'notes': 'Tanpa taugeh', 'done': false},
          {'name': '2x Teh Tarik Kaw (Ais)', 'notes': 'Kurang manis', 'done': false},
        ],
      },
      {
        'id': '#4030',
        'table': 'Table 09',
        'type': 'Dine-In',
        'minutesAgo': 12,
        'stage': KdsStage.cooking,
        'server': 'Farid',
        'items': [
          {'name': '1x Ayam Percik Kelantan Rice Set', 'notes': '', 'done': true},
          {'name': '1x Sup Tulang Merah Melaka', 'notes': 'Pedas level 3', 'done': false},
          {'name': '1x Sirap Bandung Cincau', 'notes': '', 'done': true},
        ],
      },
      {
        'id': '#4029',
        'table': 'Takeaway #12',
        'type': 'Takeaway',
        'minutesAgo': 22,
        'stage': KdsStage.cooking,
        'server': 'Counter',
        'items': [
          {'name': '3x Roti Canai Banjir Special', 'notes': 'Kuah dal & kari campur', 'done': false},
          {'name': '2x Kopi O Kaw Panas', 'notes': 'Pahit sikit', 'done': false},
        ],
      },
      {
        'id': '#4028',
        'table': 'Table 02',
        'type': 'Dine-In',
        'minutesAgo': 18,
        'stage': KdsStage.ready,
        'server': 'Farid',
        'items': [
          {'name': '1x Laksa Nyonya Melaka', 'notes': '', 'done': true},
          {'name': '1x Cendol Durian D24', 'notes': 'Extra santan', 'done': true},
        ],
      },
    ];
  }

  Color _getTimerColor(int minutes) {
    if (minutes < 10) return const Color(0xFF10B981); // Green
    if (minutes < 20) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  void _progressTicket(Map<String, dynamic> ticket) {
    setState(() {
      if (ticket['stage'] == KdsStage.incoming) {
        ticket['stage'] = KdsStage.cooking;
        showGlassToast(context, 'Ticket ${ticket['id']} moved to Cooking');
      } else if (ticket['stage'] == KdsStage.cooking) {
        ticket['stage'] = KdsStage.ready;
        showGlassToast(context, 'Ticket ${ticket['id']} marked READY FOR SERVING');
      } else if (ticket['stage'] == KdsStage.ready) {
        ticket['stage'] = KdsStage.served;
        _tickets.remove(ticket);
        showGlassToast(context, 'Ticket ${ticket['id']} completed and cleared!');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _tickets.where((t) {
      if (_filterType == 'All') return true;
      return t['type'] == _filterType;
    }).toList();

    final incomingTickets = filteredTickets.where((t) => t['stage'] == KdsStage.incoming).toList();
    final cookingTickets = filteredTickets.where((t) => t['stage'] == KdsStage.cooking).toList();
    final readyTickets = filteredTickets.where((t) => t['stage'] == KdsStage.ready).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090F),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01, color: Color(0xFFF9C80E), size: 24),
            const SizedBox(width: 12),
            const Text(
              'Kitchen Display System (KDS)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${filteredTickets.length} ACTIVE',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          // Filter pills
          Row(
            children: ['All', 'Dine-In', 'Takeaway'].map((type) {
              final isSel = _filterType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(type, style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: isSel,
                  selectedColor: const Color(0xFFF9C80E),
                  backgroundColor: const Color(0xFF141424),
                  side: const BorderSide(color: Colors.white12),
                  onSelected: (val) => setState(() => _filterType = type),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _soundEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: _soundEnabled ? const Color(0xFF44CF6C) : Colors.white38,
              size: 22,
            ),
            tooltip: 'Kitchen Chime Alert',
            onPressed: () {
              setState(() => _soundEnabled = !_soundEnabled);
              showGlassToast(context, _soundEnabled ? 'Kitchen chime alert enabled' : 'Kitchen chime muted');
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMultiColumn = constraints.maxWidth >= 900;

          if (isMultiColumn) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildColumn('NEW ORDERS', incomingTickets, const Color(0xFF42A5F5), KdsStage.incoming)),
                const VerticalDivider(width: 1, color: Colors.white12),
                Expanded(child: _buildColumn('PREPARING / COOKING', cookingTickets, const Color(0xFFF9C80E), KdsStage.cooking)),
                const VerticalDivider(width: 1, color: Colors.white12),
                Expanded(child: _buildColumn('READY TO SERVE', readyTickets, const Color(0xFF10B981), KdsStage.ready)),
              ],
            );
          } else {
            // Horizontal scrollable boards on smaller screens/tablets
            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: const Color(0xFFF9C80E),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(text: 'New (${incomingTickets.length})'),
                      Tab(text: 'Cooking (${cookingTickets.length})'),
                      Tab(text: 'Ready (${readyTickets.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildColumn('NEW ORDERS', incomingTickets, const Color(0xFF42A5F5), KdsStage.incoming),
                        _buildColumn('PREPARING', cookingTickets, const Color(0xFFF9C80E), KdsStage.cooking),
                        _buildColumn('READY', readyTickets, const Color(0xFF10B981), KdsStage.ready),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildColumn(String title, List<Map<String, dynamic>> tickets, Color headerColor, KdsStage stage) {
    return Container(
      color: const Color(0xFF0D0D17),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: headerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: headerColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${tickets.length}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tickets List
          Expanded(
            child: tickets.isEmpty
                ? Center(
                    child: Text(
                      'No tickets in this stage',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (ctx, idx) => _buildTicketCard(tickets[idx]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final timerColor = _getTimerColor(ticket['minutesAgo'] as int);
    final items = ticket['items'] as List<dynamic>;
    final stage = ticket['stage'] as KdsStage;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: timerColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: timerColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ticket Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      ticket['id'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ticket['type'] == 'Takeaway'
                            ? const Color(0xFFEC4899).withValues(alpha: 0.2)
                            : const Color(0xFF42A5F5).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticket['table'] as String,
                        style: TextStyle(
                          color: ticket['type'] == 'Takeaway' ? const Color(0xFFEC4899) : const Color(0xFF42A5F5),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // Timer badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: timerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: timerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: timerColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${ticket['minutesAgo']}m',
                        style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items Checklist
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final isDone = item['done'] as bool;
                final notes = item['notes'] as String;

                return GestureDetector(
                  onTap: () {
                    setState(() => item['done'] = !isDone);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isDone ? const Color(0xFF10B981) : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: TextStyle(
                                  color: isDone ? Colors.white38 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (notes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9C80E).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '★ $notes',
                                    style: const TextStyle(color: Color(0xFFF9C80E), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Bottom Action Button
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: stage == KdsStage.incoming
                      ? const Color(0xFF42A5F5)
                      : stage == KdsStage.cooking
                          ? const Color(0xFFF9C80E)
                          : const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _progressTicket(ticket),
                child: Text(
                  stage == KdsStage.incoming
                      ? 'Start Cooking'
                      : stage == KdsStage.cooking
                          ? 'Mark as Ready'
                          : 'Order Served (Done)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
