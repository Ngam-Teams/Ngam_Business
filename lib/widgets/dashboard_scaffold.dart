import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bottom_nav.dart';
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
                                'assets/splash.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
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

                            if (profile == null) {
                              BusinessService().getBusinessProfile();
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
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
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                    ),
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
                                ],
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

                          if (profile == null) {
                            BusinessService().getBusinessProfile();
                          }

                          final initial = businessName.isNotEmpty
                              ? businessName[0].toUpperCase()
                              : 'B';

                          final tooltipText = businessName.isEmpty
                              ? 'Memuatkan profil...'
                              : (handle != null && handle.isNotEmpty
                                  ? '$businessName (@$handle)'
                                  : businessName);

                          return Tooltip(
                            message: tooltipText,
                            waitDuration: const Duration(milliseconds: 300),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      width: 1.2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 9,
                                    height: 9,
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
                        await Supabase.instance.client.auth.signOut();
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
                        'assets/splash.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
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
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor:
              const Color(0xFF42A5F5).withValues(alpha: 0.3),
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            color: Color(0xFF42A5F5),
            size: 18,
            strokeWidth: 2.1,
          ),
        ),
      ],
    );
  }
}
