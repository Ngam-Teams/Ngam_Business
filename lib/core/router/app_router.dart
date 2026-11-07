import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/auth/presentation/reset_password_page.dart';
import '../../features/home/presentation/home_dashboard.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/pos/presentation/pos_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/business_profile_page.dart';
import '../../features/products/presentation/product_catalogue_page.dart';
import '../../features/settings/presentation/staff_management_page.dart';
import '../../features/appointments/presentation/appointments_page.dart';
import '../../features/reviews/presentation/customer_reviews_page.dart';
import '../../features/promotions/presentation/promotions_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/settings/presentation/operating_hours_page.dart';
import '../../features/customers/presentation/customer_insights_page.dart';
import '../../features/payouts/presentation/payouts_page.dart';
import '../../features/qr/presentation/qr_generator_page.dart';
import '../../features/hardware/presentation/receipt_settings_page.dart';
import '../../features/cash_drawer/presentation/cash_drawer_page.dart';
import '../../features/inbox/presentation/merchant_inbox_page.dart';
import '../../features/kds/presentation/kds_page.dart';
import '../../features/settings/presentation/subscription_plans_page.dart';
import '../../features/queue/presentation/queue_page.dart';
import '../../features/queue/presentation/queue_tv_display_page.dart';
import '../../features/payroll/presentation/payroll_management_page.dart';
import '../../features/loyalty/presentation/loyalty_stamps_page.dart';
import '../../features/settings/presentation/mfa_setup_page.dart';
import '../../features/settings/presentation/audit_logs_page.dart';
import '../../features/feed/presentation/feed_management_page.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../services/merchant_notification_service.dart';
import '../../features/settings/data/business_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
            Text(
              'auth.unauthorized_title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'auth.unauthorized_desc'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) context.go('/login');
              },
              child: Text('auth.back_to_login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Global AppShell Tab Switcher Helper
// ---------------------------------------------------------------------------
void Function(int index)? _appShellTabSwitcher;

/// Global helper to switch the primary AppShell tab without throwing routing errors
/// 0: Overview, 1: Orders, 2: POS, 3: Analytics, 4: Settings
void switchAppShellTab(int index) {
  if (_appShellTabSwitcher != null) {
    _appShellTabSwitcher!(index);
  } else {
    switch (index) {
      case 1:
        appRouter.go('/orders');
        break;
      case 2:
        appRouter.go('/pos');
        break;
      case 3:
        appRouter.go('/analytics');
        break;
      case 4:
        appRouter.go('/settings');
        break;
      default:
        appRouter.go('/');
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Main app shell — houses all tabs
// ---------------------------------------------------------------------------
class _AppShell extends StatefulWidget {
  final int initialTab;
  const _AppShell({this.initialTab = 0});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late int _selectedIndex;
  late final Set<int> _activatedTabs;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _activatedTabs = {widget.initialTab};
    _appShellTabSwitcher = (index) {
      if (mounted) {
        setState(() {
          _selectedIndex = index;
          _activatedTabs.add(index);
        });
      }
    };
    _initOrderAlerts();
  }

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _selectedIndex = widget.initialTab;
        _activatedTabs.add(widget.initialTab);
      });
    }
  }

  Future<void> _initOrderAlerts() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      final businessId = profile?['id']?.toString();
      if (businessId != null && mounted) {
        MerchantNotificationService.instance.initialize(
          businessId: businessId,
          onTabSwitch: (index) {
            if (mounted) {
              setState(() {
                _selectedIndex = index;
                _activatedTabs.add(index);
              });
            }
          },
        );
      }
    } catch (e) {
      debugPrint('[AppShell] Error initializing order alerts: $e');
    }
  }

  @override
  void dispose() {
    MerchantNotificationService.instance.dispose();
    super.dispose();
  }

  List<({dynamic icon, String label})> _getNavItems(BuildContext context) => [
    (icon: HugeIcons.strokeRoundedHome11, label: 'nav.overview'.tr()),
    (icon: HugeIcons.strokeRoundedInvoice01, label: 'nav.orders'.tr()),
    (icon: HugeIcons.strokeRoundedShoppingCart02, label: 'nav.pos'.tr()),
    (icon: HugeIcons.strokeRoundedAnalytics01, label: 'nav.analytics'.tr()),
    (icon: HugeIcons.strokeRoundedSettings01, label: 'nav.settings'.tr()),
  ];

  List<String> _getTitles(BuildContext context) => [
    'nav.overview'.tr(),
    'nav.orders'.tr(),
    'nav.pos'.tr(),
    'nav.analytics'.tr(),
    'nav.settings'.tr(),
  ];

  List<String> _getSubtitles(BuildContext context) => [
    'nav.tagline_overview'.tr(),
    'nav.tagline_orders'.tr(),
    'nav.tagline_pos'.tr(),
    'nav.tagline_analytics'.tr(),
    'nav.tagline_settings'.tr(),
  ];

  Widget _buildTab(int index) {
    if (!_activatedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const HomeDashboard();
      case 1:
        return const OrdersPage();
      case 2:
        return const PosPage();
      case 3:
        return const AnalyticsPage();
      case 4:
        return const SettingsPage();
      default:
        return const HomeDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = _getTitles(context);
    final subtitles = _getSubtitles(context);
    final navItems = _getNavItems(context);

    return DashboardScaffold(
      selectedIndex: _selectedIndex,
      onNavTap: (i) => setState(() {
        _selectedIndex = i;
        _activatedTabs.add(i);
      }),
      pageTitle: titles[_selectedIndex],
      pageSubtitle: subtitles[_selectedIndex],
      navItems: navItems,
      child: IndexedStack(
        index: _selectedIndex,
        children: List.generate(5, (index) => _buildTab(index)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Converts a Stream into a Listenable for GoRouter reactive re-evaluation
// ---------------------------------------------------------------------------
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGoingToAuth =
        state.uri.path == '/login' || 
        state.uri.path == '/signup' || 
        state.uri.path == '/reset-password' || 
        state.uri.path == '/unauthorized';

    // Password recovery: benarkan akses ke /reset-password tanpa redirect ke /home atau /login
    if (state.uri.path == '/reset-password') {
      return null;
    }

    // Not logged in — send to login (unless already going there)
    if (user == null) {
      return isGoingToAuth ? null : '/login';
    }

    // Logged in and going to auth screen — redirect to home
    if (state.uri.path == '/login' || state.uri.path == '/signup') {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _AppShell(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const _AppShell(initialTab: 0),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const _AppShell(initialTab: 1),
    ),
    GoRoute(
      path: '/pos',
      builder: (context, state) => const _AppShell(initialTab: 2),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const _AppShell(initialTab: 3),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const _AppShell(initialTab: 4),
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
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: '/unauthorized',
      builder: (context, state) => const _UnauthorizedScreen(),
    ),
    GoRoute(
      path: '/business-profile',
      builder: (context, state) => const BusinessProfilePage(),
    ),
    GoRoute(
      path: '/product-catalogue',
      builder: (context, state) => const ProductCataloguePage(),
    ),
    GoRoute(
      path: '/staff-management',
      builder: (context, state) => const StaffManagementPage(),
    ),
    GoRoute(
      path: '/appointments',
      builder: (context, state) => const AppointmentsPage(),
    ),
    GoRoute(
      path: '/customer-reviews',
      builder: (context, state) => const CustomerReviewsPage(),
    ),
    GoRoute(
      path: '/promotions',
      builder: (context, state) => const PromotionsPage(),
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const InventoryPage(),
    ),
    GoRoute(
      path: '/operating-hours',
      builder: (context, state) => const OperatingHoursPage(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomerInsightsPage(),
    ),
    GoRoute(
      path: '/payouts',
      builder: (context, state) => const PayoutsPage(),
    ),
    GoRoute(
      path: '/qr-generator',
      builder: (context, state) => const QrGeneratorPage(),
    ),
    GoRoute(
      path: '/receipt-settings',
      builder: (context, state) => const ReceiptSettingsPage(),
    ),
    GoRoute(
      path: '/cash-drawer',
      builder: (context, state) => const CashDrawerPage(),
    ),
    GoRoute(
      path: '/merchant-inbox',
      builder: (context, state) => const MerchantInboxPage(),
    ),
    GoRoute(
      path: '/kds',
      builder: (context, state) => const KdsPage(),
    ),
    GoRoute(
      path: '/subscription-plans',
      builder: (context, state) => const SubscriptionPlansPage(),
    ),
    GoRoute(
      path: '/queue',
      builder: (context, state) => const QueuePage(),
    ),
    GoRoute(
      path: '/queue/tv',
      builder: (context, state) => const QueueTvDisplayPage(),
    ),
    GoRoute(
      path: '/payroll',
      builder: (context, state) => const PayrollManagementPage(),
    ),
    GoRoute(
      path: '/loyalty',
      builder: (context, state) => const LoyaltyStampsPage(),
    ),
    GoRoute(
      path: '/mfa-setup',
      builder: (context, state) => const MfaSetupPage(),
    ),
    GoRoute(
      path: '/audit-logs',
      builder: (context, state) => const AuditLogsPage(),
    ),
    GoRoute(
      path: '/feed-studio',
      builder: (context, state) => const FeedManagementPage(),
    ),
  ],
);
