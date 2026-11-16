import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// =============================================================================
// IntegrationsPage — Ngam Business Integrations & Apps Hub
// Connects GrabFood, ShopeeFood, foodpanda, Lalamove, Payments, Accounting, etc.
// =============================================================================

enum _IntegrationStatus { available, connected, comingSoon }

class _IntegrationItem {
  final String id;
  final String name;
  final String category; // 'delivery', 'logistics', 'payments', 'accounting', 'automation'
  final String descKey;
  final Color brandColor;
  final IconData icon;
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
    required this.icon,
    this.defaultStatus = _IntegrationStatus.available,
    this.fieldLabelKey = 'integrations.store_id_label',
    this.fieldHintKey = 'integrations.store_id_hint',
    this.supportsAutoSync = true,
  });
}

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
    'payments',
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
      icon: Icons.delivery_dining_rounded,
    ),
    _IntegrationItem(
      id: 'shopeefood',
      name: 'ShopeeFood',
      category: 'delivery',
      descKey: 'integrations.desc_shopeefood',
      brandColor: Color(0xFFEE4D2D),
      icon: Icons.fastfood_rounded,
    ),
    _IntegrationItem(
      id: 'foodpanda',
      name: 'foodpanda',
      category: 'delivery',
      descKey: 'integrations.desc_foodpanda',
      brandColor: Color(0xFFD70F64),
      icon: Icons.takeout_dining_rounded,
    ),
    _IntegrationItem(
      id: 'misi',
      name: 'Misi Rakyat',
      category: 'delivery',
      descKey: 'integrations.desc_misi',
      brandColor: Color(0xFFF59E0B),
      icon: Icons.moped_rounded,
    ),
    _IntegrationItem(
      id: 'lalamove',
      name: 'Lalamove',
      category: 'logistics',
      descKey: 'integrations.desc_lalamove',
      brandColor: Color(0xFFFF6600),
      icon: Icons.local_shipping_rounded,
      fieldLabelKey: 'integrations.api_key_label',
      fieldHintKey: 'integrations.api_key_hint',
    ),
    _IntegrationItem(
      id: 'grabexpress',
      name: 'GrabExpress',
      category: 'logistics',
      descKey: 'integrations.desc_grabexpress',
      brandColor: Color(0xFF10B981),
      icon: Icons.electric_moped_rounded,
    ),
    _IntegrationItem(
      id: 'duitnow',
      name: 'DuitNow QR',
      category: 'payments',
      descKey: 'integrations.desc_duitnow',
      brandColor: Color(0xFFEC4899),
      icon: Icons.qr_code_2_rounded,
      defaultStatus: _IntegrationStatus.connected,
      supportsAutoSync: false,
    ),
    _IntegrationItem(
      id: 'chip',
      name: 'CHIP Payment',
      category: 'payments',
      descKey: 'integrations.desc_chip',
      brandColor: Color(0xFF42A5F5),
      icon: Icons.credit_card_rounded,
      defaultStatus: _IntegrationStatus.connected,
      fieldLabelKey: 'integrations.brand_id_label',
      fieldHintKey: 'integrations.brand_id_hint',
      supportsAutoSync: false,
    ),
    _IntegrationItem(
      id: 'myinvois',
      name: 'LHDN MyInvois',
      category: 'accounting',
      descKey: 'integrations.desc_myinvois',
      brandColor: Color(0xFF38BDF8),
      icon: Icons.receipt_long_rounded,
      fieldLabelKey: 'integrations.tin_label',
      fieldHintKey: 'integrations.tin_hint',
    ),
    _IntegrationItem(
      id: 'sql_accounting',
      name: 'SQL Accounting',
      category: 'accounting',
      descKey: 'integrations.desc_sql',
      brandColor: Color(0xFF6366F1),
      icon: Icons.account_balance_wallet_rounded,
      defaultStatus: _IntegrationStatus.comingSoon,
    ),
    _IntegrationItem(
      id: 'whatsapp_api',
      name: 'WhatsApp Business',
      category: 'automation',
      descKey: 'integrations.desc_whatsapp',
      brandColor: Color(0xFF25D366),
      icon: Icons.chat_rounded,
      fieldLabelKey: 'integrations.phone_id_label',
      fieldHintKey: 'integrations.phone_id_hint',
    ),
    _IntegrationItem(
      id: 'webhooks',
      name: 'Custom Webhooks',
      category: 'automation',
      descKey: 'integrations.desc_webhooks',
      brandColor: Color(0xFFA78BFA),
      icon: Icons.webhook_rounded,
      fieldLabelKey: 'integrations.webhook_url_label',
      fieldHintKey: 'integrations.webhook_url_hint',
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

    // Seed default connected items on first visit
    for (final item in _catalog) {
      if (item.defaultStatus == _IntegrationStatus.connected && !parsed.containsKey(item.id)) {
        parsed[item.id] = {
          'connected': true,
          'identifier': 'NGAM-${item.id.toUpperCase()}',
          'autoSync': true,
        };
      }
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

  int get _connectedCount => _catalog.where(_isConnected).length;

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
      case 'payments':
        return 'integrations.cat_payments'.tr();
      case 'accounting':
        return 'integrations.cat_accounting'.tr();
      case 'automation':
        return 'integrations.cat_automation'.tr();
      default:
        return 'integrations.cat_all'.tr();
    }
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

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131324),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    boxShadow: [
                      BoxShadow(
                        color: item.brandColor.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.brandColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: item.brandColor.withValues(alpha: 0.35)),
                            ),
                            child: Icon(item.icon, color: item.brandColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _categoryLabel(item.category),
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
                            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.descKey.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
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
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF0B0B16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            borderSide: BorderSide(color: item.brandColor, width: 1.3),
                          ),
                        ),
                      ),
                      if (item.supportsAutoSync) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                        children: [
                          if (isConnected)
                            TextButton(
                              onPressed: () {
                                _savedConfigs[item.id] = {
                                  'connected': false,
                                  'identifier': idController.text.trim(),
                                  'autoSync': autoSync,
                                };
                                Navigator.pop(ctx, true);
                              },
                              child: Text(
                                'integrations.disconnect_btn'.tr(),
                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'common.cancel'.tr(),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: item.brandColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              isConnected
                                  ? 'integrations.save_btn'.tr()
                                  : 'integrations.connect_btn'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  _buildHeroBanner(),
                  const SizedBox(height: 16),
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
                      mainAxisExtent: 198,
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

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF42A5F5).withValues(alpha: 0.16),
            const Color(0xFFA78BFA).withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedGlobe02,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'integrations.hero_title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'integrations.hero_desc'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'integrations.connected_count'.tr(
                    args: [_connectedCount.toString(), _catalog.length.toString()],
                  ),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.brandColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.brandColor.withValues(alpha: 0.35)),
                ),
                child: Icon(item.icon, color: item.brandColor, size: 22),
              ),
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
                    borderRadius: BorderRadius.circular(12),
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
