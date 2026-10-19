import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sound_service.dart';
import '../../../widgets/glass_toast.dart';
import '../../orders/data/orders_service.dart';
import '../../settings/data/business_service.dart';

// ============================================================
// KdsPage — Live Order Board & Preparation Display Screen
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
  bool _useDemoData = false;
  bool _isLoading = true;

  StreamSubscription? _orderSub;
  List<Map<String, dynamic>> _liveTickets = [];
  final Map<String, List<Map<String, dynamic>>> _orderItemsCache = {};
  final Set<String> _knownOrderIds = {};
  final Set<String> _checkedItemKeys = {};

  final OrdersService _ordersService = OrdersService();

  // Demo fallback tickets for preview & testing
  final List<Map<String, dynamic>> _demoTickets = [
    {
      'rawId': 'demo-1',
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
      'rawId': 'demo-2',
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
      'rawId': 'demo-3',
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
      'rawId': 'demo-4',
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

  @override
  void initState() {
    super.initState();
    _initLiveKds();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  void _initLiveKds() async {
    final businessId = BusinessService.cachedProfile?['id'] ??
        (await BusinessService().getBusinessProfile())?['id'];

    if (businessId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Initial snapshot fetch to avoid re-alerting on existing orders
    try {
      final initial = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(50);
      for (final row in initial) {
        if (row['id'] != null) {
          _knownOrderIds.add(row['id'].toString());
        }
      }
    } catch (_) {}

    // 2. Stream active orders from Supabase
    _orderSub?.cancel();
    _orderSub = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at', ascending: true)
        .listen(
      (rows) async {
        await _processOrdersStream(rows);
      },
      onError: (err) {
        debugPrint('[KDS] Stream error: $err');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _processOrdersStream(List<Map<String, dynamic>> rows) async {
    final activeRows = rows.where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      return status == 'pending' ||
          status == 'preparing' ||
          status == 'cooking' ||
          status == 'ready';
    }).toList();

    // Check for newly arriving incoming orders to play chime alert
    for (final r in activeRows) {
      final id = r['id']?.toString() ?? '';
      final status = (r['status'] ?? '').toString().toLowerCase();
      if (status == 'pending' && !_knownOrderIds.contains(id)) {
        _knownOrderIds.add(id);
        if (_soundEnabled) {
          SoundService.instance.playOrderChime();
        }
      } else if (id.isNotEmpty) {
        _knownOrderIds.add(id);
      }
    }

    // Fetch order_items for active orders not yet cached
    final activeIds = activeRows.map((r) => r['id'].toString()).toList();
    final missingIds = activeIds.where((id) => !_orderItemsCache.containsKey(id)).toList();

    if (missingIds.isNotEmpty) {
      try {
        final itemsRes = await Supabase.instance.client
            .from('order_items')
            .select()
            .filter('order_id', 'in', missingIds);

        for (final item in itemsRes) {
          final oid = item['order_id'].toString();
          _orderItemsCache.putIfAbsent(oid, () => []).add(item);
        }
      } catch (e) {
        debugPrint('[KDS] Error fetching order_items: $e');
      }
    }

    // Transform database rows into UI tickets
    final List<Map<String, dynamic>> transformed = [];
    for (final r in activeRows) {
      final id = r['id'].toString();
      final shortId = '#${id.substring(max(0, id.length - 4)).toUpperCase()}';
      final status = (r['status'] ?? 'pending').toString().toLowerCase();
      final source = (r['source'] ?? 'pos').toString().toLowerCase();
      final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now();
      final minutesAgo = DateTime.now().difference(createdAt).inMinutes;

      KdsStage stage = KdsStage.incoming;
      if (status == 'preparing' || status == 'cooking') {
        stage = KdsStage.cooking;
      } else if (status == 'ready') {
        stage = KdsStage.ready;
      }

      final rawItems = _orderItemsCache[id] ?? [];
      final List<Map<String, dynamic>> itemsList = rawItems.isEmpty
          ? [
              {
                'name': (r['notes'] != null && r['notes'].toString().isNotEmpty)
                    ? r['notes'].toString()
                    : '1x Pesanan Am',
                'notes': '',
                'done': _checkedItemKeys.contains('${id}_0'),
              }
            ]
          : rawItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final qty = item['quantity'] ?? 1;
              final name = item['product_name'] ?? 'Item';
              final itemKey = '${id}_$idx';
              return {
                'key': itemKey,
                'name': '${qty}x $name',
                'notes': item['notes'] ?? '',
                'done': _checkedItemKeys.contains(itemKey),
              };
            }).toList();

      String tableLabel = 'Kaunter';
      String typeLabel = 'Dine-In';
      if (source == 'takeaway' || source == 'delivery') {
        typeLabel = 'Takeaway';
        tableLabel = 'Bungkus';
      } else if (r['customer_name'] != null && r['customer_name'].toString().trim().isNotEmpty) {
        tableLabel = r['customer_name'].toString().trim();
      }

      transformed.add({
        'rawId': id,
        'id': shortId,
        'table': tableLabel,
        'type': typeLabel,
        'minutesAgo': minutesAgo,
        'stage': stage,
        'server': source == 'pos' ? 'Kaunter' : 'Pesanan Online',
        'items': itemsList,
        'notes': r['notes'] ?? '',
      });
    }

    if (mounted) {
      setState(() {
        _liveTickets = transformed;
        _isLoading = false;
      });
    }
  }

  Color _getTimerColor(int minutes) {
    if (minutes < 10) return const Color(0xFF10B981); // Green
    if (minutes < 20) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  Future<void> _progressTicket(Map<String, dynamic> ticket) async {
    final stage = ticket['stage'] as KdsStage;
    final isDemo = _useDemoData || ticket['rawId'].toString().startsWith('demo-');

    if (isDemo) {
      setState(() {
        if (stage == KdsStage.incoming) {
          ticket['stage'] = KdsStage.cooking;
          showGlassToast(context, 'Tiket ${ticket['id']} beralih ke Sedang Disediakan');
        } else if (stage == KdsStage.cooking) {
          ticket['stage'] = KdsStage.ready;
          showGlassToast(context, 'Tiket ${ticket['id']} ditandakan SIAP');
        } else if (stage == KdsStage.ready) {
          ticket['stage'] = KdsStage.served;
          _demoTickets.remove(ticket);
          showGlassToast(context, 'Tiket ${ticket['id']} selesai!');
        }
      });
      return;
    }

    final rawId = ticket['rawId']?.toString();
    if (rawId == null) return;

    if (stage == KdsStage.incoming) {
      final success = await _ordersService.updateOrderStatus(rawId, 'preparing');
      if (mounted && success) {
        showGlassToast(context, 'Tiket ${ticket['id']} sedang dimasak / disediakan');
      }
    } else if (stage == KdsStage.cooking) {
      final success = await _ordersService.updateOrderStatus(rawId, 'ready');
      if (mounted && success) {
        showGlassToast(context, 'Tiket ${ticket['id']} SIAP untuk diambil / dihidang');
      }
    } else if (stage == KdsStage.ready) {
      final success = await _ordersService.updateOrderStatus(rawId, 'completed');
      if (mounted && success) {
        showGlassToast(context, 'Tiket ${ticket['id']} selesai & dibersihkan dari papan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSource = _useDemoData ? _demoTickets : _liveTickets;

    final filteredTickets = activeSource.where((t) {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedTv01, color: Color(0xFFF9C80E), size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Live Order Board',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${filteredTickets.length}',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // Live / Demo Mode Badge
            GestureDetector(
              onTap: () {
                setState(() => _useDemoData = !_useDemoData);
                showGlassToast(
                  context,
                  _useDemoData ? 'Beralih ke Mod Demo Simulasi' : 'Beralih ke Data Pesanan Live',
                  color: _useDemoData ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _useDemoData
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                      : const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _useDemoData
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                        : const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _useDemoData ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _useDemoData ? 'Demo' : 'Live',
                      style: TextStyle(
                        color: _useDemoData ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white70),
            tooltip: 'Filter Tickets',
            color: const Color(0xFF1A1A2E),
            onSelected: (val) => setState(() => _filterType = val),
            itemBuilder: (context) => ['All', 'Dine-In', 'Takeaway'].map((type) {
              return PopupMenuItem(
                value: type,
                child: Text(type, style: TextStyle(color: _filterType == type ? const Color(0xFFF9C80E) : Colors.white)),
              );
            }).toList(),
          ),
          IconButton(
            icon: Icon(
              _soundEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: _soundEnabled ? const Color(0xFF44CF6C) : Colors.white38,
              size: 22,
            ),
            tooltip: 'Order Chime Alert',
            onPressed: () {
              setState(() => _soundEnabled = !_soundEnabled);
              if (_soundEnabled) {
                SoundService.instance.playOrderChime();
              }
              showGlassToast(context, _soundEnabled ? 'Order chime alert enabled' : 'Order chime muted');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF9C80E)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMultiColumn = constraints.maxWidth >= 900;

                if (activeSource.isEmpty) {
                  return _buildEmptyState();
                }

                if (isMultiColumn) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildColumn('NEW ORDERS', incomingTickets, const Color(0xFF42A5F5), KdsStage.incoming)),
                      const VerticalDivider(width: 1, color: Colors.white12),
                      Expanded(child: _buildColumn('IN PREPARATION', cookingTickets, const Color(0xFFF9C80E), KdsStage.cooking)),
                      const VerticalDivider(width: 1, color: Colors.white12),
                      Expanded(child: _buildColumn('READY FOR PICKUP', readyTickets, const Color(0xFF10B981), KdsStage.ready)),
                    ],
                  );
                } else {
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
                            Tab(text: 'Preparing (${cookingTickets.length})'),
                            Tab(text: 'Ready (${readyTickets.length})'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildColumn('NEW ORDERS', incomingTickets, const Color(0xFF42A5F5), KdsStage.incoming),
                              _buildColumn('IN PREPARATION', cookingTickets, const Color(0xFFF9C80E), KdsStage.cooking),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9C80E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF9C80E).withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTv01,
                color: Color(0xFFF9C80E),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tiada Pesanan Aktif di Dapur',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan pelanggan baharu dari kaunter atau dalam talian akan dipaparkan serta-merta di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C80E),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Muat Data Demo Simulasi', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() => _useDemoData = true);
                  },
                ),
              ],
            ),
          ],
        ),
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
    final timerColor = _getTimerColor((ticket['minutesAgo'] as int?) ?? 0);
    final items = (ticket['items'] as List<dynamic>?) ?? [];
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
                final isDone = item['done'] as bool? ?? false;
                final notes = item['notes'] as String? ?? '';
                final itemKey = item['key']?.toString();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      item['done'] = !isDone;
                      if (itemKey != null) {
                        if (!isDone) {
                          _checkedItemKeys.add(itemKey);
                        } else {
                          _checkedItemKeys.remove(itemKey);
                        }
                      }
                    });
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
                      ? 'Start Preparing'
                      : stage == KdsStage.cooking
                          ? 'Mark as Ready'
                          : 'Complete Order (Done)',
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
