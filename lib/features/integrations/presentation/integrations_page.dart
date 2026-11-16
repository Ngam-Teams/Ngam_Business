import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/liquid_glass_compat.dart';
import '../../settings/data/business_service.dart';

// =============================================================================
// IntegrationsPage — Ngam Business Integrations & Apps Hub
// Connects GrabFood, ShopeeFood, foodpanda, Misi Rakyat, Lalamove, GrabExpress,
// LHDN MyInvois, SQL Accounting, WhatsApp Business & Custom Webhooks.
// =============================================================================

enum _IntegrationStatus { available, comingSoon }

class _IntegrationItem {
  final String id;
  final String name;
  final String category; // 'delivery', 'logistics', 'accounting', 'automation'
  final String descKey;
  final Color brandColor;
  final String svgLogo;
  final String? assetLogo;
  final _IntegrationStatus defaultStatus;
  final String fieldLabelKey;
  final String fieldHintKey;
  final bool supportsAutoSync;

  const _IntegrationItem({
    required this.id,
    required this.name,
    required this.category,
    required this.descKey,
    required this.brandColor,
    required this.svgLogo,
    this.assetLogo,
    this.defaultStatus = _IntegrationStatus.available,
    this.fieldLabelKey = 'integrations.store_id_label',
    this.fieldHintKey = 'integrations.store_id_hint',
    this.supportsAutoSync = true,
  });
}

// -----------------------------------------------------------------------------
// Official-style Crisp Vector Brand Logos (Zero network / CORS dependency)
// -----------------------------------------------------------------------------
const String _svgGrabFood = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#00B14F"/>
  <path d="M44 27.5H31.5v5.8h7.1c-.8 3.6-3.7 5.9-7.6 5.9-4.9 0-8.6-3.7-8.6-8.7s3.7-8.7 8.6-8.7c2.3 0 4.4.8 6 2.3l4.3-4.3C38.6 17.3 35 15.8 31 15.8c-8.3 0-14.8 6.4-14.8 14.7S22.7 45.2 31 45.2c8 0 14.2-5.6 14.2-14.4 0-1.2-.1-2.2-.3-3.3z" fill="#FFFFFF"/>
  <circle cx="46.5" cy="18.5" r="5" fill="#FFFFFF"/>
  <path d="M44.5 18.5h4M46.5 16.5v4" stroke="#00B14F" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''';

const String _svgShopeeFood = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#EE4D2D"/>
  <path d="M24 21c0-4.4 3.6-8 8-8s8 3.6 8 8" fill="none" stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round"/>
  <rect x="16" y="21" width="32" height="28" rx="6" fill="#FFFFFF"/>
  <path d="M36.5 29.2c-1-.7-2.5-1.2-4.2-1.2-2.5 0-4.3 1.2-4.3 3 0 2 1.9 2.7 4.5 3.3 2.7.6 5 1.4 5 4.2 0 2.7-2.3 4.5-5.6 4.5-2.3 0-4.3-.7-5.6-1.7l1.4-2.5c1.1.8 2.7 1.4 4.2 1.4 1.7 0 2.7-.7 2.7-1.7 0-1.1-1-1.5-3.4-2.1-3-.7-5.9-1.5-5.9-4.7 0-2.9 2.4-4.9 6-4.9 2 0 3.9.5 5.2 1.3l-1 2.1z" fill="#EE4D2D"/>
</svg>
''';

const String _svgFoodpanda = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#D70F64"/>
  <circle cx="20" cy="21" r="6" fill="#FFFFFF"/>
  <circle cx="44" cy="21" r="6" fill="#FFFFFF"/>
  <circle cx="32" cy="34" r="15" fill="#FFFFFF"/>
  <ellipse cx="25.5" cy="32" rx="3.4" ry="4.2" transform="rotate(-15 25.5 32)" fill="#D70F64"/>
  <ellipse cx="38.5" cy="32" rx="3.4" ry="4.2" transform="rotate(15 38.5 32)" fill="#D70F64"/>
  <circle cx="25.8" cy="31.5" r="1.2" fill="#FFFFFF"/>
  <circle cx="38.2" cy="31.5" r="1.2" fill="#FFFFFF"/>
  <ellipse cx="32" cy="37.5" rx="2.6" ry="1.8" fill="#D70F64"/>
  <path d="M28.5 41c1.8 1.6 5.2 1.6 7 0" fill="none" stroke="#D70F64" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

const String _svgMisi = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#F59E0B"/>
  <path d="M15 44V20h6.8l10.2 13.5L42.2 20H49v24h-6V29.5L32 43.2 21 29.5V44h-6z" fill="#111827"/>
</svg>
''';

const String _svgLalamove = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#FF6600"/>
  <path d="M16 23h16l-3 5H19l-3-5zM14 31h20l-3 5H17l-3-5zM18 39h28v5H18l0-5z" fill="#FFFFFF"/>
  <path d="M36 20h6.5v18H49l-3.5 6H36V20z" fill="#FFFFFF"/>
</svg>
''';

const String _svgGrabExpress = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#059669"/>
  <path d="M19 23h20l4 8v12H19V23z" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linejoin="round"/>
  <path d="M19 31h24" stroke="#FFFFFF" stroke-width="2.5"/>
  <circle cx="25" cy="45" r="3.2" fill="#FFFFFF"/>
  <circle cx="38" cy="45" r="3.2" fill="#FFFFFF"/>
  <path d="M46 18l-5 7h5l-4 7" fill="none" stroke="#A7F3D0" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const String _svgMyInvois = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#1E3A8A"/>
  <path d="M20 15h17l9 9v25a3 3 0 0 1-3 3H20a3 3 0 0 1-3-3V18a3 3 0 0 1 3-3z" fill="#FFFFFF"/>
  <path d="M37 15v9h9" fill="#93C5FD"/>
  <rect x="23" y="29" width="18" height="3.2" rx="1.6" fill="#1E3A8A"/>
  <rect x="23" y="36" width="13" height="3.2" rx="1.6" fill="#1E3A8A"/>
  <circle cx="44" cy="44" r="8" fill="#F59E0B"/>
  <path d="M40.8 44l2.2 2.2 4.2-4.4" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const String _svgSqlAccounting = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#2563EB"/>
  <polygon points="32,14 48,23 48,41 32,50 16,41 16,23" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linejoin="round"/>
  <path d="M16 23l16 9 16-9M32 32v18" stroke="#FFFFFF" stroke-width="2.5" stroke-linejoin="round"/>
  <circle cx="32" cy="23" r="3" fill="#93C5FD"/>
</svg>
''';

const String _svgWhatsApp = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#25D366"/>
  <path d="M32 15c-9.4 0-17 7.4-17 16.6 0 3.2.9 6.2 2.5 8.8L15 49l9-2.4c2.4 1.3 5.1 2 8 2 9.4 0 17-7.4 17-16.6S41.4 15 32 15z" fill="#FFFFFF"/>
  <path d="M39.6 35.8c-.4-.2-2.4-1.2-2.8-1.3-.4-.1-.6-.2-.9.2-.3.4-1 1.3-1.3 1.6-.2.3-.5.3-.9.1-1.6-.8-2.9-1.8-4.1-3.3-.3-.4 0-.6.2-.9.2-.2.4-.5.6-.7.2-.2.3-.4.4-.7.1-.2 0-.5-.1-.7-.1-.2-.9-2.2-1.3-3-.3-.8-.7-.7-.9-.7h-.8c-.3 0-.7.1-1.1.5-.4.4-1.4 1.4-1.4 3.4s1.5 3.9 1.7 4.2c.2.3 2.9 4.5 7.1 6.3 2.6 1.1 3.7 1.2 5 1 .8-.1 2.4-1 2.7-1.9.3-.9.3-1.7.2-1.9-.1-.2-.4-.3-.8-.5z" fill="#25D366"/>
</svg>
''';

const String _svgWebhooks = '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" rx="16" fill="#7C3AED"/>
  <circle cx="32" cy="20" r="5" fill="#FFFFFF"/>
  <circle cx="20" cy="42" r="5" fill="#FFFFFF"/>
  <circle cx="44" cy="42" r="5" fill="#FFFFFF"/>
  <path d="M32 25v7l-9 7.5M32 32l9 7.5M25 42h14" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  static const List<String> _categoryKeys = [
    'all',
    'delivery',
    'logistics',
    'accounting',
    'automation',
  ];

  static const List<_IntegrationItem> _catalog = [
    _IntegrationItem(
      id: 'grabfood',
      name: 'GrabFood',
      category: 'delivery',
      descKey: 'integrations.desc_grabfood',
      brandColor: Color(0xFF00B14F),
      svgLogo: _svgGrabFood,
      assetLogo: 'assets/images/integrations/grabfood.png',
      defaultStatus: _IntegrationStatus.comingSoon,
    ),
    _IntegrationItem(
      id: 'shopeefood',
      name: 'ShopeeFood',
      category: 'delivery',
      descKey: 'integrations.desc_shopeefood',
      brandColor: Color(0xFFEE4D2D),
      svgLogo: _svgShopeeFood,
      assetLogo: 'assets/images/integrations/shopeefood.jpg',
      defaultStatus: _IntegrationStatus.comingSoon,
    ),
    _IntegrationItem(
      id: 'foodpanda',
      name: 'foodpanda',
      category: 'delivery',
      descKey: 'integrations.desc_foodpanda',
      brandColor: Color(0xFFD70F64),
      svgLogo: _svgFoodpanda,
      assetLogo: 'assets/images/integrations/foodpanda.jpg',
      defaultStatus: _IntegrationStatus.comingSoon,
    ),
    _IntegrationItem(
      id: 'misi',
      name: 'Misi Rakyat',
      category: 'delivery',
      descKey: 'integrations.desc_misi',
      brandColor: Color(0xFFF59E0B),
      svgLogo: _svgMisi,
      assetLogo: 'assets/images/integrations/misi_delivery.jpg',
      defaultStatus: _IntegrationStatus.comingSoon,
    ),
    _IntegrationItem(
      id: 'lalamove',
      name: 'Lalamove',
      category: 'logistics',
      descKey: 'integrations.desc_lalamove',
      brandColor: Color(0xFFFF6600),
      svgLogo: _svgLalamove,
      assetLogo: 'assets/images/integrations/lalamove.jpg',
      defaultStatus: _IntegrationStatus.comingSoon,
      fieldLabelKey: 'integrations.api_key_label',
      fieldHintKey: 'integrations.api_key_hint',
    ),
    _IntegrationItem(
      id: 'grabexpress',
      name: 'GrabExpress',
      category: 'logistics',
      descKey: 'integrations.desc_grabexpress',
      brandColor: Color(0xFF10B981),
      svgLogo: _svgGrabExpress,
      assetLogo: 'assets/images/integrations/grabexpress.jpg',
      defaultStatus: _IntegrationStatus.comingSoon,
    ),
    _IntegrationItem(
      id: 'myinvois',
      name: 'LHDN MyInvois',
      category: 'accounting',
      descKey: 'integrations.desc_myinvois',
      brandColor: Color(0xFF38BDF8),
      svgLogo: _svgMyInvois,
      assetLogo: 'assets/images/integrations/myinvois.png',
      defaultStatus: _IntegrationStatus.comingSoon,
      fieldLabelKey: 'integrations.tin_label',
      fieldHintKey: 'integrations.tin_hint',
    ),
    _IntegrationItem(
      id: 'whatsapp_api',
      name: 'WhatsApp Business',
      category: 'automation',
      descKey: 'integrations.desc_whatsapp',
      brandColor: Color(0xFF25D366),
      svgLogo: _svgWhatsApp,
      assetLogo: 'assets/images/integrations/whatsapp_business.png',
      defaultStatus: _IntegrationStatus.comingSoon,
      fieldLabelKey: 'integrations.phone_id_label',
      fieldHintKey: 'integrations.phone_id_hint',
    ),
  ];

  int _selectedCategory = 0;
  String _searchQuery = '';
  String _businessId = 'default';
  Map<String, Map<String, dynamic>> _savedConfigs = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
    final bizId = profile?['id']?.toString() ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ngam_integrations_$bizId');

    Map<String, Map<String, dynamic>> parsed = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            parsed[entry.key] = Map<String, dynamic>.from(entry.value as Map);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _businessId = bizId;
        _savedConfigs = parsed;
      });
    }
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ngam_integrations_$_businessId', jsonEncode(_savedConfigs));
  }

  bool _isConnected(_IntegrationItem item) {
    if (item.defaultStatus == _IntegrationStatus.comingSoon) return false;
    return _savedConfigs[item.id]?['connected'] == true;
  }

  List<_IntegrationItem> get _filteredCatalog {
    final q = _searchQuery.trim().toLowerCase();
    final catKey = _categoryKeys[_selectedCategory];
    return _catalog.where((item) {
      if (catKey != 'all' && item.category != catKey) return false;
      if (q.isNotEmpty) {
        final nameMatch = item.name.toLowerCase().contains(q);
        final descMatch = item.descKey.tr().toLowerCase().contains(q);
        return nameMatch || descMatch;
      }
      return true;
    }).toList();
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'delivery':
        return 'integrations.cat_delivery'.tr();
      case 'logistics':
        return 'integrations.cat_logistics'.tr();
      case 'accounting':
        return 'integrations.cat_accounting'.tr();
      case 'automation':
        return 'integrations.cat_automation'.tr();
      default:
        return 'integrations.cat_all'.tr();
    }
  }

  Widget _buildBrandLogo(_IntegrationItem item, {double size = 46}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: item.brandColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: item.assetLogo != null
            ? Image.asset(
                item.assetLogo!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              )
            : SvgPicture.string(
                item.svgLogo,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Future<void> _openConfigDialog(_IntegrationItem item) async {
    if (item.defaultStatus == _IntegrationStatus.comingSoon) {
      showGlassToast(context, 'integrations.coming_soon_toast'.tr(args: [item.name]));
      return;
    }

    final existing = _savedConfigs[item.id] ?? {};
    final idController = TextEditingController(
      text: (existing['identifier'] ?? '').toString(),
    );
    bool autoSync = existing['autoSync'] != false;
    bool isConnected = existing['connected'] == true;

    final frostedGlow = [
      Shadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 8),
      Shadow(
        color: Colors.black.withValues(alpha: 0.25),
        offset: const Offset(0.5, 0.5),
        blurRadius: 0,
      ),
    ];

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  child: GlassContainer(
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
                    settings: const LiquidGlassSettings(
                      thickness: 0.1,
                      blur: 16.0,
                      glassColor: Colors.transparent,
                      lightAngle: 45.0,
                      lightIntensity: 0.1,
                      ambientStrength: 1.0,
                      saturation: 1.0,
                      chromaticAberration: 0.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildBrandLogo(item, size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w900,
                                          shadows: frostedGlow,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _categoryLabel(item.category),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: item.brandColor,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item.descKey.tr(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.fieldLabelKey.tr(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: idController,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: item.fieldHintKey.tr(),
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.25),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: item.brandColor, width: 1.3),
                                ),
                              ),
                            ),
                            if (item.supportsAutoSync) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'integrations.auto_sync_label'.tr(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                      ),
                                    ),
                                    Switch(
                                      value: autoSync,
                                      activeThumbColor: item.brandColor,
                                      onChanged: (v) => setDialogState(() => autoSync = v),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isConnected) ...[
                                  Flexible(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          _savedConfigs[item.id] = {
                                            'connected': false,
                                            'identifier': idController.text.trim(),
                                            'autoSync': autoSync,
                                          };
                                          Navigator.pop(ctx, true);
                                        },
                                        borderRadius: BorderRadius.circular(100),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(100),
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                                            border: Border.all(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'integrations.disconnect_btn'.tr(),
                                              maxLines: 1,
                                              style: const TextStyle(
                                                color: Color(0xFFFCA5A5),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.pop(ctx, false),
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(100),
                                          color: Colors.white.withValues(alpha: 0.08),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'common.cancel'.tr(),
                                            maxLines: 1,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        final val = idController.text.trim();
                                        if (val.isEmpty) {
                                          showGlassToast(context, 'integrations.enter_id_error'.tr(), isError: true);
                                          return;
                                        }
                                        _savedConfigs[item.id] = {
                                          'connected': true,
                                          'identifier': val,
                                          'autoSync': autoSync,
                                        };
                                        Navigator.pop(ctx, true);
                                      },
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(100),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              item.brandColor.withValues(alpha: 0.90),
                                              item.brandColor.withValues(alpha: 0.72),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: item.brandColor.withValues(alpha: 0.32),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isConnected
                                                ? 'integrations.save_btn'.tr()
                                                : 'integrations.connect_btn'.tr(),
                                            maxLines: 1,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
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
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    idController.dispose();
    if (result == true) {
      await _saveConfigs();
      if (mounted) {
        setState(() {});
        final nowConn = _isConnected(item);
        showGlassToast(
          context,
          nowConn
              ? 'integrations.connected_toast'.tr(args: [item.name])
              : 'integrations.disconnected_toast'.tr(args: [item.name]),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredCatalog;

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'integrations.title'.tr(),
      subtitle: 'integrations.subtitle'.tr(),
      onBack: () => Navigator.pop(context),
      actionItems: [
        GlassNavPillItem(
          icon: Icons.sync_rounded,
          tooltip: 'integrations.sync_all'.tr(),
          onTap: () => showGlassToast(context, 'integrations.sync_success'.tr()),
        ),
      ],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 84, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildCategoryChips(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'integrations.no_results'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final crossAxisCount = width >= 1040 ? 3 : (width >= 640 ? 2 : 1);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent: 196,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) => _buildIntegrationCard(items[idx]),
                      childCount: items.length,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'integrations.search_hint'.tr(),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.45), size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.45), size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF141424),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryKeys.length,
        itemBuilder: (ctx, idx) {
          final isSel = idx == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSel
                    ? const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF2563EB)])
                    : null,
                color: isSel ? null : const Color(0xFF141424),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? Colors.transparent : Colors.white.withValues(alpha: 0.09),
                ),
              ),
              child: Center(
                child: Text(
                  _categoryLabel(_categoryKeys[idx]),
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntegrationCard(_IntegrationItem item) {
    final connected = _isConnected(item);
    final comingSoon = item.defaultStatus == _IntegrationStatus.comingSoon;
    final storedId = (_savedConfigs[item.id]?['identifier'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connected
              ? item.brandColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: connected
            ? [
                BoxShadow(
                  color: item.brandColor.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBrandLogo(item, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _categoryLabel(item.category),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (comingSoon
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFF42A5F5).withValues(alpha: 0.14)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: connected
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : (comingSoon
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFF42A5F5).withValues(alpha: 0.35)),
                  ),
                ),
                child: Text(
                  connected
                      ? 'integrations.status_connected'.tr()
                      : (comingSoon
                          ? 'integrations.status_soon'.tr()
                          : 'integrations.status_ready'.tr()),
                  style: TextStyle(
                    color: connected
                        ? const Color(0xFF10B981)
                        : (comingSoon ? Colors.white54 : const Color(0xFF42A5F5)),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              item.descKey.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (connected && storedId.isNotEmpty)
                Expanded(
                  child: Text(
                    storedId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openConfigDialog(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: connected
                        ? Colors.white.withValues(alpha: 0.08)
                        : (comingSoon
                            ? Colors.white.withValues(alpha: 0.05)
                            : item.brandColor.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: connected
                          ? Colors.white.withValues(alpha: 0.16)
                          : (comingSoon
                              ? Colors.white.withValues(alpha: 0.1)
                              : item.brandColor.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Text(
                    connected
                        ? 'integrations.configure_btn'.tr()
                        : (comingSoon
                            ? 'integrations.notify_btn'.tr()
                            : 'integrations.connect_btn'.tr()),
                    style: TextStyle(
                      color: connected
                          ? Colors.white
                          : (comingSoon ? Colors.white60 : item.brandColor),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
