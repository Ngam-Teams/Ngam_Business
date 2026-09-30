import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// CustomerInsightsPage — Loyal Customers & VIP Tiers
// ============================================================

class CustomerInsightsPage extends StatefulWidget {
  const CustomerInsightsPage({super.key});

  @override
  State<CustomerInsightsPage> createState() => _CustomerInsightsPageState();
}

class _CustomerInsightsPageState extends State<CustomerInsightsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late List<Map<String, dynamic>> _customers;

  @override
  void initState() {
    super.initState();
    _customers = [
      {
        'id': 'CUST-01',
        'name': 'Danish Irfan',
        'phone': '+60 11-2345 6789',
        'visits': 18,
        'totalSpent': 740.00,
        'lastVisit': '3 days ago',
        'tier': 'Gold VIP',
      },
      {
        'id': 'CUST-02',
        'name': 'Haziq Aiman',
        'phone': '+60 17-9876 5432',
        'visits': 12,
        'totalSpent': 480.00,
        'lastVisit': '1 week ago',
        'tier': 'Silver VIP',
      },
      {
        'id': 'CUST-03',
        'name': 'Melissa Tan',
        'phone': '+60 12-3344 5566',
        'visits': 9,
        'totalSpent': 395.00,
        'lastVisit': '2 weeks ago',
        'tier': 'Silver VIP',
      },
      {
        'id': 'CUST-04',
        'name': 'Luqman Hakim',
        'phone': '+60 13-4455 6677',
        'visits': 5,
        'totalSpent': 175.00,
        'lastVisit': 'Yesterday',
        'tier': 'Regular',
      },
      {
        'id': 'CUST-05',
        'name': 'Suresh Kumar',
        'phone': '+60 14-8899 0011',
        'visits': 3,
        'totalSpent': 105.00,
        'lastVisit': '1 month ago',
        'tier': 'Regular',
      },
    ];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      final name = c['name'].toString().toLowerCase();
      final phone = c['phone'].toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  void _sendPerk(Map<String, dynamic> customer) {
    showGlassToast(context, 'Sent RM 10.00 VIP Reward Voucher to ${customer['name']}!');
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Gold VIP':
        return Colors.amber;
      case 'Silver VIP':
        return const Color(0xFF42A5F5);
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
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
                          'Customer Insights & VIPs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Track repeat visitors & reward loyal customers',
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

            // Top Stat Summary Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Customers', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          SizedBox(height: 4),
                          Text('142', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Repeat Rate', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          SizedBox(height: 4),
                          Text('68%', style: TextStyle(color: Color(0xFF44CF6C), fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avg. Spend', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          SizedBox(height: 4),
                          Text('RM 48', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search customer by name or phone...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // Customer List
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          const Text('No customers found', style: TextStyle(color: Colors.white70, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final cust = _filteredCustomers[index];
                        final tier = cust['tier'] as String;
                        final tierCol = _tierColor(tier);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: tierCol.withValues(alpha: 0.15),
                                    child: Icon(Icons.person, color: tierCol, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              cust['name'],
                                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: tierCol.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tier,
                                                style: TextStyle(color: tierCol, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cust['phone'],
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF42A5F5), size: 22),
                                    tooltip: 'Send VIP Reward Voucher',
                                    onPressed: () => _sendPerk(cust),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${cust['visits']} visits · RM ${(cust['totalSpent'] as double).toStringAsFixed(2)} spent',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Last: ${cust['lastVisit']}',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
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
