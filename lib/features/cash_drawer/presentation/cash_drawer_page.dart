import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// CashDrawerPage — Shift Management, Petty Cash & Z-Report
// ============================================================

class CashDrawerPage extends StatefulWidget {
  const CashDrawerPage({super.key});

  @override
  State<CashDrawerPage> createState() => _CashDrawerPageState();
}

class _CashDrawerPageState extends State<CashDrawerPage> {
  final int _shiftNumber = 108;
  final String _cashierName = 'Ahmad Syafii';
  final String _shiftStartTime = 'Today, 08:30 AM';

  final double _openingFloat = 200.00;
  final double _cashSales = 1450.00;
  final double _qrSales = 2890.00;
  final double _cardSales = 1120.00;

  late List<Map<String, dynamic>> _pettyCashEntries;
  final TextEditingController _countedCashCtrl = TextEditingController(text: '1593.00');

  @override
  void initState() {
    super.initState();
    _pettyCashEntries = [
      {
        'id': 'PC-01',
        'type': 'out',
        'reason': 'Beli Ais Batu Tambahan (Kedai Runcit)',
        'amount': 15.00,
        'time': '10:45 AM',
        'author': 'Ahmad',
      },
      {
        'id': 'PC-02',
        'type': 'out',
        'reason': 'Tong Gas Memasak Petroleum (Ganti)',
        'amount': 42.00,
        'time': '01:15 PM',
        'author': 'Ahmad',
      },
    ];
  }

  @override
  void dispose() {
    _countedCashCtrl.dispose();
    super.dispose();
  }

  double get _totalPettyCashOut {
    return _pettyCashEntries.where((e) => e['type'] == 'out').fold(0.0, (sum, e) => sum + (e['amount'] as double));
  }

  double get _totalPettyCashIn {
    return _pettyCashEntries.where((e) => e['type'] == 'in').fold(0.0, (sum, e) => sum + (e['amount'] as double));
  }

  double get _expectedCashInDrawer {
    return _openingFloat + _cashSales - _totalPettyCashOut + _totalPettyCashIn;
  }

  double get _totalShiftRevenue {
    return _cashSales + _qrSales + _cardSales;
  }

  double get _cashDiscrepancy {
    final counted = double.tryParse(_countedCashCtrl.text.trim()) ?? 0.0;
    return counted - _expectedCashInDrawer;
  }

  void _openAddPettyCashDialog() {
    final reasonCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String type = 'out';

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
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Record Cash Drawer Movement',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Log petty cash payouts (expenses) or manual float top-ups.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // In / Out Segment
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => type = 'out'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: type == 'out' ? Colors.redAccent.withValues(alpha: 0.2) : const Color(0xFF1B1B2C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: type == 'out' ? Colors.redAccent : Colors.transparent),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cash Out (Expense)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => type = 'in'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: type == 'in' ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF1B1B2C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: type == 'in' ? const Color(0xFF10B981) : Colors.transparent),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cash In (Top-up)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: reasonCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Reason / Item Description',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F1B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'RM ',
                        prefixStyle: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                        labelText: 'Amount (RM)',
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
                          final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                          if (reasonCtrl.text.trim().isEmpty || amt <= 0) {
                            showGlassToast(context, 'Please enter a valid reason and amount', isError: true);
                            return;
                          }

                          setState(() {
                            _pettyCashEntries.insert(0, {
                              'id': 'PC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                              'type': type,
                              'reason': reasonCtrl.text.trim(),
                              'amount': amt,
                              'time': 'Just now',
                              'author': _cashierName,
                            });
                          });

                          Navigator.pop(ctx);
                          showGlassToast(context, 'Cash drawer movement recorded successfully!');
                        },
                        child: const Text('Record Movement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showZReportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                const HugeIcon(icon: HugeIcons.strokeRoundedInvoice02, color: Color(0xFF44CF6C), size: 36),
                const SizedBox(height: 12),
                const Text(
                  'End Shift & Z-Report Audit',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Shift #$_shiftNumber • Cashier: $_cashierName',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Report paper card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _buildZRow('Opening Cash Float', 'RM ${_openingFloat.toStringAsFixed(2)}'),
                      _buildZRow('Cash Sales', 'RM ${_cashSales.toStringAsFixed(2)}'),
                      _buildZRow('Petty Cash Out', '- RM ${_totalPettyCashOut.toStringAsFixed(2)}', color: Colors.redAccent),
                      const Divider(color: Colors.white12),
                      _buildZRow('Expected Drawer Cash', 'RM ${_expectedCashInDrawer.toStringAsFixed(2)}', isBold: true),
                      _buildZRow('Counted Drawer Cash', 'RM ${(double.tryParse(_countedCashCtrl.text) ?? 0).toStringAsFixed(2)}', isBold: true),
                      _buildZRow(
                        'Cash Discrepancy',
                        _cashDiscrepancy == 0
                            ? 'RM 0.00 (Exact)'
                            : '${_cashDiscrepancy > 0 ? "+" : ""}RM ${_cashDiscrepancy.toStringAsFixed(2)} (${_cashDiscrepancy > 0 ? "Surplus" : "Shortage"})',
                        color: _cashDiscrepancy == 0 ? const Color(0xFF10B981) : (_cashDiscrepancy > 0 ? const Color(0xFF42A5F5) : Colors.redAccent),
                        isBold: true,
                      ),
                      const Divider(color: Colors.white12),
                      _buildZRow('DuitNow / QR E-Wallets', 'RM ${_qrSales.toStringAsFixed(2)}'),
                      _buildZRow('Credit / Debit Cards', 'RM ${_cardSales.toStringAsFixed(2)}'),
                      const Divider(color: Colors.white12),
                      _buildZRow('TOTAL SHIFT REVENUE', 'RM ${_totalShiftRevenue.toStringAsFixed(2)}', color: const Color(0xFF44CF6C), isBold: true, fontSize: 15),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          showGlassToast(context, 'Printing physical Z-Report receipt...');
                        },
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedPrinter, color: Colors.white, size: 18),
                        label: const Text('Print Z-Report'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF44CF6C),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showGlassToast(context, 'Shift #$_shiftNumber closed and submitted to cloud audit!');
                        },
                        icon: const Icon(Icons.lock_clock_rounded, size: 18),
                        label: const Text('Close Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
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
              'Cash Drawer & Shift Closing',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Petty cash logs, drawer audits & Z-Reports',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoneyAdd02, color: Color(0xFF42A5F5), size: 22),
            tooltip: 'Add Petty Cash',
            onPressed: _openAddPettyCashDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Shift Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    const Color(0xFF141424),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Shift #$_shiftNumber Active',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('OPEN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cashier: $_cashierName • Started $_shiftStartTime',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Revenue Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Cash in Drawer',
                    value: 'RM ${_expectedCashInDrawer.toStringAsFixed(2)}',
                    color: const Color(0xFF44CF6C),
                    icon: HugeIcons.strokeRoundedMoney01,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'DuitNow / E-Wallet',
                    value: 'RM ${_qrSales.toStringAsFixed(2)}',
                    color: const Color(0xFF42A5F5),
                    icon: HugeIcons.strokeRoundedQrCode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Card Terminals',
                    value: 'RM ${_cardSales.toStringAsFixed(2)}',
                    color: const Color(0xFFAB47BC),
                    icon: HugeIcons.strokeRoundedCreditCard,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Shift Sales',
                    value: 'RM ${_totalShiftRevenue.toStringAsFixed(2)}',
                    color: const Color(0xFFF9C80E),
                    icon: HugeIcons.strokeRoundedCoins01,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Drawer Reconciliation Section
            const Text(
              'Drawer Cash Count & Reconciliation',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Expected Cash in Drawer', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                        'RM ${_expectedCashInDrawer.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Actual Physical Cash Counted:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _countedCashCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: 'RM ',
                            prefixStyle: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: const Color(0xFF0F0F1B),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Audit Discrepancy', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cashDiscrepancy == 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : (_cashDiscrepancy > 0 ? const Color(0xFF42A5F5).withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _cashDiscrepancy == 0
                              ? 'RM 0.00 (Balanced)'
                              : '${_cashDiscrepancy > 0 ? "+" : ""}RM ${_cashDiscrepancy.toStringAsFixed(2)} (${_cashDiscrepancy > 0 ? "Surplus" : "Shortage"})',
                          style: TextStyle(
                            color: _cashDiscrepancy == 0
                                ? const Color(0xFF10B981)
                                : (_cashDiscrepancy > 0 ? const Color(0xFF42A5F5) : Colors.redAccent),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Petty Cash Entries Ledger
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Petty Cash Log (Expenses & Top-ups)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _openAddPettyCashDialog,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF42A5F5)),
                  label: const Text('Add Entry', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._pettyCashEntries.map((e) {
              final isOut = e['type'] == 'out';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141424),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOut ? Colors.redAccent.withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: isOut ? Colors.redAccent : const Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['reason'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${e['time']} • Logged by ${e['author']}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isOut ? "-" : "+"}RM ${(e['amount'] as double).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isOut ? Colors.redAccent : const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),

            // End Shift & Z-Report Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _showZReportDialog,
                icon: const Icon(Icons.lock_clock_rounded, size: 20),
                label: const Text('End Shift & View Z-Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color color, required List<List<dynamic>> icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
