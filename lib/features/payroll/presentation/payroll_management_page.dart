import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../data/payroll_service.dart';
import '../models/staff_payroll_model.dart';
import '../../../widgets/glass_toast.dart';

class PayrollManagementPage extends StatefulWidget {
  const PayrollManagementPage({super.key});

  @override
  State<PayrollManagementPage> createState() => _PayrollManagementPageState();
}

class _PayrollManagementPageState extends State<PayrollManagementPage>
    with SingleTickerProviderStateMixin {
  final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
  final PayrollService _service = PayrollService();

  late TabController _tabController;
  List<MonthlyPayrollItem> _payrollItems = [];
  List<StaffPayrollSetting> _settings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final items = await _service.generateMonthlyPayroll();
    final settings = await _service.fetchStaffPayrollSettings();

    if (mounted) {
      setState(() {
        _payrollItems = items;
        _settings = settings;
        _loading = false;
      });
    }
  }

  double get _totalNetPayout =>
      _payrollItems.fold(0.0, (sum, i) => sum + i.netPay);

  double get _totalCommissions =>
      _payrollItems.fold(0.0, (sum, i) => sum + i.serviceCommission + i.productCommission);

  double get _totalEmployerStatutory =>
      _payrollItems.fold(0.0, (sum, i) => sum + i.epfEmployer + i.socsoEmployer + i.eisEmployer);

  bool get _isApproved =>
      _payrollItems.isNotEmpty && _payrollItems.first.status == 'approved';

  Future<void> _approvePayroll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Luluskan Gaji Bulan Ini?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Jumlah keseluruhan bayaran gaji bersih adalah ${fmt.format(_totalNetPayout)}. '
          'Slip gaji digital rasmi akan diterbitkan secara langsung ke aplikasi Ngam Teams pekerja.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sahkan & Luluskan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _service.approveMonthlyPayroll();
    setState(() {
      _payrollItems = _payrollItems.map((p) => p.copyWith(status: 'approved')).toList();
    });

    if (!mounted) return;
    showGlassToast(
      context,
      'Gaji Berjaya Diluluskan! Slip gaji telah dihantar ke Ngam Teams.',
      customColor: const Color(0xFF44CF6C),
    );
  }

  void _openAdjustmentDialog(MonthlyPayrollItem item) {
    final bonusCtrl = TextEditingController(text: item.bonusOrAllowance > 0 ? item.bonusOrAllowance.toStringAsFixed(2) : '');
    final deductCtrl = TextEditingController(text: item.penaltyOrDeduction > 0 ? item.penaltyOrDeduction.toStringAsFixed(2) : '');
    final otCtrl = TextEditingController(text: item.overtimePay.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              Text(
                'Pelarasan Gaji: ${item.staffName}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Jawatan: ${item.designation} (${item.staffCode})',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),

              _buildField('Bayaran Lebih Masa (OT) (RM)', otCtrl),
              const SizedBox(height: 10),
              _buildField('Bonus / Elaun Khas (RM)', bonusCtrl),
              const SizedBox(height: 10),
              _buildField('Potongan / Penalti Kelewatan (RM)', deductCtrl),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    final newOt = double.tryParse(otCtrl.text) ?? item.overtimePay;
                    final newBonus = double.tryParse(bonusCtrl.text) ?? 0.0;
                    final newDeduct = double.tryParse(deductCtrl.text) ?? 0.0;

                    final updated = item.copyWith(
                      overtimePay: newOt,
                      bonusOrAllowance: newBonus,
                      penaltyOrDeduction: newDeduct,
                    );
                    _service.updatePayrollItem(updated);

                    setState(() {
                      final idx = _payrollItems.indexWhere((p) => p.staffId == item.staffId);
                      if (idx != -1) _payrollItems[idx] = updated;
                    });

                    Navigator.pop(ctx);
                    showGlassToast(context, 'Pelarasan gaji disimpan');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Pelarasan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEditSettingDialog(StaffPayrollSetting setting) {
    final baseCtrl = TextEditingController(text: setting.baseSalary.toStringAsFixed(2));
    final srvCommCtrl = TextEditingController(text: setting.serviceCommissionRate.toStringAsFixed(1));
    final prodCommCtrl = TextEditingController(text: setting.productCommissionRate.toStringAsFixed(1));
    bool epf = setting.epfEnabled;
    bool socso = setting.socsoEnabled;
    bool eis = setting.eisEnabled;

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
                    Text(
                      'Tetapan Komisen: ${setting.staffName}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Kod: ${setting.staffCode} • ${setting.designation}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    _buildField('Gaji Pokok Bulanan (RM)', baseCtrl),
                    const SizedBox(height: 10),
                    _buildField('Kadar Komisen Servis (%) (cth: 35%)', srvCommCtrl),
                    const SizedBox(height: 10),
                    _buildField('Kadar Komisen Produk Retail (%) (cth: 10%)', prodCommCtrl),
                    const SizedBox(height: 14),

                    const Text(
                      'Caruman Berkanun Malaysia',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Caruman KWSP / EPF (11% Pekerja, 13% Majikan)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: epf,
                      activeColor: const Color(0xFF42A5F5),
                      onChanged: (val) => setMState(() => epf = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Caruman PERKESO / SOCSO', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: socso,
                      activeColor: const Color(0xFF42A5F5),
                      onChanged: (val) => setMState(() => socso = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Caruman Sistem Insurans Pekerjaan (SIP / EIS)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: eis,
                      activeColor: const Color(0xFF42A5F5),
                      onChanged: (val) => setMState(() => eis = val),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () async {
                          final updated = setting.copyWith(
                            baseSalary: double.tryParse(baseCtrl.text) ?? setting.baseSalary,
                            serviceCommissionRate: double.tryParse(srvCommCtrl.text) ?? setting.serviceCommissionRate,
                            productCommissionRate: double.tryParse(prodCommCtrl.text) ?? setting.productCommissionRate,
                            epfEnabled: epf,
                            socsoEnabled: socso,
                            eisEnabled: eis,
                          );

                          await _service.updateStaffPayrollSetting(updated);
                          if (mounted) {
                            setState(() {
                              final idx = _settings.indexWhere((s) => s.staffId == setting.staffId);
                              if (idx != -1) _settings[idx] = updated;
                            });
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) showGlassToast(context, 'Tetapan komisen disimpan');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan Tetapan', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
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
              'Penggajian & Komisen (Payroll)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Gaji pokok, komisen jualan & caruman',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload04, color: Color(0xFF42A5F5), size: 22),
            tooltip: 'Eksport Penyata Gaji',
            onPressed: () => showGlassToast(context, 'Mengeksport ringkasan gaji PDF/CSV...'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF42A5F5),
          labelColor: const Color(0xFF42A5F5),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Gaji Bulan Ini (Run)'),
            Tab(text: 'Tetapan Komisen'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPayrollRunTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildPayrollRunTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Payout Summary
          _buildHeroSummaryCard(),
          const SizedBox(height: 18),

          // Action Bar: Approve button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Senarai Gaji Staf (${_payrollItems.length} Orang)',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _isApproved ? null : _approvePayroll,
                icon: Icon(_isApproved ? Icons.check_circle_rounded : Icons.approval_rounded, size: 18),
                label: Text(
                  _isApproved ? 'Telah Diluluskan' : 'Luluskan Gaji',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isApproved ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items List
          ..._payrollItems.map(_buildPayrollItemCard),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.2),
            const Color(0xFF141424),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BULAN SEMASA: ${DateFormat("MMMM yyyy").format(DateTime.now()).toUpperCase()}',
                style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isApproved ? 'DILULUSKAN' : 'DRAF MENUNGGU KELULUSAN',
                  style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fmt.format(_totalNetPayout),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Anggaran Jumlah Payout Gaji Bersih',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Divider(height: 24, color: Colors.white12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jumlah Komisen', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(fmt.format(_totalCommissions), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KWSP & SOCSO Majikan', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(fmt.format(_totalEmployerStatutory), style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollItemCard(MonthlyPayrollItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    item.staffName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${item.designation} • ${item.staffCode}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Gaji Bersih (Net)', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(
                    fmt.format(item.netPay),
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white12),

          // Breakdown Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPayRow('Pokok', item.baseSalary),
              _buildPayRow('Komisen', item.serviceCommission + item.productCommission),
              _buildPayRow('OT & Tip', item.overtimePay + item.tipsShare),
              _buildPayRow('Potongan', item.totalEmployeeDeductions, isDeduction: true),
            ],
          ),

          if (item.bonusOrAllowance > 0 || item.penaltyOrDeduction > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Pelarasan: +${fmt.format(item.bonusOrAllowance)} (Bonus) | -${fmt.format(item.penaltyOrDeduction)} (Potongan)',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.bankName != null ? '${item.bankName} (${item.bankAccountNumber})' : 'Tiada maklumat bank',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              TextButton.icon(
                onPressed: () => _openAdjustmentDialog(item),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Laras Elaun/Bonus', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF42A5F5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayRow(String label, double amt, {bool isDeduction = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          '${isDeduction ? "-" : ""}${fmt.format(amt)}',
          style: TextStyle(
            color: isDeduction ? Colors.redAccent : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _settings.length,
      itemBuilder: (ctx, idx) {
        final s = _settings[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141424),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                      Text(s.staffName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${s.designation} • ${s.staffCode}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF42A5F5)),
                    onPressed: () => _openEditSettingDialog(s),
                  ),
                ],
              ),
              const Divider(height: 20, color: Colors.white12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gaji Pokok', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Text(fmt.format(s.baseSalary), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Komisen Servis', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Text('${s.serviceCommissionRate.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Komisen Retail', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Text('${s.productCommissionRate.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KWSP/SOCSO', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Text(s.epfEnabled ? 'Aktif' : 'Tidak', style: TextStyle(color: s.epfEnabled ? const Color(0xFF42A5F5) : Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
