import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../widgets/stat_card.dart';
import '../../analytics/data/analytics_service.dart';
import '../../settings/data/business_service.dart';
import '../../../core/services/app_update_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          AppUpdateService.checkOnStartup(context);
        }
      });
    });
  }

  Future<void> _loadBusinessProfile() async {
    final profile = await _businessService.getBusinessProfile();
    if (mounted) {
      setState(() {
        _businessProfile = profile;
        _loadingBusiness = false;
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
      future: _analytics.fetchOverviewStats(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

        final double todayRev = (data?['todayRevenue'] as num?)?.toDouble() ?? 0.0;
        final int todayOrders = (data?['todayOrders'] as num?)?.toInt() ?? 0;
        final int pendingOrders = (data?['pendingOrders'] as num?)?.toInt() ?? 0;
        final double monthlyRev = (data?['monthlyRevenue'] as num?)?.toDouble() ?? 0.0;

        final loading = snapshot.connectionState == ConnectionState.waiting;

        final cards = [
          StatCard(
            label: "Today's Revenue",
            value: loading ? '...' : fmt.format(todayRev),
            subtitle: '↑ Today',
            badgeColor: const Color(0xFF44CF6C),
            icon: HugeIcons.strokeRoundedMoney01,
            accentColor: const Color(0xFF42A5F5),
            onTap: () => context.push('/analytics'),
          ),
          StatCard(
            label: "Today's Orders",
            value: loading ? '...' : todayOrders.toString(),
            subtitle: 'Orders',
            badgeColor: const Color(0xFF42A5F5),
            icon: HugeIcons.strokeRoundedShoppingBag01,
            accentColor: const Color(0xFF44CF6C),
            onTap: () => context.push('/orders'),
          ),
          StatCard(
            label: 'Pending Orders',
            value: loading ? '...' : pendingOrders.toString(),
            subtitle: pendingOrders > 0 ? '$pendingOrders Action' : 'Cleared',
            badgeColor: pendingOrders > 0 ? const Color(0xFFF9C80E) : const Color(0xFF44CF6C),
            icon: HugeIcons.strokeRoundedTime02,
            accentColor: const Color(0xFFF9C80E),
            onTap: () => context.push('/orders'),
          ),
          StatCard(
            label: 'Monthly Revenue',
            value: loading ? '...' : fmt.format(monthlyRev),
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
            final isDesktop = width >= 900;
            final bottomPad = isDesktop ? 24.0 : 100.0;

            final showBanner = !_loadingBusiness && (!hasLocation || (_businessProfile?['address_line'] ?? '').isEmpty);
            // Approx upper section height on desktop (banner + stats + spacing)
            final topSectionHeight = (showBanner ? 92.0 : 0.0) + 115.0 + 20.0;
            const minPanelHeight = 350.0;
            final availableForPanels = constraints.maxHeight - (topSectionHeight + bottomPad);
            final panelHeight = availableForPanels > minPanelHeight ? availableForPanels : minPanelHeight;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Profile Setup Reminder if location or details missing
                  if (showBanner)
                    _buildProfileIncompleteBanner(context),

                  // Stat cards grid
                  _buildStatCards(cards, width),
                  const SizedBox(height: 20),

                  // Lower panels (Recent 1:3, Quick Actions 2:3)
                  if (isDesktop)
                    SizedBox(
                      height: panelHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 1, child: _buildRecentActivity(isDesktop: true)),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: _buildQuickActions(context, isDesktop: true)),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildRecentActivity(isDesktop: false),
                        const SizedBox(height: 20),
                        _buildQuickActions(context, isDesktop: false),
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

  Widget _buildStatCards(List<Widget> cards, double width) {
    if (width >= 800) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
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
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
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
          ? ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: _activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _buildActivityItem(_activities[i]),
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
        label: 'Kitchen Display\n(KDS)',
        icon: HugeIcons.strokeRoundedRestaurant01,
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
        label: 'Staff\nManagement',
        icon: HugeIcons.strokeRoundedUserGroup,
        color: const Color(0xFFE5B9FF),
        onTap: () => context.push('/staff-management'),
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
        child: const Text(
          '18 Tools',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrowPhone = constraints.maxWidth < 420;
          final crossAxisCount = isNarrowPhone ? 3 : 6;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 80,
            ),
            itemBuilder: (context, i) {
              final a = actions[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: a.icon,
                              color: a.color,
                              size: 15,
                              strokeWidth: 2.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          a.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
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
}
