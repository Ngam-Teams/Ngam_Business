import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../widgets/glass_toast.dart';
import '../../pos/models/product_model.dart';
import '../data/product_service.dart';
import '../../../widgets/glass_nav_button.dart';

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
    if (_products.isEmpty) {
      setState(() => _isLoading = true);
    }
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

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'Products & Services',
      subtitle: 'Katalog produk & servis kedai',
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedAdd01,
          tooltip: 'Tambah Item / Servis',
          onTap: () => _showAddProductModal(),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductModal(),
        backgroundColor: const Color(0xFF42A5F5),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 20),
        label: const Text('Add Item / Service', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : RefreshIndicator(
              color: const Color(0xFF42A5F5),
              onRefresh: _loadProducts,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 68),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          // Search Bar
                          Container(
                            height: 48,
                            padding: const EdgeInsets.only(left: 16, right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: Colors.white54, size: 19),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                    decoration: const InputDecoration(
                                      hintText: 'Search products, services, SKU or categories...',
                                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5),
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                              ],
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
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildProductCard(filtered[index]),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
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

                    if ((item.videoUrl != null && item.videoUrl!.isNotEmpty) ||
                        item.galleryImages.length > 1)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.videoUrl != null && item.videoUrl!.isNotEmpty) ...[
                                const Icon(Icons.play_circle_fill_rounded,
                                    color: Color(0xFF42A5F5), size: 12),
                                if (item.galleryImages.length > 1)
                                  const SizedBox(width: 4),
                              ],
                              if (item.galleryImages.length > 1)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.collections_rounded,
                                        color: Colors.white70, size: 11),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${item.galleryImages.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
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
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.formattedMinPrice,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFF42A5F5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
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
                          Text('Low: ${item.effectiveTotalStock} ${item.unit}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600))
                        else if (item.trackInventory)
                          Text('${item.effectiveTotalStock} ${item.unit} in stock', style: const TextStyle(color: Colors.white54, fontSize: 10))
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
  final _weightController = TextEditingController(text: '0.5');
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

  static const int _maxGalleryPhotos = 9;
  static const int _maxVideoSizeMb = 80;

  final List<_ProductPhotoDraft> _galleryItems = [];
  String? _existingVideoUrl;
  XFile? _pickedVideoFile;
  Uint8List? _pickedVideoBytes;
  VideoPlayerController? _videoPreviewCtrl;
  bool _videoPreviewReady = false;
  bool _videoPlaying = false;
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  String? _saveError;

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
      _weightController.text = p.weightKg.toString();
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

      for (final url in p.galleryImages) {
        if (_galleryItems.length < _maxGalleryPhotos) {
          _galleryItems.add(_ProductPhotoDraft(existingUrl: url));
        }
      }
      if (p.videoUrl != null && p.videoUrl!.trim().isNotEmpty) {
        _existingVideoUrl = p.videoUrl!.trim();
        _initVideoPreview(networkUrl: _existingVideoUrl);
      }
    }
  }

  @override
  void dispose() {
    _videoPreviewCtrl?.dispose();
    _scrollController.dispose();
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
    _weightController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _depositController.dispose();
    _maxPaxController.dispose();
    super.dispose();
  }

  Future<void> _initVideoPreview({String? networkUrl, XFile? localFile}) async {
    await _videoPreviewCtrl?.dispose();
    _videoPreviewCtrl = null;
    if (mounted) {
      setState(() {
        _videoPreviewReady = false;
        _videoPlaying = false;
      });
    }
    try {
      final ctrl = networkUrl != null
          ? VideoPlayerController.networkUrl(Uri.parse(networkUrl))
          : (kIsWeb
              ? VideoPlayerController.networkUrl(Uri.parse(localFile!.path))
              : VideoPlayerController.networkUrl(Uri.file(localFile!.path)));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);
      if (mounted) {
        setState(() {
          _videoPreviewCtrl = ctrl;
          _videoPreviewReady = true;
          _videoPlaying = false;
        });
      } else {
        ctrl.dispose();
      }
    } catch (_) {
      // Fallback safely when browser codec cannot decode preview frame
    }
  }

  Future<void> _pickMultipleImages() async {
    final remaining = _maxGalleryPhotos - _galleryItems.length;
    if (remaining <= 0) {
      showGlassToast(
        context,
        'products.max_photos_reached'.tr(args: ['$_maxGalleryPhotos']),
        isError: true,
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(maxWidth: 1400, imageQuality: 85);
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    if (picked.length > remaining && mounted) {
      showGlassToast(
        context,
        'products.max_photos_reached'.tr(args: ['$_maxGalleryPhotos']),
      );
    }

    final drafts = <_ProductPhotoDraft>[];
    for (final file in toAdd) {
      final bytes = await file.readAsBytes();
      drafts.add(_ProductPhotoDraft(localBytes: bytes, localName: file.name));
    }
    if (mounted && drafts.isNotEmpty) {
      setState(() {
        _galleryItems.addAll(drafts);
      });
    }
  }

  void _setCoverPhoto(int index) {
    if (index <= 0 || index >= _galleryItems.length) return;
    setState(() {
      final chosen = _galleryItems.removeAt(index);
      _galleryItems.insert(0, chosen);
    });
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _galleryItems.length) return;
    setState(() {
      _galleryItems.removeAt(index);
    });
  }

  Future<void> _pickProductVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final sizeMb = bytes.length / (1024 * 1024);
    if (sizeMb > _maxVideoSizeMb) {
      if (mounted) {
        showGlassToast(
          context,
          'products.video_too_large'.tr(args: ['$_maxVideoSizeMb']),
          isError: true,
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _existingVideoUrl = null;
        _pickedVideoFile = picked;
        _pickedVideoBytes = bytes;
      });
    }
    await _initVideoPreview(localFile: picked);
  }

  void _removeProductVideo() {
    _videoPreviewCtrl?.dispose();
    setState(() {
      _videoPreviewCtrl = null;
      _videoPreviewReady = false;
      _videoPlaying = false;
      _existingVideoUrl = null;
      _pickedVideoFile = null;
      _pickedVideoBytes = null;
    });
  }

  double? get _variantMinPrice {
    final prices = _variants
        .map((v) => (v['price'] as num?)?.toDouble() ?? double.tryParse(v['price']?.toString() ?? '') ?? 0.0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  double? get _variantMaxPrice {
    final prices = _variants
        .map((v) => (v['price'] as num?)?.toDouble() ?? double.tryParse(v['price']?.toString() ?? '') ?? 0.0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a > b ? a : b);
  }

  String get _variantPriceRangeText {
    final minP = _variantMinPrice ?? 0.0;
    final maxP = _variantMaxPrice ?? minP;
    if ((maxP - minP).abs() >= 0.005) {
      return 'RM ${minP.toStringAsFixed(2)} - RM ${maxP.toStringAsFixed(2)}';
    }
    return 'RM ${minP.toStringAsFixed(2)}';
  }

  bool get _hasVariantStocks => _variants.any((v) {
        final raw = v['stock'];
        if (raw == null) return false;
        if (raw is num) return true;
        return int.tryParse(raw.toString()) != null;
      });

  int get _totalVariantStock => _variants.fold<int>(0, (sum, v) {
        final raw = v['stock'];
        final s = raw is num ? raw.toInt() : (int.tryParse(raw?.toString() ?? '') ?? 0);
        return sum + (s < 0 ? 0 : s);
      });

  void _addVariantDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _OptionInputDialog(
        title: 'products.add_variant'.tr(),
        nameLabel: 'products.variant_name'.tr(),
        priceLabel: 'products.variant_price'.tr(),
        initialPrice: (double.tryParse(_priceController.text.trim()) ?? 0) > 0
            ? _priceController.text.trim()
            : '',
        submitLabel: 'common.add'.tr(),
        showStockAndWeight: _itemType == 'product',
        requirePositivePrice: true,
        onAdd: (name, pr, stock, weightKg) {
          setState(() {
            _variants.add({
              'name': name,
              'price': pr,
              if (stock != null) 'stock': stock,
              if (weightKg != null) 'weight_kg': weightKg,
            });
          });
        },
      ),
    );
  }

  void _editVariantDialog(int index) {
    final item = _variants[index];
    final currentName = (item['name'] ?? '').toString();
    final currentPrice = ((item['price'] as num?)?.toDouble() ??
            double.tryParse(item['price']?.toString() ?? '') ??
            0.0)
        .toStringAsFixed(2);
    final rawStock = item['stock'];
    final currentStock = rawStock is num
        ? rawStock.toInt().toString()
        : (rawStock?.toString() ?? '');
    final rawWeight = item['weight_kg'];
    final currentWeight = rawWeight is num
        ? rawWeight.toDouble().toString()
        : (rawWeight?.toString() ?? '');
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _OptionInputDialog(
        title: 'products.edit_variant'.tr(),
        nameLabel: 'products.variant_name'.tr(),
        priceLabel: 'products.variant_price'.tr(),
        initialName: currentName,
        initialPrice: currentPrice,
        initialStock: currentStock,
        initialWeight: currentWeight,
        submitLabel: 'common.save'.tr(),
        showStockAndWeight: _itemType == 'product',
        requirePositivePrice: true,
        onAdd: (name, pr, stock, weightKg) {
          setState(() {
            _variants[index] = {
              ...item,
              'name': name,
              'price': pr,
              if (stock != null) 'stock': stock else 'stock': null,
              if (weightKg != null) 'weight_kg': weightKg else 'weight_kg': null,
            }..removeWhere((k, v) => v == null);
          });
        },
      ),
    );
  }

  void _openTwoTierMatrixDialog() {
    final existingUrls = _galleryItems
        .map((g) => g.existingUrl ?? '')
        .where((u) => u.trim().isNotEmpty)
        .toList();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _TwoTierVariantMatrixDialog(
        existingVariants: _variants,
        galleryUrls: existingUrls,
        defaultPrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
        defaultWeightKg: double.tryParse(_weightController.text.trim()) ?? 0.5,
        onSave: (generatedVariants) {
          setState(() {
            _variants = generatedVariants;
          });
        },
      ),
    );
  }

  void _addModifierDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _OptionInputDialog(
        title: 'products.add_modifier'.tr(),
        nameLabel: 'products.modifier_name'.tr(),
        priceLabel: 'products.modifier_price'.tr(),
        initialPrice: '0.00',
        submitLabel: 'common.add'.tr(),
        onAdd: (name, pr, _, __) {
          setState(() {
            _modifiers.add({'name': name, 'price': pr});
          });
        },
      ),
    );
  }

  void _editModifierDialog(int index) {
    final item = _modifiers[index];
    final currentName = (item['name'] ?? '').toString();
    final currentPrice = ((item['price'] as num?) ?? 0.0).toStringAsFixed(2);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _OptionInputDialog(
        title: 'products.edit_modifier'.tr(),
        nameLabel: 'products.modifier_name'.tr(),
        priceLabel: 'products.modifier_price'.tr(),
        initialName: currentName,
        initialPrice: currentPrice,
        submitLabel: 'common.save'.tr(),
        onAdd: (name, pr, _, __) {
          setState(() {
            _modifiers[index] = {'name': name, 'price': pr};
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      final msg = _variants.isNotEmpty
          ? 'products.validation_name_required'.tr()
          : 'products.validation_required_fields'.tr();
      setState(() => _saveError = msg);
      showGlassToast(context, msg, isError: true);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final enteredPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    // Shopee-style: when variations exist, auto-sync base price to the lowest variation price
    // so catalog & DB queries never show RM 0.00 even if the base price field was left blank.
    final price = (_variants.isNotEmpty && (_variantMinPrice ?? 0) > 0)
        ? _variantMinPrice!
        : enteredPrice;
    final compareAt = double.tryParse(_compareAtPriceController.text);
    final costPrice = double.tryParse(_costPriceController.text);
    final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;
    final enteredStock = int.tryParse(_stockController.text.trim()) ?? 0;
    final stock = (_variants.isNotEmpty && _hasVariantStocks)
        ? _totalVariantStock
        : enteredStock;
    final lowStock = int.tryParse(_lowStockController.text) ?? 5;
    final weightKg = (double.tryParse(_weightController.text.trim()) ?? 0.5).clamp(0.0, 999.0);
    final deposit = double.tryParse(_depositController.text) ?? 0.0;
    final maxPax = int.tryParse(_maxPaxController.text) ?? 1;

    final galleryUploads = _galleryItems
        .map((g) => ProductGalleryDraftUpload(
              localBytes: g.localBytes,
              localName: g.localName,
              existingUrl: g.existingUrl,
            ))
        .toList();

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
        'weight_kg': weightKg,
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
        galleryItems: galleryUploads,
        newVideoBytes: _pickedVideoBytes,
        newVideoFileName: _pickedVideoFile?.name,
        existingVideoUrl: _existingVideoUrl,
        updateMedia: true,
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
        weightKg: weightKg,
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
        galleryItems: galleryUploads,
        videoBytes: _pickedVideoBytes,
        videoFileName: _pickedVideoFile?.name,
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
        final errText = _service.lastError ?? 'Failed to save item';
        setState(() {
          _isSaving = false;
          _saveError = errText;
        });
        showGlassToast(context, errText, isError: true);
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
                controller: _scrollController,
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

                    // ─── Shopee-Style Multi-Image Gallery & Video Section ────
                    _buildMediaGallerySection(),
                    const SizedBox(height: 14),
                    _buildProductVideoSection(),
                    const SizedBox(height: 12),
                    // ─── Aspect Ratio Recommendation Guide ───
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedInformationCircle,
                                color: Colors.blue.shade300,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Nisbah Gambar Disyorkan (Pinterest Masonry)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildRatioBadge('1:1 Square', 'F&B, Gajet, Produk Am'),
                              _buildRatioBadge('3:4 Portrait', 'Fesyen, Servis, Kosmetik'),
                              _buildRatioBadge('2:3 Tall', 'Model Penuh, Lookbook'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sistem memampatkan gambar secara automatik mengikut nisbah asal dengan kualiti HD tanpa herotan.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
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
                    if (_variants.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF42A5F5),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'products.variant_price_auto_banner'.tr(
                                      args: [_variantPriceRangeText],
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'products.variant_price_auto_hint'.tr(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: _inputDecoration(
                              _variants.isNotEmpty
                                  ? 'products.selling_price_optional_variants'.tr()
                                  : 'products.selling_price_required'.tr(),
                              HugeIcons.strokeRoundedMoney01,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (_variants.isNotEmpty) return null;
                              return (v == null || v.trim().isEmpty)
                                  ? 'products.field_required'.tr()
                                  : null;
                            },
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
                            Expanded(
                              child: Text(
                                'Profit: RM ${profit.toStringAsFixed(2)} per unit  •  Margin: ${margin.toStringAsFixed(1)}%',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ─── Conditional: Product Inventory Section ──────────────
                    if (_itemType == 'product') ...[
                      _buildSectionHeader('Inventory & Stock'),
                      if (_variants.isNotEmpty && _hasVariantStocks) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF10B981),
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'products.variant_stock_auto_banner'.tr(
                                    args: ['$_totalVariantStock', _selectedUnit],
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                'easyparcel.product_weight_label'.tr(),
                                Icons.scale_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Barcode / UPC', Icons.qr_code_scanner_rounded),
                            ),
                          ),
                        ],
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

                    // ─── Variants (Size / Flavor / 2-Tier Matrix) ────────────
                    _buildSectionHeader('Variants & Options (${_variants.length})'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: _addVariantDialog,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, color: Color(0xFF42A5F5), size: 15),
                          label: Text(
                            'products.add_variant'.tr(),
                            style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_itemType == 'product')
                          TextButton.icon(
                            onPressed: _openTwoTierMatrixDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.grid_view_rounded, color: Color(0xFFA78BFA), size: 15),
                            label: Text(
                              'products.two_tier_matrix_btn'.tr(),
                              style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'products.variants_section_hint'.tr(),
                        style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                      ),
                    ),
                    if (_variants.isEmpty)
                      const Text('No variants added (e.g. Regular, Large)', style: TextStyle(color: Colors.white30, fontSize: 12))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_variants.length, (i) {
                          final v = _variants[i];
                          final vPrice = (v['price'] as num?)?.toDouble() ??
                              double.tryParse(v['price']?.toString() ?? '') ??
                              0.0;
                          final vStockRaw = v['stock'];
                          final vStock = vStockRaw is num
                              ? vStockRaw.toInt()
                              : int.tryParse(vStockRaw?.toString() ?? '');
                          final vWeightRaw = v['weight_kg'];
                          final vWeight = vWeightRaw is num
                              ? vWeightRaw.toDouble()
                              : double.tryParse(vWeightRaw?.toString() ?? '');
                          final parts = <String>[
                            '${v['name'] ?? ''}',
                            'RM ${vPrice.toStringAsFixed(2)}',
                            if (vStock != null) 'products.variant_stock_short'.tr(args: ['$vStock']),
                            if (vWeight != null && vWeight > 0)
                              '${vWeight % 1 == 0 ? vWeight.toStringAsFixed(0) : vWeight.toString()}kg',
                          ];
                          return _buildEditableOptionChip(
                            label: parts.join(' • '),
                            onTap: () => _editVariantDialog(i),
                            onDelete: () => setState(() => _variants.removeAt(i)),
                          );
                        }),
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
                        runSpacing: 8,
                        children: List.generate(_modifiers.length, (i) {
                          final m = _modifiers[i];
                          return _buildEditableOptionChip(
                            label: '${m['name']} (+RM ${(m['price'] as num).toStringAsFixed(2)})',
                            onTap: () => _editModifierDialog(i),
                            onDelete: () => setState(() => _modifiers.removeAt(i)),
                          );
                        }),
                      ),
                    const SizedBox(height: 20),

                    if (_saveError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 17),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _saveError!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else
                      const SizedBox(height: 8),

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

  Widget _buildRatioBadge(String ratio, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ratio,
              style: const TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            desc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10.5,
            ),
          ),
        ],
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
  Widget _buildEditableOptionChip({
    required String label,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF42A5F5)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded, size: 15, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGallerySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.collections_rounded,
                  color: Color(0xFF42A5F5), size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'products.product_photos'.tr(args: ['${_galleryItems.length}']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_galleryItems.length < _maxGalleryPhotos)
                TextButton.icon(
                  onPressed: _pickMultipleImages,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: Color(0xFF42A5F5), size: 16),
                  label: Text(
                    'products.add_photos'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _galleryItems.length < _maxGalleryPhotos
                  ? _galleryItems.length + 1
                  : _galleryItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                if (idx == _galleryItems.length) {
                  return InkWell(
                    onTap: _pickMultipleImages,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCamera01,
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.85),
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'products.add_photos'.tr(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final item = _galleryItems[idx];
                final isCover = idx == 0;
                return GestureDetector(
                  onTap: isCover ? null : () => _setCoverPhoto(idx),
                  child: Container(
                    width: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCover
                            ? const Color(0xFF42A5F5)
                            : Colors.white.withValues(alpha: 0.14),
                        width: isCover ? 1.8 : 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.localBytes != null)
                          Image.memory(item.localBytes!, fit: BoxFit.cover)
                        else if (item.existingUrl != null)
                          Image.network(
                            item.existingUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white38, size: 22),
                            ),
                          ),
                        // Top-right remove button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(idx),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                        // Cover badge on index 0
                        if (isCover)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              color: const Color(0xFF42A5F5).withValues(alpha: 0.9),
                              child: Text(
                                'products.cover_badge'.tr(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
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
          if (_galleryItems.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              'products.tap_to_set_cover'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductVideoSection() {
    final hasVideo = (_pickedVideoBytes != null) ||
        (_existingVideoUrl != null && _existingVideoUrl!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasVideo
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_library_rounded,
                  color: Color(0xFFA78BFA), size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'products.product_video'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasVideo) ...[
                TextButton(
                  onPressed: _pickProductVideo,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'products.change_video'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _removeProductVideo,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'products.remove_video'.tr(),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (!hasVideo)
            InkWell(
              onTap: _pickProductVideo,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFFA78BFA),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'products.upload_product_video'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'products.video_hint'.tr(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white38, size: 20),
                  ],
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 170,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.55),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_videoPreviewReady && _videoPreviewCtrl != null)
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _videoPreviewCtrl!.value.size.width > 0
                              ? _videoPreviewCtrl!.value.size.width
                              : 320,
                          height: _videoPreviewCtrl!.value.size.height > 0
                              ? _videoPreviewCtrl!.value.size.height
                              : 180,
                          child: VideoPlayer(_videoPreviewCtrl!),
                        ),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_filled_rounded,
                              color: Color(0xFFA78BFA), size: 36),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _pickedVideoFile?.name ?? 'video.mp4',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_videoPreviewReady && _videoPreviewCtrl != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_videoPreviewCtrl!.value.isPlaying) {
                              _videoPreviewCtrl!.pause();
                              _videoPlaying = false;
                            } else {
                              _videoPreviewCtrl!.play();
                              _videoPlaying = true;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            _videoPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    if (_pickedVideoBytes != null)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(_pickedVideoBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
}

class _ProductPhotoDraft {
  final Uint8List? localBytes;
  final String? localName;
  final String? existingUrl;

  const _ProductPhotoDraft({
    this.localBytes,
    this.localName,
    this.existingUrl,
  });
}

class _OptionInputDialog extends StatefulWidget {
  final String title;
  final String nameLabel;
  final String priceLabel;
  final String initialName;
  final String initialPrice;
  final String initialStock;
  final String initialWeight;
  final String submitLabel;
  final bool showStockAndWeight;
  final bool requirePositivePrice;
  final void Function(String name, double price, int? stock, double? weightKg) onAdd;

  const _OptionInputDialog({
    required this.title,
    required this.nameLabel,
    required this.priceLabel,
    this.initialName = '',
    required this.initialPrice,
    this.initialStock = '',
    this.initialWeight = '',
    required this.submitLabel,
    this.showStockAndWeight = false,
    this.requirePositivePrice = false,
    required this.onAdd,
  });

  @override
  State<_OptionInputDialog> createState() => _OptionInputDialogState();
}

class _OptionInputDialogState extends State<_OptionInputDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _weightCtrl;
  bool _weightEditedManually = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _priceCtrl = TextEditingController(text: widget.initialPrice);
    _stockCtrl = TextEditingController(text: widget.initialStock);
    _weightCtrl = TextEditingController(text: widget.initialWeight);
    _weightEditedManually = widget.initialWeight.trim().isNotEmpty;
    if (widget.showStockAndWeight) {
      _nameCtrl.addListener(_maybeAutoFillWeight);
    }
  }

  void _maybeAutoFillWeight() {
    if (_weightEditedManually) return;
    final detected = ProductModel.parseWeightKgFromName(_nameCtrl.text);
    if (detected != null) {
      final formatted = detected % 1 == 0
          ? detected.toStringAsFixed(0)
          : detected.toString();
      if (_weightCtrl.text != formatted) {
        _weightCtrl.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    if (widget.showStockAndWeight) {
      _nameCtrl.removeListener(_maybeAutoFillWeight);
    }
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  InputDecoration _glassFieldDecoration(String label, bool isDark, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 2,
      helperStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black45,
        fontSize: 10.5,
      ),
      labelStyle: TextStyle(
        color: isDark ? Colors.white60 : Colors.black54,
        fontSize: 12.5,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
      ),
    );
  }

  void _handleSubmit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'products.variant_name_required'.tr());
      return;
    }
    final pr = double.tryParse(_priceCtrl.text.trim());
    if (widget.requirePositivePrice && (pr == null || pr <= 0)) {
      setState(() => _errorText = 'products.variant_price_required'.tr());
      return;
    }
    final stock = widget.showStockAndWeight && _stockCtrl.text.trim().isNotEmpty
        ? int.tryParse(_stockCtrl.text.trim())
        : null;
    final weightKg = widget.showStockAndWeight && _weightCtrl.text.trim().isNotEmpty
        ? double.tryParse(_weightCtrl.text.trim())
        : null;
    widget.onAdd(
      name,
      pr ?? 0.0,
      stock != null && stock >= 0 ? stock : null,
      weightKg != null && weightKg > 0 ? weightKg : null,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      onChanged: (_) {
                        if (_errorText != null) setState(() => _errorText = null);
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: _glassFieldDecoration(widget.nameLabel, isDark),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        if (_errorText != null) setState(() => _errorText = null);
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: _glassFieldDecoration(widget.priceLabel, isDark),
                    ),
                    if (widget.showStockAndWeight) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _stockCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                              decoration: _glassFieldDecoration(
                                'products.variant_stock'.tr(),
                                isDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _weightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) {
                                _weightEditedManually = v.trim().isNotEmpty;
                              },
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                              decoration: _glassFieldDecoration(
                                'products.variant_weight'.tr(),
                                isDark,
                                helperText: 'products.variant_weight_hint'.tr(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'common.cancel'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _handleSubmit,
                          child: Text(
                            widget.submitLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
}

class _TwoTierVariantMatrixDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existingVariants;
  final List<String> galleryUrls;
  final double defaultPrice;
  final double defaultWeightKg;
  final void Function(List<Map<String, dynamic>> variants) onSave;

  const _TwoTierVariantMatrixDialog({
    required this.existingVariants,
    required this.galleryUrls,
    required this.defaultPrice,
    required this.defaultWeightKg,
    required this.onSave,
  });

  @override
  State<_TwoTierVariantMatrixDialog> createState() =>
      _TwoTierVariantMatrixDialogState();
}

class _TwoTierVariantMatrixDialogState
    extends State<_TwoTierVariantMatrixDialog> {
  late final TextEditingController _t1LabelCtrl;
  late final TextEditingController _t2LabelCtrl;
  final TextEditingController _t1InputCtrl = TextEditingController();
  final TextEditingController _t2InputCtrl = TextEditingController();
  final TextEditingController _bulkPriceCtrl = TextEditingController();
  final TextEditingController _bulkStockCtrl = TextEditingController();
  final TextEditingController _bulkWeightCtrl = TextEditingController();

  final List<String> _tier1Options = [];
  final List<String> _tier2Options = [];
  final Map<String, String> _tier1Images = {};

  // Keyed by "$t1||$t2"
  final Map<String, TextEditingController> _priceCtrls = {};
  final Map<String, TextEditingController> _stockCtrls = {};
  final Map<String, TextEditingController> _weightCtrls = {};
  String? _errorText;

  static const _clothingSizePreset = ['XS', 'S', 'M', 'L', 'XL', '2XL'];

  String _comboKey(String t1, String t2) => '$t1||$t2';

  @override
  void initState() {
    super.initState();
    String initT1Label = 'Color';
    String initT2Label = 'Size';
    for (final v in widget.existingVariants) {
      final l1 = (v['tier1_label'] ?? '').toString().trim();
      final l2 = (v['tier2_label'] ?? '').toString().trim();
      if (l1.isNotEmpty) initT1Label = l1;
      if (l2.isNotEmpty) initT2Label = l2;
      final v1 = (v['tier1_value'] ?? '').toString().trim();
      final v2 = (v['tier2_value'] ?? '').toString().trim();
      if (v1.isNotEmpty && !_tier1Options.contains(v1)) {
        _tier1Options.add(v1);
      }
      if (v2.isNotEmpty && !_tier2Options.contains(v2)) {
        _tier2Options.add(v2);
      }
      final img = (v['image_url'] ?? '').toString().trim();
      if (v1.isNotEmpty && img.isNotEmpty) {
        _tier1Images[v1] = img;
      }
      if (v1.isNotEmpty && v2.isNotEmpty) {
        final key = _comboKey(v1, v2);
        final pr = (v['price'] as num?)?.toDouble() ??
            double.tryParse(v['price']?.toString() ?? '') ??
            0.0;
        final st = v['stock'];
        final wt = v['weight_kg'];
        _priceCtrls[key] = TextEditingController(
          text: pr > 0 ? pr.toStringAsFixed(2) : '',
        );
        _stockCtrls[key] = TextEditingController(
          text: st != null ? st.toString() : '',
        );
        _weightCtrls[key] = TextEditingController(
          text: wt != null ? wt.toString() : '',
        );
      }
    }
    _t1LabelCtrl = TextEditingController(text: initT1Label);
    _t2LabelCtrl = TextEditingController(text: initT2Label);
    if (widget.defaultPrice > 0) {
      _bulkPriceCtrl.text = widget.defaultPrice.toStringAsFixed(2);
    }
    if (widget.defaultWeightKg > 0) {
      _bulkWeightCtrl.text = widget.defaultWeightKg.toString();
    }
    _ensureComboControllers();
  }

  void _ensureComboControllers() {
    for (final t1 in _tier1Options) {
      for (final t2 in _tier2Options) {
        final key = _comboKey(t1, t2);
        _priceCtrls.putIfAbsent(
          key,
          () => TextEditingController(text: _bulkPriceCtrl.text.trim()),
        );
        _stockCtrls.putIfAbsent(
          key,
          () => TextEditingController(text: _bulkStockCtrl.text.trim()),
        );
        _weightCtrls.putIfAbsent(
          key,
          () => TextEditingController(text: _bulkWeightCtrl.text.trim()),
        );
      }
    }
  }

  @override
  void dispose() {
    _t1LabelCtrl.dispose();
    _t2LabelCtrl.dispose();
    _t1InputCtrl.dispose();
    _t2InputCtrl.dispose();
    _bulkPriceCtrl.dispose();
    _bulkStockCtrl.dispose();
    _bulkWeightCtrl.dispose();
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    for (final c in _stockCtrls.values) {
      c.dispose();
    }
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTier1Option() {
    final val = _t1InputCtrl.text.trim();
    if (val.isEmpty) return;
    if (!_tier1Options.contains(val)) {
      setState(() {
        _tier1Options.add(val);
        _t1InputCtrl.clear();
        _errorText = null;
        _ensureComboControllers();
      });
    } else {
      _t1InputCtrl.clear();
    }
  }

  void _addTier2Option() {
    final val = _t2InputCtrl.text.trim();
    if (val.isEmpty) return;
    if (!_tier2Options.contains(val)) {
      setState(() {
        _tier2Options.add(val);
        _t2InputCtrl.clear();
        _errorText = null;
        _ensureComboControllers();
      });
    } else {
      _t2InputCtrl.clear();
    }
  }

  void _applyClothingSizePreset() {
    setState(() {
      for (final sz in _clothingSizePreset) {
        if (!_tier2Options.contains(sz)) _tier2Options.add(sz);
      }
      _errorText = null;
      _ensureComboControllers();
    });
  }

  void _applyBulkToAll() {
    final bp = _bulkPriceCtrl.text.trim();
    final bs = _bulkStockCtrl.text.trim();
    final bw = _bulkWeightCtrl.text.trim();
    setState(() {
      for (final t1 in _tier1Options) {
        for (final t2 in _tier2Options) {
          final key = _comboKey(t1, t2);
          if (bp.isNotEmpty) _priceCtrls[key]?.text = bp;
          if (bs.isNotEmpty) _stockCtrls[key]?.text = bs;
          if (bw.isNotEmpty) _weightCtrls[key]?.text = bw;
        }
      }
      _errorText = null;
    });
  }

  void _pickTier1Photo(String t1Val) {
    if (widget.galleryUrls.isEmpty) return;
    final current = _tier1Images[t1Val];
    showDialog<void>(
      context: context,
      builder: (pCtx) => Dialog(
        backgroundColor: const Color(0xFF141826),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t1Val,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _tier1Images.remove(t1Val));
                      Navigator.pop(pCtx);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: current == null
                              ? const Color(0xFF42A5F5)
                              : Colors.white12,
                          width: current == null ? 2 : 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ),
                  ...widget.galleryUrls.map((url) {
                    final sel = current == url;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _tier1Images[t1Val] = url);
                        Navigator.pop(pCtx);
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF42A5F5)
                                : Colors.white12,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    if (_tier1Options.isEmpty || _tier2Options.isEmpty) {
      setState(() => _errorText = 'products.matrix_err_missing_tiers'.tr());
      return;
    }
    final t1Label = _t1LabelCtrl.text.trim().isEmpty
        ? 'Color'
        : _t1LabelCtrl.text.trim();
    final t2Label = _t2LabelCtrl.text.trim().isEmpty
        ? 'Size'
        : _t2LabelCtrl.text.trim();

    final out = <Map<String, dynamic>>[];
    for (final t1 in _tier1Options) {
      for (final t2 in _tier2Options) {
        final key = _comboKey(t1, t2);
        final pr = double.tryParse(_priceCtrls[key]?.text.trim() ?? '');
        if (pr == null || pr <= 0) {
          setState(() => _errorText = 'products.matrix_err_invalid_price'.tr());
          return;
        }
        final stText = _stockCtrls[key]?.text.trim() ?? '';
        final st = stText.isNotEmpty ? int.tryParse(stText) : null;
        final wtText = _weightCtrls[key]?.text.trim() ?? '';
        final wt = wtText.isNotEmpty ? double.tryParse(wtText) : null;
        final img = _tier1Images[t1];

        out.add({
          'name': '$t1 / $t2',
          'tier1_label': t1Label,
          'tier1_value': t1,
          'tier2_label': t2Label,
          'tier2_value': t2,
          'price': pr,
          if (st != null && st >= 0) 'stock': st,
          if (wt != null && wt > 0) 'weight_kg': wt,
          if (img != null && img.isNotEmpty) 'image_url': img,
        });
      }
    }
    widget.onSave(out);
    Navigator.pop(context);
  }

  InputDecoration _miniField(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comboCount = _tier1Options.length * _tier2Options.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101322).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: Color(0xFFA78BFA),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'products.two_tier_matrix_title'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'products.two_tier_matrix_subtitle'.tr(),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tier 1 Setup
                          TextField(
                            controller: _t1LabelCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: _miniField('products.tier1_name_label'.tr()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _t1InputCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  onSubmitted: (_) => _addTier1Option(),
                                  decoration: _miniField('products.tier1_add_hint'.tr()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addTier1Option,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF42A5F5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'common.add'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_tier1Options.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            if (widget.galleryUrls.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'products.matrix_tier1_photo_hint'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _tier1Options.map((val) {
                                final thumb = _tier1Images[val];
                                return InputChip(
                                  avatar: thumb != null
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(thumb),
                                        )
                                      : (widget.galleryUrls.isNotEmpty
                                          ? const Icon(
                                              Icons.image_outlined,
                                              size: 14,
                                              color: Color(0xFF42A5F5),
                                            )
                                          : null),
                                  label: Text(
                                    val,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  deleteIconColor: Colors.white54,
                                  onPressed: widget.galleryUrls.isNotEmpty
                                      ? () => _pickTier1Photo(val)
                                      : null,
                                  onDeleted: () => setState(() {
                                    _tier1Options.remove(val);
                                    _tier1Images.remove(val);
                                  }),
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Tier 2 Setup
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _t2LabelCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: _miniField('products.tier2_name_label'.tr()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _applyClothingSizePreset,
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.checkroom_rounded,
                                  size: 14,
                                  color: Color(0xFFA78BFA),
                                ),
                                label: Text(
                                  'products.preset_clothing_sizes'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFFA78BFA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _t2InputCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  onSubmitted: (_) => _addTier2Option(),
                                  decoration: _miniField('products.tier2_add_hint'.tr()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addTier2Option,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF42A5F5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'common.add'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_tier2Options.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _tier2Options.map((val) {
                                return InputChip(
                                  label: Text(
                                    val,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  deleteIconColor: Colors.white54,
                                  onDeleted: () => setState(() {
                                    _tier2Options.remove(val);
                                  }),
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Quick Fill All Bar
                          if (comboCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'products.apply_all_title'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _bulkPriceCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                          ),
                                          decoration: _miniField(
                                            'products.matrix_price_short'.tr(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextField(
                                          controller: _bulkStockCtrl,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                          ),
                                          decoration: _miniField(
                                            'products.matrix_stock_short'.tr(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextField(
                                          controller: _bulkWeightCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                          ),
                                          decoration: _miniField(
                                            'products.matrix_weight_short'.tr(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _applyBulkToAll,
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(0xFF42A5F5),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        'products.apply_all_btn'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'products.combinations_title'
                                  .tr(args: ['$comboCount']),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._tier1Options.expand(
                              (t1) => _tier2Options.map((t2) {
                                final key = _comboKey(t1, t2);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$t1 / $t2',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextField(
                                              controller: _priceCtrls[key],
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(decimal: true),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                              ),
                                              decoration: _miniField(
                                                'products.matrix_price_short'.tr(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: _stockCtrls[key],
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                              ),
                                              decoration: _miniField(
                                                'products.matrix_stock_short'.tr(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: _weightCtrls[key],
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(decimal: true),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                              ),
                                              decoration: _miniField(
                                                'products.matrix_weight_short'.tr(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'products.matrix_empty_hint'.tr(),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          if (_errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorText!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'common.cancel'.tr(),
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: comboCount > 0 ? _handleSave : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'products.matrix_save_btn'
                                .tr(args: ['$comboCount']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

