import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// ============================================================
// MerchantInboxPage — Live Customer Chat & Reservation Support
// ============================================================

class MerchantInboxPage extends StatefulWidget {
  const MerchantInboxPage({super.key});

  @override
  State<MerchantInboxPage> createState() => _MerchantInboxPageState();
}

class _MerchantInboxPageState extends State<MerchantInboxPage> {
  int _selectedFilter = 0;
  static const List<String> _filterKeys = ['all', 'orders', 'bookings', 'support'];

  List<Map<String, dynamic>> _threads = [];
  Map<String, dynamic>? _activeThread;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  String? _businessId;
  String _businessName = 'Ngam Business';

  final TextEditingController _msgInputController = TextEditingController();

  static const List<String> _quickReplyKeys = [
    'inbox.quick_reply_1',
    'inbox.quick_reply_2',
    'inbox.quick_reply_3',
    'inbox.quick_reply_4',
    'inbox.quick_reply_5',
  ];

  @override
  void initState() {
    super.initState();
    _loadLiveThreads();
  }

  String _filterLabel(String key) {
    switch (key) {
      case 'orders':
        return 'inbox.filter_orders'.tr();
      case 'bookings':
        return 'inbox.filter_bookings'.tr();
      case 'support':
        return 'inbox.filter_support'.tr();
      default:
        return 'inbox.filter_all'.tr();
    }
  }

  String _formatTime(dynamic rawIso) {
    if (rawIso == null) return '';
    final dt = DateTime.tryParse(rawIso.toString())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  Future<void> _loadLiveThreads() async {
    try {
      final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
      final businessId = profile?['id']?.toString();
      if (businessId == null || businessId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _businessId = businessId;
      _businessName = (profile?['business_name'] ?? 'Ngam Business').toString();

      final res = await Future.wait([
        Supabase.instance.client
            .from('orders')
            .select('id, owner_user_id, customer_id, customer_name, notes, source, status, total, created_at')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(15),
        Supabase.instance.client
            .from('bookings')
            .select('id, customer_id, customer_name, service_name, booking_date, booking_time, status, booking_metadata, created_at')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(15),
      ]);

      final orderRows = (res[0] as List?) ?? [];
      final bookingRows = (res[1] as List?) ?? [];

      // Lookup customer contact info from public.users without failing if RLS blocks
      final Set<String> customerIds = {};
      for (final o in orderRows) {
        final cid = o['customer_id']?.toString().trim() ?? '';
        final oid = o['owner_user_id']?.toString().trim() ?? '';
        final src = (o['source'] ?? '').toString().toLowerCase();
        final effectiveUid = cid.isNotEmpty ? cid : (src != 'pos' ? oid : '');
        if (effectiveUid.isNotEmpty) customerIds.add(effectiveUid);
      }
      for (final b in bookingRows) {
        final cid = b['customer_id']?.toString().trim() ?? '';
        if (cid.isNotEmpty) customerIds.add(cid);
      }

      final Map<String, Map<String, dynamic>> usersMap = {};
      if (customerIds.isNotEmpty) {
        try {
          final usersRes = await Supabase.instance.client
              .from('users')
              .select('id, user_name, user_phone')
              .inFilter('id', customerIds.toList());
          for (final u in (usersRes as List? ?? [])) {
            final uid = u['id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              usersMap[uid] = Map<String, dynamic>.from(u as Map);
            }
          }
        } catch (_) {}
      }

      final liveThreads = <Map<String, dynamic>>[];

      for (final o in orderRows) {
        final idStr = o['id'].toString();
        final cid = o['customer_id']?.toString().trim() ?? '';
        final oid = o['owner_user_id']?.toString().trim() ?? '';
        final src = (o['source'] ?? '').toString().toLowerCase();
        final effectiveUid = cid.isNotEmpty ? cid : (src != 'pos' ? oid : '');
        final user = effectiveUid.isNotEmpty ? usersMap[effectiveUid] : null;
        final notes = (o['notes'] ?? '').toString().trim();
        final cust = (o['customer_name'] ?? user?['user_name'] ?? '').toString().trim();
        if (cust.isEmpty && notes.isEmpty) continue;

        final shortId = idStr.length > 6 ? idStr.substring(0, 6).toUpperCase() : idStr.toUpperCase();
        final phone = (user?['user_phone'] ?? '').toString().trim();
        final status = (o['status'] ?? 'pending').toString().toLowerCase();
        final timeStr = _formatTime(o['created_at']);
        final totalStr = ((o['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);

        liveThreads.add({
          'id': 'ORD-$shortId',
          'rawId': idStr,
          'businessId': businessId,
          'customerId': effectiveUid.isNotEmpty ? effectiveUid : null,
          'sourceType': 'order',
          'status': status,
          'customerName': cust.isNotEmpty ? cust : 'inbox.customer_fallback'.tr(args: [shortId]),
          'phone': phone,
          'filterKey': 'orders',
          'shortId': shortId,
          'totalStr': totalStr,
          'orderRef': 'inbox.order_ref'.tr(args: [shortId, totalStr]),
          'unread': status == 'pending' ? 1 : 0,
          'createdAt': o['created_at']?.toString() ?? '',
          'lastTime': timeStr,
          'messages': [
            {
              'from': 'customer',
              'text': notes.isNotEmpty ? notes : 'inbox.order_default_msg'.tr(args: [shortId]),
              'time': timeStr,
            },
          ],
        });
      }

      for (final b in bookingRows) {
        final status = (b['status'] ?? 'pending').toString().toLowerCase();
        if (status == 'holding') continue;

        final idStr = b['id'].toString();
        final cid = b['customer_id']?.toString().trim() ?? '';
        final user = cid.isNotEmpty ? usersMap[cid] : null;
        final meta = b['booking_metadata'] is Map
            ? Map<String, dynamic>.from(b['booking_metadata'] as Map)
            : <String, dynamic>{};
        final cust = (b['customer_name'] ?? meta['customer_name'] ?? user?['user_name'] ?? '').toString().trim();
        final svc = (b['service_name'] ?? '').toString().trim();
        final notes = (meta['notes'] ?? '').toString().trim();
        final fallbackCode = idStr.length >= 5 ? idStr.substring(0, 5).toUpperCase() : idStr.toUpperCase();
        final ref = (meta['booking_id'] ?? meta['short_ref'] ?? 'BK-$fallbackCode').toString();
        final phone = (meta['phone'] ?? meta['customer_phone'] ?? user?['user_phone'] ?? '').toString().trim();
        final dateStr = (b['booking_date'] ?? '').toString();
        final timeSlot = (b['booking_time'] ?? '').toString();
        final timeStr = _formatTime(b['created_at']);
        final displaySvc = svc.isNotEmpty ? svc : 'inbox.service_fallback'.tr();

        liveThreads.add({
          'id': 'BK-$ref',
          'rawId': idStr,
          'businessId': businessId,
          'customerId': cid.isNotEmpty ? cid : null,
          'sourceType': 'booking',
          'status': status,
          'customerName': cust.isNotEmpty ? cust : 'inbox.booking_customer_fallback'.tr(),
          'phone': phone,
          'filterKey': 'bookings',
          'orderRef': '$ref • $displaySvc ($dateStr)'.trim(),
          'unread': status == 'pending' ? 1 : 0,
          'createdAt': b['created_at']?.toString() ?? '',
          'lastTime': timeStr,
          'messages': [
            {
              'from': 'customer',
              'text': notes.isNotEmpty
                  ? notes
                  : 'inbox.booking_default_msg'.tr(args: [displaySvc, dateStr, timeSlot]),
              'time': timeStr,
            },
          ],
        });
      }

      liveThreads.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));

      if (mounted) {
        setState(() {
          _threads = liveThreads;
          _isLoading = false;
          if (_threads.isNotEmpty && _activeThread == null) {
            _activeThread = _threads.first;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredThreads {
    if (_selectedFilter == 0) return _threads;
    final targetKey = _filterKeys[_selectedFilter];
    return _threads.where((t) => t['filterKey'] == targetKey).toList();
  }

  @override
  void dispose() {
    _msgInputController.dispose();
    super.dispose();
  }

  Future<void> _callCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '').trim();
    if (clean.isEmpty) {
      if (mounted) showGlassToast(context, 'inbox.no_phone_number'.tr(), isError: true);
      return;
    }
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) showGlassToast(context, 'inbox.dialer_error'.tr(), isError: true);
    }
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _msgInputController.text.trim();
    if (text.isEmpty || _activeThread == null) return;

    final thread = _activeThread!;
    setState(() {
      final messages = thread['messages'] as List<dynamic>;
      messages.add({
        'from': 'merchant',
        'text': text,
        'timeKey': 'inbox.just_now',
      });
      thread['unread'] = 0;
    });

    if (quickText == null) {
      _msgInputController.clear();
    }

    // Best-effort push/in-app notification for logged-in Ngam app customers
    final customerId = thread['customerId']?.toString();
    final bizId = thread['businessId']?.toString() ?? _businessId;
    if (customerId != null && customerId.isNotEmpty && bizId != null) {
      try {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': customerId,
          'business_id': bizId,
          'title': 'inbox.reply_notif_title'.tr(args: [_businessName]),
          'message': text,
          'type': thread['sourceType'] == 'order' ? 'pesanan' : 'tempahan',
          'reference_id': thread['rawId']?.toString(),
          'is_read': false,
        });
      } catch (_) {}
    }
  }

  Future<void> _confirmThreadAction(Map<String, dynamic> thread) async {
    if (_isUpdatingStatus) return;
    final rawId = thread['rawId']?.toString() ?? '';
    final sourceType = thread['sourceType']?.toString() ?? '';
    if (rawId.isEmpty) return;

    setState(() => _isUpdatingStatus = true);
    try {
      final targetStatus = sourceType == 'booking' ? 'confirmed' : 'preparing';
      final table = sourceType == 'booking' ? 'bookings' : 'orders';

      await Supabase.instance.client
          .from(table)
          .update({'status': targetStatus})
          .eq('id', rawId);

      final customerId = thread['customerId']?.toString();
      final bizId = thread['businessId']?.toString() ?? _businessId;
      if (customerId != null && customerId.isNotEmpty && bizId != null) {
        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': customerId,
            'business_id': bizId,
            'title': 'inbox.reply_notif_title'.tr(args: [_businessName]),
            'message': sourceType == 'booking'
                ? 'inbox.booking_confirmed_toast'.tr()
                : 'inbox.order_preparing_toast'.tr(),
            'type': sourceType == 'booking' ? 'tempahan' : 'pesanan',
            'reference_id': rawId,
            'is_read': false,
          });
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          thread['status'] = targetStatus;
          thread['unread'] = 0;
        });
        showGlassToast(
          context,
          sourceType == 'booking'
              ? 'inbox.booking_confirmed_toast'.tr()
              : 'inbox.order_preparing_toast'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'inbox.status_update_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape || media.size.width > media.size.height;
    final isDesktop = media.size.width >= 768 || isLandscape;

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: _activeThread != null && !isDesktop ? (_activeThread!['customerName'] as String) : 'inbox.title'.tr(),
      subtitle: _activeThread != null && !isDesktop ? (_activeThread!['orderRef'] as String) : 'inbox.subtitle'.tr(),
      onBack: () {
        if (_activeThread != null && !isDesktop) {
          setState(() => _activeThread = null);
        } else {
          Navigator.pop(context);
        }
      },
      actionItems: [
        if (_activeThread != null)
          GlassNavPillItem(
            icon: Icons.phone_rounded,
            tooltip: 'inbox.call_customer'.tr(),
            onTap: () => _callCustomer((_activeThread!['phone'] ?? '').toString()),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.only(top: 68),
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Column(
            children: [
              _buildFilterChips(),
              Expanded(child: _buildThreadList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.white12),
        Expanded(
          child: _activeThread != null ? _buildChatDetail(_activeThread!) : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_activeThread != null) {
      return _buildChatDetail(_activeThread!);
    }
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(child: _buildThreadList()),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _filterKeys.length,
        itemBuilder: (ctx, idx) {
          final isSel = idx == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = idx),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF42A5F5) : const Color(0xFF141424),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? const Color(0xFF42A5F5) : Colors.white12),
              ),
              child: Center(
                child: Text(
                  _filterLabel(_filterKeys[idx]),
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThreadList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
      );
    }

    final list = _filteredThreads;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white24, size: 40),
              const SizedBox(height: 12),
              Text(
                'inbox.no_chats'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'inbox.no_messages_desc'.tr(),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final thread = list[idx];
        final isSel = _activeThread != null && _activeThread!['id'] == thread['id'];
        final unread = thread['unread'] as int;
        final messages = thread['messages'] as List<dynamic>;
        final lastMsg = messages.isNotEmpty ? messages.last['text'] as String : '';
        final custName = (thread['customerName'] as String).trim();
        final initial = custName.isNotEmpty ? custName.substring(0, 1).toUpperCase() : '?';
        final rawLastTime = (thread['lastTime'] ?? '').toString();
        final displayLastTime = rawLastTime.isNotEmpty ? rawLastTime : 'inbox.recent'.tr();

        return GestureDetector(
          onTap: () {
            setState(() {
              _activeThread = thread;
              thread['unread'] = 0;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF1E293B) : const Color(0xFF141424),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSel
                    ? const Color(0xFF42A5F5)
                    : (unread > 0
                        ? const Color(0xFF42A5F5).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              custName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            displayLastTime,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thread['orderRef'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFF9C80E), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread > 0 ? Colors.white : Colors.white60,
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF42A5F5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatDetail(Map<String, dynamic> thread) {
    final messages = thread['messages'] as List<dynamic>;
    final sourceType = (thread['sourceType'] ?? '').toString();
    final status = (thread['status'] ?? 'pending').toString().toLowerCase();
    final isAlreadyConfirmed = sourceType == 'booking'
        ? (status == 'confirmed' || status == 'completed' || status == 'serving')
        : (status == 'preparing' || status == 'ready' || status == 'completed');
    final actionLabel = sourceType == 'booking'
        ? (isAlreadyConfirmed ? 'inbox.slot_confirmed_badge'.tr() : 'inbox.confirm_slot'.tr())
        : (isAlreadyConfirmed ? 'inbox.order_preparing_badge'.tr() : 'inbox.confirm_order'.tr());

    return Column(
      children: [
        // Pinned context header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF42A5F5), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  thread['orderRef'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isAlreadyConfirmed ? Colors.white54 : const Color(0xFF44CF6C),
                  side: BorderSide(color: isAlreadyConfirmed ? Colors.white24 : const Color(0xFF44CF6C)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (isAlreadyConfirmed || _isUpdatingStatus)
                    ? null
                    : () => _confirmThreadAction(thread),
                icon: Icon(
                  isAlreadyConfirmed ? Icons.verified_rounded : Icons.check,
                  size: 14,
                ),
                label: Text(actionLabel, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        // Chat message bubbles
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (ctx, idx) {
              final msg = messages[idx] as Map<String, dynamic>;
              final isMerchant = msg['from'] == 'merchant';
              final msgTime = msg['timeKey'] != null
                  ? (msg['timeKey'] as String).tr()
                  : ((msg['time'] ?? '').toString().isNotEmpty
                      ? msg['time'].toString()
                      : 'inbox.recent'.tr());

              return Align(
                alignment: isMerchant ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isMerchant ? const Color(0xFF42A5F5) : const Color(0xFF1B1B2C),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMerchant ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMerchant ? Radius.zero : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMerchant ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['text'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msgTime,
                        style: TextStyle(
                          color: isMerchant ? Colors.white70 : Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Quick Reply Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickReplyKeys.length,
            itemBuilder: (ctx, idx) {
              final chipText = _quickReplyKeys[idx].tr();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(chipText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  backgroundColor: const Color(0xFF141424),
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onPressed: () => _sendMessage(chipText),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Text input bar
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedCamera01, color: Colors.white54, size: 20),
                onPressed: () => showGlassToast(context, 'inbox.photo_ready_toast'.tr()),
              ),
              Expanded(
                child: TextField(
                  controller: _msgInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'inbox.type_message'.tr(),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF42A5F5), size: 24),
                onPressed: () => _sendMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedChatting01, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text('inbox.select_conversation'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }
}
