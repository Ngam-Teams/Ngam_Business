import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/loyalty_service.dart';
import '../models/loyalty_model.dart';
import '../../../widgets/glass_toast.dart';

class LoyaltyStampsPage extends StatefulWidget {
  const LoyaltyStampsPage({super.key});

  @override
  State<LoyaltyStampsPage> createState() => _LoyaltyStampsPageState();
}

class _LoyaltyStampsPageState extends State<LoyaltyStampsPage> {
  final LoyaltyService _service = LoyaltyService();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  LoyaltyProgramModel? _program;
  List<CustomerLoyaltyCardModel> _cards = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'ready' | 'active'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final prog = await _service.fetchProgram();
    final cards = await _service.fetchCustomerCards();

    if (mounted) {
      setState(() {
        _program = prog;
        _cards = cards;
        _loading = false;
      });
    }
  }

  List<CustomerLoyaltyCardModel> get _filteredCards {
    if (_filter == 'ready') {
      return _cards.where((c) => c.isRewardReady).toList();
    }
    if (_filter == 'active') {
      return _cards.where((c) => !c.isRewardReady).toList();
    }
    return _cards;
  }

  Future<void> _chopStampQuick() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      showGlassToast(context, 'Sila masukkan nombor telefon pelanggan', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null;
    _phoneCtrl.clear();
    _nameCtrl.clear();

    try {
      final updated = await _service.chopStamp(
        customerPhone: phone,
        customerName: name,
      );

      await _loadData();

      if (!mounted) return;
      if (updated.isRewardReady) {
        showGlassToast(
          context,
          'Tahniah! ${updated.customerName} telah capai ${updated.totalStampsRequired} cop & layak tebus ganjaran!',
          customColor: const Color(0xFF10B981),
        );
      } else {
        showGlassToast(
          context,
          '1 Cop Berjaya Diberikan kepada ${updated.customerName}! (${updated.currentStamps}/${updated.totalStampsRequired})',
          customColor: const Color(0xFF42A5F5),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  Future<void> _redeemReward(CustomerLoyaltyCardModel card) async {
    try {
      await _service.redeemReward(card.id);
      await _loadData();
      if (!mounted) return;
      showGlassToast(
        context,
        'Ganjaran ${card.customerName} berjaya ditebus!',
        customColor: const Color(0xFF44CF6C),
      );
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    }
  }

  void _openProgramSettingsModal() {
    if (_program == null) return;
    final titleCtrl = TextEditingController(text: _program!.title);
    final rewardCtrl = TextEditingController(text: _program!.rewardTitle);
    final minSpendCtrl = TextEditingController(text: _program!.minSpendPerStamp.toStringAsFixed(2));
    int totalStamps = _program!.totalStamps;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white24)),
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
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tetapan Program Kad Cop Digital',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Kustomisasi tajuk, bilangan cop & ganjaran pelanggan',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    _buildField('Nama Program Kad Cop', titleCtrl),
                    const SizedBox(height: 12),

                    const Text(
                      'Jumlah Cop Untuk Tebus Ganjaran',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [5, 8, 10].map((count) {
                        final isSel = totalStamps == count;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$count Cop', style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                            selected: isSel,
                            selectedColor: const Color(0xFF42A5F5),
                            backgroundColor: const Color(0xFF1A1A2E),
                            side: BorderSide(color: isSel ? const Color(0xFF42A5F5) : Colors.white12),
                            onSelected: (val) {
                              if (val) setMState(() => totalStamps = count);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    _buildField('Ganjaran Bila Penuh Cop', rewardCtrl, hint: 'cth: Percuma 1x Haircut'),
                    const SizedBox(height: 12),
                    _buildField('Min. Belanja Bagi Setiap Cop (RM)', minSpendCtrl),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () async {
                          final updated = _program!.copyWith(
                            title: titleCtrl.text.trim(),
                            rewardTitle: rewardCtrl.text.trim(),
                            totalStamps: totalStamps,
                            minSpendPerStamp: double.tryParse(minSpendCtrl.text) ?? _program!.minSpendPerStamp,
                          );

                          await _service.saveProgram(updated);
                          setState(() => _program = updated);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) showGlassToast(context, 'Program Kad Cop dikemas kini');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan Tetapan Program', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kad Cop Digital (Loyalty)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Program kesetiaan & ganjaran pelanggan',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF42A5F5), size: 22),
            tooltip: 'Tetapan Program',
            onPressed: _openProgramSettingsModal,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Program Card
                  _buildProgramHero(),
                  const SizedBox(height: 16),

                  // Quick Chop Section
                  _buildQuickChopSection(),
                  const SizedBox(height: 20),

                  // Filter Chips
                  _buildFilterChips(),
                  const SizedBox(height: 14),

                  // Cards List
                  if (_filteredCards.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredCards.map(_buildCustomerCard),
                ],
              ),
            ),
    );
  }

  Widget _buildProgramHero() {
    if (_program == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.25),
            const Color(0xFF141424),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, color: Color(0xFFA5B4FC), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _program!.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'PROGRAM AKTIF',
                  style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kumpul ${_program!.totalStamps} Cop = ${_program!.rewardTitle}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min. Belanja: RM ${_program!.minSpendPerStamp.toStringAsFixed(2)} / cop',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '${_cards.length} Kad Dikeluarkan',
                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChopSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.touch_app_rounded, color: Color(0xFF42A5F5), size: 18),
              SizedBox(width: 8),
              Text(
                'Beri Cop Pelanggan di Kaunter',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'No. Telefon Pelanggan',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    prefixIcon: const Icon(Icons.phone_rounded, color: Colors.white38, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nama (Pilihan)',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _chopStampQuick,
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('+ Beri 1 Cop Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final readyCount = _cards.where((c) => c.isRewardReady).length;

    return Row(
      children: [
        _buildFilterChip('all', 'Semua (${_cards.length})'),
        const SizedBox(width: 8),
        _buildFilterChip('ready', 'Sedia Ditebus ($readyCount)', highlight: readyCount > 0),
        const SizedBox(width: 8),
        _buildFilterChip('active', 'Sedang Kumpul'),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, {bool highlight = false}) {
    final isSel = _filter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSel ? Colors.white : (highlight ? const Color(0xFF34D399) : Colors.white70),
          fontSize: 12,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSel,
      selectedColor: highlight ? const Color(0xFF10B981) : const Color(0xFF42A5F5),
      backgroundColor: const Color(0xFF141424),
      side: BorderSide(color: isSel ? Colors.transparent : (highlight ? const Color(0xFF10B981) : Colors.white12)),
      onSelected: (val) {
        if (val) setState(() => _filter = key);
      },
    );
  }

  Widget _buildCustomerCard(CustomerLoyaltyCardModel card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: card.isRewardReady
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: card.isRewardReady ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.customerName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    card.customerPhone,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              if (card.isRewardReady)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text(
                    '🎉 SEDIA DITEBUS',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                )
              else
                Text(
                  'Lagi ${card.stampsRemaining} cop',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Stamp Circles Row!
          _buildStampCirclesRow(card),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terakhir dicop: ${DateFormat("d MMM yyyy").format(card.lastStampedAt)} • Ditebus: ${card.totalRewardsRedeemed}x',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),

              if (card.isRewardReady)
                ElevatedButton.icon(
                  onPressed: () => _redeemReward(card),
                  icon: const Icon(Icons.redeem_rounded, size: 16),
                  label: const Text('Tebus Ganjaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    await _service.chopStamp(customerPhone: card.customerPhone);
                    await _loadData();
                    if (mounted) showGlassToast(context, '+1 Cop ditambahkan!');
                  },
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('+1 Cop', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    side: const BorderSide(color: Color(0xFF42A5F5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStampCirclesRow(CustomerLoyaltyCardModel card) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(card.totalStampsRequired, (index) {
        final isStamped = index < card.currentStamps;
        final isRewardSlot = index == card.totalStampsRequired - 1;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isStamped
                ? (isRewardSlot ? const Color(0xFFF59E0B) : const Color(0xFF42A5F5))
                : const Color(0xFF1A1A2E),
            shape: BoxShape.circle,
            border: Border.all(
              color: isStamped
                  ? Colors.white
                  : (isRewardSlot ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : Colors.white24),
              width: 1.5,
            ),
            boxShadow: isStamped
                ? [
                    BoxShadow(
                      color: (isRewardSlot ? const Color(0xFFF59E0B) : const Color(0xFF42A5F5))
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isStamped
                ? Icon(
                    isRewardSlot ? Icons.card_giftcard_rounded : Icons.check_rounded,
                    color: Colors.white,
                    size: 22,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isRewardSlot ? const Color(0xFFF59E0B) : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.stars_outlined, color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Tiada Kad Cop Pelanggan',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Gunakan borang di atas untuk beri cop pertama kepada pelanggan',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
