import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late String _selectedId;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId ?? 'restaurant';
    // If not found directly, check legacy or default
    final item = BusinessTypeCatalog.findById(_selectedId);
    if (item != null) {
      _selectedId = item.id;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BusinessTypeItem> get _filteredItems {
    return BusinessTypeCatalog.allTypes.where((item) {
      // 1. Filter by category
      if (_selectedCategory != 'all' && item.categoryGroup != _selectedCategory) {
        return false;
      }

      // 2. Filter by search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = item.nameKey.tr().toLowerCase();
        final desc = item.descKey.tr().toLowerCase();
        final cat = 'business_type.categories.${item.categoryGroup}'.tr().toLowerCase();
        final id = item.id.toLowerCase();
        return name.contains(q) || desc.contains(q) || cat.contains(q) || id.contains(q);
      }

      return true;
    }).toList();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizId = profile?['id']?.toString();

      if (bizId != null && bizId.isNotEmpty) {
        final dbIndustry = BusinessTypeCatalog.toDbIndustry(_selectedId);
        await bizService.updateBusinessProfile(bizId, {
          'business_industry': dbIndustry,
        });

        // Also preserve granular business_type in business_settings operating_hours
        final existingSettings = profile?['settings'];
        final opHours = (existingSettings is Map && existingSettings['operating_hours'] is Map)
            ? Map<String, dynamic>.from(existingSettings['operating_hours'] as Map)
            : <String, dynamic>{};
        opHours['business_type'] = _selectedId;
        await bizService.saveBusinessSettings(bizId, {'operating_hours': opHours});
      }

      if (mounted) {
        showGlassToast(context, 'business_type.save_success'.tr());
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(_selectedId);
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
    final isDesktop = screenWidth >= 900;
    final activeItem = BusinessTypeCatalog.findById(_selectedId);

    final bgDark = const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final brandGreen = const Color(0xFF44CF6C);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(_selectedId);
        } else {
          GlassNavButton.safeNavBack(context, fallbackRoute: '/settings');
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? bgDark : const Color(0xFFF8FAFC),
        appBar: GlassAppBar(
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
        ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Search Section ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'business_type.search_hint'.tr(),
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            // ─── Category Filter Chips ─────────────────────────────────────
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandGreen
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? brandGreen : borderColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
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

            // ─── Active Selected Banner ────────────────────────────────────
            if (activeItem != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brandGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
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
                              Text(
                                'business_type.current_selected'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: brandGreen,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: brandGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'business_type.categories.${activeItem.categoryGroup}'.tr(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: brandGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeItem.nameKey.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: brandGreen,
                      size: 20,
                    ),
                  ],
                ),
              ),

            // ─── Business Types List/Grid ──────────────────────────────────
            Expanded(
              child: _filteredItems.isEmpty
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
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'business_type.no_results_desc'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 3 : (screenWidth > 600 ? 2 : 1),
                        childAspectRatio: isDesktop ? 2.4 : (screenWidth > 600 ? 2.2 : 3.2),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, idx) {
                        final item = _filteredItems[idx];
                        final isSelected = item.id == _selectedId;

                        return InkWell(
                          onTap: () => setState(() => _selectedId = item.id),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandGreen.withValues(alpha: 0.08)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? brandGreen : borderColor,
                                width: isSelected ? 1.8 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: brandGreen.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? brandGreen.withValues(alpha: 0.2)
                                        : (isDark
                                            ? const Color(0xFF334155).withValues(alpha: 0.4)
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
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.nameKey.tr(),
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? (isDark ? Colors.white : Colors.black)
                                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF334155).withValues(alpha: 0.6)
                                                  : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'business_type.categories.${item.categoryGroup}'.tr(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white60 : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.descKey.tr(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                          Icons.check,
                                          size: 14,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
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
  );
}
}
