import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// CustomerReviewsPage — Manage & Reply to Customer Reviews
// ============================================================

class CustomerReviewsPage extends StatefulWidget {
  const CustomerReviewsPage({super.key});

  @override
  State<CustomerReviewsPage> createState() => _CustomerReviewsPageState();
}

class _CustomerReviewsPageState extends State<CustomerReviewsPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Needs Reply', '5 Stars', '1-3 Stars'];

  late List<Map<String, dynamic>> _reviews;
  final Map<String, TextEditingController> _replyControllers = {};
  final Set<String> _replyingIds = {};

  @override
  void initState() {
    super.initState();
    _reviews = [
      {
        'id': 'REV-201',
        'customerName': 'Farhan Akmal',
        'rating': 5,
        'date': '2 hours ago',
        'service': 'Premium Haircut',
        'comment': 'Best cut I had in months! The barber was very attentive and the shop vibes are modern and clean.',
        'merchantReply': 'Thank you so much Farhan! Glad you enjoyed the cut. See you next month!',
        'replyDate': '1 hour ago',
      },
      {
        'id': 'REV-200',
        'customerName': 'Amira Syuhada',
        'rating': 4,
        'date': 'Yesterday',
        'service': 'Facial Treatment',
        'comment': 'Very relaxing ambience. Staff was super polite. Waited about 10 mins past my slot though.',
        'merchantReply': null,
        'replyDate': null,
      },
      {
        'id': 'REV-199',
        'customerName': 'Kenneth Wong',
        'rating': 5,
        'date': '3 days ago',
        'service': 'Beard Grooming',
        'comment': 'Top notch service and sharp lines. Will definitely recommend to friends.',
        'merchantReply': 'Appreciate the kind words Kenneth! Cheers!',
        'replyDate': '2 days ago',
      },
      {
        'id': 'REV-198',
        'customerName': 'Hafizuddin',
        'rating': 3,
        'date': '5 days ago',
        'service': 'Hair Wash & Styling',
        'comment': 'Good service overall, but the waiting area was quite crowded during peak hour.',
        'merchantReply': null,
        'replyDate': null,
      },
    ];

    for (var r in _reviews) {
      _replyControllers[r['id']] = TextEditingController();
    }
    _loadLiveReviews();
  }

  Future<void> _loadLiveReviews() async {
    try {
      final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
      final businessId = profile?['id']?.toString();
      if (businessId == null || businessId.isEmpty) return;

      final orders = await Supabase.instance.client
          .from('orders')
          .select('id, customer_name, notes, created_at')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(100);

      final List<Map<String, dynamic>> liveRevs = [];
      for (final o in (orders as List)) {
        final notes = (o['notes'] ?? '').toString();
        final match = RegExp(r'\[ULASAN PELANGGAN:\s*(\d+)★\]\s*(.*)').firstMatch(notes);
        if (match != null) {
          final rating = int.tryParse(match.group(1) ?? '5') ?? 5;
          final comment = (match.group(2) ?? '').trim();
          final id = 'REV-${o['id'].toString().substring(0, 6)}';
          _replyControllers.putIfAbsent(id, () => TextEditingController());
          liveRevs.add({
            'id': id,
            'order_id': o['id'],
            'customerName': o['customer_name']?.toString() ?? 'Pelanggan Ngam',
            'rating': rating,
            'date': 'Pesanan Disahkan',
            'service': 'Pesanan Kedai',
            'comment': comment.isNotEmpty ? comment : 'Perkhidmatan terbaik!',
            'merchantReply': null,
            'replyDate': null,
          });
        }
      }

      if (liveRevs.isNotEmpty && mounted) {
        setState(() {
          _reviews = [...liveRevs, ..._reviews];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (var c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredReviews {
    if (_selectedFilterIndex == 0) return _reviews;
    if (_selectedFilterIndex == 1) {
      return _reviews.where((r) => r['merchantReply'] == null).toList();
    }
    if (_selectedFilterIndex == 2) {
      return _reviews.where((r) => r['rating'] == 5).toList();
    }
    return _reviews.where((r) => (r['rating'] as int) <= 3).toList();
  }

  void _submitReply(Map<String, dynamic> review) {
    final ctrl = _replyControllers[review['id']];
    final text = ctrl?.text.trim() ?? '';
    if (text.isEmpty) {
      showGlassToast(context, 'Please enter a reply', isError: true);
      return;
    }

    setState(() {
      review['merchantReply'] = text;
      review['replyDate'] = 'Just now';
      _replyingIds.remove(review['id']);
    });

    ctrl?.clear();
    showGlassToast(context, 'Reply published to customer!');
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'Customer Reviews',
      subtitle: 'Maklum balas & ulasan pelanggan',
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 68),
          ),
          // Rating Overview Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF42A5F5).withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '4.8',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          Icon(Icons.star_half_rounded, color: Colors.amber, size: 16),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '128 Total Customer Reviews',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '94% of customers gave 4 or 5 stars. Keep up the high standard of service!',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 8),
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: SizedBox(
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
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 14),
          ),

          // Reviews List
          if (_filteredReviews.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 14),
                    const Text('No reviews found in this category', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                        final rev = _filteredReviews[index];
                        final String id = rev['id'];
                        final bool hasReply = rev['merchantReply'] != null;
                        final bool isReplying = _replyingIds.contains(id);

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
                              // Customer row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                                    child: Text(
                                      (rev['customerName'] as String).substring(0, 1),
                                      style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rev['customerName'],
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${rev['service']} · ${rev['date']}',
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < (rev['rating'] as int) ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Text(
                                rev['comment'],
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              ),

                              // Merchant Reply if exists
                              if (hasReply) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.storefront_rounded, color: Color(0xFF42A5F5), size: 14),
                                              SizedBox(width: 6),
                                              Text(
                                                'Your Response (Owner)',
                                                style: TextStyle(
                                                  color: Color(0xFF42A5F5),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            rev['replyDate'] ?? '',
                                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        rev['merchantReply'],
                                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Reply Input / Action
                              if (!hasReply) ...[
                                const SizedBox(height: 12),
                                if (isReplying) ...[
                                  TextField(
                                    controller: _replyControllers[id],
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Write your friendly reply to customer...',
                                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => setState(() => _replyingIds.remove(id)),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF42A5F5),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _submitReply(rev),
                                        child: const Text('Send Reply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => setState(() => _replyingIds.add(id)),
                                      icon: const Icon(Icons.reply_rounded, color: Color(0xFF42A5F5), size: 16),
                                      label: const Text('Reply to Customer', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                  },
                  childCount: _filteredReviews.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
