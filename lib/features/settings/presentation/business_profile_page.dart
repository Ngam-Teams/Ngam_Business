import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../widgets/glass_toast.dart';
import '../../../widgets/map_picker_screen.dart';
import '../data/business_service.dart';
import '../models/business_type_catalog.dart';
import '../../../widgets/glass_nav_button.dart';

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
  final _handleController = TextEditingController();
  bool _isHandleCustomized = false;
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
  int _estimatedWaitMinutes = 15;
  final _chairsController = TextEditingController(text: '1');
  bool _enableWalkIn = true;
  bool _enableBooking = true;
  bool _enableOrder = true;
  Map<String, dynamic> _existingOperatingHours = {};

  // Banking & Compliance
  String? _selectedBank;
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();

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
    _nameController.addListener(_onNameChanged);
    _loadProfile();
  }

  void _onNameChanged() {
    if (!_isHandleCustomized && (_businessId == null || _handleController.text.trim().isEmpty)) {
      final generated = BusinessService.generateHandleFromName(_nameController.text);
      if (_handleController.text != generated) {
        _handleController.text = generated;
      }
    }
  }

  void _populateProfile(Map<String, dynamic> data) {
    _businessId = data['id'];
    _nameController.text = data['business_name'] ?? '';

    final handle = (data['business_handle'] as String?)?.trim() ?? '';
    if (handle.isNotEmpty) {
      _handleController.text = handle.replaceAll('@', '').toLowerCase();
      _isHandleCustomized = true;
    } else if (_nameController.text.isNotEmpty) {
      _handleController.text = BusinessService.generateHandleFromName(_nameController.text);
      _isHandleCustomized = false;
    }

    // Load granular business_type if preserved in operating_hours, else fall back to business_industry
    String? granularType;
    if (data['settings'] != null && data['settings'] is Map) {
      final s = data['settings'] as Map<String, dynamic>;
      final op = s['operating_hours'];
      if (op is Map && op['business_type'] != null) {
        granularType = op['business_type']?.toString();
      }
    }

    final rawIndustry = (granularType ?? data['business_industry'] as String? ?? 'restaurant').toLowerCase();
    final matched = BusinessTypeCatalog.findById(rawIndustry);
    if (matched != null) {
      _selectedIndustry = matched.id;
    } else {
      _selectedIndustry = 'restaurant';
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
        _existingOperatingHours = Map<String, dynamic>.from(opHours);
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

        if (opHours['estimated_wait_minutes'] != null) {
          _estimatedWaitMinutes = (opHours['estimated_wait_minutes'] as num?)?.toInt() ?? 15;
        }

        if (opHours['service_modes'] is List) {
          final modes = (opHours['service_modes'] as List)
              .map((e) => e.toString().toLowerCase())
              .toList();
          _enableWalkIn = modes.contains('walkin');
          _enableBooking = modes.contains('booking');
          _enableOrder = modes.contains('order');
        } else {
          if (opHours.containsKey('enable_walkin')) {
            _enableWalkIn = opHours['enable_walkin'] != false;
          }
          if (opHours.containsKey('enable_booking')) {
            _enableBooking = opHours['enable_booking'] != false;
          }
          if (opHours.containsKey('enable_order')) {
            _enableOrder = opHours['enable_order'] != false;
          }
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

  Future<void> _loadProfile() async {
    // 1. Tunjuk data cache profil serta-merta jika ada (0 saat / sifar loading)
    final cached = BusinessService.cachedProfile ?? await BusinessService.loadCachedProfile();
    if (cached != null && mounted) {
      _populateProfile(cached);
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Tarik profil terkini dari Supabase di latar belakang
    final data = await _service.getBusinessProfile();
    if (mounted && data != null) {
      _populateProfile(data);
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
      showGlassToast(context, 'business_profile.business_name_required'.tr(), isError: true);
      return;
    }

    final cleanHandle = _handleController.text.trim().replaceAll('@', '').toLowerCase();
    if (cleanHandle.isEmpty) {
      showGlassToast(context, 'business_profile.handle_empty_error'.tr(), isError: true);
      return;
    }
    if (cleanHandle.length < 3 || cleanHandle.length > 30) {
      showGlassToast(context, 'business_profile.handle_length_error'.tr(), isError: true);
      return;
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(cleanHandle)) {
      showGlassToast(context, 'business_profile.handle_chars_error'.tr(), isError: true);
      return;
    }

    setState(() => _isSaving = true);

    // Uniqueness validation against Supabase
    final isAvailable = await _service.isHandleAvailable(cleanHandle, excludeBusinessId: _businessId);
    if (!isAvailable) {
      setState(() => _isSaving = false);
      if (mounted) {
        showGlassToast(context, 'business_profile.handle_taken_error'.tr(args: [cleanHandle]), isError: true);
      }
      return;
    }

    final dbIndustry = BusinessTypeCatalog.toDbIndustry(_selectedIndustry);
    final businessData = {
      'business_name': _nameController.text.trim(),
      'business_handle': cleanHandle,
      'business_industry': dbIndustry,
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

    if (!_enableWalkIn && !_enableBooking && !_enableOrder) {
      setState(() => _enableWalkIn = true);
    }

    final serviceModesList = <String>[
      if (_enableWalkIn) 'walkin',
      if (_enableBooking) 'booking',
      if (_enableOrder) 'order',
    ];

    final mergedOperatingHours = <String, dynamic>{
      ..._existingOperatingHours,
      'business_type': _selectedIndustry,
      'open_time': _formatTimeOfDay(_openTime),
      'close_time': _formatTimeOfDay(_closeTime),
      'days': _existingOperatingHours['days'] ??
          ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'service_modes': serviceModesList,
      'enable_walkin': _enableWalkIn,
      'enable_booking': _enableBooking,
      'enable_order': _enableOrder,
      'estimated_wait_minutes': _estimatedWaitMinutes,
    };
    _existingOperatingHours = mergedOperatingHours;

    final settingsData = {
      'is_halal': _isHalal,
      'slot_duration': _slotDuration,
      'total_chairs': int.tryParse(_chairsController.text.trim()) ?? 1,
      'operating_hours': mergedOperatingHours,
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
        showGlassToast(context, 'business_profile.save_success'.tr());
        // Refresh profile state
        await _loadProfile();
      }
    } catch (e, stack) {
      debugPrint('Failed to save business details: $e\n$stack');
      if (mounted) {
        showGlassToast(context, 'business_profile.save_error'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: type == 'logo' ? 1024 : 2560,
      maxHeight: type == 'logo' ? 1024 : 1440,
      imageQuality: 90,
    );

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
          final label = type == 'logo'
              ? 'business_profile.logo_name'.tr()
              : 'business_profile.cover_name'.tr();
          showGlassToast(context, 'business_profile.upload_success'.tr(args: [label]));
        }
      } else {
        if (mounted) showGlassToast(context, 'business_profile.upload_failed'.tr(), isError: true);
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'business_profile.upload_error'.tr(args: [e.toString()]), isError: true);
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
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _handleController.dispose();
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

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: isNewBusiness
          ? 'business_profile.add_business_title'.tr()
          : 'business_profile.title'.tr(),
      subtitle: 'business_profile.subtitle'.tr(),
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedTick01,
          tooltip: 'business_profile.save_tooltip'.tr(),
          isLoading: _isSaving,
          onTap: _isSaving ? null : _saveProfile,
        ),
      ],
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 120),
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
                          title: 'business_profile.identity_title'.tr(),
                          subtitle: 'business_profile.identity_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedStore01,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          // Business Name (Unlocked & Editable)
                          _buildTextField(
                            label: 'business_profile.business_name_label'.tr(),
                            controller: _nameController,
                            icon: HugeIcons.strokeRoundedStore01,
                            hint: 'business_profile.business_name_hint'.tr(),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'business_profile.business_name_required'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Business Handle (@handle for unique URL and QR standees)
                          _buildHandleField(),

                          const SizedBox(height: 16),

                          // Industry Selector (fnb, barber, retail, services)
                          _buildIndustrySelector(),

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'business_profile.ssm_label'.tr(),
                                  controller: _regNoController,
                                  icon: HugeIcons.strokeRoundedBuilding03,
                                  hint: 'business_profile.ssm_hint'.tr(),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildTextField(
                                  label: 'business_profile.sst_label'.tr(),
                                  controller: _sstNoController,
                                  icon: HugeIcons.strokeRoundedInvoice01,
                                  hint: 'business_profile.sst_hint'.tr(),
                                ),
                              ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 28),

                        // Section 2: Contact Info
                        _buildSectionHeader(
                          title: 'business_profile.contact_title'.tr(),
                          subtitle: 'business_profile.contact_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedCall02,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          _buildTextField(
                            label: 'business_profile.phone_label'.tr(),
                            controller: _phoneController,
                            icon: HugeIcons.strokeRoundedCall02,
                            keyboardType: TextInputType.phone,
                            hint: 'business_profile.phone_hint'.tr(),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'business_profile.email_label'.tr(),
                            controller: _emailController,
                            icon: HugeIcons.strokeRoundedMail01,
                            keyboardType: TextInputType.emailAddress,
                            hint: 'business_profile.email_hint'.tr(),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'business_profile.website_label'.tr(),
                            controller: _websiteController,
                            icon: HugeIcons.strokeRoundedGlobe02,
                            keyboardType: TextInputType.url,
                            hint: 'business_profile.website_hint'.tr(),
                          ),
                        ]),

                        const SizedBox(height: 28),

                        // Section 3: Physical Address & Map Location Pin
                        _buildSectionHeader(
                          title: 'business_profile.location_title'.tr(),
                          subtitle: 'business_profile.location_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedLocation01,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          _buildTextField(
                            label: 'business_profile.street_label'.tr(),
                            controller: _addressLineController,
                            icon: HugeIcons.strokeRoundedLocation01,
                            hint: 'business_profile.street_hint'.tr(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  label: 'business_profile.postcode_label'.tr(),
                                  controller: _postcodeController,
                                  icon: HugeIcons.strokeRoundedMailbox01,
                                  keyboardType: TextInputType.number,
                                  hint: 'business_profile.postcode_hint'.tr(),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  label: 'business_profile.city_label'.tr(),
                                  controller: _cityController,
                                  icon: HugeIcons.strokeRoundedCity01,
                                  hint: 'business_profile.city_hint'.tr(),
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
                                  label: 'business_profile.country_label'.tr(),
                                  controller: _countryController,
                                  icon: HugeIcons.strokeRoundedGlobal,
                                  hint: 'business_profile.country_default'.tr(),
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

                        // Section 4A: Store Service Modes (Walk-In / Booking / Order)
                        _buildSectionHeader(
                          title: 'business_profile.service_modes_title'.tr(),
                          subtitle: 'business_profile.service_modes_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedTicket01,
                        ),
                        const SizedBox(height: 16),
                        _buildServiceModesSection(),

                        const SizedBox(height: 28),

                        // Section 4B: Operating Hours & Settings
                        _buildSectionHeader(
                          title: 'business_profile.hours_section_title'.tr(),
                          subtitle: 'business_profile.hours_section_subtitle'.tr(),
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
                          Text(
                            'business_profile.daily_hours_title'.tr(),
                            style: const TextStyle(
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
                                  label: 'business_profile.opening_time_label'.tr(),
                                  time: _openTime,
                                  onTap: () => _selectTime(true),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildTimePickerTile(
                                  label: 'business_profile.closing_time_label'.tr(),
                                  time: _closeTime,
                                  onTap: () => _selectTime(false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Color(0x1AFFFFFF), height: 1),
                          const SizedBox(height: 20),

                          // Walk-In & Booking Capacity Settings
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'business_profile.chairs_capacity_label'.tr(),
                                  controller: _chairsController,
                                  icon: HugeIcons.strokeRoundedUserGroup,
                                  keyboardType: TextInputType.number,
                                  hint: '1',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildEstimatedWaitDropdown(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSlotDurationDropdown(),
                        ]),

                        const SizedBox(height: 28),

                        // Section 5: Banking & Payout Info
                        _buildSectionHeader(
                          title: 'business_profile.banking_section_title'.tr(),
                          subtitle: 'business_profile.banking_section_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedCreditCard,
                        ),
                        const SizedBox(height: 16),
                        _buildCardContainer([
                          _buildBankDropdown(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'business_profile.account_holder_label'.tr(),
                            controller: _accountHolderController,
                            icon: HugeIcons.strokeRoundedUser,
                            hint: 'business_profile.account_holder_hint'.tr(),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'business_profile.account_number_label'.tr(),
                            controller: _accountNumberController,
                            icon: HugeIcons.strokeRoundedInvoice02,
                            keyboardType: TextInputType.number,
                            hint: 'business_profile.account_number_hint'.tr(),
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
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'business_profile.saving_details'.tr(),
                                        style: const TextStyle(
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
                                        isNewBusiness
                                            ? 'business_profile.add_business_btn'.tr()
                                            : 'business_profile.save_changes_btn'.tr(),
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
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: Colors.white54,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'business_profile.upload_cover_hint'.tr(),
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedEdit02,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text('business_profile.change_cover'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12)),
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

  Widget _buildHandleField() {
    final rawHandle = _handleController.text.trim().replaceAll('@', '').toLowerCase();
    final isValidLength = rawHandle.length >= 3 && rawHandle.length <= 30;
    final isValidFormat = RegExp(r'^[a-z0-9_-]+$').hasMatch(rawHandle);
    final isValid = isValidLength && isValidFormat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'business_profile.handle_label'.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (rawHandle.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isValid
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isValid
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isValid ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 12,
                      color: isValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isValid
                          ? 'business_profile.handle_valid_format'.tr()
                          : (!isValidLength
                              ? 'business_profile.handle_length_rule'.tr()
                              : 'business_profile.handle_chars_rule'.tr()),
                      style: TextStyle(
                        color: isValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        TextFormField(
          controller: _handleController,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          onChanged: (val) {
            _isHandleCustomized = true;
            setState(() {});
          },
          validator: (val) {
            final clean = (val ?? '').trim().replaceAll('@', '').toLowerCase();
            if (clean.isEmpty) return 'business_profile.handle_empty_error'.tr();
            if (clean.length < 3 || clean.length > 30) return 'business_profile.handle_length_error'.tr();
            if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(clean)) {
              return 'business_profile.handle_chars_error'.tr();
            }
            return null;
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: 'business_profile.handle_hint'.tr(),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
            prefixIcon: Container(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alternate_email_rounded,
                    color: Color(0xFF42A5F5),
                    size: 18,
                  ),
                  SizedBox(width: 4),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            suffixIcon: rawHandle.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.white38, size: 16),
                    tooltip: 'business_profile.handle_regen_tooltip'.tr(),
                    onPressed: () {
                      if (_nameController.text.trim().isNotEmpty) {
                        setState(() {
                          _handleController.text = BusinessService.generateHandleFromName(_nameController.text);
                          _isHandleCustomized = false;
                        });
                      }
                    },
                  )
                : null,
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
        const SizedBox(height: 8),
        // Live URL Preview Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, color: Color(0xFF42A5F5), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'business_profile.store_link_prefix'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    children: [
                      const TextSpan(
                        text: 'https://ngam.dev/@',
                        style: TextStyle(
                          color: Color(0xFF90CAF9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: rawHandle.isEmpty ? 'handle' : rawHandle,
                        style: TextStyle(
                          color: rawHandle.isEmpty ? Colors.white30 : const Color(0xFF42A5F5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rawHandle.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final url = 'https://ngam.dev/@$rawHandle';
                    Clipboard.setData(ClipboardData(text: url));
                    showGlassToast(context, 'business_profile.link_copied_toast'.tr(args: [url]));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndustrySelector() {
    final active = BusinessTypeCatalog.findById(_selectedIndustry) ?? BusinessTypeCatalog.allTypes.first;
    const brandGreen = Color(0xFF44CF6C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'business_type.title'.tr(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final result = await context.push<String>('/business-type?current=$_selectedIndustry');
            if (result != null && mounted) {
              setState(() {
                _selectedIndustry = result;
              });
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: brandGreen.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: active.icon,
                      color: brandGreen,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              active.nameKey.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: brandGreen.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'business_type.categories.${active.categoryGroup}'.tr(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: brandGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        active.descKey.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brandGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'business_type.change_type'.tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: brandGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: brandGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'business_profile.state_label'.tr(),
            style: const TextStyle(
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
            hintText: 'business_profile.state_select'.tr(),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'business_profile.select_bank_label'.tr(),
            style: const TextStyle(
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
            hintText: 'business_profile.select_bank_label'.tr(),
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

  Widget _buildServiceModesSection() {
    final isWalkInOnly = _enableWalkIn && !_enableBooking && !_enableOrder;
    final isWalkInBooking = _enableWalkIn && _enableBooking && !_enableOrder;
    final isOrderOnly = !_enableWalkIn && !_enableBooking && _enableOrder;
    final isAllActive = _enableWalkIn && _enableBooking && _enableOrder;

    return _buildCardContainer([
      Text(
        'business_profile.quick_preset_label'.tr(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildPresetChip(
            label: 'business_profile.preset_walkin_only'.tr(),
            isSelected: isWalkInOnly,
            color: const Color(0xFF10B981),
            onTap: () => setState(() {
              _enableWalkIn = true;
              _enableBooking = false;
              _enableOrder = false;
            }),
          ),
          _buildPresetChip(
            label: 'business_profile.preset_walkin_booking'.tr(),
            isSelected: isWalkInBooking,
            color: const Color(0xFF42A5F5),
            onTap: () => setState(() {
              _enableWalkIn = true;
              _enableBooking = true;
              _enableOrder = false;
            }),
          ),
          _buildPresetChip(
            label: 'business_profile.preset_order_only'.tr(),
            isSelected: isOrderOnly,
            color: const Color(0xFFF59E0B),
            onTap: () => setState(() {
              _enableWalkIn = false;
              _enableBooking = false;
              _enableOrder = true;
            }),
          ),
          _buildPresetChip(
            label: 'business_profile.preset_all_modes'.tr(),
            isSelected: isAllActive,
            color: const Color(0xFFA78BFA),
            onTap: () => setState(() {
              _enableWalkIn = true;
              _enableBooking = true;
              _enableOrder = true;
            }),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _buildServiceModeCard(
        title: 'business_profile.mode_walkin_title'.tr(),
        subtitle: 'business_profile.mode_walkin_desc'.tr(),
        icon: HugeIcons.strokeRoundedTicket01,
        accentColor: const Color(0xFF10B981),
        isEnabled: _enableWalkIn,
        onToggle: (val) {
          if (!val && !_enableBooking && !_enableOrder) {
            showGlassToast(context, 'business_profile.min_one_mode_toast'.tr(), isError: true);
            return;
          }
          setState(() => _enableWalkIn = val);
        },
      ),
      const SizedBox(height: 12),
      _buildServiceModeCard(
        title: 'business_profile.mode_booking_title'.tr(),
        subtitle: 'business_profile.mode_booking_desc'.tr(),
        icon: HugeIcons.strokeRoundedCalendar03,
        accentColor: const Color(0xFF42A5F5),
        isEnabled: _enableBooking,
        onToggle: (val) {
          if (!val && !_enableWalkIn && !_enableOrder) {
            showGlassToast(context, 'business_profile.min_one_mode_toast'.tr(), isError: true);
            return;
          }
          setState(() => _enableBooking = val);
        },
      ),
      const SizedBox(height: 12),
      _buildServiceModeCard(
        title: 'business_profile.mode_order_title'.tr(),
        subtitle: 'business_profile.mode_order_desc'.tr(),
        icon: HugeIcons.strokeRoundedShoppingBag01,
        accentColor: const Color(0xFFF59E0B),
        isEnabled: _enableOrder,
        onToggle: (val) {
          if (!val && !_enableWalkIn && !_enableBooking) {
            showGlassToast(context, 'business_profile.min_one_mode_toast'.tr(), isError: true);
            return;
          }
          setState(() => _enableOrder = val);
        },
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF42A5F5), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'business_profile.reserved_settings_note'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              size: 15,
              color: isSelected ? color : Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceModeCard({
    required String title,
    required String subtitle,
    required dynamic icon,
    required Color accentColor,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
  }) {
    return GestureDetector(
      onTap: () => onToggle(!isEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEnabled
              ? accentColor.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? accentColor.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
            width: isEnabled ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isEnabled
                    ? accentColor.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(
                icon: icon,
                color: isEnabled ? accentColor : Colors.white54,
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
                      Text(
                        title,
                        style: TextStyle(
                          color: isEnabled ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? accentColor.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isEnabled
                              ? 'business_profile.mode_active_badge'.tr()
                              : 'business_profile.mode_reserved_badge'.tr(),
                          style: TextStyle(
                            color: isEnabled ? accentColor : Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isEnabled ? 0.65 : 0.38),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: isEnabled,
              activeColor: accentColor,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatedWaitDropdown() {
    const waitOptions = [10, 15, 20, 30, 45, 60];
    final currentVal = waitOptions.contains(_estimatedWaitMinutes) ? _estimatedWaitMinutes : 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'business_profile.walkin_wait_label'.tr(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownButtonFormField<int>(
          isExpanded: true,
          value: currentVal,
          dropdownColor: const Color(0xFF1A1A24),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedHourglass,
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
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
          ),
          items: waitOptions.map((mins) {
            return DropdownMenuItem<int>(
              value: mins,
              child: Text(
                'business_profile.prep_time_minutes'.tr(args: [mins.toString()]),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _estimatedWaitMinutes = val);
          },
        ),
      ],
    );
  }

  Widget _buildSlotDurationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'business_profile.booking_slot_duration'.tr(),
            style: const TextStyle(
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
          items: [
            DropdownMenuItem(value: 15, child: Text('business_profile.prep_time_minutes'.tr(args: ['15']), overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 30, child: Text('business_profile.prep_time_minutes'.tr(args: ['30']), overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 45, child: Text('business_profile.prep_time_minutes'.tr(args: ['45']), overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 60, child: Text('business_profile.prep_time_minutes'.tr(args: ['60']), overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 90, child: Text('business_profile.prep_time_minutes'.tr(args: ['90']), overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 120, child: Text('business_profile.prep_time_minutes'.tr(args: ['120']), overflow: TextOverflow.ellipsis)),
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
                    Text(
                      'business_profile.halal_title'.tr(),
                      style: const TextStyle(
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
                        child: Text(
                          'business_profile.halal_badge'.tr(),
                          style: const TextStyle(
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
                  'business_profile.halal_desc'.tr(),
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
          showGlassToast(context, 'business_profile.gps_service_disabled'.tr(), isError: true);
        }
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showGlassToast(context, 'business_profile.gps_permission_denied'.tr(), isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showGlassToast(context, 'business_profile.gps_permission_permanent'.tr(), isError: true);
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
        showGlassToast(context, 'business_profile.gps_success_toast'.tr(args: [
          currentPos.latitude.toStringAsFixed(4),
          currentPos.longitude.toStringAsFixed(4),
        ]));
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'business_profile.gps_weak_toast'.tr(), isError: true);
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'business_profile.gps_coordinates_label'.tr(),
            style: const TextStyle(
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
                  showGlassToast(context, 'business_profile.location_pinned_toast'.tr());
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
                          hasLocation
                              ? 'business_profile.location_pinned'.tr()
                              : 'business_profile.pin_location'.tr(),
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
                              : 'business_profile.pin_location_hint'.tr(),
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
              _detectingGps ? 'business_profile.detecting_gps'.tr() : 'business_profile.auto_gps_btn'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
