import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'bottom_nav.dart';
import 'glass_toast.dart';
import '../features/auth/data/auth_service.dart';
import '../features/settings/data/business_service.dart';

/// DashboardScaffold — master responsive layout for Ngam Business.
///
/// Desktop (≥800px): collapsible floating rail with Gemini-style Expand & Shrink modes:
/// - Shrunk mode: ultra-slim (72px) icon-only rail. Hovering over the logo transforms
///   it into the expand icon button; clicking expands the sidebar.
/// - Expanded mode: full (260px) labeled sidebar with collapse icon in top right.
/// Mobile (<800px): floating glassmorphic pill BottomNav.
class DashboardScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final Widget child;
  final String pageTitle;
  final String pageSubtitle;
  final List<({dynamic icon, String label})> navItems;

  const DashboardScaffold({
    super.key,
    required this.selectedIndex,
    required this.onNavTap,
    required this.child,
    required this.pageTitle,
    required this.pageSubtitle,
    required this.navItems,
  });

  /// Preserves sidebar expanded/collapsed state across tab & route changes
  static final ValueNotifier<bool> isExpandedNotifier = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A14),
          extendBody: true,
          bottomNavigationBar: isDesktop
              ? null
              : BottomNav(
                  currentIndex: selectedIndex,
                  onTap: onNavTap,
                  items: navItems
                      .map((item) =>
                          NavItem(icon: item.icon, title: item.label))
                      .toList(),
                ),
          body: SafeArea(
            bottom: false,
            child: isDesktop
                ? Row(
                    children: [
                      _buildNavigationRail(context),
                      Expanded(
                        child: _buildContent(context, isDesktop),
                      ),
                    ],
                  )
                : _buildContent(context, isDesktop),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation Rail (collapsible: Gemini-style Expand and Shrink modes)
  // ---------------------------------------------------------------------------
  Widget _buildNavigationRail(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isExpandedNotifier,
      builder: (context, isExpanded, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: isExpanded ? 260 : 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Top Bar (Logo & Expand / Shrink Interactions)
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/app.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/splash.png',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'N',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Ngam',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Business',
                                    style: TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Collapse icon button in expanded mode
                            _CollapseSidebarButton(
                              onTap: () => isExpandedNotifier.value = false,
                            ),
                          ],
                        ),
                      )
                    else
                      // Shrunk mode: Logo swaps to expand button on hover!
                      _LogoExpandButton(
                        onTap: () => isExpandedNotifier.value = true,
                      ),

                    const SizedBox(height: 14),

                    // Store Profile Section
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: BusinessService.profileNotifier,
                          builder: (context, liveProfile, _) {
                            final profile =
                                liveProfile ?? BusinessService.cachedProfile;
                            final businessName = (profile?['business_name'] ??
                                    profile?['name'] ??
                                    profile?['title'] ??
                                    '')
                                .toString()
                                .trim();
                            final handle =
                                (profile?['business_handle'] as String?)?.trim();
                            final logoUrl = (profile?['business_logo_url'] ??
                                    profile?['logo_url']) as String?;

                            if (profile == null) {
                              BusinessService().getBusinessProfile();
                            }

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => context.push('/business-profile'),
                                borderRadius: BorderRadius.circular(12),
                                hoverColor: Colors.white.withValues(alpha: 0.08),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _StoreAvatar(
                                        size: 34,
                                        logoUrl: logoUrl,
                                        businessName: businessName,
                                        showStatusDot: true,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              businessName.isEmpty
                                                  ? 'Memuatkan...'
                                                  : businessName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 1.5),
                                            Text(
                                              handle != null && handle.isNotEmpty
                                                  ? '@$handle'
                                                  : 'Live on Explore',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.45),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      ValueListenableBuilder<Map<String, dynamic>?>(
                        valueListenable: BusinessService.profileNotifier,
                        builder: (context, liveProfile, _) {
                          final profile =
                              liveProfile ?? BusinessService.cachedProfile;
                          final businessName = (profile?['business_name'] ??
                                  profile?['name'] ??
                                  profile?['title'] ??
                                  '')
                              .toString()
                              .trim();
                          final handle =
                              (profile?['business_handle'] as String?)?.trim();
                          final logoUrl = (profile?['business_logo_url'] ??
                                  profile?['logo_url']) as String?;

                          if (profile == null) {
                            BusinessService().getBusinessProfile();
                          }

                          final tooltipText = businessName.isEmpty
                              ? 'Profil Kedai'
                              : (handle != null && handle.isNotEmpty
                                  ? '$businessName (@$handle)'
                                  : businessName);

                          return Tooltip(
                            message: '$tooltipText\n(Klik untuk profil)',
                            waitDuration: const Duration(milliseconds: 250),
                            child: _StoreAvatar(
                              size: 38,
                              logoUrl: logoUrl,
                              businessName: businessName,
                              showStatusDot: true,
                              onTap: () => context.push('/business-profile'),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Nav items (Smoothly adapts to Expanded or Shrunk)
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: navItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = navItems[index];
                          final selected = index == selectedIndex;
                          return _SidebarNavItem(
                            icon: item.icon,
                            label: item.label,
                            selected: selected,
                            isExpanded: isExpanded,
                            onTap: () => onNavTap(index),
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Sign Out
                    _SidebarNavItem(
                      icon: HugeIcons.strokeRoundedLogout02,
                      label: 'Sign Out',
                      selected: false,
                      isExpanded: isExpanded,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF141420),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            title: const Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedLogout02,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Log Keluar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: const Text(
                              'Adakah anda pasti ingin log keluar dari akaun perniagaan ini?',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.redAccent.withValues(alpha: 0.85),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Log Keluar'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          showGlassToast(context, 'Sedang log keluar...');
                          await AuthService().signOut();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Content Area
  // ---------------------------------------------------------------------------
  Widget _buildContent(BuildContext context, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 20 : 16,
        isDesktop ? 20 : 16,
        isDesktop ? 24 : 16,
        isDesktop ? 20 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pageTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pageSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _TopBarActions(),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo / Expand Button (Gemini Style: Hover over logo transforms into expand icon)
// ---------------------------------------------------------------------------
class _LogoExpandButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LogoExpandButton({required this.onTap});

  @override
  State<_LogoExpandButton> createState() => _LogoExpandButtonState();
}

class _LogoExpandButtonState extends State<_LogoExpandButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isHovered ? 'Kembangkan Sidebar' : 'Ngam Business',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: _isHovered
                  ? const HugeIcon(
                      key: ValueKey('expand_icon'),
                      icon: HugeIcons.strokeRoundedSidebarLeft01,
                      color: Colors.white,
                      size: 20,
                      strokeWidth: 2.1,
                    )
                  : ClipRRect(
                      key: const ValueKey('logo_img'),
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/app.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/splash.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'N',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapse Button (Gemini Style: Top right icon button to collapse sidebar)
// ---------------------------------------------------------------------------
class _CollapseSidebarButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CollapseSidebarButton({required this.onTap});

  @override
  State<_CollapseSidebarButton> createState() => _CollapseSidebarButtonState();
}

class _CollapseSidebarButtonState extends State<_CollapseSidebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Kecilkan Sidebar',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSidebarLeft,
                color: Colors.white70,
                size: 18,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar Nav Item (Dual Mode: Icon + Text in Expand, Icon Only in Shrink)
// ---------------------------------------------------------------------------
class _SidebarNavItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool selected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      // Shrunk mode: Icon only with Tooltip
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: Center(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: selected ? const Color(0xFF42A5F5) : Colors.white38,
                  size: 22,
                  strokeWidth: selected ? 2.3 : 1.9,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded mode: Icon + Label (Full width rail "cam b4")
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF42A5F5).withValues(alpha: 0.35)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: selected ? const Color(0xFF42A5F5) : Colors.white38,
              size: 20,
              strokeWidth: selected ? 2.3 : 1.9,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top Bar Actions
// ---------------------------------------------------------------------------
class _TopBarActions extends StatelessWidget {
  const _TopBarActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedNotification02,
            color: Colors.white54,
            size: 20,
            strokeWidth: 2.1,
          ),
          tooltip: 'Pemberitahuan',
          onPressed: () => context.push('/merchant-inbox'),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: BusinessService.profileNotifier,
          builder: (context, liveProfile, _) {
            final profile = liveProfile ?? BusinessService.cachedProfile;
            final businessName = (profile?['business_name'] ??
                    profile?['name'] ??
                    profile?['title'] ??
                    '')
                .toString()
                .trim();
            final logoUrl = (profile?['business_logo_url'] ??
                    profile?['logo_url']) as String?;

            return Tooltip(
              message: 'Profil Kedai',
              child: _StoreAvatar(
                size: 34,
                logoUrl: logoUrl,
                businessName: businessName,
                showStatusDot: false,
                onTap: () => context.push('/business-profile'),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Store Avatar (Displays business logo with graceful initial-fallback)
// ---------------------------------------------------------------------------
class _StoreAvatar extends StatelessWidget {
  final double size;
  final String? logoUrl;
  final String businessName;
  final bool showStatusDot;
  final VoidCallback? onTap;

  const _StoreAvatar({
    this.size = 36,
    this.logoUrl,
    required this.businessName,
    this.showStatusDot = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = businessName.trim().isNotEmpty
        ? businessName.trim()[0].toUpperCase()
        : 'N';

    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;

    final avatarContent = ClipOval(
      child: hasLogo
          ? Image.network(
              logoUrl!.trim(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallback(initial);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: size,
                  height: size,
                  color: Colors.white.withValues(alpha: 0.05),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size * 0.4,
                    height: size * 0.4,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF42A5F5),
                    ),
                  ),
                );
              },
            )
          : _buildFallback(initial),
    );

    final avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF161622),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    Widget result = avatarCircle;

    if (showStatusDot) {
      final dotSize = (size * 0.26).clamp(8.0, 11.0);
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCircle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0A0A14),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      result = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: result,
        ),
      );
    }

    return result;
  }

  Widget _buildFallback(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2B3D),
            Color(0xFF161622),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
