import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../widgets/glass_toast.dart';
import '../../../widgets/map_picker_screen.dart';
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
  bool _detectingGps = false;
  String? _businessId;

  // Identity Controllers
  final _nameController = TextEditingController();
  String _selectedIndustry = 'services';
  final _regNoController = TextEditingController();
  final _sstNoController = TextEditingController();

  // Contact Controllers
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  // Address Controllers
  final _addressLineController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedState;
  final _countryController = TextEditingController(text: 'Malaysia');

  // Media & Geolocation
  String? _logoUrl;
  String? _coverUrl;
  double? _latitude;
  double? _longitude;

  // Settings (Operating hours & Store features)
  bool _isHalal = false;
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);
  int _slotDuration = 30;
  final _chairsController = TextEditingController(text: '1');

  // Banking & Compliance
  String? _selectedBank;
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();

  static final List<Map<String, dynamic>> _industries = [
    {
      'id': 'fnb',
      'label': 'Food & Beverage',
      'icon': HugeIcons.strokeRoundedRestaurant01,
      'subtitle': 'Restaurants, Cafes, Bakeries & Food stalls',
    },
    {
      'id': 'barber',
      'label': 'Barber & Salon',
      'icon': HugeIcons.strokeRoundedScissor,
      'subtitle': 'Barbershops, Hair Salons, Spas & Grooming',
    },
    {
      'id': 'retail',
      'label': 'Retail & Shopping',
      'icon': HugeIcons.strokeRoundedShoppingBag01,
      'subtitle': 'Boutiques, Marts, Electronics & General Stores',
    },
    {
      'id': 'services',
      'label': 'Services & Other',
      'icon': HugeIcons.strokeRoundedBriefcase02,
      'subtitle': 'Consulting, Workshops, Fitness & Professional',
    },
  ];

  static const List<String> _malaysianStates = [
    'Kuala Lumpur',
    'Selangor',
    'Penang',
    'Johor',
    'Perak',
    'Melaka',
    'Kedah',
    'Pahang',
    'Negeri Sembilan',
    'Kelantan',
    'Terengganu',
    'Perlis',
    'Sabah',
    'Sarawak',
    'Putrajaya',
    'Labuan',
  ];

  static const List<String> _malaysianBanks = [
    'Maybank',
    'CIMB Bank',
    'Public Bank',
    'RHB Bank',
    'Hong Leong Bank',
    'AmBank',
    'Bank Islam',
    'Affin Bank',
    'Alliance Bank',
    'Standard Chartered',
    'HSBC Bank',
    'Other Bank',
  ];

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

        final industry = (data['business_industry'] as String? ?? 'services').toLowerCase();
        if (_industries.any((i) => i['id'] == industry)) {
          _selectedIndustry = industry;
        } else {
          _selectedIndustry = 'services';
        }

        _regNoController.text = data['business_registration_number'] ?? '';
        _sstNoController.text = data['sst_number'] ?? '';
        _phoneController.text = data['business_phone'] ?? '';
        _emailController.text = data['business_email'] ?? '';
        _websiteController.text = data['business_website'] ?? '';

        _addressLineController.text = data['address_line'] ?? '';
        _postcodeController.text = data['postcode'] ?? '';
        _cityController.text = data['business_city'] ?? '';

        final stateVal = data['state'] as String?;
        if (stateVal != null && _malaysianStates.contains(stateVal)) {
          _selectedState = stateVal;
        } else if (stateVal != null && stateVal.isNotEmpty) {
          _selectedState = stateVal;
        }

        _countryController.text = data['business_country'] ?? 'Malaysia';
        _logoUrl = data['business_logo_url'];
        _coverUrl = data['business_cover_url'];
        _latitude = (data['latitude'] as num?)?.toDouble();
        _longitude = (data['longitude'] as num?)?.toDouble();

        // Load Settings if present
        if (data['settings'] != null) {
          final settings = data['settings'] as Map<String, dynamic>;
          _isHalal = settings['is_halal'] ?? false;
          _slotDuration = settings['slot_duration'] ?? 30;
          _chairsController.text = (settings['total_chairs'] ?? 1).toString();

          final opHours = settings['operating_hours'];
          if (opHours is Map) {
            final openStr = opHours['open_time'] as String?;
            final closeStr = opHours['close_time'] as String?;
            if (openStr != null && openStr.contains(':')) {
              final parts = openStr.split(':');
              _openTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
            }
            if (closeStr != null && closeStr.contains(':')) {
              final parts = closeStr.split(':');
              _closeTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 22, minute: int.tryParse(parts[1]) ?? 0);
            }
          }
        }

        // Load Compliance if present
        if (data['compliance'] != null) {
          final compliance = data['compliance'] as Map<String, dynamic>;
          final bank = compliance['bank_name'] as String?;
          if (bank != null && _malaysianBanks.contains(bank)) {
            _selectedBank = bank;
          } else if (bank != null && bank.isNotEmpty) {
            _selectedBank = 'Other Bank';
          }
          _accountHolderController.text = compliance['account_holder'] ?? '';
          _accountNumberController.text = compliance['account_number'] ?? '';
        }
      }
      setState(() => _isLoading = false);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      showGlassToast(context, 'Please complete the required fields.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final businessData = {
      'business_name': _nameController.text.trim(),
      'business_industry': _selectedIndustry,
      'business_registration_number': _regNoController.text.trim().isNotEmpty
          ? _regNoController.text.trim()
          : 'PENDING-REG',
      'sst_number': _sstNoController.text.trim(),
      'business_phone': _phoneController.text.trim(),
      'business_email': _emailController.text.trim(),
      'business_website': _websiteController.text.trim(),
      'address_line': _addressLineController.text.trim(),
      'postcode': _postcodeController.text.trim(),
      'business_city': _cityController.text.trim(),
      'state': _selectedState ?? '',
      'business_country': _countryController.text.trim().isNotEmpty
          ? _countryController.text.trim()
          : 'Malaysia',
      'latitude': _latitude,
      'longitude': _longitude,
      'business_logo_url': _logoUrl,
      'business_cover_url': _coverUrl,
    };

    final settingsData = {
      'is_halal': _isHalal,
      'slot_duration': _slotDuration,
      'total_chairs': int.tryParse(_chairsController.text.trim()) ?? 1,
      'operating_hours': {
        'open_time': _formatTimeOfDay(_openTime),
        'close_time': _formatTimeOfDay(_closeTime),
        'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      },
    };

    final complianceData = {
      'bank_name': _selectedBank ?? '',
      'account_holder': _accountHolderController.text.trim(),
      'account_number': _accountNumberController.text.trim(),
    };

    try {
      await _service.saveFullBusinessDetails(
        businessId: _businessId,
        businessData: businessData,
        settingsData: settingsData,
        complianceData: complianceData,
      );

      if (mounted) {
        showGlassToast(context, 'Business details saved successfully!');
        // Refresh profile state
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Failed to save details: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (image == null) return;

    setState(() => _isSaving = true);

    try {
      // Ensure business exists before uploading
      if (_businessId == null) {
        final created = await _service.createBusinessProfile(
          businessName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : 'My Business',
          businessIndustry: _selectedIndustry,
        );
        _businessId = created['id'];
      }

      final folder = type == 'logo' ? 'logos' : 'covers';
      final url = await _service.uploadBusinessImage(_businessId!, folder, image);

      if (url != null) {
        final field = type == 'logo' ? 'business_logo_url' : 'business_cover_url';
        await _service.updateBusinessProfile(_businessId!, {field: url});

        setState(() {
          if (type == 'logo') _logoUrl = url;
          if (type == 'cover') _coverUrl = url;
        });

        if (mounted) {
          showGlassToast(context, '${type == 'logo' ? 'Logo' : 'Cover'} uploaded successfully!');
        }
      } else {
        if (mounted) showGlassToast(context, 'Upload failed. Storage bucket error.', isError: true);
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime(bool isOpenTime) async {
    final initial = isOpenTime ? _openTime : _closeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF42A5F5),
              surface: Color(0xFF1A1A24),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regNoController.dispose();
    _sstNoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressLineController.dispose();
    _postcodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _chairsController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNewBusiness = _businessId == null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10101A),
        elevation: 0,
        title: Text(
          isNewBusiness ? 'Add Business Details' : 'Business Profile & Details',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedTick01,
                        color: Color(0xFF42A5F5),
                        size: 18,
                      ),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save',
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0).copyWith(bottom: 120),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover & Logo Branding
                        _buildImagesSection(),

                        const SizedBox(height: 36),

                        // Section 1: Business Identity
                        _buildSectionHeader(
                          title: 'Business Identity',
                          subtitle: 'Your public business name, category, and legal registration',
                          icon: HugeIcons.strokeRoundedStore01,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          // Business Name (Unlocked & Editable)
                          _buildTextField(
                            label: 'Business Name *',
                            controller: _nameController,
                            icon: HugeIcons.strokeRoundedStore01,
                            hint: 'e.g. Kedai Kopi Ngam',
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Business name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Industry Selector (fnb, barber, retail, services)
                          _buildIndustrySelector(),

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Registration Number (SSM)',
                                  controller: _regNoController,
                                  icon: HugeIcons.strokeRoundedBuilding03,
                                  hint: 'e.g. 202401012345 (123456-X)',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildTextField(
                                  label: 'SST Number (Optional)',
                                  controller: _sstNoController,
                                  icon: HugeIcons.strokeRoundedInvoice01,
                                  hint: 'e.g. W10-1808-32000018',
                                ),
                              ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 28),

                        // Section 2: Contact Info
                        _buildSectionHeader(
                          title: 'Contact Information',
                          subtitle: 'How customers reach you for orders, queries, and bookings',
                          icon: HugeIcons.strokeRoundedCall02,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          _buildTextField(
                            label: 'Business Phone / WhatsApp',
                            controller: _phoneController,
                            icon: HugeIcons.strokeRoundedCall02,
                            keyboardType: TextInputType.phone,
                            hint: 'e.g. +60123456789',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Business Email',
                            controller: _emailController,
                            icon: HugeIcons.strokeRoundedMail01,
                            keyboardType: TextInputType.emailAddress,
                            hint: 'e.g. hello@kedaingam.my',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Website / Social Link',
                            controller: _websiteController,
                            icon: HugeIcons.strokeRoundedGlobe02,
                            keyboardType: TextInputType.url,
                            hint: 'e.g. https://instagram.com/kedaingam',
                          ),
                        ]),

                        const SizedBox(height: 28),

                        // Section 3: Physical Address & Map Location Pin
                        _buildSectionHeader(
                          title: 'Address & Store Location',
                          subtitle: 'Used by customers on Ngam Explore to find your premises',
                          icon: HugeIcons.strokeRoundedLocation01,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          _buildTextField(
                            label: 'Street Address *',
                            controller: _addressLineController,
                            icon: HugeIcons.strokeRoundedLocation01,
                            hint: 'e.g. Lot 3-12, Level 3, Pavilion Kuala Lumpur',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  label: 'Postcode',
                                  controller: _postcodeController,
                                  icon: HugeIcons.strokeRoundedMailbox01,
                                  keyboardType: TextInputType.number,
                                  hint: 'e.g. 55100',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  label: 'City',
                                  controller: _cityController,
                                  icon: HugeIcons.strokeRoundedCity01,
                                  hint: 'e.g. Kuala Lumpur',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStateDropdown(),
                              ),
                              const SizedBox(width: 12),
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
                          const SizedBox(height: 20),
                          const Divider(color: Color(0x1AFFFFFF), height: 1),
                          const SizedBox(height: 16),
                          // Map Picker
                          _buildMapSection(),
                        ]),

                        const SizedBox(height: 28),

                        // Section 4: Operating Hours & Settings
                        _buildSectionHeader(
                          title: 'Operating Hours & Settings',
                          subtitle: 'Control business open hours, halal certification, and booking capacity',
                          icon: HugeIcons.strokeRoundedTime02,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          // Halal Toggle
                          _buildHalalSwitch(),
                          const SizedBox(height: 20),
                          const Divider(color: Color(0x1AFFFFFF), height: 1),
                          const SizedBox(height: 20),

                          // Operating Hours Pickers
                          const Text(
                            'Daily Operating Hours',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimePickerTile(
                                  label: 'Opening Time',
                                  time: _openTime,
                                  onTap: () => _selectTime(true),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildTimePickerTile(
                                  label: 'Closing Time',
                                  time: _closeTime,
                                  onTap: () => _selectTime(false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Color(0x1AFFFFFF), height: 1),
                          const SizedBox(height: 20),

                          // Booking & Capacity
                          Row(
                            children: [
                              Expanded(
                                child: _buildSlotDurationDropdown(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Service Capacity / Chairs',
                                  controller: _chairsController,
                                  icon: HugeIcons.strokeRoundedUserGroup,
                                  keyboardType: TextInputType.number,
                                  hint: '1',
                                ),
                              ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 28),

                        // Section 5: Banking & Payout Info
                        _buildSectionHeader(
                          title: 'Banking & Payout Account',
                          subtitle: 'Bank details for customer settlement payouts and platform billing',
                          icon: HugeIcons.strokeRoundedCreditCard,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          _buildBankDropdown(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Account Holder Name',
                            controller: _accountHolderController,
                            icon: HugeIcons.strokeRoundedUser,
                            hint: 'e.g. Syarikat Ngam Sdn Bhd',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Bank Account Number',
                            controller: _accountNumberController,
                            icon: HugeIcons.strokeRoundedInvoice02,
                            keyboardType: TextInputType.number,
                            hint: 'e.g. 514012345678',
                          ),
                        ]),

                        const SizedBox(height: 40),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child: _isSaving
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Saving Details...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      HugeIcon(
                                        icon: isNewBusiness
                                            ? HugeIcons.strokeRoundedAdd01
                                            : HugeIcons.strokeRoundedTick01,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isNewBusiness ? 'Add Business Details' : 'Save Business Changes',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
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

  // ---------------------------------------------------------------------------
  // Widget Builders
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required dynamic icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(
            icon: icon,
            color: const Color(0xFF42A5F5),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
            height: 170,
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
                      Text(
                        'Tap to Upload Store Cover Banner',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedEdit02,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text('Change Cover', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        // Logo Avatar
        Positioned(
          bottom: -32,
          left: 20,
          child: GestureDetector(
            onTap: () => _pickAndUploadImage('logo'),
            child: Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
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
                        icon: HugeIcons.strokeRoundedStore01,
                        color: Colors.white54,
                        size: 30,
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

  Widget _buildIndustrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Business Category *',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: _industries.length,
          itemBuilder: (context, index) {
            final item = _industries[index];
            final isSelected = _selectedIndustry == item['id'];

            return GestureDetector(
              onTap: () => setState(() => _selectedIndustry = item['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF42A5F5)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: item['icon'],
                      color: isSelected ? const Color(0xFF42A5F5) : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item['subtitle'],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'State',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedState != null && _malaysianStates.contains(_selectedState)
              ? _selectedState
              : null,
          dropdownColor: const Color(0xFF1A1A24),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            hintText: 'Select State',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMapPin,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
          items: _malaysianStates.map((state) {
            return DropdownMenuItem<String>(
              value: state,
              child: Text(state, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedState = val),
        ),
      ],
    );
  }

  Widget _buildBankDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Bank Name',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedBank != null && _malaysianBanks.contains(_selectedBank)
              ? _selectedBank
              : null,
          dropdownColor: const Color(0xFF1A1A24),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Select Payout Bank',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedBuilding03,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
          items: _malaysianBanks.map((bank) {
            return DropdownMenuItem<String>(
              value: bank,
              child: Text(bank, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedBank = val),
        ),
      ],
    );
  }

  Widget _buildSlotDurationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Booking Slot Duration',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButtonFormField<int>(
          isExpanded: true,
          value: _slotDuration,
          dropdownColor: const Color(0xFF1A1A24),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 15, child: Text('15 Minutes', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 30, child: Text('30 Minutes', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 45, child: Text('45 Minutes', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 60, child: Text('60 Minutes (1 Hour)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 90, child: Text('90 Minutes', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 120, child: Text('120 Minutes (2 Hours)', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _slotDuration = val);
          },
        ),
      ],
    );
  }

  Widget _buildHalalSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isHalal
            ? const Color(0xFF44CF6C).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isHalal
              ? const Color(0xFF44CF6C).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isHalal
                  ? const Color(0xFF44CF6C).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkBadge01,
              color: _isHalal ? const Color(0xFF44CF6C) : Colors.white54,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Halal Certified / Muslim Friendly',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (_isHalal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF44CF6C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HALAL',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Displays a Halal verified badge on customer app search and explore pages',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isHalal,
            activeColor: const Color(0xFF44CF6C),
            onChanged: (val) => setState(() => _isHalal = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              color: Color(0xFF42A5F5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required dynamic icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: HugeIcon(
                icon: icon,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _autoDetectGps() async {
    setState(() => _detectingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showGlassToast(context, 'GPS dimatikan. Sila hidupkan lokasi dalam tetapan.', isError: true);
        }
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showGlassToast(context, 'Kebenaran GPS ditolak. Sila benarkan akses lokasi.', isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showGlassToast(context, 'Kebenaran GPS disekat kekal. Sila benarkan dalam tetapan aplikasi.', isError: true);
        }
        await Geolocator.openAppSettings();
        return;
      }

      // Check last known position first as quick fallback
      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        setState(() {
          _latitude = lastKnown.latitude;
          _longitude = lastKnown.longitude;
        });
      }

      Position currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      }

      setState(() {
        _latitude = currentPos.latitude;
        _longitude = currentPos.longitude;
      });

      if (_businessId != null) {
        await _service.updateBusinessProfile(_businessId!, {
          'latitude': _latitude,
          'longitude': _longitude,
        });
      }

      if (mounted) {
        showGlassToast(context, 'Lokasi GPS berjaya dikesan: ${currentPos.latitude.toStringAsFixed(4)}, ${currentPos.longitude.toStringAsFixed(4)}');
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Satelit GPS lemah. Anda boleh buka peta untuk pin kedai secara manual.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _detectingGps = false);
    }
  }

  Widget _buildMapSection() {
    final bool hasLocation = _latitude != null && _longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'GPS Coordinates & Map Pin',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final LatLng? initial = hasLocation ? LatLng(_latitude!, _longitude!) : null;
              final LatLng? selectedLoc = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapPickerScreen(initialLocation: initial),
                ),
              );
              if (selectedLoc != null) {
                setState(() {
                  _latitude = selectedLoc.latitude;
                  _longitude = selectedLoc.longitude;
                });
                if (_businessId != null) {
                  await _service.updateBusinessProfile(_businessId!, {
                    'latitude': _latitude,
                    'longitude': _longitude,
                  });
                }
                if (mounted) {
                  showGlassToast(context, 'Location pinned successfully!');
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasLocation ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasLocation
                          ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: hasLocation ? const Color(0xFF42A5F5) : Colors.white54,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLocation ? 'Location Pinned' : 'Pin Business Location',
                          style: TextStyle(
                            color: hasLocation ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasLocation
                              ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}'
                              : 'Tap to open map and pinpoint store entrance',
                          style: TextStyle(
                            color: hasLocation ? const Color(0xFF42A5F5) : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: hasLocation ? const Color(0xFF42A5F5) : Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF42A5F5),
              side: BorderSide(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _detectingGps ? null : _autoDetectGps,
            icon: _detectingGps
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5)))
                : const HugeIcon(icon: HugeIcons.strokeRoundedNavigation03, color: Color(0xFF42A5F5), size: 18),
            label: Text(
              _detectingGps ? 'Detecting current GPS...' : 'Auto-Detect Current GPS Location',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
