import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// InventoryPage — Stock Levels & Low Stock Alert Management
// ============================================================

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All Items', 'Low Stock (< 5)', 'Out of Stock'];
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late List<Map<String, dynamic>> _inventory;

  @override
  void initState() {
    super.initState();
    _inventory = [
      {
        'id': 'PRD-01',
        'name': 'Matte Clay Pomade (100g)',
        'category': 'Hair Care',
        'stock': 3,
        'lowStockThreshold': 5,
        'price': 45.00,
        'imageUrl': 'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?q=80&w=200',
        'isAvailable': true,
      },
      {
        'id': 'PRD-02',
        'name': 'Beard Grooming Oil (50ml)',
        'category': 'Shaving',
        'stock': 0,
        'lowStockThreshold': 5,
        'price': 38.00,
        'imageUrl': 'https://images.unsplash.com/photo-1621605815971-fbc98d665033?q=80&w=200',
        'isAvailable': false,
      },
      {
        'id': 'PRD-03',
        'name': 'Organic Face Scrub (150ml)',
        'category': 'Skincare',
        'stock': 2,
        'lowStockThreshold': 5,
        'price': 55.00,
        'imageUrl': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=200',
        'isAvailable': true,
      },
      {
        'id': 'PRD-04',
        'name': 'Styling Sea Salt Spray (200ml)',
        'category': 'Hair Care',
        'stock': 24,
        'lowStockThreshold': 5,
        'price': 42.00,
        'imageUrl': 'https://images.unsplash.com/photo-1619233543640-af09c173763b?q=80&w=200',
        'isAvailable': true,
      },
      {
        'id': 'PRD-05',
        'name': 'Wooden Beard Comb',
        'category': 'Accessories',
        'stock': 18,
        'lowStockThreshold': 5,
        'price': 20.00,
        'imageUrl': 'https://plus.unsplash.com/premium_photo-1661290481306-4841edd49719?q=80&w=200',
        'isAvailable': true,
      },
    ];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _inventory.where((item) {
      final nameMatches = item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      if (!nameMatches) return false;

      final stock = item['stock'] as int;
      if (_selectedFilterIndex == 1) {
        return stock > 0 && stock <= 5;
      } else if (_selectedFilterIndex == 2) {
        return stock == 0;
      }
      return true;
    }).toList();
  }

  int get _lowStockCount => _inventory.where((i) => (i['stock'] as int) > 0 && (i['stock'] as int) <= 5).length;
  int get _outOfStockCount => _inventory.where((i) => (i['stock'] as int) == 0).length;

  void _adjustStock(Map<String, dynamic> item, int delta) {
    setState(() {
      int newStock = (item['stock'] as int) + delta;
      if (newStock < 0) newStock = 0;
      item['stock'] = newStock;
      item['isAvailable'] = newStock > 0;
    });
    showGlassToast(context, 'Stock for ${item['name']} updated: ${item['stock']} units');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
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
                          'Inventory & Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Live stock monitoring & low stock alerts',
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

            // Low Stock Warning Banner if any
            if (_lowStockCount > 0 || _outOfStockCount > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9C80E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF9C80E).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF9C80E), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attention: $_lowStockCount items running low, $_outOfStockCount items out of stock!',
                        style: const TextStyle(color: Color(0xFFF9C80E), fontSize: 13, fontWeight: FontWeight.bold),
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
                  hintText: 'Search product by name...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
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
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF42A5F5)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _filters[idx],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Inventory List
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          const Text('No products found', style: TextStyle(color: Colors.white70, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final int stock = item['stock'] as int;
                        final bool isLow = stock > 0 && stock <= 5;
                        final bool isOut = stock == 0;

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
                                      ? const Color(0xFFF9C80E).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Section: Thumbnail + Full-Width Product Info + Status Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Image.network(
                                        item['imageUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          child: const Icon(Icons.image, color: Colors.white24, size: 22),
                                        ),
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
                                          item['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'RM ${(item['price'] as double).toStringAsFixed(2)} · ${item['category']}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Stock Status Badge (Top-Right)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? Colors.redAccent.withValues(alpha: 0.15)
                                          : isLow
                                              ? const Color(0xFFF9C80E).withValues(alpha: 0.15)
                                              : const Color(0xFF44CF6C).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isOut
                                            ? Colors.redAccent.withValues(alpha: 0.3)
                                            : isLow
                                                ? const Color(0xFFF9C80E).withValues(alpha: 0.3)
                                                : const Color(0xFF44CF6C).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      isOut
                                          ? 'OUT OF STOCK'
                                          : isLow
                                              ? 'LOW ($stock LEFT)'
                                              : '$stock IN STOCK',
                                      style: TextStyle(
                                        color: isOut
                                            ? Colors.redAccent
                                            : isLow
                                                ? const Color(0xFFF9C80E)
                                                : const Color(0xFF44CF6C),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              // Subtle divider
                              Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              const SizedBox(height: 10),

                              // Bottom Controls Row: Available Stock Label (Left) + Quick Stepper (Right)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left: Units Indicator
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 15,
                                        color: isOut
                                            ? Colors.redAccent
                                            : isLow
                                                ? const Color(0xFFF9C80E)
                                                : Colors.white54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Baki Stok: ',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                      ),
                                      Text(
                                        '$stock unit',
                                        style: TextStyle(
                                          color: isOut
                                              ? Colors.redAccent
                                              : isLow
                                                  ? const Color(0xFFF9C80E)
                                                  : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Right: Stepper controls [-] count [+] [+10]
                                  Row(
                                    children: [
                                      // [-] Button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _adjustStock(item, -1),
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

                                      // Stock Number Counter
                                      Container(
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
                                      const SizedBox(width: 8),

                                      // [+] Button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _adjustStock(item, 1),
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
                                          onTap: () => _adjustStock(item, 10),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            height: 34,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                '+10',
                                                style: TextStyle(
                                                  color: Color(0xFF42A5F5),
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
        ),
      ),
    );
  }
}
