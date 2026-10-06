import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../models/order_model.dart';
import '../../../../widgets/glass_toast.dart';

class SplitPaymentResult {
  final List<PaymentSplit> splits;
  final String? customerName;
  final String? notes;
  final double total;
  final double change;

  SplitPaymentResult({
    required this.splits,
    required this.total,
    required this.change,
    this.customerName,
    this.notes,
  });
}

class SplitPaymentSheet extends StatefulWidget {
  final double totalAmount;
  final int itemCount;
  final String initialCustomerName;

  const SplitPaymentSheet({
    super.key,
    required this.totalAmount,
    required this.itemCount,
    this.initialCustomerName = '',
  });

  static Future<SplitPaymentResult?> show({
    required BuildContext context,
    required double totalAmount,
    required int itemCount,
    String initialCustomerName = '',
  }) {
    return showModalBottomSheet<SplitPaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SplitPaymentSheet(
        totalAmount: totalAmount,
        itemCount: itemCount,
        initialCustomerName: initialCustomerName,
      ),
    );
  }

  @override
  State<SplitPaymentSheet> createState() => _SplitPaymentSheetState();
}

class _SplitPaymentSheetState extends State<SplitPaymentSheet> {
  final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

  late TextEditingController _customerCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _cashTenderedCtrl;

  final List<PaymentSplit> _recordedSplits = [];
  String _selectedMethod = 'cash'; // 'cash' | 'duitnow' | 'card' | 'ewallet'

  double get _totalAllocated =>
      _recordedSplits.fold(0.0, (sum, s) => sum + s.amount);

  double get _remainingDue =>
      (widget.totalAmount - _totalAllocated).clamp(0.0, double.infinity);

  double get _totalChange {
    double change = 0.0;
    for (final s in _recordedSplits) {
      if (s.method == 'cash' && s.changeAmount != null) {
        change += s.changeAmount!;
      }
    }
    // Also include live change if cash is currently being entered
    if (_selectedMethod == 'cash') {
      final inputAmt = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
      final tendered = double.tryParse(_cashTenderedCtrl.text.replaceAll(',', '')) ?? 0.0;
      if (tendered > inputAmt) {
        change += (tendered - inputAmt);
      }
    }
    return change;
  }

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(text: widget.initialCustomerName);
    _notesCtrl = TextEditingController();
    _amountCtrl = TextEditingController(text: widget.totalAmount.toStringAsFixed(2));
    _cashTenderedCtrl = TextEditingController(text: widget.totalAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    _amountCtrl.dispose();
    _cashTenderedCtrl.dispose();
    super.dispose();
  }

  void _onMethodSelected(String method) {
    setState(() {
      _selectedMethod = method;
      if (method == 'cash') {
        _cashTenderedCtrl.text = _amountCtrl.text;
      }
    });
  }

  void _setAmount(double amount) {
    setState(() {
      _amountCtrl.text = amount.toStringAsFixed(2);
      if (_selectedMethod == 'cash') {
        _cashTenderedCtrl.text = amount.toStringAsFixed(2);
      }
    });
  }

  void _addQuickCash(double extra) {
    final cur = double.tryParse(_cashTenderedCtrl.text.replaceAll(',', '')) ?? 0.0;
    setState(() {
      _cashTenderedCtrl.text = (cur + extra).toStringAsFixed(2);
    });
  }

  void _addCurrentSplit() {
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    if (amt <= 0) {
      showGlassToast(context, 'Sila masukkan amaun sah', isError: true);
      return;
    }

    if (amt > _remainingDue + 0.001) {
      showGlassToast(context, 'Amaun melebihi baki tertunggak (${fmt.format(_remainingDue)})', isError: true);
      return;
    }

    double? tendered;
    double? change;

    if (_selectedMethod == 'cash') {
      tendered = double.tryParse(_cashTenderedCtrl.text.replaceAll(',', '')) ?? amt;
      if (tendered < amt) {
        showGlassToast(context, 'Duit tunai diterima kurang daripada amaun yang dicaj', isError: true);
        return;
      }
      change = tendered > amt ? tendered - amt : 0.0;
    }

    setState(() {
      _recordedSplits.add(
        PaymentSplit(
          method: _selectedMethod,
          amount: amt,
          tenderedAmount: tendered,
          changeAmount: change,
        ),
      );

      // Auto update next input for any remaining balance
      final newRemaining = (widget.totalAmount - _totalAllocated).clamp(0.0, double.infinity);
      _amountCtrl.text = newRemaining.toStringAsFixed(2);
      _cashTenderedCtrl.text = newRemaining.toStringAsFixed(2);
    });
  }

  void _removeSplit(int index) {
    setState(() {
      _recordedSplits.removeAt(index);
      final newRemaining = (widget.totalAmount - _totalAllocated).clamp(0.0, double.infinity);
      _amountCtrl.text = newRemaining.toStringAsFixed(2);
      _cashTenderedCtrl.text = newRemaining.toStringAsFixed(2);
    });
  }

  void _completeCheckout() {
    // If no splits were added manually yet, but current input covers the bill, auto-add
    if (_recordedSplits.isEmpty) {
      final inputAmt = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
      if (inputAmt >= widget.totalAmount - 0.001) {
        _addCurrentSplit();
      }
    }

    if (_remainingDue > 0.01) {
      showGlassToast(
        context,
        'Bayaran belum cukup! Masih ada baki ${fmt.format(_remainingDue)} belum dilunaskan.',
        isError: true,
      );
      return;
    }

    Navigator.pop(
      context,
      SplitPaymentResult(
        splits: _recordedSplits,
        total: widget.totalAmount,
        change: _totalChange,
        customerName: _customerCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isFullyPaid = _remainingDue <= 0.001;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF10101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bayaran & Checkout POS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.itemCount} item • Jumlah: ${fmt.format(widget.totalAmount)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner (Remaining & Change)
                  _buildStatusBanner(),
                  const SizedBox(height: 16),

                  // Recorded Splits (if any)
                  if (_recordedSplits.isNotEmpty) ...[
                    _buildRecordedSplitsSection(),
                    const SizedBox(height: 16),
                  ],

                  // If still need payment, show tender inputs
                  if (!isFullyPaid) ...[
                    _buildPaymentMethodPicker(),
                    const SizedBox(height: 16),
                    _buildTenderInputs(),
                    const SizedBox(height: 16),
                  ],

                  // Customer name & Notes
                  _buildCustomerDetails(),
                ],
              ),
            ),
          ),

          // Footer Confirmation Bar
          _buildFooterBar(isFullyPaid),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isFullyPaid = _remainingDue <= 0.001;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFullyPaid
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyPaid
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isFullyPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: isFullyPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                size: 26,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFullyPaid ? 'Bayaran Lengkap' : 'Baki Kena Bayar',
                    style: TextStyle(
                      color: isFullyPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    fmt.format(_remainingDue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_totalChange > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Baki Pulangan',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  fmt.format(_totalChange),
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecordedSplitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pecahan Bayaran Telah Direkod (Split)',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._recordedSplits.asMap().entries.map((entry) {
          final idx = entry.key;
          final split = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _getMethodIcon(split.method),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          split.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (split.method == 'cash' && split.tenderedAmount != null && split.tenderedAmount! > split.amount)
                          Text(
                            'Diterima: ${fmt.format(split.tenderedAmount)} • Baki: ${fmt.format(split.changeAmount ?? 0)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      fmt.format(split.amount),
                      style: const TextStyle(
                        color: Color(0xFF44CF6C),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _removeSplit(idx),
                      tooltip: 'Padam tender ini',
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentMethodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Kaedah Bayaran',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMethodButton('cash', 'Tunai', HugeIcons.strokeRoundedMoney01)),
            const SizedBox(width: 8),
            Expanded(child: _buildMethodButton('duitnow', 'DuitNow', HugeIcons.strokeRoundedQrCode)),
            const SizedBox(width: 8),
            Expanded(child: _buildMethodButton('card', 'Kad', HugeIcons.strokeRoundedCreditCard)),
            const SizedBox(width: 8),
            Expanded(child: _buildMethodButton('ewallet', 'E-Wallet', HugeIcons.strokeRoundedWallet01)),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodButton(String method, String label, dynamic iconData) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => _onMethodSelected(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF42A5F5).withValues(alpha: 0.2) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF42A5F5) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: iconData,
              color: isSelected ? const Color(0xFF42A5F5) : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenderInputs() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amaun Dibayar (${_getMethodName(_selectedMethod)})',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _setAmount(_remainingDue),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Bayar Semua Baki',
                    style: TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Amount text field
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'RM ',
              prefixStyle: const TextStyle(color: Color(0xFF42A5F5), fontSize: 18, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) {
              if (_selectedMethod == 'cash') {
                setState(() => _cashTenderedCtrl.text = val);
              } else {
                setState(() {});
              }
            },
          ),

          // Quick Amount Chips
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickAmountChip('RM 10', 10.0),
                const SizedBox(width: 6),
                _buildQuickAmountChip('RM 20', 20.0),
                const SizedBox(width: 6),
                _buildQuickAmountChip('RM 50', 50.0),
                const SizedBox(width: 6),
                _buildQuickAmountChip('RM 100', 100.0),
              ],
            ),
          ),

          // Cash change calculator section
          if (_selectedMethod == 'cash') ...[
            const Divider(height: 24, color: Colors.white12),
            const Text(
              'Duit Tunai Diterima Dari Pelanggan',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cashTenderedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'RM ',
                prefixStyle: const TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickCashTenderChip('+RM 5', 5.0),
                  const SizedBox(width: 6),
                  _buildQuickCashTenderChip('+RM 10', 10.0),
                  const SizedBox(width: 6),
                  _buildQuickCashTenderChip('+RM 20', 20.0),
                  const SizedBox(width: 6),
                  _buildQuickCashTenderChip('+RM 50', 50.0),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Add this split button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _addCurrentSplit,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                _recordedSplits.isEmpty ? 'Rekod Kaedah Ini (Atau Terus Sahkan)' : '+ Tambah Bahagian Bayaran Ini',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF42A5F5),
                side: const BorderSide(color: Color(0xFF42A5F5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, double val) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: const Color(0xFF1A1A2E),
      side: const BorderSide(color: Colors.white12),
      onPressed: () => _setAmount(val),
    );
  }

  Widget _buildQuickCashTenderChip(String label, double extra) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Color(0xFF34D399), fontSize: 12)),
      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
      side: const BorderSide(color: Color(0x3310B981)),
      onPressed: () => _addQuickCash(extra),
    );
  }

  Widget _buildCustomerDetails() {
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
          const Text(
            'Maklumat Tambahan (Pilihan)',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customerCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nama Pelanggan',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nota / Rujukan Meja / Resit',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBar(bool isFullyPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _completeCheckout,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  isFullyPaid
                      ? 'Sahkan & Bayar (${fmt.format(widget.totalAmount)})'
                      : 'Bayar Sekarang (${fmt.format(widget.totalAmount)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF44CF6C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const HugeIcon(icon: HugeIcons.strokeRoundedMoney01, color: Color(0xFF44CF6C), size: 20);
      case 'duitnow':
        return const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Color(0xFF42A5F5), size: 20);
      case 'card':
        return const HugeIcon(icon: HugeIcons.strokeRoundedCreditCard, color: Color(0xFFA78BFA), size: 20);
      case 'ewallet':
        return const HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: Color(0xFFF59E0B), size: 20);
      default:
        return const Icon(Icons.payment_rounded, color: Colors.white70, size: 20);
    }
  }

  String _getMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'duitnow':
        return 'DuitNow QR';
      case 'card':
        return 'Kad Bank';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method;
    }
  }
}
