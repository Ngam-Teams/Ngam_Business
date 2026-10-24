import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../widgets/glass_toast.dart';
import '../models/voucher_model.dart';
import '../data/voucher_service.dart';

// =============================================================================
// PromotionsPage — Pusat Kawalan E-Commerce Vouchers & Promotions
// =============================================================================

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final VoucherService _voucherService = VoucherService();
  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

  int _selectedFilterIndex = 0;
  final List<String> _filters = [
    'Semua',
    'Aktif',
    'Akan Datang',
    'Tamat / Habis',
    'Dinyahaktifkan',
  ];

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<VoucherModel> _vouchers = [];
  VoucherStats _stats = const VoucherStats();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vouchers = await _voucherService.fetchVouchers();
      final stats = await _voucherService.getVoucherStats();

      if (mounted) {
        setState(() {
          _vouchers = vouchers;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<VoucherModel> get _filteredVouchers {
    return _vouchers.where((v) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final matchesCode = v.code.toLowerCase().contains(_searchQuery);
        final matchesTitle = v.title.toLowerCase().contains(_searchQuery);
        if (!matchesCode && !matchesTitle) return false;
      }

      // 2. Filter Status
      switch (_selectedFilterIndex) {
        case 1: // Aktif
          return v.isCurrentlyValid;
        case 2: // Akan Datang
          return v.isActive && v.isScheduled;
        case 3: // Tamat / Habis
          return v.isExpired || v.isFullyRedeemed;
        case 4: // Dinyahaktifkan
          return !v.isActive;
        case 0: // Semua
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _toggleVoucher(VoucherModel voucher, bool newVal) async {
    final oldState = voucher.isActive;
    setState(() {
      final idx = _vouchers.indexWhere((item) => item.id == voucher.id);
      if (idx != -1) {
        _vouchers[idx] = voucher.copyWith(isActive: newVal);
      }
    });

    try {
      await _voucherService.toggleVoucherStatus(voucher.id, newVal, voucher.code);
      if (!mounted) return;
      showGlassToast(
        context,
        newVal ? 'Baucar "${voucher.code}" diaktifkan' : 'Baucar "${voucher.code}" dijeda / dinyahaktifkan',
        customColor: newVal ? const Color(0xFF44CF6C) : const Color(0xFFFFA726),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final idx = _vouchers.indexWhere((item) => item.id == voucher.id);
        if (idx != -1) {
          _vouchers[idx] = voucher.copyWith(isActive: oldState);
        }
      });
      showGlassToast(context, 'Gagal mengemaskini status: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(VoucherModel voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text(
          'Padam Baucar Promosi?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Adakah anda pasti ingin memadam baucar "${voucher.code}"? '
          'Tindakan ini kekal dan tidak boleh diundur.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Padam Baucar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _voucherService.deleteVoucher(voucher.id, voucher.code);
        if (!mounted) return;
        showGlassToast(context, 'Baucar "${voucher.code}" berjaya dipadam.');
        _loadData();
      } catch (e) {
        if (!mounted) return;
        showGlassToast(context, 'Gagal memadam baucar: $e', isError: true);
      }
    }
  }

  void _openVoucherEditor({VoucherModel? initialVoucher}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoucherEditorModal(
        initialVoucher: initialVoucher,
        onSaved: () {
          _loadData();
        },
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
        elevation: 6,
        onPressed: () => _openVoucherEditor(),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Cipta Baucar Baru',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF141722),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
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
                              'Baucar & Promosi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pengurusan kod diskaun standard e-commerce',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                        tooltip: 'Muat Semula',
                      ),
                    ],
                  ),
                ),
              ),

              // Metrics Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: _buildMetricsBar(),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari mengikut kod atau tajuk baucar...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
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
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF42A5F5)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF42A5F5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _filters[idx],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // Vouchers List
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Ralat memuatkan baucar:\n$_errorMessage',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5)),
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Cuba Semula'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_filteredVouchers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.confirmation_num_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tiada baucar sepadan dengan "$_searchQuery"'
                              : 'Tiada baucar dalam kategori ini',
                          style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cipta kod promosi untuk menarik lebih ramai pelanggan',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF42A5F5),
                            side: const BorderSide(color: Color(0xFF42A5F5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openVoucherEditor(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Cipta Baucar Pertama'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final voucher = _filteredVouchers[index];
                        return _buildVoucherTicketCard(voucher);
                      },
                      childCount: _filteredVouchers.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Baucar Aktif',
            value: '${_stats.activeCount}',
            color: const Color(0xFF44CF6C),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Penebusan',
            value: '${_stats.totalRedemptions}',
            color: const Color(0xFF42A5F5),
            icon: Icons.bolt_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Jimat Pelanggan',
            value: _currencyFmt.format(_stats.totalDiscountGiven),
            color: const Color(0xFF8B5CF6),
            icon: Icons.savings_outlined,
            isCurrency: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    bool isCurrency = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCurrency ? 13 : 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherTicketCard(VoucherModel voucher) {
    final statusColor = voucher.isCurrentlyValid
        ? const Color(0xFF44CF6C)
        : voucher.isScheduled
            ? const Color(0xFFFFA726)
            : voucher.isExpired || voucher.isFullyRedeemed
                ? const Color(0xFFEF5350)
                : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: voucher.isCurrentlyValid
              ? const Color(0xFF42A5F5).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Ticket Notch & Discount Stub
              Container(
                width: 86,
                decoration: BoxDecoration(
                  color: voucher.isPercentage
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.12)
                      : const Color(0xFF44CF6C).withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      voucher.isPercentage ? Icons.percent_rounded : Icons.monetization_on_outlined,
                      size: 20,
                      color: voucher.isPercentage ? const Color(0xFF42A5F5) : const Color(0xFF44CF6C),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      voucher.shortDiscountBadge,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: voucher.isPercentage ? const Color(0xFF42A5F5) : const Color(0xFF44CF6C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'POTONGAN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Right Ticket Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Code Chip + Status + Switch
                      Row(
                        children: [
                          // Copyable Code Chip
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: voucher.code));
                              showGlassToast(context, 'Kod "${voucher.code}" disalin!');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, color: Color(0xFF42A5F5), size: 12),
                                  const SizedBox(width: 5),
                                  Text(
                                    voucher.code,
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              voucher.statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Quick Toggle Switch
                          SizedBox(
                            height: 28,
                            child: Switch(
                              value: voucher.isActive,
                              activeColor: const Color(0xFF42A5F5),
                              onChanged: (val) => _toggleVoucher(voucher, val),
                            ),
                          ),

                          // More Popup
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
                            color: const Color(0xFF1E2230),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openVoucherEditor(initialVoucher: voucher);
                              } else if (val == 'delete') {
                                _confirmDelete(voucher);
                              } else if (val == 'copy') {
                                Clipboard.setData(ClipboardData(text: voucher.code));
                                showGlassToast(context, 'Kod "${voucher.code}" disalin!');
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                                    SizedBox(width: 10),
                                    Text('Salin Kod', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                                    SizedBox(width: 10),
                                    Text('Sunting Baucar', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 16),
                                    SizedBox(width: 10),
                                    Text('Padam', style: TextStyle(color: Color(0xFFEF5350), fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Title
                      Text(
                        voucher.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Full Discount Description & Conditions
                      Text(
                        '${voucher.formattedDiscount} · ${voucher.formattedMinSpend}',
                        style: const TextStyle(
                          color: Color(0xFF44CF6C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tags: Eligibility & Validity
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildTagChip(
                            icon: Icons.people_outline_rounded,
                            label: voucher.formattedEligibility,
                          ),
                          _buildTagChip(
                            icon: Icons.calendar_today_rounded,
                            label: voucher.formattedValidity,
                          ),
                          if (voucher.usageLimitPerUser > 1)
                            _buildTagChip(
                              icon: Icons.repeat_rounded,
                              label: 'Maks ${voucher.usageLimitPerUser}x / pelanggan',
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Quota Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            voucher.totalUsageLimit != null
                                ? 'Ditebus: ${voucher.timesUsed} / ${voucher.totalUsageLimit}'
                                : 'Ditebus: ${voucher.timesUsed} kali (Tanpa had kuota)',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          if (voucher.totalUsageLimit != null)
                            Text(
                              '${((voucher.quotaProgress) * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      if (voucher.totalUsageLimit != null) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: voucher.quotaProgress,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              voucher.isFullyRedeemed ? const Color(0xFFEF5350) : const Color(0xFF42A5F5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Comprehensive E-Commerce Voucher Editor Modal (Create / Edit)
// =============================================================================

class _VoucherEditorModal extends StatefulWidget {
  final VoucherModel? initialVoucher;
  final VoidCallback onSaved;

  const _VoucherEditorModal({
    this.initialVoucher,
    required this.onSaved,
  });

  @override
  State<_VoucherEditorModal> createState() => _VoucherEditorModalState();
}

class _VoucherEditorModalState extends State<_VoucherEditorModal> {
  final _formKey = GlobalKey<FormState>();
  final VoucherService _voucherService = VoucherService();

  late TextEditingController _codeCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _discountValCtrl;
  late TextEditingController _maxCapCtrl;
  late TextEditingController _minSpendCtrl;
  late TextEditingController _totalQuotaCtrl;
  late TextEditingController _limitPerUserCtrl;

  String _discountType = 'percentage'; // 'percentage' | 'fixed_amount'
  bool _hasMaxCap = false;
  bool _hasTotalQuota = false;
  bool _hasExpiry = true;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now().add(const Duration(days: 30));
  String _customerEligibility = 'all'; // 'all' | 'new_customers' | 'members_only'
  bool _isActive = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initialVoucher;
    _codeCtrl = TextEditingController(text: v?.code ?? _generateAutoCode());
    _titleCtrl = TextEditingController(text: v?.title ?? '');
    _descriptionCtrl = TextEditingController(text: v?.description ?? '');
    _discountValCtrl = TextEditingController(
      text: v != null ? (v.discountValue % 1 == 0 ? v.discountValue.toInt().toString() : v.discountValue.toString()) : '10',
    );
    _maxCapCtrl = TextEditingController(
      text: v?.maxDiscountAmount != null ? v!.maxDiscountAmount!.toStringAsFixed(2) : '15.00',
    );
    _minSpendCtrl = TextEditingController(
      text: v != null ? v.minSpend.toStringAsFixed(2) : '0.00',
    );
    _totalQuotaCtrl = TextEditingController(
      text: v?.totalUsageLimit != null ? v!.totalUsageLimit.toString() : '100',
    );
    _limitPerUserCtrl = TextEditingController(
      text: v != null ? v.usageLimitPerUser.toString() : '1',
    );

    if (v != null) {
      _discountType = v.discountType;
      _hasMaxCap = v.maxDiscountAmount != null && v.maxDiscountAmount! > 0;
      _hasTotalQuota = v.totalUsageLimit != null;
      _hasExpiry = v.endDate != null;
      _startDate = v.startDate;
      _endDate = v.endDate;
      _customerEligibility = v.customerEligibility;
      _isActive = v.isActive;
    }

    _discountValCtrl.addListener(() => setState(() {}));
    _codeCtrl.addListener(() => setState(() {}));
    _titleCtrl.addListener(() => setState(() {}));
    _minSpendCtrl.addListener(() => setState(() {}));
    _maxCapCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _discountValCtrl.dispose();
    _maxCapCtrl.dispose();
    _minSpendCtrl.dispose();
    _totalQuotaCtrl.dispose();
    _limitPerUserCtrl.dispose();
    super.dispose();
  }

  String _generateAutoCode() {
    const prefixes = ['SAVE', 'NGAM', 'DEAL', 'MEGA', 'SUPER', 'DISKAUN', 'SPECIAL'];
    final prefix = prefixes[Random().nextInt(prefixes.length)];
    final num = (Random().nextInt(8) + 2) * 5; // 10, 15, 20, 25, 30...
    return '$prefix$num';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF42A5F5),
              surface: Color(0xFF141722),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeCtrl.text.trim().toUpperCase();
    final title = _titleCtrl.text.trim().isEmpty ? '$code Special' : _titleCtrl.text.trim();
    final discountVal = double.tryParse(_discountValCtrl.text.trim()) ?? 0.0;
    final minSpend = double.tryParse(_minSpendCtrl.text.trim()) ?? 0.0;
    final maxCap = (_discountType == 'percentage' && _hasMaxCap)
        ? double.tryParse(_maxCapCtrl.text.trim())
        : null;
    final totalQuota = _hasTotalQuota ? int.tryParse(_totalQuotaCtrl.text.trim()) : null;
    final limitPerUser = int.tryParse(_limitPerUserCtrl.text.trim()) ?? 1;

    setState(() => _isSaving = true);

    try {
      if (widget.initialVoucher == null) {
        await _voucherService.createVoucher(
          code: code,
          title: title,
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          discountType: _discountType,
          discountValue: discountVal,
          maxDiscountAmount: maxCap,
          minSpend: minSpend,
          totalUsageLimit: totalQuota,
          usageLimitPerUser: limitPerUser,
          startDate: _startDate,
          endDate: _hasExpiry ? _endDate : null,
          customerEligibility: _customerEligibility,
          isActive: _isActive,
        );
        if (!mounted) return;
        showGlassToast(context, 'Baucar "$code" berjaya dicipta!');
      } else {
        await _voucherService.updateVoucher(widget.initialVoucher!.id, {
          'code': code,
          'title': title,
          'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          'discount_type': _discountType,
          'discount_value': discountVal,
          'max_discount_amount': maxCap,
          'min_spend': minSpend,
          'total_usage_limit': totalQuota,
          'usage_limit_per_user': limitPerUser,
          'start_date': _startDate.toUtc().toIso8601String(),
          'end_date': _hasExpiry && _endDate != null ? _endDate!.toUtc().toIso8601String() : null,
          'customer_eligibility': _customerEligibility,
          'is_active': _isActive,
        });
        if (!mounted) return;
        showGlassToast(context, 'Baucar "$code" berjaya dikemaskini!');
      }

      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final errStr = e.toString();
      String friendlyMsg = 'Ralat: $errStr';
      if (errStr.contains('42501') || errStr.contains('permission denied')) {
        friendlyMsg = 'Ralat 42501: Kebenaran terhad pada pangkalan data Supabase. Sila jalankan skrip "fix_vouchers_permissions.sql" di Supabase SQL Editor.';
      }
      showGlassToast(context, friendlyMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initialVoucher != null;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF10131E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Sunting Baucar Promosi' : 'Cipta Baucar Standard E-Commerce',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Konfigurasi jenis diskaun, had siling, kuota & kelayakan',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 16),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIVE PREVIEW CARD
                    _buildLivePreviewCard(),

                    const SizedBox(height: 22),

                    // SECTION 1: KOD & TAJUK
                    _buildSectionHeader('1. Maklumat Baucar', Icons.label_outline_rounded),
                    const SizedBox(height: 12),

                    // Code with auto generator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Kod Baucar (cth: RAYA20)',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF42A5F5), size: 18),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Kod baucar wajib diisi';
                              if (val.trim().length < 3) return 'Minimum 3 aksara';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            foregroundColor: const Color(0xFF42A5F5),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _codeCtrl.text = _generateAutoCode();
                            });
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Jana Kod', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Nama / Tajuk Promosi (cth: Diskaun Khas Hujung Minggu)',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Tajuk baucar diperlukan';
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    // SECTION 2: PERATURAN DISKAUN
                    _buildSectionHeader('2. Peraturan & Nilai Diskaun', Icons.percent_rounded),
                    const SizedBox(height: 12),

                    // Toggle Percentage vs Fixed
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _discountType = 'percentage'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _discountType == 'percentage'
                                    ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _discountType == 'percentage'
                                      ? const Color(0xFF42A5F5)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.percent_rounded,
                                    size: 16,
                                    color: _discountType == 'percentage' ? const Color(0xFF42A5F5) : Colors.white54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Peratusan (%)',
                                    style: TextStyle(
                                      color: _discountType == 'percentage' ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _discountType = 'fixed_amount'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _discountType == 'fixed_amount'
                                    ? const Color(0xFF44CF6C).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _discountType == 'fixed_amount'
                                      ? const Color(0xFF44CF6C)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.monetization_on_outlined,
                                    size: 16,
                                    color: _discountType == 'fixed_amount' ? const Color(0xFF44CF6C) : Colors.white54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Jumlah Tetap (RM)',
                                    style: TextStyle(
                                      color: _discountType == 'fixed_amount' ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Discount value and Min Spend in Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountValCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: _discountType == 'percentage' ? 'Nilai Diskaun (%)' : 'Potongan (RM)',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              prefixText: _discountType == 'fixed_amount' ? 'RM ' : null,
                              suffixText: _discountType == 'percentage' ? '%' : null,
                              prefixStyle: const TextStyle(color: Color(0xFF44CF6C), fontWeight: FontWeight.bold),
                              suffixStyle: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              final num = double.tryParse(val ?? '');
                              if (num == null || num <= 0) return 'Masukkan nilai > 0';
                              if (_discountType == 'percentage' && num > 100) return 'Maksimum 100%';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minSpendCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Belanja Min. (RM)',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              prefixText: 'RM ',
                              prefixStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              final num = double.tryParse(val ?? '');
                              if (num == null || num < 0) return 'Nilai tidak sah';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // Max Discount Capping (Percentage only)
                    if (_discountType == 'percentage') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Had Siling Diskaun (Max Cap)',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Cth: 10% diskaun tetapi dihadkan maks RM 15.00',
                                        style: TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _hasMaxCap,
                                  activeColor: const Color(0xFF42A5F5),
                                  onChanged: (val) => setState(() => _hasMaxCap = val),
                                ),
                              ],
                            ),
                            if (_hasMaxCap) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _maxCapCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Had Diskaun Maksimum (RM)',
                                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                  prefixText: 'RM ',
                                  prefixStyle: const TextStyle(color: Color(0xFF42A5F5)),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.04),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // SECTION 3: HAD PENGGUNAAN & KUOTA
                    _buildSectionHeader('3. Had Penebusan & Kuota', Icons.tune_rounded),
                    const SizedBox(height: 12),

                    // Total Quota limit
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hadkan Jumlah Kuota Keseluruhan',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Bila kuota habis, baucar ditutup secara automatik',
                                      style: TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _hasTotalQuota,
                                activeColor: const Color(0xFF42A5F5),
                                onChanged: (val) => setState(() => _hasTotalQuota = val),
                              ),
                            ],
                          ),
                          if (_hasTotalQuota) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _totalQuotaCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Jumlah Kuota Penebusan (cth: 100 unit)',
                                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                suffixText: 'unit',
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Per-User Limit
                    TextFormField(
                      controller: _limitPerUserCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Had Penebusan Setiap Pelanggan (cth: 1 kali guna)',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        suffixText: 'kali / pelanggan',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (val) {
                        final num = int.tryParse(val ?? '');
                        if (num == null || num < 1) return 'Sekurang-kurangnya 1 kali';
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    // SECTION 4: TEMPOH SAH
                    _buildSectionHeader('4. Tempoh Sah Kempen', Icons.calendar_month_outlined),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(isStart: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tarikh Mula', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('d MMM yyyy').format(_startDate),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _hasExpiry ? () => _pickDate(isStart: false) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: _hasExpiry ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tarikh Luput', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _hasExpiry && _endDate != null
                                        ? DateFormat('d MMM yyyy').format(_endDate!)
                                        : 'Tiada Luput',
                                    style: TextStyle(
                                      color: _hasExpiry ? Colors.white : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tetapkan Tarikh Luput Kempen',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Switch(
                          value: _hasExpiry,
                          activeColor: const Color(0xFF42A5F5),
                          onChanged: (val) {
                            setState(() {
                              _hasExpiry = val;
                              if (val && _endDate == null) {
                                _endDate = _startDate.add(const Duration(days: 30));
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // SECTION 5: KELAYAKAN SASARAN
                    _buildSectionHeader('5. Kelayakan Sasaran Pelanggan', Icons.group_outlined),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChoiceChip('Semua Pelanggan', 'all'),
                        _buildChoiceChip('Pelanggan Baru', 'new_customers'),
                        _buildChoiceChip('Ahli Sahaja', 'members_only'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Active Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aktifkan Baucar Serta-Merta',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isActive,
                          activeColor: const Color(0xFF44CF6C),
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        onPressed: _isSaving ? null : _saveVoucher,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isEdit ? 'Simpan Perubahan Baucar' : 'Lancarkan Kempen Baucar',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF42A5F5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, String value) {
    final isSelected = _customerEligibility == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF42A5F5).withValues(alpha: 0.25),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      side: BorderSide(
        color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.08),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _customerEligibility = value);
      },
    );
  }

  Widget _buildLivePreviewCard() {
    final code = _codeCtrl.text.trim().isEmpty ? 'CONTOH20' : _codeCtrl.text.trim().toUpperCase();
    final title = _titleCtrl.text.trim().isEmpty ? 'Baucar Diskaun Hebat' : _titleCtrl.text.trim();
    final discountVal = double.tryParse(_discountValCtrl.text.trim()) ?? 10.0;
    final minSpend = double.tryParse(_minSpendCtrl.text.trim()) ?? 0.0;
    final maxCap = double.tryParse(_maxCapCtrl.text.trim());

    String discountText;
    if (_discountType == 'percentage') {
      discountText = '${discountVal % 1 == 0 ? discountVal.toInt() : discountVal.toStringAsFixed(1)}% OFF';
      if (_hasMaxCap && maxCap != null && maxCap > 0) {
        discountText += ' (Maks RM ${maxCap.toStringAsFixed(2)})';
      }
    } else {
      discountText = 'RM ${discountVal.toStringAsFixed(2)} OFF';
    }

    final minSpendText = minSpend > 0 ? 'Min. Belanja RM ${minSpend.toStringAsFixed(2)}' : 'Tanpa Belanja Min.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF42A5F5)),
              const SizedBox(width: 6),
              const Text(
                'PREVIEW TIKET BAUCAR PELANGGAN (LIVE)',
                style: TextStyle(
                  color: Color(0xFF42A5F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF44CF6C).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Standard E-Commerce',
                  style: TextStyle(color: Color(0xFF44CF6C), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _discountType == 'percentage'
                        ? '${discountVal % 1 == 0 ? discountVal.toInt() : discountVal.toStringAsFixed(1)}%'
                        : 'RM ${discountVal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$discountText · $minSpendText',
                        style: const TextStyle(color: Color(0xFF44CF6C), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
