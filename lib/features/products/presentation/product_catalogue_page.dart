import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../widgets/glass_toast.dart';
import '../../pos/models/product_model.dart';
import '../data/product_service.dart';

class ProductCataloguePage extends StatefulWidget {
  const ProductCataloguePage({super.key});

  @override
  State<ProductCataloguePage> createState() => _ProductCataloguePageState();
}

class _ProductCataloguePageState extends State<ProductCataloguePage> {
  final _service = ProductService();
  bool _isLoading = true;
  List<ProductModel> _products = [];
  StreamSubscription<List<ProductModel>>? _productSubscription;

  String _typeFilter = 'all'; // 'all', 'product', 'service'
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initProductStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _productSubscription?.cancel();
    super.dispose();
  }

  void _initProductStream() {
    setState(() => _isLoading = true);
    _productSubscription = _service.streamAllProducts().listen((products) {
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  Future<void> _loadProducts() async {
    final products = await _service.fetchAllProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    return _products.where((p) {
      if (_typeFilter == 'product' && p.isService) return false;
      if (_typeFilter == 'service' && p.isProduct) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchCat = (p.category ?? '').toLowerCase().contains(q);
        final matchSku = (p.sku ?? '').toLowerCase().contains(q);
        if (!matchName && !matchCat && !matchSku) return false;
      }
      return true;
    }).toList();
  }

  void _showAddProductModal({ProductModel? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddProductSheet(existingProduct: product),
    ).then((value) {
      if (value == true) {
        _loadProducts();
      }
    });
  }

  Future<void> _toggleAvailability(ProductModel product) async {
    final success = await _service.updateProduct(
      product.id,
      {'is_active': !product.isAvailable},
    );
    if (success) {
      _loadProducts();
    } else {
      if (mounted) {
        showGlassToast(context, 'Failed to update item availability', isError: true);
      }
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: Text('Delete ${product.isService ? 'Service' : 'Product'}', style: const TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${product.name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.deleteProduct(product.id);
      if (success) {
        _loadProducts();
        if (mounted) showGlassToast(context, '${product.name} deleted');
      } else {
        if (mounted) showGlassToast(context, 'Failed to delete item', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productCount = _products.where((p) => p.isProduct).length;
    final serviceCount = _products.where((p) => p.isService).length;
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10101A),
        elevation: 0,
        title: const Text(
          'Products & Services',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductModal(),
        backgroundColor: const Color(0xFF42A5F5),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 20),
        label: const Text('Add Item / Service', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : Column(
              children: [
                // ─── Search and Filter Header ────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: const Color(0xFF10101A),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search products, services, SKU or categories...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Pills (All / Products / Services)
                      Row(
                        children: [
                          _buildFilterChip('all', 'All (${_products.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('product', '📦 Products ($productCount)'),
                          const SizedBox(width: 8),
                          _buildFilterChip('service', '✂️ Services ($serviceCount)'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Products & Services Grid ────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF42A5F5),
                          onRefresh: _loadProducts,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.68,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildProductCard(item);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _typeFilter == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _typeFilter = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedPackage,
            color: Colors.white.withValues(alpha: 0.2),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No items match your search' : 'No products or services yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "+ Add Item / Service" to build your catalogue',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GestureDetector(
        onTap: () => _showAddProductModal(product: item),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Image & Badges ──────────────────────────────
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        image: item.imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(item.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: item.imageUrl == null
                          ? Center(
                              child: HugeIcon(
                                icon: item.isService
                                    ? HugeIcons.strokeRoundedClock01
                                    : HugeIcons.strokeRoundedPackage,
                                color: Colors.white.withValues(alpha: 0.2),
                                size: 32,
                              ),
                            )
                          : null,
                    ),

                    // Type Badge (Product or Service)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isService
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.85)
                              : const Color(0xFF3B82F6).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.isService ? 'Service' : 'Product',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Halal & Featured badges
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          if (item.isHalal)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'HALAL',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (item.isFeatured)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star, color: Colors.white, size: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Details ─────────────────────────────────────
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Text(
                        item.category?.toUpperCase() ?? 'GENERAL',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Name
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Price & Discount Strikethrough
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'RM ${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF42A5F5),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (item.hasDiscount) ...[
                            const SizedBox(width: 4),
                            Text(
                              'RM ${item.compareAtPrice!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white38,
                                decoration: TextDecoration.lineThrough,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),

                      // Stock (Product) or Duration (Service) Indicator
                      if (item.isProduct) ...[
                        if (item.isOutOfStock)
                          const Text('Out of Stock', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
                        else if (item.isLowStock)
                          Text('Low: ${item.stock} ${item.unit}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600))
                        else if (item.trackInventory)
                          Text('${item.stock} ${item.unit} in stock', style: const TextStyle(color: Colors.white54, fontSize: 10))
                        else
                          const Text('In Stock', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600)),
                      ] else ...[
                        Text(
                          '${item.durationMinutes} mins • ${item.serviceLocation == 'in_store' ? 'In-Store' : 'Mobile'}',
                          style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 6),

                      // Availability Switch & Delete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Transform.scale(
                            scale: 0.75,
                            alignment: Alignment.centerLeft,
                            child: Switch(
                              value: item.isAvailable,
                              onChanged: (_) => _toggleAvailability(item),
                              activeColor: const Color(0xFF42A5F5),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                            onPressed: () => _deleteProduct(item),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Comprehensive Add / Edit Item & Service Sheet
// =============================================================================

class _AddProductSheet extends StatefulWidget {
  final ProductModel? existingProduct;
  const _AddProductSheet({this.existingProduct});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _service = ProductService();
  final _formKey = GlobalKey<FormState>();

  String _itemType = 'product'; // 'product' or 'service'

  // Text Controllers
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _descController = TextEditingController();

  // Pricing
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0.0');

  // Product Inventory
  final _stockController = TextEditingController(text: '0');
  final _lowStockController = TextEditingController(text: '5');
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _selectedUnit = 'pcs';
  bool _trackInventory = true;

  // Service Scheduling
  int _durationMinutes = 30;
  int _bufferMinutes = 0;
  final _depositController = TextEditingController(text: '0.00');
  String _serviceLocation = 'in_store';
  final _maxPaxController = TextEditingController(text: '1');

  // Flags & Badges
  bool _isAvailable = true;
  bool _isFeatured = false;
  bool _isHalal = false;

  // Variants & Modifiers
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _modifiers = [];

  XFile? _imageFile;
  bool _isSaving = false;

  static const _unitOptions = ['pcs', 'pack', 'kg', 'g', 'cup', 'box', 'portion', 'set'];
  static const _durationOptions = [15, 30, 45, 60, 90, 120];
  static const _bufferOptions = [0, 5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _itemType = p.itemType;
      _nameController.text = p.name;
      _categoryController.text = p.category ?? '';
      _subCategoryController.text = p.subCategory ?? '';
      _descController.text = p.description ?? '';

      _priceController.text = p.price.toStringAsFixed(2);
      if (p.compareAtPrice != null) _compareAtPriceController.text = p.compareAtPrice!.toStringAsFixed(2);
      if (p.costPrice != null) _costPriceController.text = p.costPrice!.toStringAsFixed(2);
      _taxRateController.text = p.taxRate.toStringAsFixed(1);

      _stockController.text = p.stock.toString();
      _lowStockController.text = p.lowStockThreshold.toString();
      _skuController.text = p.sku ?? '';
      _barcodeController.text = p.barcode ?? '';
      _selectedUnit = p.unit;
      _trackInventory = p.trackInventory;

      _durationMinutes = p.durationMinutes;
      _bufferMinutes = p.bufferMinutes;
      _depositController.text = p.depositAmount.toStringAsFixed(2);
      _serviceLocation = p.serviceLocation;
      _maxPaxController.text = p.maxPax.toString();

      _isAvailable = p.isAvailable;
      _isFeatured = p.isFeatured;
      _isHalal = p.isHalal;

      _variants = List<Map<String, dynamic>>.from(p.variants);
      _modifiers = List<Map<String, dynamic>>.from(p.modifiers);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _subCategoryController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _costPriceController.dispose();
    _taxRateController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _depositController.dispose();
    _maxPaxController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  void _addVariantDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: _priceController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Add Variant / Option', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Variant Name (e.g. Large, 500g)', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Price (RM)', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final pr = double.tryParse(priceCtrl.text) ?? 0.0;
              if (name.isNotEmpty) {
                setState(() {
                  _variants.add({'name': name, 'price': pr});
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addModifierDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Add Topping / Add-on', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Add-on Name (e.g. Extra Cheese)', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Extra Price (+RM)', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final pr = double.tryParse(priceCtrl.text) ?? 0.0;
              if (name.isNotEmpty) {
                setState(() {
                  _modifiers.add({'name': name, 'price': pr});
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final price = double.tryParse(_priceController.text) ?? 0.0;
    final compareAt = double.tryParse(_compareAtPriceController.text);
    final costPrice = double.tryParse(_costPriceController.text);
    final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final lowStock = int.tryParse(_lowStockController.text) ?? 5;
    final deposit = double.tryParse(_depositController.text) ?? 0.0;
    final maxPax = int.tryParse(_maxPaxController.text) ?? 1;

    Uint8List? imageBytes;
    String? imageExt;

    if (_imageFile != null) {
      imageBytes = await _imageFile!.readAsBytes();
      imageExt = _imageFile!.name.split('.').last;
    }

    bool success = false;

    if (widget.existingProduct != null) {
      // Update
      final updates = {
        'name': _nameController.text.trim(),
        'item_type': _itemType,
        'price': price,
        'compare_at_price': compareAt,
        'cost_price': costPrice,
        'tax_rate': taxRate,
        'category': _categoryController.text.trim(),
        'sub_category': _subCategoryController.text.trim(),
        'description': _descController.text.trim(),
        'sku': _skuController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'stock': stock,
        'track_inventory': _trackInventory,
        'low_stock_threshold': lowStock,
        'unit': _selectedUnit,
        'is_active': _isAvailable,
        'is_featured': _isFeatured,
        'is_halal': _isHalal,
        'variants': _variants,
        'modifiers': _modifiers,
        'duration_minutes': _durationMinutes,
        'buffer_minutes': _bufferMinutes,
        'deposit_amount': deposit,
        'service_location': _serviceLocation,
        'max_pax': maxPax,
      };

      success = await _service.updateProduct(
        widget.existingProduct!.id,
        updates,
        imageBytes: imageBytes,
        imageExt: imageExt,
      );
    } else {
      // Add new
      final product = await _service.addProduct(
        name: _nameController.text.trim(),
        itemType: _itemType,
        price: price,
        compareAtPrice: compareAt,
        costPrice: costPrice,
        taxRate: taxRate,
        category: _categoryController.text.trim(),
        subCategory: _subCategoryController.text.trim(),
        description: _descController.text.trim(),
        sku: _skuController.text.trim(),
        barcode: _barcodeController.text.trim(),
        stock: stock,
        trackInventory: _trackInventory,
        lowStockThreshold: lowStock,
        unit: _selectedUnit,
        isAvailable: _isAvailable,
        isFeatured: _isFeatured,
        isHalal: _isHalal,
        variants: _variants,
        modifiers: _modifiers,
        durationMinutes: _durationMinutes,
        bufferMinutes: _bufferMinutes,
        depositAmount: deposit,
        serviceLocation: _serviceLocation,
        maxPax: maxPax,
        imageBytes: imageBytes,
        imageExt: imageExt,
      );
      success = product != null;
    }

    if (mounted) {
      if (success) {
        showGlassToast(
          context,
          widget.existingProduct != null
              ? '${_itemType == 'service' ? 'Service' : 'Product'} updated successfully'
              : '${_itemType == 'service' ? 'Service' : 'Product'} added successfully',
        );
        Navigator.pop(context, true);
      } else {
        showGlassToast(context, 'Failed to save item', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? sellingPrice = double.tryParse(_priceController.text);
    final double? costPrice = double.tryParse(_costPriceController.text);
    double? margin;
    double? profit;
    if (sellingPrice != null && costPrice != null && sellingPrice > costPrice && sellingPrice > 0) {
      profit = sellingPrice - costPrice;
      margin = (profit / sellingPrice) * 100;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF161622).withValues(alpha: 0.96),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.existingProduct != null ? 'Edit Item' : 'New Product / Service',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ─── Type Segmented Switcher (Product vs Service) ────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _itemType = 'product'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _itemType == 'product' ? const Color(0xFF3B82F6) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const HugeIcon(icon: HugeIcons.strokeRoundedPackage, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Physical / F&B Product',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: _itemType == 'product' ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _itemType = 'service'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _itemType == 'service' ? const Color(0xFF8B5CF6) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.content_cut_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Service / Appointment',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: _itemType == 'service' ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Image Picker ────────────────────────────────────────
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(File(_imageFile!.path)),
                                  fit: BoxFit.cover,
                                )
                              : (widget.existingProduct?.imageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(widget.existingProduct!.imageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        ),
                        child: _imageFile == null && widget.existingProduct?.imageUrl == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedCamera01,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 26,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Cover Image',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                  ),
                                ],
                              )
                            : const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 16,
                                    child: Icon(Icons.edit, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Basic Info ──────────────────────────────────────────
                    _buildSectionHeader('Basic Information'),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        _itemType == 'service' ? 'Service Name (e.g. Signature Fade Cut)' : 'Product Name (e.g. Pisang Goreng Cheese)',
                        HugeIcons.strokeRoundedPackage,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _categoryController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Category (e.g. F&B, Barber)', HugeIcons.strokeRoundedTag01),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _subCategoryController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Sub-category', HugeIcons.strokeRoundedLayers01),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: _inputDecoration('Description / Ingredients / Notes', HugeIcons.strokeRoundedNote01),
                    ),
                    const SizedBox(height: 20),

                    // ─── Pricing & Costs ─────────────────────────────────────
                    _buildSectionHeader('Pricing & Margins'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: _inputDecoration('Selling Price (RM) *', HugeIcons.strokeRoundedMoney01),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _compareAtPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Compare-at (RM)', HugeIcons.strokeRoundedDiscount01),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Cost Price (RM)', HugeIcons.strokeRoundedCoins01),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _taxRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Tax/SST Rate (%)', Icons.percent_rounded),
                          ),
                        ),
                      ],
                    ),

                    // Live Profit Margin Indicator
                    if (margin != null && profit != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Profit: RM ${profit.toStringAsFixed(2)} per unit  •  Margin: ${margin.toStringAsFixed(1)}%',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ─── Conditional: Product Inventory Section ──────────────
                    if (_itemType == 'product') ...[
                      _buildSectionHeader('Inventory & Stock'),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Stock Quantity', HugeIcons.strokeRoundedDashboardSquare02),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              dropdownColor: const Color(0xFF1A1A28),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDecoration('Unit', Icons.scale_rounded),
                              items: _unitOptions
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase())))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lowStockController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Low Stock Alert', HugeIcons.strokeRoundedAlertCircle),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _skuController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('SKU Code', HugeIcons.strokeRoundedQrCode),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _barcodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Barcode / UPC', Icons.qr_code_scanner_rounded),
                      ),
                      const SizedBox(height: 10),

                      // Track Inventory Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Track Inventory Stock', style: TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: const Text('Prevent ordering when item is out of stock', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        value: _trackInventory,
                        activeColor: const Color(0xFF42A5F5),
                        onChanged: (v) => setState(() => _trackInventory = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Conditional: Service Details Section ────────────────
                    if (_itemType == 'service') ...[
                      _buildSectionHeader('Service & Appointment Setup'),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _durationMinutes,
                              dropdownColor: const Color(0xFF1A1A28),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDecoration('Duration', HugeIcons.strokeRoundedClock01),
                              items: _durationOptions
                                  .map((d) => DropdownMenuItem(value: d, child: Text('$d Mins')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _durationMinutes = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _bufferMinutes,
                              dropdownColor: const Color(0xFF1A1A28),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDecoration('Buffer Time', HugeIcons.strokeRoundedHourglass),
                              items: _bufferOptions
                                  .map((b) => DropdownMenuItem(value: b, child: Text('$b Mins')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _bufferMinutes = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _depositController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Booking Deposit (RM)', HugeIcons.strokeRoundedShield01),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _serviceLocation,
                              dropdownColor: const Color(0xFF1A1A28),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDecoration('Location', HugeIcons.strokeRoundedLocation01),
                              items: const [
                                DropdownMenuItem(value: 'in_store', child: Text('In-Store')),
                                DropdownMenuItem(value: 'mobile_service', child: Text('Mobile / Home')),
                                DropdownMenuItem(value: 'online', child: Text('Online Call')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _serviceLocation = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Badges & Flags ──────────────────────────────────────
                    _buildSectionHeader('Badges & Visibility'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Halal Certified (F&B / Salon)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Shows verified green Halal badge on store', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      value: _isHalal,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (v) => setState(() => _isHalal = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Featured / Best Seller', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Pinned to top of menu for quick ordering', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      value: _isFeatured,
                      activeColor: const Color(0xFFF59E0B),
                      onChanged: (v) => setState(() => _isFeatured = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active / Available for Order', style: TextStyle(color: Colors.white, fontSize: 13)),
                      value: _isAvailable,
                      activeColor: const Color(0xFF42A5F5),
                      onChanged: (v) => setState(() => _isAvailable = v),
                    ),
                    const SizedBox(height: 16),

                    // ─── Variants (Size / Flavor) ────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Variants & Options (${_variants.length})'),
                        TextButton.icon(
                          onPressed: _addVariantDialog,
                          icon: const Icon(Icons.add, color: Color(0xFF42A5F5), size: 16),
                          label: const Text('Add Variant', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12)),
                        ),
                      ],
                    ),
                    if (_variants.isEmpty)
                      const Text('No variants added (e.g. Regular, Large)', style: TextStyle(color: Colors.white30, fontSize: 12))
                    else
                      Wrap(
                        spacing: 8,
                        children: _variants.map((v) {
                          return Chip(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            label: Text(
                              '${v['name']} • RM ${(v['price'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                            onDeleted: () => setState(() => _variants.remove(v)),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),

                    // ─── Modifiers / Add-ons ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Toppings & Add-ons (${_modifiers.length})'),
                        TextButton.icon(
                          onPressed: _addModifierDialog,
                          icon: const Icon(Icons.add, color: Color(0xFF42A5F5), size: 16),
                          label: const Text('Add Add-on', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12)),
                        ),
                      ],
                    ),
                    if (_modifiers.isEmpty)
                      const Text('No add-ons added (e.g. Extra Cheese +RM2.00)', style: TextStyle(color: Colors.white30, fontSize: 12))
                    else
                      Wrap(
                        spacing: 8,
                        children: _modifiers.map((m) {
                          return Chip(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            label: Text(
                              '${m['name']} (+RM ${(m['price'] as num).toStringAsFixed(2)})',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                            onDeleted: () => setState(() => _modifiers.remove(m)),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 28),

                    // ─── Save Button ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                widget.existingProduct != null
                                    ? 'Save ${_itemType == 'service' ? 'Service' : 'Product'} Changes'
                                    : 'Create ${_itemType == 'service' ? 'Service' : 'Product'}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, dynamic icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: icon is IconData
            ? Icon(icon, color: Colors.white54, size: 18)
            : HugeIcon(icon: icon, color: Colors.white54, size: 18),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
      ),
    );
  }
}
