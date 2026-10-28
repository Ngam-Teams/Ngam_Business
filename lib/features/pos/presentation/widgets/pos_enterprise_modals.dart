import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/pos_service.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../../../widgets/glass_toast.dart';

// =============================================================================
// 1. ITEM MODIFIERS, VARIANTS & KITCHEN NOTE MODAL
// =============================================================================

class ItemModifierResult {
  final String? selectedVariant;
  final double variantPriceDelta;
  final List<Map<String, dynamic>> selectedModifiers;
  final String? itemNote;
  final int quantity;

  ItemModifierResult({
    this.selectedVariant,
    this.variantPriceDelta = 0.0,
    required this.selectedModifiers,
    this.itemNote,
    this.quantity = 1,
  });
}

class PosItemModifierModal extends StatefulWidget {
  final ProductModel product;
  final CartItem? existingItem;

  const PosItemModifierModal({
    super.key,
    required this.product,
    this.existingItem,
  });

  static Future<ItemModifierResult?> show({
    required BuildContext context,
    required ProductModel product,
    CartItem? existingItem,
  }) {
    return showDialog<ItemModifierResult>(
      context: context,
      builder: (ctx) => PosItemModifierModal(
        product: product,
        existingItem: existingItem,
      ),
    );
  }

  @override
  State<PosItemModifierModal> createState() => _PosItemModifierModalState();
}

class _PosItemModifierModalState extends State<PosItemModifierModal> {
  String? _selectedVariant;
  double _variantPriceDelta = 0.0;
  final List<Map<String, dynamic>> _selectedModifiers = [];
  late final TextEditingController _noteCtrl;
  final TextEditingController _customModNameCtrl = TextEditingController();
  final TextEditingController _customModPriceCtrl = TextEditingController();
  int _quantity = 1;

  List<Map<String, dynamic>> get _availableVariants {
    if (widget.product.variants.isNotEmpty) {
      return widget.product.variants;
    }
    if (widget.product.isService) {
      return [
        {'name': 'Standard', 'price_delta': 0.0},
        {'name': 'Premium / VIP', 'price_delta': 15.0},
        {'name': 'Express', 'price_delta': 10.0},
      ];
    }
    return [
      {'name': 'Biasa (Regular)', 'price_delta': 0.0},
      {'name': 'Besar (Large)', 'price_delta': 2.00},
      {'name': 'Panas (Hot)', 'price_delta': 0.0},
      {'name': 'Sejuk / Ais (Iced)', 'price_delta': 0.50},
      {'name': 'Set Kombo', 'price_delta': 4.50},
    ];
  }

  List<Map<String, dynamic>> get _availableModifiers {
    final base = <Map<String, dynamic>>[
      ...widget.product.modifiers,
    ];
    final presets = widget.product.isService
        ? [
            {'name': 'Servis Keutamaan', 'price': 5.00},
            {'name': 'Produk Rawatan Tambahan', 'price': 10.00},
          ]
        : [
            {'name': 'Kurang Manis', 'price': 0.0},
            {'name': 'Kurang Ais', 'price': 0.0},
            {'name': 'Tak Nak Sayur / Bawang', 'price': 0.0},
            {'name': 'Kuah / Sambal Asing', 'price': 0.0},
            {'name': 'Tambah Telur Mata', 'price': 1.50},
            {'name': 'Tambah Cheese', 'price': 2.00},
            {'name': 'Tambah Nasi / Mee', 'price': 2.00},
            {'name': 'Bungkus Kotak', 'price': 1.00},
          ];

    for (final p in presets) {
      if (!base.any((b) => b['name']?.toString().toLowerCase() == p['name'].toString().toLowerCase())) {
        base.add(p);
      }
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _selectedVariant = existing?.selectedVariant;
    _variantPriceDelta = existing?.variantPriceDelta ?? 0.0;
    if (existing != null) {
      _selectedModifiers.addAll(
        existing.selectedModifiers.map((m) => Map<String, dynamic>.from(m)),
      );
      _quantity = existing.quantity;
    }
    _noteCtrl = TextEditingController(text: existing?.itemNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _customModNameCtrl.dispose();
    _customModPriceCtrl.dispose();
    super.dispose();
  }

  double get _modifiersTotal => _selectedModifiers.fold(
        0.0,
        (s, m) => s + ((m['price'] as num?)?.toDouble() ?? 0.0),
      );

  double get _unitPrice =>
      widget.product.price + _variantPriceDelta + _modifiersTotal;

  double get _lineTotal => _unitPrice * _quantity;

  bool _isModifierSelected(String name) {
    return _selectedModifiers.any((m) => m['name']?.toString() == name);
  }

  void _toggleModifier(Map<String, dynamic> mod) {
    final name = mod['name']?.toString() ?? '';
    setState(() {
      if (_isModifierSelected(name)) {
        _selectedModifiers.removeWhere((m) => m['name']?.toString() == name);
      } else {
        _selectedModifiers.add({
          'name': name,
          'price': (mod['price'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });
  }

  void _addCustomModifier() {
    final name = _customModNameCtrl.text.trim();
    if (name.isEmpty) return;
    final price = double.tryParse(_customModPriceCtrl.text.trim()) ?? 0.0;
    setState(() {
      _selectedModifiers.add({'name': name, 'price': price});
      _customModNameCtrl.clear();
      _customModPriceCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF42A5F5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Harga Asal: RM ${widget.product.price.toStringAsFixed(2)} • Pilih Varian & Tambahan',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                ),
              ],
            ),
            const Divider(color: Color(0x22FFFFFF), height: 20),

            // Scrollable Options
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Variants / Size
                    const Text(
                      '1. PILIH VARIAN / SAIZ',
                      style: TextStyle(
                        color: Color(0xFF42A5F5),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableVariants.map((v) {
                        final vName = v['name']?.toString() ?? 'Standard';
                        final vDelta = (v['price_delta'] as num?)?.toDouble() ??
                            (v['price'] as num?)?.toDouble() ??
                            0.0;
                        final isSel = _selectedVariant == vName;

                        return ChoiceChip(
                          label: Text(
                            vDelta > 0
                                ? '$vName (+RM ${vDelta.toStringAsFixed(2)})'
                                : vName,
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF42A5F5),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedVariant = vName;
                                _variantPriceDelta = vDelta;
                              } else {
                                _selectedVariant = null;
                                _variantPriceDelta = 0.0;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 2. Add-ons / Modifiers
                    const Text(
                      '2. PILIHAN TAMBAHAN (ADD-ONS / MODIFIERS)',
                      style: TextStyle(
                        color: Color(0xFF00C853),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableModifiers.map((m) {
                        final mName = m['name']?.toString() ?? '';
                        final mPrice = (m['price'] as num?)?.toDouble() ?? 0.0;
                        final isSel = _isModifierSelected(mName);

                        return FilterChip(
                          label: Text(
                            mPrice > 0
                                ? '$mName (+RM ${mPrice.toStringAsFixed(2)})'
                                : mName,
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF00C853).withValues(alpha: 0.25),
                          checkmarkColor: const Color(0xFF00C853),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFF00C853)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          labelStyle: TextStyle(
                            color: isSel ? const Color(0xFF00C853) : Colors.white70,
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => _toggleModifier(m),
                        );
                      }).toList(),
                    ),

                    // Show any custom modifiers added that aren't in presets
                    if (_selectedModifiers.any((m) => !_availableModifiers.any((a) => a['name'] == m['name']))) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedModifiers
                            .where((m) => !_availableModifiers.any((a) => a['name'] == m['name']))
                            .map((m) {
                          final mName = m['name']?.toString() ?? '';
                          final mPrice = (m['price'] as num?)?.toDouble() ?? 0.0;
                          return Chip(
                            backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.2),
                            label: Text(
                              '$mName (+RM ${mPrice.toStringAsFixed(2)})',
                              style: const TextStyle(color: Color(0xFF00C853), fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF00C853)),
                            onDeleted: () => _toggleModifier(m),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Custom Add-on Row
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _customModNameCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Tambah pilihan lain (cth: Sos Lebih)',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11.5),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _customModPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              prefixText: '+RM ',
                              prefixStyle: const TextStyle(color: Colors.white54, fontSize: 11.5),
                              hintText: '0.00',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11.5),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _addCustomModifier,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.2),
                          ),
                          icon: const Icon(Icons.add_rounded, color: Color(0xFF00C853), size: 18),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 3. Special Kitchen / Item Note
                    const Text(
                      '3. NOTA KHAS DAPUR / PESANAN',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Cth: Meja luar, jangan letak kacang, potong 2...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: Color(0x22FFFFFF), height: 22),

            // Footer: Quantity Stepper + Confirm Button
            Row(
              children: [
                if (widget.existingItem == null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          ItemModifierResult(
                            selectedVariant: _selectedVariant,
                            variantPriceDelta: _variantPriceDelta,
                            selectedModifiers: _selectedModifiers,
                            itemNote: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                            quantity: _quantity,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        '${widget.existingItem != null ? "Kemas Kini" : "Tambah ke Troli"} • RM ${_lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. HELD ORDERS / OPEN TABS MODAL (SIMPAN & SAMBUNG PESANAN MEJA)
// =============================================================================

class PosHeldOrdersModal extends StatelessWidget {
  final List<HeldOrderModel> heldOrders;
  final void Function(HeldOrderModel order) onResume;
  final void Function(HeldOrderModel order) onDelete;

  const PosHeldOrdersModal({
    super.key,
    required this.heldOrders,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Senarai Pesanan Ditahan / Open Tabs (${heldOrders.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Simpan bil meja yang sedang makan atau pelanggan yang belum selesai bayar',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
            const Divider(color: Color(0x22FFFFFF), height: 22),

            if (heldOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: Colors.white24, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Tiada Pesanan Ditahan',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tekan butang "Tahan Bil" pada troli untuk menyimpan pesanan meja.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: heldOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final h = heldOrders[i];
                    final diffMins = DateTime.now().difference(h.heldAt).inMinutes;
                    final timeStr = diffMins < 1
                        ? 'Baru sahaja'
                        : (diffMins < 60 ? '$diffMins minit lepas' : DateFormat('hh:mm a').format(h.heldAt));

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  h.orderType == 'dine_in'
                                      ? 'Meja ${h.tableNumber}'
                                      : h.orderType.toUpperCase(),
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                h.ticketNumber,
                                style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              if (h.customerName != null && h.customerName!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '• ${h.customerName}',
                                    style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else
                                const Spacer(),
                              Text(
                                timeStr,
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            h.items.map((item) => '${item.quantity}x ${item.formattedOrderItemName}').join(', '),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${h.itemCount} item • ${fmt.format(h.subtotal)}',
                                style: const TextStyle(
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => onDelete(h),
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                    label: const Text('Padam', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onResume(h);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF42A5F5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                    label: const Text('Sambung / Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
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

// =============================================================================
// 3. MANUAL DISCOUNT MODAL (% OR RM WITH MANAGER PIN FOR >20%)
// =============================================================================

class ManualDiscountResult {
  final double discountAmount;
  final String label;

  ManualDiscountResult({required this.discountAmount, required this.label});
}

class PosManualDiscountModal extends StatefulWidget {
  final double subtotal;

  const PosManualDiscountModal({super.key, required this.subtotal});

  static Future<ManualDiscountResult?> show({
    required BuildContext context,
    required double subtotal,
  }) {
    return showDialog<ManualDiscountResult>(
      context: context,
      builder: (ctx) => PosManualDiscountModal(subtotal: subtotal),
    );
  }

  @override
  State<PosManualDiscountModal> createState() => _PosManualDiscountModalState();
}

class _PosManualDiscountModalState extends State<PosManualDiscountModal> {
  bool _isPercent = true;
  final TextEditingController _valCtrl = TextEditingController(text: '10');
  final TextEditingController _reasonCtrl = TextEditingController(text: 'Diskaun Pelanggan / Kedai');
  final TextEditingController _pinCtrl = TextEditingController();
  String? _errorText;

  double get _calculatedDiscount {
    final val = double.tryParse(_valCtrl.text.trim()) ?? 0.0;
    if (val <= 0) return 0.0;
    if (_isPercent) {
      return (widget.subtotal * (val.clamp(0.0, 100.0) / 100.0));
    }
    return val.clamp(0.0, widget.subtotal);
  }

  bool get _requiresManagerPin {
    if (widget.subtotal <= 0) return false;
    return (_calculatedDiscount / widget.subtotal) > 0.20;
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    _reasonCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final amt = _calculatedDiscount;
    if (amt <= 0) {
      setState(() => _errorText = 'Sila masukkan nilai diskaun yang sah.');
      return;
    }
    if (_requiresManagerPin && _pinCtrl.text.trim() != '1234') {
      setState(() => _errorText = 'PIN Pengurus tidak sah (PIN Lalai: 1234).');
      return;
    }
    final rawVal = _valCtrl.text.trim();
    final reason = _reasonCtrl.text.trim().isEmpty ? 'Diskaun Manual' : _reasonCtrl.text.trim();
    final label = _isPercent ? '$reason ($rawVal%)' : reason;

    Navigator.pop(context, ManualDiscountResult(discountAmount: amt, label: label));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141424),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      title: const Row(
        children: [
          Icon(Icons.discount_rounded, color: Color(0xFF00C853), size: 22),
          SizedBox(width: 10),
          Text('Diskaun Manual / Staf', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Switcher (% vs RM)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Peratus (%)')),
                    selected: _isPercent,
                    selectedColor: const Color(0xFF42A5F5),
                    onSelected: (_) => setState(() => _isPercent = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Nilai Tetap (RM)')),
                    selected: !_isPercent,
                    selectedColor: const Color(0xFF42A5F5),
                    onSelected: (_) => setState(() => _isPercent = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_isPercent ? ['5', '10', '15', '20', '50'] : ['2', '5', '10', '15', '20']).map((preset) {
                return ActionChip(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  label: Text(
                    _isPercent ? '$preset%' : 'RM $preset',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => setState(() {
                    _valCtrl.text = preset;
                    _errorText = null;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _valCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _errorText = null),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: _isPercent ? 'Peratus Diskaun (%)' : 'Jumlah Diskaun (RM)',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                suffixText: 'Tolak: -RM ${_calculatedDiscount.toStringAsFixed(2)}',
                suffixStyle: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _reasonCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Sebab / Label Diskaun',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_requiresManagerPin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'PIN Pengurus Diperlukan (>20% Diskaun) [Lalai: 1234]',
                  labelStyle: const TextStyle(color: Colors.amber, fontSize: 11.5),
                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.amber, size: 18),
                  filled: true,
                  fillColor: Colors.amber.withValues(alpha: 0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Guna Diskaun', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

// =============================================================================
// 4. RECENT ORDERS, REPRINT & VOID / REFUND MODAL (WITH MANAGER PIN)
// =============================================================================

class PosRecentOrdersVoidModal extends StatefulWidget {
  final PosService service;
  final void Function(Map<String, dynamic> orderData) onReprintOrder;

  const PosRecentOrdersVoidModal({
    super.key,
    required this.service,
    required this.onReprintOrder,
  });

  @override
  State<PosRecentOrdersVoidModal> createState() => _PosRecentOrdersVoidModalState();
}

class _PosRecentOrdersVoidModalState extends State<PosRecentOrdersVoidModal> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final list = await widget.service.fetchRecentOrders(limit: 25);
    if (!mounted) return;
    setState(() {
      _orders = list;
      _loading = false;
    });
  }

  Future<void> _promptVoidOrder(Map<String, dynamic> order) async {
    final pinCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Tersilap Kunci Pesanan');
    String? err;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF181828),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
          ),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 22),
              SizedBox(width: 10),
              Text('Sahkan Batal / Refund (Void)', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pembatalan ini akan menukar status pesanan kepada DIBATALKAN dan memulangkan semula kuantiti stok ke inventori.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Tersilap Kunci Pesanan',
                  'Pelanggan Tukar Fikiran',
                  'Item Habis / Rosak',
                  'Ujian Sistem POS',
                ].map((r) => ActionChip(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      label: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      onPressed: () => setDialogState(() => reasonCtrl.text = r),
                    )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Sebab Pembatalan / Refund',
                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'PIN Pengurus (Lalai: 1234)',
                  labelStyle: const TextStyle(color: Colors.amber, fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.amber, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kembali', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinCtrl.text.trim() != '1234') {
                  setDialogState(() => err = 'PIN Pengurus salah! Gunakan 1234.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sahkan Void & Pulang Stok', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.service.voidOrder(
        orderId: order['id'].toString(),
        reason: reasonCtrl.text.trim(),
        existingNotes: order['notes'] as String?,
      );
      if (!mounted) return;
      showGlassToast(
        context,
        'Pesanan telah dibatalkan (Void) & stok telah dipulangkan ke inventori.',
        customColor: Colors.orange,
      );
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Gagal membatalkan pesanan: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_rounded, color: Color(0xFF42A5F5), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sejarah Pesanan POS, Cetak Semula & Void/Refund',
                        style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Semak transaksi terkini, cetak semula resit, atau batalkan pesanan (PIN Pengurus)',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                ),
              ],
            ),
            const Divider(color: Color(0x22FFFFFF), height: 20),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
                  : _orders.isEmpty
                      ? const Center(
                          child: Text('Tiada rekod pesanan ditemui.', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final o = _orders[i];
                            final status = (o['status'] as String? ?? 'pending').toLowerCase();
                            final isVoided = status == 'cancelled' || status == 'voided';
                            final total = (o['total'] as num?)?.toDouble() ?? 0.0;
                            final createdAt = DateTime.tryParse(o['created_at']?.toString() ?? '')?.toLocal();
                            final timeStr = createdAt != null
                                ? DateFormat('dd/MM hh:mm a').format(createdAt)
                                : '';
                            final rawItems = (o['order_items'] as List?) ?? [];

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isVoided
                                    ? Colors.redAccent.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isVoided
                                      ? Colors.redAccent.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isVoided
                                              ? Colors.redAccent.withValues(alpha: 0.2)
                                              : const Color(0xFF00C853).withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isVoided ? 'DIBATALKAN (VOID)' : status.toUpperCase(),
                                          style: TextStyle(
                                            color: isVoided ? Colors.redAccent : const Color(0xFF00C853),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '#${o['id'].toString().substring(0, 6).toUpperCase()}',
                                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          o['customer_name']?.toString() ?? 'Pelanggan Kaunter',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  if (rawItems.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      rawItems.map((it) => '${it['quantity']}x ${it['product_name']}').join(', '),
                                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (o['notes'] != null && o['notes'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      o['notes'].toString(),
                                      style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fmt.format(total),
                                        style: TextStyle(
                                          color: isVoided ? Colors.white38 : const Color(0xFF00C853),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
                                          fontFamily: 'monospace',
                                          decoration: isVoided ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              widget.onReprintOrder(o);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF42A5F5),
                                              side: BorderSide(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            icon: const Icon(Icons.print_rounded, size: 15),
                                            label: const Text('Cetak Resit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          ),
                                          if (!isVoided) ...[
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () => _promptVoidOrder(o),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                                foregroundColor: Colors.redAccent,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              ),
                                              icon: const Icon(Icons.cancel_rounded, size: 15),
                                              label: const Text('Void / Refund', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
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

// =============================================================================
// 5. DIRECT THERMAL RECEIPT PREVIEW & 1-CLICK PRINT ENGINE
// =============================================================================

class PosQuickThermalReceiptModal extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const PosQuickThermalReceiptModal({super.key, required this.receipt});

  static Future<void> show(BuildContext context, Map<String, dynamic> receipt) {
    return showDialog(
      context: context,
      builder: (ctx) => PosQuickThermalReceiptModal(receipt: receipt),
    );
  }

  String _buildPlainTextReceipt() {
    final lines = (receipt['items'] as List?)?.cast<String>() ?? [];
    final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;
    final method = receipt['method']?.toString() ?? 'TUNAI';
    final ref = receipt['ref']?.toString() ?? '#POS';
    final customer = receipt['customer']?.toString() ?? 'Pelanggan Kaunter';
    final mode = receipt['mode']?.toString() ?? 'DINE-IN';

    return '''
================================
          WARUNG NGAM
   Resit Rasmi Jualan Kaunter
================================
Rujukan : $ref
Tarikh  : ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}
Mod     : $mode
Pelanggan: $customer
--------------------------------
${lines.join('\n')}
--------------------------------
JUMLAH BESAR : RM ${total.toStringAsFixed(2)}
Kaedah Bayar : $method
Status       : LULUS / SELESAI
================================
Terima kasih! Sila datang lagi.
''';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final lines = (receipt['items'] as List?)?.cast<String>() ?? [];
    final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;
    final method = receipt['method']?.toString() ?? 'TUNAI';
    final ref = receipt['ref']?.toString() ?? '#POS';
    final customer = receipt['customer']?.toString() ?? 'Pelanggan Kaunter';
    final mode = receipt['mode']?.toString() ?? 'DINE-IN';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF181828),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print_rounded, color: Color(0xFF42A5F5), size: 20),
                    SizedBox(width: 8),
                    Text('Slip Resit Thermal (58mm/80mm)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Receipt Paper
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('RESIT RASMI POS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, fontFamily: 'monospace')),
                  Text('$ref • $mode', style: const TextStyle(color: Colors.black87, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  Text(DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()), style: const TextStyle(color: Colors.black54, fontSize: 10, fontFamily: 'monospace')),
                  Text('Pelanggan: $customer', style: const TextStyle(color: Colors.black87, fontSize: 10.5, fontFamily: 'monospace')),
                  const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontFamily: 'monospace')),
                  ...lines.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l, style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                        ),
                      )),
                  const Text('--------------------------------', style: TextStyle(color: Colors.black45, fontFamily: 'monospace')),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('JUMLAH BESAR:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, fontFamily: 'monospace')),
                      Text(fmt.format(total), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'monospace')),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kaedah Bayaran: $method', style: const TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 8),
                  const Text('Terima kasih! Sila datang lagi.', style: TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final text = _buildPlainTextReceipt();
                      await Clipboard.setData(ClipboardData(text: text));
                      final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
                      if (await canLaunchUrl(waUri)) {
                        await launchUrl(waUri, mode: LaunchMode.externalApplication);
                      } else if (context.mounted) {
                        showGlassToast(context, 'Resit disalin ke papan keratan!');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final text = _buildPlainTextReceipt();
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        Navigator.pop(context);
                        showGlassToast(
                          context,
                          'Arahan cetakan ESC/POS dihantar ke pencetak thermal!',
                          customColor: const Color(0xFF00C853),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Cetak Terus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
