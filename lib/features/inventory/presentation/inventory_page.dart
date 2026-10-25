import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';
import '../../pos/models/product_model.dart';
import '../../products/data/product_service.dart';

// ============================================================
// InventoryPage — Real-Time Stock Levels & Low Stock Alerts
// ============================================================

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final ProductService _productService = ProductService();
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Semua Produk', 'Stok Rendah', 'Habis Stok'];
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjustStock(ProductModel product, int delta) async {
    final newStock = (product.stock + delta).clamp(0, 999999);
    final success = await _productService.updateStock(product.id, newStock);
    if (mounted) {
      if (success) {
        showGlassToast(context, 'Stok ${product.name} dikemaskini: $newStock ${product.unit}');
      } else {
        showGlassToast(context, 'Gagal mengemaskini stok', isError: true);
      }
    }
  }

  void _showSetStockDialog(ProductModel product) {
    final textCtrl = TextEditingController(text: '${product.stock}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tetapkan Stok: ${product.name}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan kuantiti stok fizikal sebenar:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                suffixText: product.unit,
                suffixStyle: const TextStyle(color: Colors.white60),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                ),
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
            onPressed: () async {
              final val = int.tryParse(textCtrl.text.trim());
              if (val != null) {
                Navigator.pop(ctx);
                await _adjustStock(product, val - product.stock);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: StreamBuilder<List<ProductModel>>(
          stream: _productService.streamAllProducts(),
          builder: (context, snapshot) {
            final allItems = snapshot.data ?? [];
            // Filter physical items that track inventory (or all products)
            final physicalItems = allItems.where((p) => p.isProduct).toList();

            final lowStockCount = physicalItems.where((i) => i.trackInventory && i.isLowStock).length;
            final outOfStockCount = physicalItems.where((i) => i.trackInventory && i.isOutOfStock).length;

            final filteredItems = physicalItems.where((item) {
              final query = _searchQuery.toLowerCase();
              final matchesQuery = item.name.toLowerCase().contains(query) ||
                  (item.category?.toLowerCase().contains(query) ?? false) ||
                  (item.sku?.toLowerCase().contains(query) ?? false) ||
                  (item.barcode?.toLowerCase().contains(query) ?? false);

              if (!matchesQuery) return false;

              if (_selectedFilterIndex == 1) {
                return item.trackInventory && item.isLowStock;
              } else if (_selectedFilterIndex == 2) {
                return item.trackInventory && item.isOutOfStock;
              }
              return true;
            }).toList();

            return Column(
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
                              'Inventori & Pengurusan Stok',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pemantauan stok masa nyata & amaran kekurangan stok',
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

                // Low Stock / Out of Stock Warning Banner
                if (lowStockCount > 0 || outOfStockCount > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Amaran Stok: $lowStockCount item stok rendah, $outOfStockCount item kehabisan stok!',
                            style: const TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari produk mengikut nama, kategori, kod bar...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                // Filter Chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filters.length,
                    itemBuilder: (context, idx) {
                      final isSelected = _selectedFilterIndex == idx;
                      int badgeCount = 0;
                      if (idx == 0) badgeCount = physicalItems.length;
                      if (idx == 1) badgeCount = lowStockCount;
                      if (idx == 2) badgeCount = outOfStockCount;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilterIndex = idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF42A5F5)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _filters[idx],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black.withValues(alpha: 0.25) : Colors.white12,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$badgeCount',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // Inventory List
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting && allItems.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                        )
                      : filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                                  const SizedBox(height: 14),
                                  const Text('Tiada produk dijumpai', style: TextStyle(color: Colors.white70, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Cuba cari dengan kata kunci lain'
                                        : 'Tambah produk fizikal di Katalog untuk mula jejaki stok',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final product = filteredItems[index];
                                final int stock = product.stock;
                                final bool isLow = product.trackInventory && product.isLowStock;
                                final bool isOut = product.trackInventory && product.isOutOfStock;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isOut
                                          ? Colors.redAccent.withValues(alpha: 0.4)
                                          : isLow
                                              ? const Color(0xFFFF9800).withValues(alpha: 0.4)
                                              : Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Section: Thumbnail + Info + Status Badge
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Product Thumbnail
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: SizedBox(
                                              width: 52,
                                              height: 52,
                                              child: (product.imageUrl != null && product.imageUrl!.trim().isNotEmpty)
                                                  ? Image.network(
                                                      product.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: Colors.white.withValues(alpha: 0.05),
                                                        child: const Icon(Icons.image, color: Colors.white24, size: 22),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: Colors.white.withValues(alpha: 0.05),
                                                      child: const Icon(Icons.inventory_2_rounded, color: Colors.white24, size: 22),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Product Title & Price
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'RM ${product.price.toStringAsFixed(2)}${product.category != null ? " · ${product.category}" : ""}',
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Stock Status Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isOut
                                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                                  : isLow
                                                      ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                                                      : const Color(0xFF00C853).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isOut
                                                    ? Colors.redAccent.withValues(alpha: 0.3)
                                                    : isLow
                                                        ? const Color(0xFFFF9800).withValues(alpha: 0.3)
                                                        : const Color(0xFF00C853).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              isOut
                                                  ? 'HABIS STOK'
                                                  : isLow
                                                      ? 'RENDAH ($stock TINGGAL)'
                                                      : '$stock UNIT DALAM STOK',
                                              style: TextStyle(
                                                color: isOut
                                                    ? Colors.redAccent
                                                    : isLow
                                                        ? const Color(0xFFFFB74D)
                                                        : const Color(0xFF00C853),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      Container(
                                        height: 1,
                                        color: Colors.white.withValues(alpha: 0.06),
                                      ),
                                      const SizedBox(height: 10),

                                      // Bottom Controls Row: Available Stock Label + Quick Stepper
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Left: Units & Threshold Indicator
                                          GestureDetector(
                                            onTap: () => _showSetStockDialog(product),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 15,
                                                  color: isOut
                                                      ? Colors.redAccent
                                                      : isLow
                                                          ? const Color(0xFFFF9800)
                                                          : Colors.white54,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Baki: ',
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                                                ),
                                                Text(
                                                  '$stock ${product.unit}',
                                                  style: TextStyle(
                                                    color: isOut
                                                        ? Colors.redAccent
                                                        : isLow
                                                            ? const Color(0xFFFFB74D)
                                                            : Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.edit_rounded, size: 12, color: Colors.white30),
                                              ],
                                            ),
                                          ),

                                          // Right: Stepper controls [-] count [+] [+10]
                                          Row(
                                            children: [
                                              // [-] Button
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _adjustStock(product, -1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.06),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                                    ),
                                                    child: const Center(
                                                      child: Icon(Icons.remove_rounded, color: Colors.white70, size: 18),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Stock Number Counter (Tap to edit)
                                              GestureDetector(
                                                onTap: () => _showSetStockDialog(product),
                                                child: Container(
                                                  constraints: const BoxConstraints(minWidth: 32),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '$stock',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // [+] Button
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _adjustStock(product, 1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
                                                    ),
                                                    child: const Center(
                                                      child: Icon(Icons.add_rounded, color: Color(0xFF42A5F5), size: 18),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // [+10] Button
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _adjustStock(product, 10),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    height: 34,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF00C853).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.4)),
                                                    ),
                                                    child: const Center(
                                                      child: Text(
                                                        '+10',
                                                        style: TextStyle(
                                                          color: Color(0xFF00C853),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
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
            );
          },
        ),
      ),
    );
  }
}
