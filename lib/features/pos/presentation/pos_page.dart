import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../pos/data/pos_service.dart';
import '../../pos/models/product_model.dart';
import '../../pos/models/order_model.dart';
import '../../promotions/data/voucher_service.dart';
import 'widgets/split_payment_sheet.dart';
import 'widgets/payment_terminal_modal.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/modal_sheet.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final PosService _service = PosService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  List<CartItem> _cart = [];
  bool _loading = true;
  String _selectedCategory = 'All';

  // Enterprise POS State (Square, Toast & StoreHub Standard)
  String _orderType = 'dine_in'; // 'dine_in', 'takeaway', 'delivery'
  String _tableNumber = '01';
  int _orderSequence = 4032;

  // Voucher & Loyalty State
  String? _appliedVoucherCode;
  double _voucherDiscount = 0.0;
  String? _voucherId;
  bool _isApplyingVoucher = false;

  List<String> get _categories {
    final cats = _allProducts
        .map((p) => (p.category == null || p.category!.trim().isEmpty) ? 'Other' : p.category!.trim())
        .toSet()
        .toList()
      ..sort();
    return ['All', ...cats];
  }

  double get _cartTotal =>
      _cart.fold(0, (sum, item) => sum + item.subtotal);

  int get _cartCount =>
      _cart.fold(0, (sum, item) => sum + item.quantity);

  double get _discountedSubtotal =>
      (_cartTotal - _voucherDiscount).clamp(0.0, double.infinity);

  // Bank Negara Malaysia 5-sen rounding mechanism for cash & POS
  double get _grandTotal {
    if (_cart.isEmpty) return 0.0;
    final sub = _discountedSubtotal;
    return (sub * 20).round() / 20.0;
  }

  double get _roundingAmount =>
      _cart.isEmpty ? 0.0 : _grandTotal - _discountedSubtotal;

  List<double> get _quickCashOptions {
    final total = _grandTotal;
    if (total <= 0) return [];
    final list = <double>[];
    
    // Always include exact amount as first chip
    list.add(total);

    // Malaysian notes
    final notes = [5.0, 10.0, 20.0, 50.0, 100.0];
    for (final note in notes) {
      if (note > total && !list.contains(note)) {
        list.add(note);
      }
    }

    final nextTen = (total / 10).ceil() * 10.0;
    if (nextTen > total && !list.contains(nextTen)) {
      list.add(nextTen);
    }
    final nextFifty = (total / 50).ceil() * 50.0;
    if (nextFifty > total && !list.contains(nextFifty)) {
      list.add(nextFifty);
    }

    list.sort();
    final higher = list.where((n) => n > total).toList();
    final result = <double>[total];
    result.addAll(higher.take(3));
    return result;
  }

  StreamSubscription<List<ProductModel>>? _productSubscription;

  @override
  void initState() {
    super.initState();
    _initProductStream();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _productSubscription?.cancel();
    _searchController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _initProductStream() {
    setState(() => _loading = true);
    _productSubscription = _service.streamProducts().listen((products) {
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        
        // Remove items from the cart if they are deleted or made unavailable
        _cart.removeWhere((cartItem) => 
            !_allProducts.any((p) => p.id == cartItem.product.id));

        _applyFilter();
        _loading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }



  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchQuery = query.isEmpty ||
            p.name.toLowerCase().contains(query);
        final pCat = (p.category == null || p.category!.trim().isEmpty) ? 'Other' : p.category!.trim();
        final matchCat = _selectedCategory == 'All' || pCat == _selectedCategory;
        return matchQuery && matchCat;
      }).toList();
    });
  }

  void _addToCart(ProductModel product) {
    setState(() {
      final existing = _cart.where((i) => i.product.id == product.id).firstOrNull;
      if (existing != null) {
        existing.quantity++;
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _cart.remove(item);
      }
    });
  }

  void _deleteFromCart(CartItem item) {
    setState(() => _cart.remove(item));
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    final subtotal = _grandTotal;
    final result = await SplitPaymentSheet.show(
      context: context,
      totalAmount: subtotal,
      itemCount: _cartCount,
      initialCustomerName: _customerController.text.trim(),
    );

    if (result == null || !mounted) return;

    try {
      String? combinedNotes = result.notes;
      final modeTag = '[Mod: ${_orderType.toUpperCase()} | Meja: $_tableNumber]';
      combinedNotes = (combinedNotes == null || combinedNotes.trim().isEmpty)
          ? modeTag
          : '$modeTag | $combinedNotes';

      if (result.voucherCode != null && result.discountAmount > 0) {
        final voucherTag = '[Baucar: ${result.voucherCode} (-RM ${result.discountAmount.toStringAsFixed(2)})]';
        combinedNotes = '$voucherTag | $combinedNotes';
      } else if (_appliedVoucherCode != null && _voucherDiscount > 0) {
        final voucherTag = '[Baucar: $_appliedVoucherCode (-RM ${_voucherDiscount.toStringAsFixed(2)})]';
        combinedNotes = '$voucherTag | $combinedNotes';
      }

      await _service.submitOrder(
        items: _cart,
        total: result.total,
        customerName: result.customerName,
        notes: combinedNotes,
        paymentSplits: result.splits,
      );

      // Rekod penebusan baucar dalam Supabase jika baucar digunakan
      if (result.voucherId != null && result.discountAmount > 0) {
        try {
          await VoucherService().recordVoucherUsage(
            voucherId: result.voucherId!,
            discountAmount: result.discountAmount,
            orderSubtotal: subtotal,
            customerPhone: null,
          );
        } catch (_) {}
      } else if (_voucherId != null && _voucherDiscount > 0) {
        try {
          await VoucherService().recordVoucherUsage(
            voucherId: _voucherId!,
            discountAmount: _voucherDiscount,
            orderSubtotal: subtotal,
            customerPhone: null,
          );
        } catch (_) {}
      }

      if (!mounted) return;

      final summary = result.splits.map((s) => '${s.displayName}: RM ${s.amount.toStringAsFixed(2)}').join(', ');
      final discountText = result.discountAmount > 0 ? ' • Baucar: -RM ${result.discountAmount.toStringAsFixed(2)}' : '';
      final changeText = result.change > 0 ? ' • Baki Pulangan: RM ${result.change.toStringAsFixed(2)}' : '';

      showGlassToast(
        context,
        'Pesanan Selesai! ($summary$discountText$changeText)',
        customColor: const Color(0xFF00C853),
      );
      setState(() {
        _cart = [];
        _customerController.clear();
        _appliedVoucherCode = null;
        _voucherDiscount = 0.0;
        _voucherId = null;
        _orderSequence++;
      });
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Gagal membuat pesanan: $e', isError: true);
    }
  }

  Future<void> _openPaymentTerminal({TerminalStep initialStep = TerminalStep.chooseMethod}) async {
    if (_cart.isEmpty) return;
    final grandTotal = _grandTotal;
    final customer = _customerController.text.trim();
    final orderRef = 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final result = await PaymentTerminalModal.show(
      context: context,
      amount: grandTotal,
      orderTitle: 'Pesanan #$orderRef (${_cart.length} item)',
      customerName: customer.isNotEmpty ? customer : 'Pelanggan Kaunter',
      itemLines: _cart.map((i) => '${i.quantity}x ${i.product.name} | RM ${i.subtotal.toStringAsFixed(2)}').toList(),
      initialStep: initialStep,
    );

    if (result == null || !result.isSuccess || !mounted) return;

    try {
      String notes = '[Mod: ${_orderType.toUpperCase()} | Meja: $_tableNumber] [Terminal: ${result.paymentMethod.toUpperCase()}]';
      if (_appliedVoucherCode != null && _voucherDiscount > 0) {
        notes += ' [Baucar: $_appliedVoucherCode (-RM ${_voucherDiscount.toStringAsFixed(2)})]';
      }
      if (result.paymentMethod == 'cash' && result.change > 0) {
        notes += ' (Diterima: RM ${result.cashTendered.toStringAsFixed(2)}, Baki: RM ${result.change.toStringAsFixed(2)})';
      }

      await _service.submitOrder(
        items: _cart,
        total: grandTotal,
        customerName: customer.isNotEmpty ? customer : null,
        notes: notes,
        paymentSplits: [
          PaymentSplit(method: result.paymentMethod, amount: grandTotal),
        ],
      );

      if (_voucherId != null && _voucherDiscount > 0) {
        try {
          await VoucherService().recordVoucherUsage(
            voucherId: _voucherId!,
            discountAmount: _voucherDiscount,
            orderSubtotal: _cartTotal,
            customerPhone: null,
          );
        } catch (_) {}
      }

      if (!mounted) return;

      showGlassToast(
        context,
        'Pesanan Selesai! (${result.paymentMethod.toUpperCase()}: RM ${grandTotal.toStringAsFixed(2)})',
        customColor: const Color(0xFF00C853),
      );

      setState(() {
        _cart = [];
        _customerController.clear();
        _appliedVoucherCode = null;
        _voucherDiscount = 0.0;
        _voucherId = null;
        _orderSequence++;
      });
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Gagal membuat pesanan: $e', isError: true);
    }
  }

  // Fast Cash 1-Click Tender (Square & Toast POS high-speed cashier feature)
  Future<void> _handleQuickCash(double cashTendered) async {
    if (_cart.isEmpty) return;
    final grandTotal = _grandTotal;
    final change = (cashTendered - grandTotal).clamp(0.0, double.infinity);
    final customer = _customerController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payments_rounded, color: Color(0xFF00C853), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Bayaran Tunai Pantas',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jumlah Perlu Bayar:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  'RM ${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tunai Diterima:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  'RM ${cashTendered.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                ),
              ],
            ),
            const Divider(color: Color(0x22FFFFFF), height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BAKI PULANGAN:', style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(
                    'RM ${change.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Selesai & Buka Laci 🖨️',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      String notes = '[Mod: ${_orderType.toUpperCase()} | Meja: $_tableNumber] [Terminal: TUNAI PANTAS] (Diterima: RM ${cashTendered.toStringAsFixed(2)}, Baki: RM ${change.toStringAsFixed(2)})';
      if (_appliedVoucherCode != null && _voucherDiscount > 0) {
        notes += ' [Baucar: $_appliedVoucherCode (-RM ${_voucherDiscount.toStringAsFixed(2)})]';
      }

      await _service.submitOrder(
        items: _cart,
        total: grandTotal,
        customerName: customer.isNotEmpty ? customer : null,
        notes: notes,
        paymentSplits: [
          PaymentSplit(method: 'cash', amount: grandTotal),
        ],
      );

      if (_voucherId != null && _voucherDiscount > 0) {
        try {
          await VoucherService().recordVoucherUsage(
            voucherId: _voucherId!,
            discountAmount: _voucherDiscount,
            orderSubtotal: _cartTotal,
            customerPhone: null,
          );
        } catch (_) {}
      }

      if (!mounted) return;

      showGlassToast(
        context,
        'Tunai Selesai! Baki Pulangan: RM ${change.toStringAsFixed(2)}',
        customColor: const Color(0xFF00C853),
      );

      setState(() {
        _cart = [];
        _customerController.clear();
        _appliedVoucherCode = null;
        _voucherDiscount = 0.0;
        _voucherId = null;
        _orderSequence++;
      });
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Gagal membuat pesanan: $e', isError: true);
    }
  }

  void _showCustomerDialog() {
    final nameCtrl = TextEditingController(text: _customerController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Color(0xFF42A5F5), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Maklumat Pelanggan',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama atau no. telefon pelanggan untuk rekod pesanan & poin:',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nama / No. Telefon Pelanggan',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                hintText: 'Cth: En. Khairul / 012-3456789',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (_customerController.text.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _customerController.clear());
                Navigator.pop(ctx);
              },
              child: const Text('Padam', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _customerController.text = nameCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTableNumberDialog() {
    final tableCtrl = TextEditingController(text: _tableNumber);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF42A5F5), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pilih No. Meja / Token',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih meja pantas atau taip nombor meja/token:',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['01', '02', '03', '04', '05', '06', '07', '08', 'VIP 1', 'Luar'].map((t) {
                final isSel = _tableNumber == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: isSel,
                  selectedColor: const Color(0xFF42A5F5),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.white70,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _tableNumber = t);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tableCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombor / Nama Meja Kustom',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                hintText: 'Cth: Meja 12 / Token 99',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tableCtrl.text.trim().isNotEmpty) {
                setState(() => _tableNumber = tableCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVoucherDialog() {
    final voucherCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141424),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF00C853), size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Tebus Baucar / Kupon',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan kod baucar atau promosi yang sah:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: voucherCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                  decoration: InputDecoration(
                    labelText: 'Kod Baucar',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    hintText: 'Cth: DISKAUN10 / MERDEKA',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: _isApplyingVoucher ? null : () async {
                  final code = voucherCtrl.text.trim().toUpperCase();
                  if (code.isEmpty) return;

                  setModalState(() => _isApplyingVoucher = true);
                  final val = await VoucherService().validateVoucher(code: code, orderAmount: _cartTotal);
                  setModalState(() => _isApplyingVoucher = false);

                  if (!ctx.mounted) return;

                  if (val.isValid && val.discountAmount > 0) {
                    setState(() {
                      _appliedVoucherCode = code;
                      _voucherDiscount = val.discountAmount;
                      _voucherId = val.voucherId;
                    });
                    Navigator.pop(ctx);
                    showGlassToast(
                      context,
                      'Baucar berjaya ditebus! Jimat RM ${val.discountAmount.toStringAsFixed(2)}',
                      customColor: const Color(0xFF00C853),
                    );
                  } else {
                    showGlassToast(
                      context,
                      val.errorMessage ?? 'Kod baucar tidak sah atau telah tamat.',
                      isError: true,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isApplyingVoucher
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Gunakan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: _buildProductGrid()),
              const SizedBox(width: 20),
              SizedBox(
                width: constraints.maxWidth >= 1100 ? 380 : (constraints.maxWidth >= 900 ? 350 : 330),
                child: _buildCart(),
              ),
            ],
          );
        }

        return Stack(
          children: [
            _buildProductGrid(),
            if (_cart.isNotEmpty)
              Positioned(
                bottom: 90,
                left: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => ModalSheet.show(
                    context: context,
                    initialChildSize: 0.85,
                    builder: (ctx, _) => Column(
                      children: [
                        _buildOrderModeHeader(),
                        _buildCustomerBar(),
                        Expanded(child: _buildCartContent()),
                        _buildCartFooter(),
                      ],
                    ),
                  ),
                  child: _buildCartBadge(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProductGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search + category filters
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Category chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _categories
                .map((cat) => _buildCategoryChip(cat))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Grid
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF42A5F5),
                  ),
                )
              : _filteredProducts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 175,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, i) =>
                          _buildProductCard(_filteredProducts[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String cat) {
    final selected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = cat);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF42A5F5)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF42A5F5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          cat,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final inCart = _cart
        .where((i) => i.product.id == product.id)
        .map((i) => i.quantity)
        .firstOrNull;

    final hasImage = product.imageUrl != null && product.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: inCart != null
                ? const Color(0xFF42A5F5).withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inCart != null
                  ? const Color(0xFF42A5F5)
                  : Colors.white.withValues(alpha: 0.09),
              width: inCart != null ? 1.5 : 1.0,
            ),
            boxShadow: inCart != null
                ? [
                    BoxShadow(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                if (hasImage) ...[
                  // Card with Image
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Image
                      Expanded(
                        flex: 5,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(product.imageUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Bottom Details
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'RM ${product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      color: inCart != null
                                          ? const Color(0xFF42A5F5)
                                          : const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      inCart != null ? Icons.check_rounded : Icons.add_rounded,
                                      size: 13,
                                      color: inCart != null ? Colors.white : const Color(0xFF42A5F5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Card without Image (Clean, compact POS tile)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: category pill or icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (product.category != null && product.category!.trim().isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.category!,
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  size: 14,
                                  color: Colors.white38,
                                ),
                              ),
                            const SizedBox(width: 24), // Leave space for cart badge if inCart
                          ],
                        ),
                        // Middle: Product Name (occupies remaining height cleanly)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Bottom row: Price and Add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'RM ${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF42A5F5),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: inCart != null
                                    ? const Color(0xFF42A5F5)
                                    : Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                inCart != null ? Icons.check_rounded : Icons.add_rounded,
                                size: 15,
                                color: inCart != null ? Colors.white : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // In-Cart Badge at Top-Right
                if (inCart != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        '$inCart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              // Cart header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedShoppingCart01,
                      color: Color(0xFF42A5F5),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_cart.isNotEmpty)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _cart = []),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: Color(0x1AFFFFFF),
              ),

              // Cart items
              Expanded(child: _buildCartContent()),

              // Total + checkout
              _buildCartFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedShoppingCart01,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Cart is empty',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _cart.length,
      separatorBuilder: (_, __) =>
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
      itemBuilder: (_, i) => _buildCartRow(_cart[i]),
    );
  }

  Widget _buildCartRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'RM ${item.product.price.toStringAsFixed(2)} × ${item.quantity}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _cartBtn(
                Icons.remove_rounded,
                () => _removeFromCart(item),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _cartBtn(
                Icons.add_rounded,
                () => _addToCart(item.product),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteFromCart(item),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete01,
              color: Colors.redAccent.withValues(alpha: 0.7),
              size: 18,
              strokeWidth: 2.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCartFooter() {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        children: [
          // Customer name
          TextField(
            controller: _customerController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Customer name (optional)',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF42A5F5)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                fmt.format(_cartTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step 1: Caj RM XX.XX (Direct 4-Step Terminal Flow)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : _openPaymentTerminal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED1164),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFED1164).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                shadowColor: const Color(0xFFED1164).withValues(alpha: 0.35),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _cart.isEmpty ? 'Pilih Produk Dahulu' : 'Caj ${fmt.format(_cartTotal)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary: Split payment & voucher options
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _cart.isEmpty ? null : _checkout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text(
                'Pecah Bayaran & Baucar (Split)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBadge() {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedShoppingCart01,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_cartCount item${_cartCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                fmt.format(_cartTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
