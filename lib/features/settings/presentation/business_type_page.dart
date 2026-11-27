import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../data/business_service.dart';
import '../models/business_type_catalog.dart';

class BusinessTypePage extends StatefulWidget {
  final String? initialSelectedId;

  const BusinessTypePage({
    super.key,
    this.initialSelectedId,
  });

  @override
  State<BusinessTypePage> createState() => _BusinessTypePageState();
}

class _BusinessTypePageState extends State<BusinessTypePage> {
  String? _selectedId;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelectedId?.trim();
    if (initial != null && initial.isNotEmpty) {
      final item = BusinessTypeCatalog.findById(initial);
      _selectedId = item?.id;
    } else {
      final cached = BusinessService.cachedProfile;
      _selectedId = _extractTypeFromProfile(cached);
      _syncCurrentTypeFromServer();
    }
  }

  String? _extractTypeFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final direct = profile['business_type']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return BusinessTypeCatalog.findById(direct)?.id;
    }
    final settings = profile['settings'];
    if (settings is Map && settings['operating_hours'] is Map) {
      final opType = (settings['operating_hours'] as Map)['business_type']?.toString().trim();
      if (opType != null && opType.isNotEmpty) {
        return BusinessTypeCatalog.findById(opType)?.id;
      }
    }
    final industry = profile['business_industry']?.toString().trim();
    if (industry != null && industry.isNotEmpty && industry.toLowerCase() != 'services') {
      return BusinessTypeCatalog.findById(industry)?.id;
    }
    return null;
  }

  Future<void> _syncCurrentTypeFromServer() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      final resolved = _extractTypeFromProfile(profile);
      if (mounted && resolved != null && resolved != _selectedId) {
        setState(() => _selectedId = resolved);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BusinessTypeItem> get _filteredItems {
    return BusinessTypeCatalog.searchRanked(
      _searchQuery,
      categoryGroup: _selectedCategory,
    );
  }

  Future<void> _handleSave() async {
    final chosenId = _selectedId;
    if (_isSaving || chosenId == null || chosenId.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizId = profile?['id']?.toString();
      final selectedItem = BusinessTypeCatalog.findById(chosenId);

      if (bizId != null && bizId.isNotEmpty) {
        final dbIndustry = BusinessTypeCatalog.toDbIndustry(chosenId);
        final categoryGroup = selectedItem?.categoryGroup ?? 'home_services';
        final bookingMode = selectedItem?.bookingMode ?? 'none';

        await bizService.updateBusinessProfile(bizId, {
          'business_industry': dbIndustry,
          'category_group': categoryGroup,
          'business_type': chosenId,
          'booking_mode': bookingMode,
        });

        // Mirror 3-layer taxonomy inside business_settings.operating_hours
        // and seed smart default service modes only if not yet customized.
        final existingSettings = profile?['settings'];
        final opHours = (existingSettings is Map && existingSettings['operating_hours'] is Map)
            ? Map<String, dynamic>.from(existingSettings['operating_hours'] as Map)
            : <String, dynamic>{};
        opHours['business_type'] = chosenId;
        opHours['category_group'] = categoryGroup;
        opHours['booking_mode'] = bookingMode;
        if (opHours['service_modes'] == null) {
          final rec = BusinessTypeCatalog.recommendedServiceModes(chosenId);
          opHours['service_modes'] = BusinessTypeCatalog.recommendedServiceModeList(chosenId);
          opHours['enable_walkin'] = rec.walkIn;
          opHours['enable_booking'] = rec.booking;
          opHours['enable_order'] = rec.order;
        }
        await bizService.saveBusinessSettings(bizId, {'operating_hours': opHours});
      }

      if (mounted) {
        showGlassToast(context, 'business_type.save_success'.tr());
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(chosenId);
        } else {
          GlassNavButton.safeNavBack(context, fallbackRoute: '/settings');
        }
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'business_type.save_error'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 640;
    final activeItem = _selectedId != null ? BusinessTypeCatalog.findById(_selectedId) : null;
    final filtered = _filteredItems;

    // Follow app theme background seamlessly in both Dark & Light modes
    final pageBg = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131322) : Colors.white;
    final chipBg = isDark ? const Color(0xFF161626) : const Color(0xFFF1F5F9);
    final bottomBarBg = isDark ? const Color(0xFF0E0E1A) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF64748B);
    const brandGreen = Color(0xFF44CF6C);

    return GlassScaffold(
      backgroundColor: pageBg,
      title: 'business_type.title'.tr(),
      subtitle: 'business_type.subtitle'.tr(),
      fallbackRoute: '/settings',
      onBack: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(_selectedId);
        } else {
          GlassNavButton.safeNavBack(context, fallbackRoute: '/settings');
        }
      },
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: bottomBarBg,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isSaving || _selectedId == null) ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: brandGreen.withValues(alpha: 0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        'business_type.save_selection'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 68),
          // ─── Search Section (48px standardized glass pill) ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Container(
              height: 48,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : borderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: primaryText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'business_type.search_hint'.tr(),
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
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
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: secondaryText,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          // ─── Category Filter Chips (Ordered by real-world volume) ───────
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: BusinessTypeCatalog.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = BusinessTypeCatalog.categories[idx];
                final isSelected = _selectedCategory == cat;
                final label = 'business_type.categories.$cat'.tr();

                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? brandGreen : chipBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? brandGreen : borderColor,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.black
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Active Selected Banner ─────────────────────────────────────
          if (activeItem != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brandGreen.withValues(alpha: isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brandGreen.withValues(alpha: 0.32)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: activeItem.icon,
                        color: brandGreen,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'business_type.current_selected'.tr(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: brandGreen,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeItem.nameKey.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBadge(
                              label: 'business_type.categories.${activeItem.categoryGroup}'.tr(),
                              color: brandGreen,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: brandGreen,
                    size: 20,
                  ),
                ],
              ),
            ),

          // ─── Business Types List / Responsive Grid ──────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'business_type.no_results_title'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'business_type.no_results_desc'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : useGrid
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: screenWidth >= 1024 ? 3 : 2,
                          mainAxisExtent: 126,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) => _buildTypeCard(
                          item: filtered[idx],
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          brandGreen: brandGreen,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) => _buildTypeCard(
                          item: filtered[idx],
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          brandGreen: brandGreen,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.28 : 0.25),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isDark ? color : color.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required BusinessTypeItem item,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryText,
    required Color secondaryText,
    required Color brandGreen,
  }) {
    final isSelected = item.id == _selectedId;

    return InkWell(
      onTap: () => setState(() => _selectedId = item.id),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected
              ? brandGreen.withValues(alpha: isDark ? 0.1 : 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? brandGreen : borderColor,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandGreen.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? brandGreen.withValues(alpha: 0.2)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: HugeIcon(
                  icon: item.icon,
                  color: isSelected
                      ? brandGreen
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.nameKey.tr(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.descKey.tr(),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: secondaryText,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'business_type.categories.${item.categoryGroup}'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? brandGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected ? brandGreen : borderColor,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.black,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
