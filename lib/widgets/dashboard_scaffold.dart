import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bottom_nav.dart';
import '../features/settings/data/business_service.dart';

/// DashboardScaffold — master responsive layout for Ngam Business.
///
/// Desktop (≥800px): ultra-slim icon-only floating rail (width: ~72px).
/// Mobile (<800px):  floating glassmorphic pill BottomNav.
///
/// Mirrors the layout structure from ngam_console/lib/features/console/presentation/dashboard.dart
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
  // Navigation Rail (ultra-slim icon-only floating rail — desktop only)
  // ---------------------------------------------------------------------------
  Widget _buildNavigationRail(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: 72,
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

                // Ngam Splash Logo Icon
                Tooltip(
                  message: 'Ngam Business',
                  waitDuration: const Duration(milliseconds: 350),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/splash.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Business Profile Avatar with Online Status
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
                      waitDuration: const Duration(milliseconds: 350),
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

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                ),

                const SizedBox(height: 14),

                // Nav items (icon only with tooltip)
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: navItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final selected = index == selectedIndex;
                      return _SidebarNavItem(
                        icon: item.icon,
                        label: item.label,
                        selected: selected,
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
                const SizedBox(height: 8),

                _SidebarNavItem(
                  icon: HugeIcons.strokeRoundedLogout02,
                  label: 'Sign Out',
                  selected: false,
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
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
// Sidebar Nav Item (Icon Only with Tooltip)
// ---------------------------------------------------------------------------
class _SidebarNavItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
