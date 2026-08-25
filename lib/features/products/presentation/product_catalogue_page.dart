import 'dart:ui';
import 'dart:typed_data';
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

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _service.fetchAllProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  void _showAddProductModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddProductSheet(),
    ).then((value) {
      if (value == true) {
        _loadProducts();
      }
    });
  }

  Future<void> _toggleAvailability(ProductModel product) async {
    final success = await _service.updateProduct(
      product.id,
      {'is_available': !product.isAvailable},
    );
    if (success) {
      _loadProducts();
    } else {
      if (mounted) {
        showGlassToast(context, 'Failed to update product', isError: true);
      }
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Delete Product', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${product.name}?', style: const TextStyle(color: Colors.white70)),
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
        if (mounted) showGlassToast(context, 'Product deleted');
      } else {
        if (mounted) showGlassToast(context, 'Failed to delete product', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Items & Services',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductModal,
        backgroundColor: const Color(0xFF42A5F5),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 20),
        label: const Text('Add Item/Service', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : _products.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _buildProductCard(product);
                  },
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
            'No products yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    image: product.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(product.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.imageUrl == null
                      ? Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedImage01,
                            color: Colors.white.withValues(alpha: 0.2),
                            size: 32,
                          ),
                        )
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF42A5F5),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Switch(
                          value: product.isAvailable,
                          onChanged: (_) => _toggleAvailability(product),
                          activeColor: const Color(0xFF42A5F5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        IconButton(
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01, color: Colors.redAccent, size: 18),
                          onPressed: () => _deleteProduct(product),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet();

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _service = ProductService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stockController = TextEditingController();
  final _descController = TextEditingController();
  final _skuController = TextEditingController();
  
  XFile? _imageFile;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    
    Uint8List? imageBytes;
    String? imageExt;
    
    if (_imageFile != null) {
      imageBytes = await _imageFile!.readAsBytes();
      imageExt = _imageFile!.name.split('.').last;
    }
    
    final product = await _service.addProduct(
      name: _nameController.text.trim(),
      price: price,
      category: _categoryController.text.trim(),
      description: _descController.text.trim(),
      sku: _skuController.text.trim(),
      stock: stock,
      imageBytes: imageBytes,
      imageExt: imageExt,
    );
    
    if (mounted) {
      if (product != null) {
        showGlassToast(context, 'Product added successfully');
        Navigator.pop(context, true);
      } else {
        showGlassToast(context, 'Failed to add product', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24).withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Item / Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: NetworkImage(_imageFile!.path),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCamera01,
                                  color: Colors.white54,
                                  size: 24, // Smaller icon size!
                                ),
                                SizedBox(height: 8),
                                Text('Add Product Image', style: TextStyle(color: Colors.white54)),
                              ],
                            )
                          : const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedEdit02,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Item/Service Name', HugeIcons.strokeRoundedPackage),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Price (RM)', HugeIcons.strokeRoundedMoney01),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Stock Qty', HugeIcons.strokeRoundedDashboardSquare02),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Category', HugeIcons.strokeRoundedTag01),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _skuController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('SKU/Barcode', HugeIcons.strokeRoundedQrCode),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: _inputDecoration('Description', HugeIcons.strokeRoundedNote01),
                  ),
                  
                  const SizedBox(height: 32),
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
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  InputDecoration _inputDecoration(String label, dynamic icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: HugeIcon(icon: icon, color: Colors.white54, size: 20),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
    );
  }
}
