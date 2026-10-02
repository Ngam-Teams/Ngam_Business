import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/glass_toast.dart';

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
  final List<String> _filters = ['All Messages', 'Order Inquiries', 'Bookings', 'Support'];

  late List<Map<String, dynamic>> _threads;
  Map<String, dynamic>? _activeThread;

  final TextEditingController _msgInputController = TextEditingController();

  final List<String> _quickReplies = [
    'Meja anda sudah sedia!',
    'Pesanan sedang disiapkan di dapur.',
    'Boleh, kami sediakan kerusi bayi.',
    'Ada tempat letak kereta percuma di belakang.',
    'Terima kasih, jumpa sebentar lagi!',
  ];

  @override
  void initState() {
    super.initState();
    _threads = [
      {
        'id': 'TH-01',
        'customerName': 'Amirul Hakim',
        'phone': '+60 17-234 5678',
        'type': 'Bookings',
        'orderRef': 'Booking #BK-1082 (Today, 2:30 PM)',
        'unread': 2,
        'lastTime': '2m ago',
        'messages': [
          {'from': 'customer', 'text': 'Salam bos, saya dah buat tempahan untuk 2:30 petang ni.', 'time': '2:15 PM'},
          {'from': 'customer', 'text': 'Boleh request meja dekat tingkap tak?', 'time': '2:16 PM'},
        ],
      },
      {
        'id': 'TH-02',
        'customerName': 'Nurul Huda',
        'phone': '+60 19-876 5432',
        'type': 'Order Inquiries',
        'orderRef': 'Table #04 (Dine-in Order #NG-4029)',
        'unread': 0,
        'lastTime': '15m ago',
        'messages': [
          {'from': 'customer', 'text': 'Nasi lemak rendang tu pedas sangat ke?', 'time': '12:20 PM'},
          {'from': 'merchant', 'text': 'Pedas sedap sederhana kak, sambal manis pedas ala Melaka!', 'time': '12:22 PM'},
          {'from': 'customer', 'text': 'Baik terima kasih, dah submit order guna QR.', 'time': '12:25 PM'},
        ],
      },
      {
        'id': 'TH-03',
        'customerName': 'Jason Tan',
        'phone': '+60 12-334 1122',
        'type': 'Support',
        'orderRef': 'Takeaway #NG-4015',
        'unread': 0,
        'lastTime': '1h ago',
        'messages': [
          {'from': 'customer', 'text': 'Hi, is parking available nearby?', 'time': '11:00 AM'},
          {'from': 'merchant', 'text': 'Yes Jason, free parking available at the back alley!', 'time': '11:02 AM'},
          {'from': 'customer', 'text': 'Awesome, on my way now.', 'time': '11:05 AM'},
        ],
      },
      {
        'id': 'TH-04',
        'customerName': 'Siti Khadijah',
        'phone': '+60 13-909 8811',
        'type': 'Bookings',
        'orderRef': 'Family Dinner (Tomorrow, 8:00 PM)',
        'unread': 0,
        'lastTime': '3h ago',
        'messages': [
          {'from': 'customer', 'text': 'Hai, esok boleh sediakan 2 baby chair untuk meja kami?', 'time': '09:30 AM'},
          {'from': 'merchant', 'text': 'Boleh puan, kami dah reserve siap-siap!', 'time': '09:32 AM'},
        ],
      },
    ];

    // Default to first thread
    _activeThread = _threads.first;
  }

  @override
  void dispose() {
    _msgInputController.dispose();
    super.dispose();
  }

  void _callCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) showGlassToast(context, 'Could not open phone dialer', isError: true);
    }
  }

  void _sendMessage([String? quickText]) {
    final text = quickText ?? _msgInputController.text.trim();
    if (text.isEmpty || _activeThread == null) return;

    setState(() {
      final messages = _activeThread!['messages'] as List<dynamic>;
      messages.add({
        'from': 'merchant',
        'text': text,
        'time': 'Just now',
      });
      _activeThread!['unread'] = 0;
    });

    if (quickText == null) {
      _msgInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (_activeThread != null && !isDesktop) {
              setState(() => _activeThread = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeThread != null && !isDesktop ? (_activeThread!['customerName'] as String) : 'Customer Inbox',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _activeThread != null && !isDesktop ? (_activeThread!['orderRef'] as String) : 'Customer inquiries & chat',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_activeThread != null)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: Color(0xFF44CF6C), size: 22),
              onPressed: () => _callCustomer(_activeThread!['phone'] as String),
            ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
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
        itemCount: _filters.length,
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
                  _filters[idx],
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _threads.length,
      itemBuilder: (ctx, idx) {
        final thread = _threads[idx];
        final isSel = _activeThread != null && _activeThread!['id'] == thread['id'];
        final unread = thread['unread'] as int;
        final messages = thread['messages'] as List<dynamic>;
        final lastMsg = messages.isNotEmpty ? messages.last['text'] as String : '';

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
                color: isSel ? const Color(0xFF42A5F5) : (unread > 0 ? const Color(0xFF42A5F5).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  child: Text(
                    (thread['customerName'] as String).substring(0, 1),
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
                          Text(
                            thread['customerName'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            thread['lastTime'] as String,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thread['orderRef'] as String,
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
                  foregroundColor: const Color(0xFF44CF6C),
                  side: const BorderSide(color: Color(0xFF44CF6C)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => showGlassToast(context, 'Customer reservation marked active'),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Confirm Slot', style: TextStyle(fontSize: 11)),
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
              final msg = messages[idx];
              final isMerchant = msg['from'] == 'merchant';

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
                        msg['time'] as String,
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
            itemCount: _quickReplies.length,
            itemBuilder: (ctx, idx) {
              final chip = _quickReplies[idx];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(chip, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  backgroundColor: const Color(0xFF141424),
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onPressed: () => _sendMessage(chip),
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
                onPressed: () => showGlassToast(context, 'Photo attachment ready to upload'),
              ),
              Expanded(
                child: TextField(
                  controller: _msgInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type reply to customer...',
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedChatting01, color: Colors.white24, size: 48),
          SizedBox(height: 16),
          Text('Select a conversation to start chatting', style: TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }
}
