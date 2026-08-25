import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../pos/data/pos_service.dart';
import '../../pos/models/product_model.dart';
import '../../pos/models/order_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await _service.fetchProducts();
    if (!mounted) return;
    setState(() {
      _allProducts = products;
      _applyFilter();
      _loading = false;
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

    final confirmed = await _showCheckoutConfirm();
    if (!confirmed || !mounted) return;

    try {
      await _service.submitOrder(
        items: _cart,
        total: _cartTotal,
        customerName: _customerController.text,
      );
      if (!mounted) return;
      showGlassToast(
        context,
        'Order placed! RM ${_cartTotal.toStringAsFixed(2)}',
        customColor: const Color(0xFF44CF6C),
      );
      setState(() {
        _cart = [];
        _customerController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Failed to place order.', isError: true);
    }
  }

  Future<bool> _showCheckoutConfirm() async {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          'Confirm Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_cartCount item${_cartCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${fmt.format(_cartTotal)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
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
              const SizedBox(width: 24),
              SizedBox(width: 300, child: _buildCart()),
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
                    initialChildSize: 0.7,
                    builder: (ctx, _) => _buildCartContent(),
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
                  ? RefreshIndicator(
                      onRefresh: _loadProducts,
                      color: const Color(0xFF42A5F5),
                      backgroundColor: const Color(0xFF1A1A2E),
                      child: ListView(
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
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      color: const Color(0xFF42A5F5),
                      backgroundColor: const Color(0xFF1A1A2E),
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 120),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, i) =>
                            _buildProductCard(_filteredProducts[i]),
                      ),
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

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: inCart != null
              ? const Color(0xFF42A5F5).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: inCart != null
                ? const Color(0xFF42A5F5).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.category != null && product.category!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.category!,
                            style: const TextStyle(
                              color: Color(0xFF42A5F5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'RM ${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (inCart != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF42A5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$inCart',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : _checkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF42A5F5).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    color: Colors.white,
                    size: 18,
                    strokeWidth: 2.1,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
