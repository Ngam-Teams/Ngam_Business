import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/home/presentation/home_dashboard.dart';
import '../../features/pos/presentation/pos_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/business_profile_page.dart';
import '../../widgets/dashboard_scaffold.dart';

// ---------------------------------------------------------------------------
// Unauthorized screen
// ---------------------------------------------------------------------------
class _UnauthorizedScreen extends StatelessWidget {
  const _UnauthorizedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedLock,
              color: Colors.redAccent,
              size: 56,
              strokeWidth: 2.1,
            ),
            const SizedBox(height: 20),
            const Text(
              'Access Denied',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account does not have business access.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main app shell — houses all 4 tabs
// ---------------------------------------------------------------------------
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;

  static final _navItems = [
    (icon: HugeIcons.strokeRoundedHome11, label: 'Overview'),
    (icon: HugeIcons.strokeRoundedShoppingCart02, label: 'POS'),
    (icon: HugeIcons.strokeRoundedAnalytics01, label: 'Analytics'),
    (icon: HugeIcons.strokeRoundedSettings01, label: 'Settings'),
  ];

  static const _titles = ['Overview', 'Point of Sale', 'Analytics', 'Settings'];
  static const _subtitles = [
    'Your business at a glance',
    'Manage orders & products',
    'Revenue & performance',
    'Account & preferences',
  ];

  static const _pages = [
    HomeDashboard(),
    PosPage(),
    AnalyticsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      selectedIndex: _selectedIndex,
      onNavTap: (i) => setState(() => _selectedIndex = i),
      pageTitle: _titles[_selectedIndex],
      pageSubtitle: _subtitles[_selectedIndex],
      navItems: _navItems,
      child: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final isGoingToAuth =
        state.uri.path == '/login' || 
        state.uri.path == '/signup' || 
        state.uri.path == '/unauthorized';

    // Not logged in — send to login (unless already going there)
    if (user == null) {
      return isGoingToAuth ? null : '/login';
    }

    // Logged in and going to auth screen — redirect to home
    if (state.uri.path == '/login' || state.uri.path == '/signup') {
      return '/home';
    }

    // For protected routes — verify business role
    if (!isGoingToAuth) {
      try {
        final response = await Supabase.instance.client
            .from('user_roles')
            .select('role')
            .eq('user_id', user.id)
            .maybeSingle();

        final role = response?['role'] as String?;
        if (role != null && role != 'tenant_admin' && role != 'staff') {
          // If a role exists but isn't a business role → unauthorized
          return '/unauthorized';
        }
      } catch (_) {
        // If user_roles table doesn't exist yet, allow access
        // (useful during development before DB is fully set up)
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const _AppShell(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/unauthorized',
      builder: (context, state) => const _UnauthorizedScreen(),
    ),
    GoRoute(
      path: '/business-profile',
      builder: (context, state) => const BusinessProfilePage(),
    ),
  ],
);
