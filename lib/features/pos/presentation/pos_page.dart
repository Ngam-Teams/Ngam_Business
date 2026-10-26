import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../pos/data/pos_service.dart';
import '../../pos/models/product_model.dart';
import '../../pos/models/order_model.dart';
import '../../promotions/data/voucher_service.dart';
import '../../customers/data/membership_service.dart';
import 'widgets/split_payment_sheet.dart';
import 'widgets/payment_terminal_modal.dart';
import 'widgets/dynamic_pos_scanner_modal.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/modal_sheet.dart';
import '../../../../core/services/sound_service.dart';

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
  CustomerMember? _selectedMember;

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
    if (_allProducts.isEmpty) {
      setState(() => _loading = true);
    }
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
    // Inventory & Stock Check for physical products
    if (product.isProduct && product.trackInventory) {
      if (product.stock <= 0) {
        SoundService.instance.playErrorBeep();
        showGlassToast(
          context,
          'Stok Habis! "${product.name}" tiada baki dalam inventori.',
          isError: true,
        );
        return;
      }

      final existing = _cart.where((i) => i.product.id == product.id).firstOrNull;
      if (existing != null && existing.quantity >= product.stock) {
        SoundService.instance.playErrorBeep();
        showGlassToast(
          context,
          'Had stok maksimum dicapai (Baki: ${product.stock} ${product.unit}).',
          isError: true,
        );
        return;
      }
    }

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
      if (_selectedMember != null) {
        try {
          await MembershipService().recordVisit(
            phone: _selectedMember!.phone,
            amountSpent: subtotal,
          );
        } catch (_) {}
      }

      setState(() {
        _cart = [];
        _customerController.clear();
        _selectedMember = null;
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
      customerName: _selectedMember != null
          ? '${_selectedMember!.name} (${_selectedMember!.phone})'
          : (customer.isNotEmpty ? customer : 'Pelanggan Kaunter'),
      itemLines: _cart.map((i) => '${i.quantity}x ${i.product.name}${i.isReward ? " (🎁 Ganjaran)" : ""} | RM ${i.subtotal.toStringAsFixed(2)}').toList(),
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

      if (_selectedMember != null) {
        try {
          await MembershipService().recordVisit(
            phone: _selectedMember!.phone,
            amountSpent: result.amount,
          );
        } catch (_) {}
      }

      setState(() {
        _cart = [];
        _customerController.clear();
        _selectedMember = null;
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

      if (_selectedMember != null) {
        try {
          await MembershipService().recordVisit(
            phone: _selectedMember!.phone,
            amountSpent: grandTotal,
          );
        } catch (_) {}
      }

      setState(() {
        _cart = [];
        _customerController.clear();
        _selectedMember = null;
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

  Future<void> _showDynamicScanner() async {
    final result = await DynamicPosScannerModal.show(
      context: context,
      currentSubtotal: _cartTotal,
      availableProducts: _allProducts,
      currentMember: _selectedMember,
    );

    if (result == null || !mounted) return;

    switch (result.type) {
      case DynamicScanType.member:
        setState(() {
          _selectedMember = result.member;
          _customerController.text = '${result.member!.name} (${result.member!.phone})';
        });
        showGlassToast(
          context,
          'Ahli Dipautkan: ${result.member!.name} [${result.member!.tierBadge}]',
          customColor: const Color(0xFF00C853),
        );
        break;

      case DynamicScanType.freeRewardItem:
        final rewardProd = result.rewardProduct ??
            ProductModel(
              id: 'reward-${DateTime.now().millisecondsSinceEpoch}',
              name: result.rewardItemName ?? 'Ganjaran Percuma',
              itemType: 'product',
              price: 0.0,
            );

        setState(() {
          _cart.add(CartItem(
            product: rewardProd,
            quantity: 1,
            isReward: true,
            rewardDescription: 'Penebusan Ganjaran: ${result.rewardItemName}',
          ));
        });
        showGlassToast(
          context,
          result.message,
          customColor: const Color(0xFFFF9800),
        );
        break;

      case DynamicScanType.voucherDiscount:
        setState(() {
          _appliedVoucherCode = result.voucherCode;
          _voucherDiscount = result.discountAmount;
          _voucherId = result.voucherId;
        });
        showGlassToast(
          context,
          result.message,
          customColor: const Color(0xFF00C853),
        );
        break;
    }
  }

  void _showVoucherDialog() => _showDynamicScanner();

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

        // Stock Alert Banner if any products are out of stock or low stock
        _buildStockAlertBanner(),

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

  Widget _buildStockAlertBanner() {
    final alertItems = _allProducts
        .where((p) => p.isProduct && p.trackInventory && (p.isLowStock || p.isOutOfStock))
        .toList();

    if (alertItems.isEmpty) return const SizedBox.shrink();

    final outOfStockCount = alertItems.where((p) => p.isOutOfStock).length;
    final lowStockCount = alertItems.where((p) => p.isLowStock).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Perhatian: ${outOfStockCount > 0 ? "$outOfStockCount habis stok, " : ""}$lowStockCount item stok rendah.',
              style: const TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _showLowStockReviewSheet(alertItems),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Semak', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFB74D), size: 9),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLowStockReviewSheet(List<ProductModel> alertItems) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          constraints: const BoxConstraints(maxHeight: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, color: Color(0xFFFF9800), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Senarai Amaran Stok & Inventori',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Item di bawah memerlukan penambahan stok segera untuk mengelakkan gangguan jualan.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: alertItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = alertItems[idx];
                    final isOut = item.isOutOfStock;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOut
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : const Color(0xFFFF9800).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isOut ? Colors.redAccent : const Color(0xFFFF9800)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isOut ? Icons.block_rounded : Icons.warning_amber_rounded,
                              color: isOut ? Colors.redAccent : const Color(0xFFFF9800),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'RM ${item.price.toStringAsFixed(2)} · Had Minima: ${item.lowStockThreshold} ${item.unit}',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isOut ? Colors.redAccent : const Color(0xFFFF9800)).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOut ? '0 (HABIS)' : '${item.stock} ${item.unit}',
                              style: TextStyle(
                                color: isOut ? Colors.redAccent : const Color(0xFFFFB74D),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
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
        );
      },
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'RM ${product.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF42A5F5),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (product.isProduct && product.trackInventory)
                                        Text(
                                          product.isOutOfStock ? 'Habis stok' : '${product.stock} dlm stok',
                                          style: TextStyle(
                                            color: product.isOutOfStock
                                                ? Colors.redAccent
                                                : (product.isLowStock ? const Color(0xFFFF9800) : Colors.white38),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'RM ${product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFF42A5F5),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (product.isProduct && product.trackInventory)
                                  Text(
                                    product.isOutOfStock
                                        ? 'Habis stok'
                                        : (product.isLowStock
                                            ? 'Tinggal ${product.stock} ${product.unit}'
                                            : 'Baki: ${product.stock} ${product.unit}'),
                                    style: TextStyle(
                                      color: product.isOutOfStock
                                          ? Colors.redAccent
                                          : (product.isLowStock ? const Color(0xFFFF9800) : Colors.white38),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
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

                // Out of stock dark tint overlay
                if (product.isProduct && product.trackInventory && product.isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),

                // Out of Stock Badge at Top-Left
                if (product.isProduct && product.trackInventory && product.isOutOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block_rounded, size: 9, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'HABIS STOK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // Low Stock Badge at Top-Left
                else if (product.isProduct && product.trackInventory && product.isLowStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Tinggal ${product.stock}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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
            color: const Color(0xFF141424),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Order Type Switcher & Ticket Header
              _buildOrderModeHeader(),

              // 2. Customer VIP / Walk-in Bar
              _buildCustomerBar(),

              const Divider(
                height: 1,
                color: Color(0x1AFFFFFF),
              ),

              // 3. Cart Items (Scrollable)
              Expanded(child: _buildCartContent()),

              // 4. Enterprise Breakdown, Fast Cash Chips & Emerald Pay Button
              _buildCartFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderModeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Segmented order type switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                _orderTypeChip('dine_in', 'Makan Sini', Icons.restaurant_rounded),
                _orderTypeChip('takeaway', 'Bungkus', Icons.takeout_dining_rounded),
                _orderTypeChip('delivery', 'Hantar', Icons.delivery_dining_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Sub-bar: Ticket No, Table / Mode Pill, Clear
          Row(
            children: [
              // Ticket Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#NG-$_orderSequence',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Table or Delivery Pill
              if (_orderType == 'dine_in')
                GestureDetector(
                  onTap: _showTableNumberDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_restaurant_rounded, color: Color(0xFF42A5F5), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'Meja $_tableNumber',
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.edit_rounded, color: Color(0xFF42A5F5), size: 10),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _orderType == 'takeaway' ? 'Bawa Pulang 🛍️' : 'Penghantaran 🛵',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const Spacer(),

              // Clear button
              if (_cart.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _cart = [];
                      _appliedVoucherCode = null;
                      _voucherDiscount = 0.0;
                      _voucherId = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Padam Troli',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderTypeChip(String type, String label, IconData icon) {
    final isSel = _orderType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orderType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF42A5F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSel ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : Colors.white60,
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerBar() {
    final hasCustomer = _customerController.text.trim().isNotEmpty || _selectedMember != null;
    final displayName = _selectedMember != null
        ? _selectedMember!.name
        : (_customerController.text.trim().isNotEmpty ? _customerController.text.trim() : 'Pelanggan Tetamu (Walk-in)');

    final subtitle = _selectedMember != null
        ? '${_selectedMember!.tierBadge} • ${_selectedMember!.stamps}/${_selectedMember!.totalStampsRequired} Cop • ${_selectedMember!.points} Mata'
        : (hasCustomer ? 'Rekod Pesanan Pelanggan' : '+ Tekan atau imbas untuk kenalpasti ahli');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _selectedMember != null
            ? (_selectedMember!.isVip
                ? Colors.amber.withValues(alpha: 0.1)
                : const Color(0xFF00C853).withValues(alpha: 0.08))
            : (hasCustomer
                ? const Color(0xFF42A5F5).withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selectedMember != null
              ? (_selectedMember!.isVip ? Colors.amber.withValues(alpha: 0.35) : const Color(0xFF00C853).withValues(alpha: 0.3))
              : (hasCustomer ? const Color(0xFF42A5F5).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _selectedMember != null
                  ? (_selectedMember!.isVip ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFF00C853).withValues(alpha: 0.2))
                  : (hasCustomer ? const Color(0xFF42A5F5).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedMember != null ? Icons.stars_rounded : (hasCustomer ? Icons.person_rounded : Icons.person_outline_rounded),
              size: 15,
              color: _selectedMember != null
                  ? (_selectedMember!.isVip ? Colors.amber : const Color(0xFF00C853))
                  : (hasCustomer ? const Color(0xFF42A5F5) : Colors.white60),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _showCustomerDialog,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: hasCustomer ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _selectedMember != null
                          ? (_selectedMember!.isVip ? Colors.amber : const Color(0xFF00C853))
                          : (hasCustomer ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.45)),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dynamic Scanner Quick Action
          GestureDetector(
            onTap: _showDynamicScanner,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 13, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'Imbas Pintar',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (hasCustomer) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _customerController.clear();
                _selectedMember = null;
              }),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    if (_cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedShoppingCart01,
                  color: Colors.white30,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Troli Kosong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tekan produk di sebelah kiri untuk mula menambah pesanan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _cart.length,
      separatorBuilder: (_, __) =>
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
      itemBuilder: (_, i) => _buildCartRow(_cart[i]),
    );
  }

  Widget _buildCartRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product name and unit price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.isReward) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '🎁 GANJARAN',
                          style: TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item.product.name,
                        style: TextStyle(
                          color: item.isReward ? const Color(0xFFFFB74D) : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.isReward
                      ? 'Penebusan Ganjaran • Percuma (RM 0.00)'
                      : 'RM ${item.product.price.toStringAsFixed(2)} / unit',
                  style: TextStyle(
                    color: item.isReward ? const Color(0xFFFF9800) : Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontFamily: item.isReward ? null : 'monospace',
                    fontWeight: item.isReward ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // Stepper [-] count [+]
          Row(
            children: [
              _cartBtn(
                Icons.remove_rounded,
                () => _removeFromCart(item),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              _cartBtn(
                Icons.add_rounded,
                () => _addToCart(item.product),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Line subtotal
          Text(
            item.isReward ? 'RM 0.00' : 'RM ${item.subtotal.toStringAsFixed(2)}',
            style: TextStyle(
              color: item.isReward ? const Color(0xFFFF9800) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(width: 6),
          // Delete icon
          GestureDetector(
            onTap: () => _deleteFromCart(item),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
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
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }

  Widget _buildCartFooter() {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Financial Breakdown (Subtotal, Voucher, Rounding, Grand Total)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal ($_cartCount ${_cartCount == 1 ? 'item' : 'items'})',
                      style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                    ),
                    Text(
                      fmt.format(_cartTotal),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Voucher Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Baucar / Promosi',
                      style: TextStyle(color: Colors.white60, fontSize: 11.5),
                    ),
                    if (_appliedVoucherCode != null && _voucherDiscount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '-RM ${_voucherDiscount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00C853),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _appliedVoucherCode = null;
                                _voucherDiscount = 0.0;
                                _voucherId = null;
                              });
                            },
                            child: const Icon(Icons.cancel_rounded, size: 14, color: Colors.redAccent),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: _showVoucherDialog,
                        child: const Text(
                          '+ Tebus Kod',
                          style: TextStyle(
                            color: Color(0xFF42A5F5),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),

                // Rounding row (if non-zero)
                if (_roundingAmount.abs() > 0.001) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Penyelarasan (5-Sen)',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        '${_roundingAmount >= 0 ? '+' : ''}RM ${_roundingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],

                const Divider(color: Color(0x1AFFFFFF), height: 16),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JUMLAH BESAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Termasuk Cukai SST',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      fmt.format(_grandTotal),
                      style: const TextStyle(
                        color: Color(0xFF00C853),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Fast Cash Tender Chips (1-Click Drawer Open)
          if (_cart.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💵 TUNAI PANTAS:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    '1-Klik Selesai',
                    style: TextStyle(
                      color: const Color(0xFF00C853).withValues(alpha: 0.8),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickCashOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final opt = _quickCashOptions[i];
                  final isExact = (opt - _grandTotal).abs() < 0.01;
                  return InkWell(
                    onTap: () => _handleQuickCash(opt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isExact
                            ? const Color(0xFF00C853).withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isExact
                              ? const Color(0xFF00C853).withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        isExact ? 'Tepat (${opt.toStringAsFixed(2)})' : 'RM ${opt.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isExact ? const Color(0xFF00C853) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 3. Primary Pay Button (Emerald Green #00C853 Corporate)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _cart.isEmpty
                  ? null
                  : () => _openPaymentTerminal(initialStep: TerminalStep.chooseMethod),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF00C853).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                shadowColor: const Color(0xFF00C853).withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BAYAR SEKARANG',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _cart.isEmpty ? 'Pilih Produk Dahulu' : 'Pilih Kaedah Bayaran',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fmt.format(_grandTotal),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Bar Pintasan Kaedah Bayaran (Quick Payment Methods Bar)
          Row(
            children: [
              _quickMethodBtn(
                'DuitNow',
                Icons.qr_code_rounded,
                _cart.isEmpty ? null : () => _openPaymentTerminal(initialStep: TerminalStep.showQr),
              ),
              const SizedBox(width: 6),
              _quickMethodBtn(
                'Tunai',
                Icons.payments_rounded,
                _cart.isEmpty ? null : () => _openPaymentTerminal(initialStep: TerminalStep.cashTender),
              ),
              const SizedBox(width: 6),
              _quickMethodBtn(
                'Kad/EDC',
                Icons.credit_card_rounded,
                _cart.isEmpty ? null : () => _openPaymentTerminal(initialStep: TerminalStep.cardPayment),
              ),
              const SizedBox(width: 6),
              _quickMethodBtn(
                'Pecah Bil',
                Icons.alt_route_rounded,
                _cart.isEmpty ? null : _checkout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickMethodBtn(String label, IconData icon, VoidCallback? onTap) {
    return Expanded(
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.white.withValues(alpha: 0.03),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: const Color(0xFF42A5F5)),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
            color: const Color(0xFF00C853).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C853).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_cartCount ${_cartCount == 1 ? 'item' : 'items'} • ${_orderType.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                fmt.format(_grandTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'monospace',
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
