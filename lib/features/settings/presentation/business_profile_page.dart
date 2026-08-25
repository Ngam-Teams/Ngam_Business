import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../widgets/glass_toast.dart';
import '../data/business_service.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key});

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _service = BusinessService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _businessId;

  // Controllers
  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _regNoController = TextEditingController();

  String? _logoUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await _service.getBusinessProfile();
    
    if (mounted) {
      if (data != null) {
        _businessId = data['id'];
        _nameController.text = data['business_name'] ?? '';
        _industryController.text = data['business_industry'] ?? '';
        _phoneController.text = data['business_phone'] ?? '';
        _websiteController.text = data['business_website'] ?? '';
        _cityController.text = data['business_city'] ?? '';
        _countryController.text = data['business_country'] ?? '';
        _regNoController.text = data['business_registration_number'] ?? '';
        _logoUrl = data['business_logo_url'];
        _coverUrl = data['business_cover_url'];
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _businessId == null) return;
    
    setState(() => _isSaving = true);
    
    final updates = {
      'business_industry': _industryController.text.trim(),
      'business_phone': _phoneController.text.trim(),
      'business_website': _websiteController.text.trim(),
      'business_city': _cityController.text.trim(),
      'business_country': _countryController.text.trim(),
      'business_registration_number': _regNoController.text.trim(),
    };

    try {
      await _service.updateBusinessProfile(_businessId!, updates);
      if (mounted) {
        showGlassToast(context, 'Business profile updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Failed to update profile.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage(String type) async {
    if (_businessId == null) return;
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    setState(() => _isSaving = true);
    final folder = type == 'logo' ? 'logos' : 'covers';
    final url = await _service.uploadBusinessImage(_businessId!, folder, image);
    
    if (url != null) {
      // Update the database with the new URL
      final field = type == 'logo' ? 'business_logo_url' : 'business_cover_url';
      await _service.updateBusinessProfile(_businessId!, {field: url});
      
      setState(() {
        if (type == 'logo') _logoUrl = url;
        if (type == 'cover') _coverUrl = url;
      });
      if (mounted) showGlassToast(context, '${type.toUpperCase()} uploaded successfully!');
    } else {
      if (mounted) showGlassToast(context, 'Upload failed.', isError: true);
    }
    
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _regNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Business Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0).copyWith(bottom: 120),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover & Logo
                        _buildImagesSection(),
                        
                        const SizedBox(height: 32),
                        
                        // Basic Details
                        const Text(
                          'Basic Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Business Name (Locked)
                        _buildLockedNameField(),
                        
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Industry',
                          controller: _industryController,
                          icon: HugeIcons.strokeRoundedBriefcase02,
                          hint: 'e.g. F&B, Barber, Retail',
                        ),
                        
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Registration Number',
                          controller: _regNoController,
                          icon: HugeIcons.strokeRoundedBuilding03,
                          hint: 'SSM / Registration No.',
                        ),

                        const SizedBox(height: 32),
                        
                        // Contact Info
                        const Text(
                          'Contact & Location',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          icon: HugeIcons.strokeRoundedCall02,
                          keyboardType: TextInputType.phone,
                          hint: '+60...',
                        ),
                        
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Website',
                          controller: _websiteController,
                          icon: HugeIcons.strokeRoundedGlobe02,
                          keyboardType: TextInputType.url,
                          hint: 'https://...',
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'City',
                                controller: _cityController,
                                icon: HugeIcons.strokeRoundedCity01,
                                hint: 'Kuala Lumpur',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                label: 'Country',
                                controller: _countryController,
                                icon: HugeIcons.strokeRoundedGlobal,
                                hint: 'Malaysia',
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
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

  Widget _buildImagesSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Image
        GestureDetector(
          onTap: () => _pickAndUploadImage('cover'),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              image: _coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_coverUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _coverUrl == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: Colors.white54,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text('Add Cover Image', style: TextStyle(color: Colors.white54)),
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
        // Logo
        Positioned(
          bottom: -40,
          left: 24,
          child: GestureDetector(
            onTap: () => _pickAndUploadImage('logo'),
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0A0A14), width: 4),
                image: _logoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_logoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (_logoUrl == null)
                    const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedBuilding03,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0A0A14), width: 2),
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: Colors.white,
                        size: 14,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Business Name',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedStore01,
                color: Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _nameController.text.isNotEmpty ? _nameController.text : 'Unknown',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showGlassToast(
                  context,
                  'Request sent to admin for approval.',
                  customColor: const Color(0xFF42A5F5),
                ),
                child: const Text(
                  'Request Change',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required dynamic icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HugeIcon(
                icon: icon,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF42A5F5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
