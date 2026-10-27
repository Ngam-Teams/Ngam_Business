import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/glass_toast.dart';
import '../../../widgets/stat_card.dart';
import '../../../core/utils/file_saver/file_saver.dart';
import '../../analytics/data/analytics_service.dart';
import '../../orders/data/orders_service.dart';
import '../../settings/data/business_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/ngam_teams_service.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final AnalyticsService _analytics = AnalyticsService();
  final BusinessService _businessService = BusinessService();

  Map<String, dynamic>? _businessProfile;
  bool _loadingBusiness = true;
  late Future<Map<String, dynamic>> _overviewFuture;
  String? _lastLoadedBusinessId;

  @override
  void initState() {
    super.initState();
    _businessProfile = BusinessService.cachedProfile;
    _loadingBusiness = _businessProfile == null;
    _lastLoadedBusinessId = _businessProfile?['id']?.toString();
    _overviewFuture = _analytics.fetchOverviewStats();

    BusinessService.profileNotifier.addListener(_onProfileUpdated);
    _loadBusinessProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          AppUpdateService.checkOnStartup(context);
        }
      });
    });
  }

  void _onProfileUpdated() {
    if (mounted) {
      final updatedProfile = BusinessService.profileNotifier.value;
      final newId = updatedProfile?['id']?.toString();
      final bool idChanged = newId != null && newId != _lastLoadedBusinessId;

      setState(() {
        _businessProfile = updatedProfile;
        if (_businessProfile != null) {
          _loadingBusiness = false;
        }
        if (idChanged) {
          _lastLoadedBusinessId = newId;
          _overviewFuture = _analytics.fetchOverviewStats(forceRefresh: true);
        }
      });
    }
  }

  @override
  void dispose() {
    BusinessService.profileNotifier.removeListener(_onProfileUpdated);
    super.dispose();
  }

  Future<void> _loadBusinessProfile() async {
    final profile = await _businessService.getBusinessProfile();
    if (mounted) {
      final newId = profile?['id']?.toString();
      final bool idChanged = newId != null && newId != _lastLoadedBusinessId;

      setState(() {
        _businessProfile = profile;
        _loadingBusiness = false;
        if (idChanged) {
          _lastLoadedBusinessId = newId;
          _overviewFuture = _analytics.fetchOverviewStats(forceRefresh: true);
        }
      });
    }
  }

  static const _activities = [
    (
      time: 'Just now',
      event: 'Order #2041 completed — RM 32.00',
      icon: HugeIcons.strokeRoundedShoppingBag01,
      color: Color(0xFF42A5F5),
    ),
    (
      time: '12 min ago',
      event: 'New product added: Laksa',
      icon: HugeIcons.strokeRoundedAdd01,
      color: Color(0xFF44CF6C),
    ),
    (
      time: '1h ago',
      event: 'Order #2040 completed — RM 18.50',
      icon: HugeIcons.strokeRoundedShoppingBag01,
      color: Color(0xFF42A5F5),
    ),
    (
      time: '2h ago',
      event: 'Stock updated: Nasi Lemak (50 units)',
      icon: HugeIcons.strokeRoundedPackageDelivered,
      color: Color(0xFF42A5F5),
    ),
    (
      time: '3h ago',
      event: 'Order #2039 completed — RM 24.00',
      icon: HugeIcons.strokeRoundedShoppingBag01,
      color: Color(0xFF42A5F5),
    ),
    (
      time: '4h ago',
      event: 'Customer review received: 5.0 ⭐',
      icon: HugeIcons.strokeRoundedStar,
      color: Color(0xFFFFA726),
    ),
    (
      time: '5h ago',
      event: 'Order #2038 completed — RM 45.00',
      icon: HugeIcons.strokeRoundedShoppingBag01,
      color: Color(0xFF42A5F5),
    ),
    (
      time: '6h ago',
      event: 'Payout settlement RM 380.00 processed',
      icon: HugeIcons.strokeRoundedCoins01,
      color: Color(0xFF10B981),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? AnalyticsService.cachedOverviewStats;
        final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

        final double todayRev = (data?['todayRevenue'] as num?)?.toDouble() ?? 0.0;
        final int todayOrders = (data?['todayOrders'] as num?)?.toInt() ?? 0;
        final int pendingOrders = (data?['pendingOrders'] as num?)?.toInt() ?? 0;
        final double monthlyRev = (data?['monthlyRevenue'] as num?)?.toDouble() ?? 0.0;

        final loading = (snapshot.connectionState == ConnectionState.waiting) && data == null;

        final cards = [
          StatCard(
            label: "Today's Revenue",
            value: fmt.format(todayRev),
            isLoading: loading,
            subtitle: '↑ Today',
            badgeColor: const Color(0xFF44CF6C),
            icon: HugeIcons.strokeRoundedMoney01,
            accentColor: const Color(0xFF42A5F5),
            onTap: () => context.push('/analytics'),
          ),
          StatCard(
            label: "Today's Orders",
            value: todayOrders.toString(),
            isLoading: loading,
            subtitle: 'Orders',
            badgeColor: const Color(0xFF42A5F5),
            icon: HugeIcons.strokeRoundedShoppingBag01,
            accentColor: const Color(0xFF44CF6C),
            onTap: () => context.push('/orders'),
          ),
          StatCard(
            label: 'Pending Orders',
            value: pendingOrders.toString(),
            isLoading: loading,
            subtitle: pendingOrders > 0 ? '$pendingOrders Action' : 'Cleared',
            badgeColor: pendingOrders > 0 ? const Color(0xFFF9C80E) : const Color(0xFF44CF6C),
            icon: HugeIcons.strokeRoundedTime02,
            accentColor: const Color(0xFFF9C80E),
            onTap: () => context.push('/orders'),
          ),
          StatCard(
            label: 'Monthly Revenue',
            value: fmt.format(monthlyRev),
            isLoading: loading,
            subtitle: 'This Month',
            badgeColor: const Color(0xFF8B5CF6),
            icon: HugeIcons.strokeRoundedChartIncrease,
            accentColor: const Color(0xFF8B5CF6),
            onTap: () => context.push('/analytics'),
          ),
        ];

        final hasLocation = _businessProfile?['latitude'] != null && _businessProfile?['longitude'] != null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            // Detect landscape or sufficiently wide window
            final isLandscape = (width > height) ||
                (MediaQuery.orientationOf(context) == Orientation.landscape) ||
                (width >= 620);

            final showBanner = !_loadingBusiness &&
                (!hasLocation || (_businessProfile?['address_line'] ?? '').isEmpty);

            // In landscape or wide screens: ALWAYS keep Recent Activity & Quick Actions SIDE-BY-SIDE!
            if (isLandscape) {
              // Full-viewport non-scrolling layout when height is sufficient
              if (height >= 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBanner) _buildProfileIncompleteBanner(context),
                    _buildStatCards(cards, width, isLandscape: true),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: width < 900 ? 5 : 2,
                            child: _buildRecentActivity(isDesktop: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: width < 900 ? 7 : 3,
                            child: _buildQuickActions(context, isDesktop: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Ultra-short landscape screen (< 360px height)
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBanner) _buildProfileIncompleteBanner(context),
                    _buildStatCards(cards, width, isLandscape: true),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: width < 900 ? 5 : 2,
                            child: _buildRecentActivity(isDesktop: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: width < 900 ? 7 : 3,
                            child: _buildQuickActions(context, isDesktop: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile portrait layout (vertical phone) with Pull-to-Refresh
            return RefreshIndicator(
              onRefresh: () async {
                final f = _analytics.fetchOverviewStats(forceRefresh: true);
                setState(() {
                  _overviewFuture = f;
                });
                await f;
              },
              color: const Color(0xFF42A5F5),
              backgroundColor: const Color(0xFF141424),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBanner) _buildProfileIncompleteBanner(context),
                    _buildStatCards(cards, width, isLandscape: false),
                    const SizedBox(height: 16),
                    _buildRecentActivity(isDesktop: false),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, isDesktop: false),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileIncompleteBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF9C80E).withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF9C80E).withValues(alpha: 0.4),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 450;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9C80E).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        color: Color(0xFFF9C80E),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Set Up Store Location & Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pin your entrance on the map and add street address so customers can discover you on Ngam Explore.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await context.push('/business-profile');
                      _loadBusinessProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9C80E),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: const Text(
                      'Add Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9C80E).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  color: Color(0xFFF9C80E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Up Your Store Location & Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pin your entrance on the map and add street address so customers can discover you on Ngam Explore.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await context.push('/business-profile');
                  _loadBusinessProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9C80E),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text(
                  'Add Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCards(List<Widget> cards, double width, {bool isLandscape = false}) {
    if (width >= 700 || isLandscape) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
            const SizedBox(width: 10),
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 10),
                Expanded(child: cards[3]),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildRecentActivity({bool isDesktop = false}) {
    return _buildPanel(
      title: 'Recent Activity',
      icon: HugeIcons.strokeRoundedActivity01,
      expand: isDesktop,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF44CF6C).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF44CF6C).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF44CF6C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Live Feed',
              style: TextStyle(
                color: Color(0xFF44CF6C),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: isDesktop
          ? Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: _activities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _buildActivityItem(_activities[i]),
              ),
            )
          : Column(
              children: _activities
                  .map(
                    (act) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildActivityItem(act),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildActivityItem(({Color color, String event, dynamic icon, String time}) act) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: act.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(
            icon: act.icon,
            color: act.color,
            size: 16,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                act.event,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                act.time,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, {bool isDesktop = false}) {
    final actions = [
      (
        label: 'Smart Queue\n& TV Display',
        icon: HugeIcons.strokeRoundedTv01,
        color: const Color(0xFF6C5CE7),
        onTap: () => context.push('/queue'),
      ),
      (
        label: 'Payroll &\nKomisen Staf',
        icon: HugeIcons.strokeRoundedCoins01,
        color: const Color(0xFF10B981),
        onTap: () => context.push('/payroll'),
      ),
      (
        label: 'Kad Cop Digital\n(Loyalty)',
        icon: HugeIcons.strokeRoundedAward01,
        color: const Color(0xFFF59E0B),
        onTap: () => context.push('/loyalty'),
      ),
      (
        label: 'Bookings &\nSlots',
        icon: HugeIcons.strokeRoundedCalendar01,
        color: const Color(0xFF42A5F5),
        onTap: () => context.push('/appointments'),
      ),
      (
        label: 'Inventory &\nStock Alerts',
        icon: HugeIcons.strokeRoundedPackageDelivered,
        color: const Color(0xFFF9C80E),
        onTap: () => context.push('/inventory'),
      ),
      (
        label: 'Feed & Post\nStudio',
        icon: HugeIcons.strokeRoundedVideo01,
        color: const Color(0xFFEC4899),
        onTap: () => context.push('/feed-studio'),
      ),
      (
        label: 'Promotions &\nVouchers',
        icon: HugeIcons.strokeRoundedDiscountTag02,
        color: const Color(0xFF44CF6C),
        onTap: () => context.push('/promotions'),
      ),
      (
        label: 'Customer\nReviews',
        icon: HugeIcons.strokeRoundedStar,
        color: const Color(0xFFFFA726),
        onTap: () => context.push('/customer-reviews'),
      ),
      (
        label: 'Hours &\nRush Mode',
        icon: HugeIcons.strokeRoundedTime02,
        color: const Color(0xFF26C6DA),
        onTap: () => context.push('/operating-hours'),
      ),
      (
        label: 'Customer VIPs\n& Insights',
        icon: HugeIcons.strokeRoundedUserGroup,
        color: const Color(0xFFAB47BC),
        onTap: () => context.push('/customers'),
      ),
      (
        label: 'Items &\nServices',
        icon: HugeIcons.strokeRoundedGridView,
        color: const Color(0xFF44CF6C),
        onTap: () => context.push('/product-catalogue'),
      ),
      (
        label: 'Business Details\n& Map Pin',
        icon: HugeIcons.strokeRoundedStore01,
        color: const Color(0xFF42A5F5),
        onTap: () async {
          await context.push('/business-profile');
          _loadBusinessProfile();
        },
      ),
      (
        label: 'Payouts &\nSettlement',
        icon: HugeIcons.strokeRoundedMoneySend02,
        color: const Color(0xFF10B981),
        onTap: () => context.push('/payouts'),
      ),
      (
        label: 'Live Order\nBoard',
        icon: HugeIcons.strokeRoundedTv01,
        color: const Color(0xFFF9C80E),
        onTap: () => context.push('/kds'),
      ),
      (
        label: 'Customer Inbox\n& Chat',
        icon: HugeIcons.strokeRoundedChatting01,
        color: const Color(0xFF42A5F5),
        onTap: () => context.push('/merchant-inbox'),
      ),
      (
        label: 'QR & Standee\nGenerator',
        icon: HugeIcons.strokeRoundedQrCode,
        color: const Color(0xFF6C5CE7),
        onTap: () => context.push('/qr-generator'),
      ),
      (
        label: 'Cash Drawer\n& Z-Report',
        icon: HugeIcons.strokeRoundedMoney01,
        color: const Color(0xFF26C6DA),
        onTap: () => context.push('/cash-drawer'),
      ),
      (
        label: 'Receipts &\nPrinter',
        icon: HugeIcons.strokeRoundedPrinter,
        color: const Color(0xFFEC4899),
        onTap: () => context.push('/receipt-settings'),
      ),
      (
        label: 'Ngam Teams\n& Pasukan',
        icon: HugeIcons.strokeRoundedUserGroup,
        color: const Color(0xFFE5B9FF),
        onTap: () => NgamTeamsService.showTeamsHubModal(
          context,
          businessName: (_businessProfile?['business_name'] ?? BusinessService.cachedProfile?['business_name']) as String?,
        ),
      ),
      (
        label: 'WhatsApp\nMarketing',
        icon: HugeIcons.strokeRoundedWhatsapp,
        color: const Color(0xFF25D366),
        onTap: () => _openWhatsAppMarketing(context),
      ),
      (
        label: 'Eksport\nLaporan (Z)',
        icon: HugeIcons.strokeRoundedDownload04,
        color: const Color(0xFFF9C80E),
        onTap: () => _openDailyReportExport(context),
      ),
      (
        label: 'Pusat Bantuan\n(Akan Datang)',
        icon: HugeIcons.strokeRoundedShield01,
        color: const Color(0xFF818CF8),
        onTap: () => showGlassToast(context, 'Pusat Bantuan akan hadir tidak lama lagi.'),
      ),
      (
        label: 'Log Audit\n(Akan Datang)',
        icon: HugeIcons.strokeRoundedClock01,
        color: const Color(0xFF38BDF8),
        onTap: () => showGlassToast(context, 'Log Aktiviti & Audit akan hadir tidak lama lagi.'),
      ),
      (
        label: 'Custom Tool\n(Akan Datang)',
        icon: HugeIcons.strokeRoundedSparkles,
        color: const Color(0xFFA78BFA),
        onTap: () => showGlassToast(context, 'Fungsi ini akan ditambah tidak lama lagi.'),
      ),
    ];

    return _buildPanel(
      title: 'Quick Actions',
      icon: HugeIcons.strokeRoundedZap,
      expand: isDesktop,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          '${actions.length} Tools',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final availableWidth = constraints.maxWidth;

          // Desktop: 6 columns x 4 rows = 24 buttons!
          // Narrow / Mobile: 3 columns (8 rows) or Tablet: 4 columns (6 rows)
          final isDesktopGrid = isDesktop && availableWidth >= 440;
          final crossAxisCount = isDesktopGrid ? 6 : (availableWidth < 420 ? 3 : 4);
          final rowCount = (actions.length / crossAxisCount).ceil();

          const crossAxisSpacing = 8.0;
          const mainAxisSpacing = 8.0;
          const minCardHeight = 74.0;

          double cardHeight = 84.0;
          ScrollPhysics physics = const NeverScrollableScrollPhysics();

          if (isDesktop && availableHeight.isFinite && availableHeight > 0) {
            final totalVerticalSpacing = (rowCount - 1) * mainAxisSpacing;
            final dynamicHeight = (availableHeight - totalVerticalSpacing) / rowCount;

            if (dynamicHeight >= minCardHeight) {
              cardHeight = dynamicHeight;
              physics = const NeverScrollableScrollPhysics();
            } else {
              cardHeight = minCardHeight;
              physics = const BouncingScrollPhysics();
            }
          }

          final bool canScroll = isDesktop && (physics is! NeverScrollableScrollPhysics);

          final grid = GridView.builder(
            padding: EdgeInsets.zero,
            physics: isDesktop ? physics : const NeverScrollableScrollPhysics(),
            shrinkWrap: !isDesktop,
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisExtent: cardHeight,
            ),
            itemBuilder: (context, i) {
              final a = actions[i];
              return _QuickActionButton(
                label: a.label,
                icon: a.icon,
                color: a.color,
                onTap: a.onTap,
                cardHeight: cardHeight,
              );
            },
          );

          if (canScroll) {
            return Scrollbar(
              thumbVisibility: true,
              child: grid,
            );
          }
          return grid;
        },
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required dynamic icon,
    required Widget child,
    Widget? trailing,
    bool expand = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: expand ? double.infinity : null,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: icon,
                      color: const Color(0xFF42A5F5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing,
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (expand)
                Expanded(child: child)
              else
                child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String label, int index, int selectedIdx, VoidCallback onTap) {
    final isSel = index == selectedIdx;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF25D366).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? const Color(0xFF25D366) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? const Color(0xFF25D366) : Colors.white70,
            fontSize: 11,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _openWhatsAppMarketing(BuildContext context) {
    final profile = _businessProfile ?? BusinessService.cachedProfile;
    final storeName = (profile?['business_name'] ?? profile?['name'] ?? profile?['title'] ?? 'Kedai Kami').toString().trim();
    final handle = (profile?['business_handle'] as String?)?.trim() ?? '';
    final storeLink = handle.isNotEmpty ? 'https://ngam.dev/@$handle' : 'https://ngam.dev';

    final templates = [
      '🎉 Promosi Istimewa Hujung Minggu!\nJom nikmati hidangan lazat di $storeName hari ini! Kumpul cop ganjaran digital untuk setiap pembelian.\n\nLihat menu & pesan terus di sini:\n$storeLink',
      '🔥 Menu Panas & Menarik!\nAda menu istimewa menanti anda di $storeName hari ini. Disediakan segar setiap masa!\n\nPesan awal untuk elak beratur:\n$storeLink',
      '🏷️ Baucar Ganjaran Khas!\nTerima kasih kerana setia bersama $storeName. Dapatkan tawaran diskaun menarik untuk pesanan anda!\n\nSemak promosi terkini di sini:\n$storeLink',
    ];

    int selectedIdx = 0;
    final textCtrl = TextEditingController(text: templates[0]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedWhatsapp,
                          color: Color(0xFF25D366),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WhatsApp Marketing Broadcast',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Hantar promosi & pautan kedai ke pelanggan dengan 1 klik',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Pilih Templat Promosi:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTemplateChip('Promosi', 0, selectedIdx, () {
                        setModalState(() {
                          selectedIdx = 0;
                          textCtrl.text = templates[0];
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildTemplateChip('Menu Baru', 1, selectedIdx, () {
                        setModalState(() {
                          selectedIdx = 1;
                          textCtrl.text = templates[1];
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildTemplateChip('Ganjaran Cop', 2, selectedIdx, () {
                        setModalState(() {
                          selectedIdx = 2;
                          textCtrl.text = templates[2];
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF25D366))),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Salin Teks'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: textCtrl.text));
                            Navigator.pop(ctx);
                            showGlassToast(context, 'Teks promosi telah disalin!', color: const Color(0xFF25D366));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedWhatsapp, color: Colors.black, size: 18),
                          label: const Text('Buka WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final text = Uri.encodeComponent(textCtrl.text);
                            final url = Uri.parse('https://wa.me/?text=$text');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openDailyReportExport(BuildContext context) async {
    final profile = _businessProfile ?? BusinessService.cachedProfile;
    final storeName = (profile?['business_name'] ?? profile?['name'] ?? profile?['title'] ?? 'Kedai Kami').toString().trim();
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final dateStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<OrderModel>>(
          future: OrdersService().fetchOrders(),
          builder: (context, snapshot) {
            final orders = snapshot.data ?? [];
            final today = DateTime.now();
            final todayOrders = orders.where((o) =>
                o.createdAt.year == today.year &&
                o.createdAt.month == today.month &&
                o.createdAt.day == today.day).toList();

            final totalRev = todayOrders
                .where((o) => o.status != 'cancelled')
                .fold<double>(0.0, (sum, o) => sum + o.total);
            final completedCount = todayOrders.where((o) => o.status == 'completed').length;
            final pendingCount = todayOrders.where((o) => o.status == 'pending').length;

            return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9C80E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedDownload04,
                          color: Color(0xFFF9C80E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ringkasan Jualan Harian (Z-Reading)',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$storeName • $dateStr',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jumlah Jualan Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(fmt.format(totalRev), style: const TextStyle(color: Color(0xFF44CF6C), fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 20, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jumlah Pesanan', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('${todayOrders.length} Pesanan', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Selesai / Menunggu', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text('$completedCount Selesai • $pendingCount Menunggu', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Salin Ringkasan'),
                          onPressed: () {
                            final reportText = '''
📊 RINGKASAN JUALAN (Z-REPORT)
🏪 Kedai: $storeName
📅 Tarikh: $dateStr
💰 Jumlah Jualan: ${fmt.format(totalRev)}
📦 Jumlah Pesanan: ${todayOrders.length}
✅ Selesai: $completedCount
⏳ Menunggu: $pendingCount
— Dijana oleh Ngam Business
''';
                            Clipboard.setData(ClipboardData(text: reportText));
                            Navigator.pop(ctx);
                            showGlassToast(context, 'Ringkasan Z-Report telah disalin!');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF9C80E),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Eksport CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final buffer = StringBuffer();
                            buffer.writeln('ID_Pesanan,Tarikh,Pelanggan,Jumlah_RM,Status,Sumber');
                            for (final o in todayOrders) {
                              buffer.writeln('${o.id},${o.createdAt.toIso8601String()},${o.customerName ?? "Pelanggan"},${o.total.toStringAsFixed(2)},${o.status},${o.source}');
                            }
                            final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
                            final safeDate = DateFormat('yyyy-MM-dd').format(today);
                            await downloadStandeeImage(bytes: bytes, fileName: 'Z_Report_$safeDate.csv');
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              showGlassToast(context, 'Fail CSV berjaya dimuat turun!');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final double cardHeight;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.cardHeight,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSpacious = widget.cardHeight >= 92;
    final iconBoxSize = isSpacious ? 32.0 : 26.0;
    final iconSize = isSpacious ? 17.0 : 14.0;
    final fontSize = isSpacious ? 11.0 : (widget.cardHeight >= 82 ? 10.5 : 9.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(
                alpha: _isHovered ? 0.08 : 0.04,
              ),
              border: Border.all(
                color: _isHovered
                    ? widget.color.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(isSpacious ? 9 : 7),
                  ),
                  child: Center(
                    child: widget.icon is IconData
                        ? Icon(
                            widget.icon as IconData,
                            color: widget.color,
                            size: iconSize,
                          )
                        : HugeIcon(
                            icon: widget.icon,
                            color: widget.color,
                            size: iconSize,
                            strokeWidth: 2.1,
                          ),
                  ),
                ),
                SizedBox(height: isSpacious ? 6 : 4),
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
