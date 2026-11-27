import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../integrations/data/easyparcel_service.dart';
import '../data/business_service.dart';

/// Built-in Ngam Shipping settings page (powered by EasyParcel Platform Mode).
/// Lets merchants toggle courier shipping ON/OFF in 1 click, whitelist/blacklist
/// couriers, pin a preferred courier, choose pickup/dropoff & checkout mode,
/// and configure store pickup address — all overflow-safe on mobile & web.
class ShippingSettingsPage extends StatefulWidget {
  const ShippingSettingsPage({super.key});

  @override
  State<ShippingSettingsPage> createState() => _ShippingSettingsPageState();
}

class _ShippingSettingsPageState extends State<ShippingSettingsPage> {
  static const Color _epPink = Color(0xFFEC008C);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _sky = Color(0xFF38BDF8);

  final EasyParcelService _service = EasyParcelService();

  bool _loading = true;
  bool _saving = false;
  bool _testingKey = false;
  bool _showAdvancedCustom = false;

  bool _isEnabled = false;
  bool _useCustomKey = false;
  String _environment = 'demo';
  String _checkoutMode = 'customer_choice'; // 'customer_choice' | 'auto_best'
  String _serviceMode = 'all'; // 'all' | 'pickup' | 'dropoff'
  String _preferredCourier = '';
  final Set<String> _disabledCouriers = <String>{};

  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addr1Ctrl;
  late final TextEditingController _addr2Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _postcodeCtrl;
  String _stateCode = 'sgr';

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addr1Ctrl = TextEditingController();
    _addr2Ctrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _postcodeCtrl = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _cityCtrl.dispose();
    _postcodeCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _businessProfile;

  Future<void> _loadData() async {
    final cfg = await _service.getConfig();
    final profile = await BusinessService().getBusinessProfile() ?? BusinessService.cachedProfile;
    if (!mounted) return;

    _businessProfile = profile;
    final biz = EasyParcelService.extractBusinessPickupDefaults(profile);
    final hasSavedPickupAddr =
        cfg.senderAddr1.trim().isNotEmpty || cfg.senderPostcode.trim().isNotEmpty;

    setState(() {
      _isEnabled = cfg.isConnected;
      _useCustomKey = !cfg.isPlatformMode;
      _showAdvancedCustom = !cfg.isPlatformMode;
      _environment = cfg.environment;
      _checkoutMode = cfg.checkoutMode;
      _serviceMode = cfg.serviceMode;
      _preferredCourier = cfg.preferredCourier;
      _disabledCouriers
        ..clear()
        ..addAll(cfg.disabledCouriers);

      _apiKeyCtrl.text = cfg.apiKey;
      _nameCtrl.text = cfg.senderName.trim().isNotEmpty ? cfg.senderName : (biz['name'] ?? '');
      _phoneCtrl.text = cfg.senderPhone.trim().isNotEmpty ? cfg.senderPhone : (biz['phone'] ?? '');
      _addr1Ctrl.text = cfg.senderAddr1.trim().isNotEmpty ? cfg.senderAddr1 : (biz['addr1'] ?? '');
      _addr2Ctrl.text = cfg.senderAddr2;
      _postcodeCtrl.text = cfg.senderPostcode.trim().isNotEmpty
          ? cfg.senderPostcode
          : (biz['postcode'] ?? '');
      _cityCtrl.text = cfg.senderCity.trim().isNotEmpty ? cfg.senderCity : (biz['city'] ?? '');
      final bizState = biz['state'] ?? 'sgr';
      _stateCode = (hasSavedPickupAddr && cfg.senderState.trim().isNotEmpty)
          ? cfg.senderState.trim()
          : (bizState.isNotEmpty ? bizState : 'sgr');
      _loading = false;
    });
  }

  void _applyBusinessProfileAddress() {
    final biz = EasyParcelService.extractBusinessPickupDefaults(_businessProfile);
    final hasAny = (biz['addr1'] ?? '').isNotEmpty ||
        (biz['postcode'] ?? '').isNotEmpty ||
        (biz['city'] ?? '').isNotEmpty ||
        (biz['phone'] ?? '').isNotEmpty;
    if (!hasAny) {
      showGlassToast(context, 'shipping_settings.profile_address_empty_toast'.tr(), isError: true);
      return;
    }
    setState(() {
      if ((biz['name'] ?? '').isNotEmpty) _nameCtrl.text = biz['name']!;
      if ((biz['phone'] ?? '').isNotEmpty) _phoneCtrl.text = biz['phone']!;
      if ((biz['addr1'] ?? '').isNotEmpty) _addr1Ctrl.text = biz['addr1']!;
      if ((biz['postcode'] ?? '').isNotEmpty) _postcodeCtrl.text = biz['postcode']!;
      if ((biz['city'] ?? '').isNotEmpty) _cityCtrl.text = biz['city']!;
      if ((biz['state'] ?? '').isNotEmpty) _stateCode = biz['state']!;
    });
    showGlassToast(context, 'shipping_settings.copied_from_profile_toast'.tr());
  }

  Future<void> _saveSettings() async {
    if (_isEnabled && _postcodeCtrl.text.trim().length < 5) {
      showGlassToast(context, 'shipping_settings.err_postcode_required'.tr(), isError: true);
      return;
    }
    if (_isEnabled && _useCustomKey && _apiKeyCtrl.text.trim().isEmpty) {
      showGlassToast(context, 'easyparcel.err_api_key_required'.tr(), isError: true);
      return;
    }

    // Ensure at least 1 courier remains enabled
    if (_isEnabled && _disabledCouriers.length >= kMalaysiaCouriers.length) {
      showGlassToast(context, 'shipping_settings.err_min_one_courier'.tr(), isError: true);
      return;
    }

    setState(() => _saving = true);

    final effectivePreferred =
        _disabledCouriers.contains(_preferredCourier) ? '' : _preferredCourier;

    final cfg = EasyParcelConfig(
      isConnected: _isEnabled,
      mode: _useCustomKey ? 'custom' : 'platform',
      environment: _useCustomKey ? _environment : 'live',
      apiKey: _useCustomKey ? _apiKeyCtrl.text.trim() : '',
      senderName: _nameCtrl.text.trim(),
      senderPhone: _phoneCtrl.text.trim(),
      senderAddr1: _addr1Ctrl.text.trim(),
      senderAddr2: _addr2Ctrl.text.trim(),
      senderCity: _cityCtrl.text.trim(),
      senderPostcode: _postcodeCtrl.text.trim(),
      senderState: _stateCode,
      autoSync: true,
      disabledCouriers: _disabledCouriers.toList()..sort(),
      preferredCourier: effectivePreferred,
      serviceMode: _serviceMode,
      checkoutMode: _checkoutMode,
    );

    try {
      await _service.saveConfig(cfg);
      if (!mounted) return;
      setState(() => _saving = false);
      showGlassToast(
        context,
        _isEnabled
            ? 'shipping_settings.saved_enabled_toast'.tr()
            : 'shipping_settings.saved_disabled_toast'.tr(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showGlassToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _testCustomKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      showGlassToast(context, 'easyparcel.err_api_key_required'.tr(), isError: true);
      return;
    }
    setState(() => _testingKey = true);
    final res = await _service.verifyConnection(apiKey: key, environment: _environment);
    if (!mounted) return;
    setState(() => _testingKey = false);
    if (res['success'] == true) {
      final bal = (res['balance'] as num?)?.toDouble() ?? 0.0;
      showGlassToast(context, 'easyparcel.verify_ok'.tr(args: [bal.toStringAsFixed(2)]));
    } else {
      showGlassToast(context, res['error']?.toString() ?? 'easyparcel.verify_failed'.tr(), isError: true);
    }
  }

  void _applyTrustedPreset() {
    setState(() {
      _disabledCouriers.clear();
      for (final c in kMalaysiaCouriers) {
        if (c['tag'] != 'reliable') {
          _disabledCouriers.add(c['key']!);
        }
      }
      if (_disabledCouriers.contains(_preferredCourier)) {
        _preferredCourier = '';
      }
    });
    showGlassToast(context, 'shipping_settings.preset_trusted_applied'.tr());
  }

  void _enableAllCouriers() {
    setState(() => _disabledCouriers.clear());
  }

  int get _enabledCourierCount => kMalaysiaCouriers.length - _disabledCouriers.length;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'shipping_settings.title'.tr(),
      subtitle: 'shipping_settings.subtitle'.tr(),
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedTick01,
          tooltip: 'shipping_settings.save_btn'.tr(),
          isLoading: _saving,
          onTap: _saving ? null : _saveSettings,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _epPink))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 72, 16, 110),
                  children: [
                    _buildHeroToggleCard(),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _isEnabled ? 1.0 : 0.55,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCheckoutModeCard(),
                          const SizedBox(height: 16),
                          _buildServiceModeCard(),
                          const SizedBox(height: 16),
                          _buildCourierControlsCard(),
                          const SizedBox(height: 16),
                          _buildPickupAddressCard(),
                          const SizedBox(height: 16),
                          _buildAdvancedCustomCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    Color? borderColor,
    Gradient? gradient,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? Colors.white.withValues(alpha: 0.045) : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.10),
          width: 1.1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required Color accent,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: accent, size: 18),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _buildHeroToggleCard() {
    return _buildGlassCard(
      borderColor: _isEnabled
          ? _emerald.withValues(alpha: 0.45)
          : _epPink.withValues(alpha: 0.30),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isEnabled
            ? [
                _emerald.withValues(alpha: 0.16),
                _epPink.withValues(alpha: 0.08),
              ]
            : [
                _epPink.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.03),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isEnabled
                        ? [_emerald, const Color(0xFF059669)]
                        : [_epPink, const Color(0xFFBE185D)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: (_isEnabled ? _emerald : _epPink).withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'shipping_settings.hero_title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'shipping_settings.hero_desc'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _isEnabled,
                activeTrackColor: _emerald,
                activeThumbColor: Colors.white,
                onChanged: (v) => setState(() => _isEnabled = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _statusPill(
                label: _isEnabled
                    ? 'shipping_settings.status_active'.tr()
                    : 'shipping_settings.status_off'.tr(),
                color: _isEnabled ? _emerald : Colors.white54,
                icon: _isEnabled ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
              ),
              _statusPill(
                label: _useCustomKey
                    ? 'shipping_settings.mode_custom_badge'.tr()
                    : 'shipping_settings.mode_platform_badge'.tr(),
                color: _sky,
                icon: Icons.bolt_rounded,
              ),
              if (_isEnabled)
                _statusPill(
                  label: 'shipping_settings.couriers_active_count'.tr(
                    args: [_enabledCourierCount.toString(), kMalaysiaCouriers.length.toString()],
                  ),
                  color: _epPink,
                  icon: Icons.verified_user_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutModeCard() {
    Widget optionTile({
      required String id,
      required String title,
      required String desc,
      required IconData icon,
      String? badge,
    }) {
      final selected = _checkoutMode == id;
      return InkWell(
        onTap: () => setState(() => _checkoutMode = id),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? _epPink.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _epPink : Colors.white.withValues(alpha: 0.10),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                color: selected ? _epPink : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(icon, size: 15, color: selected ? const Color(0xFFF472B6) : Colors.white70),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _emerald.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: _emerald,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.tune_rounded,
            accent: _epPink,
            title: 'shipping_settings.checkout_mode_title'.tr(),
            subtitle: 'shipping_settings.checkout_mode_subtitle'.tr(),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileA = optionTile(
                id: 'customer_choice',
                title: 'shipping_settings.mode_customer_choice'.tr(),
                desc: 'shipping_settings.mode_customer_choice_desc'.tr(),
                icon: Icons.touch_app_rounded,
                badge: 'shipping_settings.recommended_badge'.tr(),
              );
              final tileB = optionTile(
                id: 'auto_best',
                title: 'shipping_settings.mode_auto_best'.tr(),
                desc: 'shipping_settings.mode_auto_best_desc'.tr(),
                icon: Icons.auto_awesome_rounded,
              );
              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tileA),
                    const SizedBox(width: 12),
                    Expanded(child: tileB),
                  ],
                );
              }
              return Column(
                children: [
                  tileA,
                  const SizedBox(height: 10),
                  tileB,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceModeCard() {
    Widget modeChip(String id, String label, IconData icon) {
      final active = _serviceMode == id;
      return InkWell(
        onTap: () => setState(() => _serviceMode = id),
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? _sky.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: active ? _sky : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? _sky : Colors.white60),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.inventory_2_outlined,
            accent: _sky,
            title: 'shipping_settings.service_mode_title'.tr(),
            subtitle: 'shipping_settings.service_mode_subtitle'.tr(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              modeChip('all', 'shipping_settings.service_all'.tr(), Icons.all_inclusive_rounded),
              modeChip('pickup', 'shipping_settings.service_pickup'.tr(), Icons.directions_car_rounded),
              modeChip('dropoff', 'shipping_settings.service_dropoff'.tr(), Icons.storefront_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourierControlsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.shield_outlined,
            accent: _emerald,
            title: 'shipping_settings.couriers_title'.tr(),
            subtitle: 'shipping_settings.couriers_subtitle'.tr(),
          ),
          const SizedBox(height: 12),
          // Quick presets bar (Wrap = zero overflow!)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetButton(
                label: 'shipping_settings.preset_trusted'.tr(),
                icon: Icons.verified_rounded,
                color: _emerald,
                onTap: _applyTrustedPreset,
              ),
              _presetButton(
                label: 'shipping_settings.preset_enable_all'.tr(),
                icon: Icons.done_all_rounded,
                color: _sky,
                onTap: _enableAllCouriers,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: _amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'shipping_settings.preferred_tip'.tr(),
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...kMalaysiaCouriers.map((courier) {
            final key = courier['key']!;
            final name = courier['name']!;
            final colorVal = int.tryParse(courier['color'] ?? '0xFFEC008C') ?? 0xFFEC008C;
            final brandColor = Color(colorVal);
            final isOn = !_disabledCouriers.contains(key);
            final isPreferred = _preferredCourier == key && isOn;
            final initials = name
                .split(RegExp(r'[\s-]+'))
                .where((p) => p.isNotEmpty)
                .take(2)
                .map((p) => p[0].toUpperCase())
                .join();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isOn
                    ? (isPreferred
                        ? _amber.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.04))
                    : Colors.white.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPreferred
                      ? _amber.withValues(alpha: 0.55)
                      : (isOn ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: isOn ? 0.22 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: brandColor.withValues(alpha: isOn ? 0.50 : 0.18),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: isOn ? Colors.white : Colors.white38,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isOn ? Colors.white : Colors.white38,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            decoration: isOn ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        if (isPreferred)
                          Text(
                            'shipping_settings.preferred_label'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _amber,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else if (!isOn)
                          Text(
                            'shipping_settings.courier_blocked_label'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOn)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'shipping_settings.set_preferred_tooltip'.tr(),
                      icon: Icon(
                        isPreferred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isPreferred ? _amber : Colors.white38,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _preferredCourier = isPreferred ? '' : key;
                        });
                      },
                    ),
                  Transform.scale(
                    scale: 0.86,
                    child: Switch.adaptive(
                      value: isOn,
                      activeTrackColor: _emerald,
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            _disabledCouriers.remove(key);
                          } else {
                            _disabledCouriers.add(key);
                            if (_preferredCourier == key) {
                              _preferredCourier = '';
                            }
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _presetButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupAddressCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.location_on_outlined,
            accent: _epPink,
            title: 'shipping_settings.pickup_title'.tr(),
            subtitle: 'shipping_settings.pickup_subtitle'.tr(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _presetButton(
              icon: Icons.store_mall_directory_outlined,
              label: 'shipping_settings.use_store_profile_btn'.tr(),
              color: _sky,
              onTap: _applyBusinessProfileAddress,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 480;
              final nameField = _buildInputField(_nameCtrl, 'easyparcel.sender_name'.tr());
              final phoneField = _buildInputField(
                _phoneCtrl,
                'easyparcel.sender_phone'.tr(),
                keyboardType: TextInputType.phone,
              );
              final postcodeField = _buildInputField(
                _postcodeCtrl,
                'easyparcel.postcode'.tr(),
                keyboardType: TextInputType.number,
                maxLength: 5,
              );
              final cityField = _buildInputField(_cityCtrl, 'easyparcel.city'.tr());

              return Column(
                children: [
                  if (isWide)
                    Row(
                      children: [
                        Expanded(child: nameField),
                        const SizedBox(width: 10),
                        Expanded(child: phoneField),
                      ],
                    )
                  else ...[
                    nameField,
                    const SizedBox(height: 10),
                    phoneField,
                  ],
                  const SizedBox(height: 10),
                  _buildInputField(_addr1Ctrl, 'easyparcel.address_line1'.tr()),
                  const SizedBox(height: 10),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: postcodeField),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: cityField),
                      ],
                    )
                  else ...[
                    postcodeField,
                    const SizedBox(height: 10),
                    cityField,
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('state_$_stateCode'),
                    initialValue: kMalaysiaStates.any((s) => s['code'] == _stateCode)
                        ? _stateCode
                        : 'sgr',
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: _inputDecoration('easyparcel.state'.tr()),
                    items: kMalaysiaStates
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['code'],
                            child: Text(
                              s['name']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _stateCode = v);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCustomCard() {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showAdvancedCustom = !_showAdvancedCustom),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_outlined, size: 17, color: Colors.white.withValues(alpha: 0.65)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'easyparcel.custom_mode_toggle'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _showAdvancedCustom ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedCustom) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'shipping_settings.use_own_ep_switch'.tr(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5),
                  ),
                ),
                Switch.adaptive(
                  value: _useCustomKey,
                  activeTrackColor: _epPink,
                  activeThumbColor: Colors.white,
                  onChanged: (v) => setState(() => _useCustomKey = v),
                ),
              ],
            ),
            if (_useCustomKey) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('easyparcel.env_demo'.tr()),
                    selected: _environment == 'demo',
                    onSelected: (_) => setState(() => _environment = 'demo'),
                    selectedColor: _epPink.withValues(alpha: 0.28),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  ChoiceChip(
                    label: Text('easyparcel.env_live'.tr()),
                    selected: _environment == 'live',
                    onSelected: (_) => setState(() => _environment = 'live'),
                    selectedColor: _emerald.withValues(alpha: 0.28),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInputField(_apiKeyCtrl, 'easyparcel.api_key_label'.tr()),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _testingKey ? null : _testCustomKey,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sky,
                    side: BorderSide(color: _sky.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _testingKey
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _sky),
                        )
                      : const Icon(Icons.verified_outlined, size: 16),
                  label: Text('easyparcel.test_connection_btn'.tr()),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEnabled ? _emerald : _epPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          'shipping_settings.save_btn'.tr(),
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 12.5),
      counterText: '',
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.045),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _epPink, width: 1.4),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: _inputDecoration(label),
    );
  }
}
