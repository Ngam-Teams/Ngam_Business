import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// PromotionsPage — Manage Discount Vouchers & Marketing Promos
// ============================================================

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Active', 'Scheduled', 'Expired'];

  late List<Map<String, dynamic>> _vouchers;

  @override
  void initState() {
    super.initState();
    _vouchers = [
      {
        'id': 'V-01',
        'code': 'NGAM10',
        'title': '10% Storewide Welcome Discount',
        'discount': '10% OFF',
        'minSpend': 20.00,
        'usedCount': 42,
        'maxUses': 100,
        'expiry': '31 Dec 2026',
        'isActive': true,
      },
      {
        'id': 'V-02',
        'code': 'WELCOME5',
        'title': 'RM 5.00 Off First Service',
        'discount': 'RM 5.00 OFF',
        'minSpend': 35.00,
        'usedCount': 18,
        'maxUses': 50,
        'expiry': '15 Nov 2026',
        'isActive': true,
      },
      {
        'id': 'V-03',
        'code': 'MERDEKA67',
        'title': 'Merdeka Special Deal',
        'discount': '15% OFF',
        'minSpend': 50.00,
        'usedCount': 50,
        'maxUses': 50,
        'expiry': '31 Aug 2026',
        'isActive': false,
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredVouchers {
    if (_selectedFilterIndex == 0) {
      return _vouchers.where((v) => v['isActive'] == true).toList();
    } else if (_selectedFilterIndex == 1) {
      return [];
    } else {
      return _vouchers.where((v) => v['isActive'] == false).toList();
    }
  }

  void _openCreateVoucherModal() {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '10');
    final minSpendCtrl = TextEditingController(text: '20');

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
              'Create New Promo Voucher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Promo Code (e.g. FLASH20)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Discount %',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minSpendCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Min Spend (RM)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
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
                  final code = codeCtrl.text.trim().toUpperCase();
                  if (code.isEmpty) {
                    showGlassToast(context, 'Please enter a code name', isError: true);
                    return;
                  }
                  setState(() {
                    _vouchers.insert(0, {
                      'id': 'V-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      'code': code,
                      'title': '$code Special Promo',
                      'discount': '${discountCtrl.text.trim()}% OFF',
                      'minSpend': double.tryParse(minSpendCtrl.text.trim()) ?? 0.0,
                      'usedCount': 0,
                      'maxUses': 100,
                      'expiry': '30 Days From Now',
                      'isActive': true,
                    });
                  });
                  Navigator.pop(ctx);
                  showGlassToast(context, 'Voucher "$code" created successfully!');
                },
                child: const Text('Launch Voucher Campaign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        onPressed: _openCreateVoucherModal,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          'Promotions & Vouchers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Create discount codes for customer checkout',
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

            // Vouchers List
            Expanded(
              child: _filteredVouchers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_offer_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          const Text('No vouchers in this category', style: TextStyle(color: Colors.white70, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: _filteredVouchers.length,
                      itemBuilder: (context, index) {
                        final v = _filteredVouchers[index];
                        final bool active = v['isActive'] as bool;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFF42A5F5).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Promo Code Pill
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: v['code']));
                                      showGlassToast(context, 'Copied "${v['code']}" to clipboard!');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.copy_rounded, color: Color(0xFF42A5F5), size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            v['code'],
                                            style: const TextStyle(
                                              color: Color(0xFF42A5F5),
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Active Switch
                                  Switch(
                                    value: active,
                                    activeColor: const Color(0xFF42A5F5),
                                    onChanged: (val) {
                                      setState(() {
                                        v['isActive'] = val;
                                      });
                                      showGlassToast(context, val ? 'Voucher activated' : 'Voucher paused');
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Text(
                                v['title'],
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${v['discount']} · Min spend RM ${(v['minSpend'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFF44CF6C), fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),

                              // Progress Bar of usages
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Claimed: ${v['usedCount']} / ${v['maxUses']}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  Text(
                                    'Expires: ${v['expiry']}',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (v['usedCount'] as int) / (v['maxUses'] as int),
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
                                ),
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
