import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// PayoutsPage — Merchant Settlement, Bank Accounts & Withdrawals
// ============================================================

enum PayoutStatus { completed, processing, onHold }

class PayoutsPage extends StatefulWidget {
  const PayoutsPage({super.key});

  @override
  State<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends State<PayoutsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  double _availableBalance = 4820.50;
  final double _pendingClearance = 1240.00;
  final double _lifetimePayout = 38950.00;
  String _selectedSchedule = 'Daily Auto-Payout';

  late List<Map<String, dynamic>> _bankAccounts;
  late List<Map<String, dynamic>> _settlementHistory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _bankAccounts = [
      {
        'id': 'BA-01',
        'bankName': 'Maybank Islamic',
        'accountNumber': '5642 8890 ****',
        'accountHolder': 'WARUNG NGAM SDN BHD',
        'isDefault': true,
        'badgeColor': const Color(0xFFF9C80E),
      },
      {
        'id': 'BA-02',
        'bankName': 'CIMB Bank',
        'accountNumber': '8009 2314 ****',
        'accountHolder': 'WARUNG NGAM SDN BHD',
        'isDefault': false,
        'badgeColor': const Color(0xFFEF4444),
      },
    ];

    _settlementHistory = [
      {
        'id': 'SET-88910',
        'date': 'Today, 06:00 AM',
        'bankName': 'Maybank Islamic',
        'accountNumber': '5642 8890 ****',
        'amount': 1850.00,
        'fee': 0.00,
        'status': PayoutStatus.processing,
        'reference': 'DNT20260930061248',
      },
      {
        'id': 'SET-88909',
        'date': 'Yesterday, 06:00 AM',
        'bankName': 'Maybank Islamic',
        'accountNumber': '5642 8890 ****',
        'amount': 2430.80,
        'fee': 0.00,
        'status': PayoutStatus.completed,
        'reference': 'DNT20260929061099',
      },
      {
        'id': 'SET-88908',
        'date': '28 Sep 2026',
        'bankName': 'Maybank Islamic',
        'accountNumber': '5642 8890 ****',
        'amount': 3120.00,
        'fee': 0.00,
        'status': PayoutStatus.completed,
        'reference': 'DNT20260928061320',
      },
      {
        'id': 'SET-88907',
        'date': '27 Sep 2026',
        'bankName': 'Maybank Islamic',
        'accountNumber': '5642 8890 ****',
        'amount': 2980.50,
        'fee': 0.00,
        'status': PayoutStatus.completed,
        'reference': 'DNT20260927061114',
      },
      {
        'id': 'SET-88906',
        'date': '26 Sep 2026',
        'bankName': 'CIMB Bank',
        'accountNumber': '8009 2314 ****',
        'amount': 1450.00,
        'fee': 0.00,
        'status': PayoutStatus.completed,
        'reference': 'DNT20260926061001',
      },
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openRequestWithdrawalDialog() {
    final amountController = TextEditingController();
    String selectedBankId = _bankAccounts.firstWhere((b) => b['isDefault'])['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
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
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedMoneySend02,
                          color: Color(0xFF44CF6C),
                          size: 26,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Instant Payout Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Funds will be transferred via DuitNow Instant Settlement.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Balance banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available to Withdraw',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            'RM ${_availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF44CF6C),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount input
                    const Text(
                      'Withdrawal Amount (RM)',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'RM ',
                        prefixStyle: const TextStyle(color: Color(0xFF44CF6C), fontSize: 20, fontWeight: FontWeight.bold),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F1B),
                        suffixIcon: TextButton(
                          onPressed: () {
                            setModalState(() {
                              amountController.text = _availableBalance.toStringAsFixed(2);
                            });
                          },
                          child: const Text('MAX', style: TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold)),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bank selector
                    const Text(
                      'Destination Bank Account',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ..._bankAccounts.map((b) {
                      final isSelected = selectedBankId == b['id'];
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedBankId = b['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF42A5F5).withValues(alpha: 0.15) : const Color(0xFF1B1B2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF42A5F5) : Colors.white10,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: b['badgeColor'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b['bankName'] as String,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      '${b['accountNumber']} • ${b['accountHolder']}',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5), size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF44CF6C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final amt = double.tryParse(amountController.text.trim()) ?? 0;
                          if (amt <= 0) {
                            showGlassToast(context, 'Please enter a valid amount', isError: true);
                            return;
                          }
                          if (amt > _availableBalance) {
                            showGlassToast(context, 'Amount exceeds available balance', isError: true);
                            return;
                          }

                          final targetBank = _bankAccounts.firstWhere((b) => b['id'] == selectedBankId);
                          setState(() {
                            _availableBalance -= amt;
                            _settlementHistory.insert(0, {
                              'id': 'SET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                              'date': 'Just now',
                              'bankName': targetBank['bankName'],
                              'accountNumber': targetBank['accountNumber'],
                              'amount': amt,
                              'fee': 0.00,
                              'status': PayoutStatus.processing,
                              'reference': 'DNT${DateTime.now().millisecondsSinceEpoch}',
                            });
                          });

                          Navigator.pop(ctx);
                          showGlassToast(context, 'Payout of RM ${amt.toStringAsFixed(2)} requested via DuitNow!');
                        },
                        child: const Text(
                          'Confirm & Transfer Now',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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

  void _openAddBankDialog() {
    final bankNameController = TextEditingController();
    final accNoController = TextEditingController();
    final holderController = TextEditingController(text: 'WARUNG NGAM SDN BHD');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
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
                const SizedBox(height: 20),
                const Text(
                  'Link Business Bank Account',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Must match SSM registered business name for compliance.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: bankNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Bank Name (e.g. Public Bank / Hong Leong)',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: accNoController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: holderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (bankNameController.text.trim().isEmpty || accNoController.text.trim().isEmpty) {
                        showGlassToast(context, 'Please fill in all bank details', isError: true);
                        return;
                      }
                      setState(() {
                        _bankAccounts.add({
                          'id': 'BA-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                          'bankName': bankNameController.text.trim(),
                          'accountNumber': accNoController.text.trim(),
                          'accountHolder': holderController.text.trim(),
                          'isDefault': false,
                          'badgeColor': const Color(0xFF00CEC9),
                        });
                      });
                      Navigator.pop(ctx);
                      showGlassToast(context, 'Bank account linked successfully!');
                    },
                    child: const Text('Save Bank Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payouts & Settlement',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Direct bank transfers & DuitNow settlements',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload01, color: Colors.white70, size: 20),
            tooltip: 'Export Statement',
            onPressed: () => showGlassToast(context, 'Monthly financial statement exported (PDF/CSV)'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF42A5F5),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Overview & Accounts'),
            Tab(text: 'Settlement History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Balance Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ready for Payout',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Instant Active',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'RM ${_availableBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Clearance',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${_pendingClearance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFF9C80E), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: Colors.white12),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lifetime Withdrawn',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${_lifetimePayout.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF44CF6C),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _openRequestWithdrawalDialog,
                    icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                    label: const Text(
                      'Request Instant Payout',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Payout Schedule Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Auto-Payout Schedule',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedSchedule,
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 13, fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF42A5F5)),
                items: ['Daily Auto-Payout', 'Weekly (Mondays)', 'Manual Only']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedSchedule = val);
                    showGlassToast(context, 'Schedule updated to $val');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bank Accounts Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Linked Bank Accounts',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _openAddBankDialog,
                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF42A5F5)),
                label: const Text('Add Account', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._bankAccounts.map((acc) => _buildBankCard(acc)),
        ],
      ),
    );
  }

  Widget _buildBankCard(Map<String, dynamic> acc) {
    final isDefault = acc['isDefault'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDefault ? const Color(0xFF42A5F5).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (acc['badgeColor'] as Color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedBuilding06,
              color: acc['badgeColor'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      acc['bankName'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(color: Color(0xFF42A5F5), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  acc['accountNumber'] as String,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, letterSpacing: 0.5),
                ),
                Text(
                  acc['accountHolder'] as String,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isDefault)
            TextButton(
              onPressed: () {
                setState(() {
                  for (var b in _bankAccounts) {
                    b['isDefault'] = (b['id'] == acc['id']);
                  }
                });
                showGlassToast(context, '${acc['bankName']} set as primary account');
              },
              child: const Text('Set Primary', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _settlementHistory.length,
      itemBuilder: (context, index) {
        final item = _settlementHistory[index];
        final isCompleted = item['status'] == PayoutStatus.completed;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141424),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF9C80E).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : Icons.access_time_rounded,
                  color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF9C80E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item['bankName'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          'RM ${(item['amount'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${item['date']} • Ref: ${item['id']}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFF9C80E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCompleted ? 'Transferred' : 'Processing',
                            style: TextStyle(
                              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF9C80E),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
