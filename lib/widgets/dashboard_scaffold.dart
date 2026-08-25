import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bottom_nav.dart';

/// DashboardScaffold — master responsive layout for Ngam Business.
///
/// Desktop (≥800px): frosted glass NavigationRail sidebar + content area.
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
  // Navigation Rail (frosted glass sidebar — desktop only)
  // ---------------------------------------------------------------------------
  Widget _buildNavigationRail(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: 220,
          color: Colors.white.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo / Wordmark
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF42A5F5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngam',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Business',
                          style: TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Nav items
              ...navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final selected = index == selectedIndex;
                return _SidebarNavItem(
                  icon: item.icon,
                  label: item.label,
                  selected: selected,
                  onTap: () => onNavTap(index),
                );
              }),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              _SidebarNavItem(
                icon: HugeIcons.strokeRoundedLogout02,
                label: 'Sign Out',
                selected: false,
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                },
              ),
              const SizedBox(height: 24),
            ],
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
        isDesktop ? 32 : 16,
        isDesktop ? 32 : 16,
        isDesktop ? 32 : 16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pageTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pageSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              _TopBarActions(),
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
// Sidebar Nav Item
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: selected ? const Color(0xFF42A5F5) : Colors.white38,
              size: 20,
              strokeWidth: 2.1,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
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
