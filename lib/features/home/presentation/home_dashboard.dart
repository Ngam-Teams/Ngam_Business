import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../widgets/stat_card.dart';
import '../../analytics/data/analytics_service.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final AnalyticsService _analytics = AnalyticsService();

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

        final loading = snapshot.connectionState == ConnectionState.waiting;

        final cards = [
          StatCard(
            label: "Today's Revenue",
            value: loading ? '...' : fmt.format(todayRev),
            subtitle: 'Today',
            icon: HugeIcons.strokeRoundedMoney01,
            accentColor: const Color(0xFF42A5F5),
          ),
          StatCard(
            label: "Today's Orders",
            value: loading ? '...' : todayOrders.toString(),
            icon: HugeIcons.strokeRoundedShoppingBag01,
            accentColor: const Color(0xFF42A5F5),
          ),
          StatCard(
            label: 'Pending Orders',
            value: loading ? '...' : (data?['pendingOrders'] ?? 0).toString(),
            icon: HugeIcons.strokeRoundedTime02,
            accentColor: const Color(0xFFF9C80E),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat cards grid
                  _buildStatCards(cards, width),
                  const SizedBox(height: 28),

                  // Lower panels
                  if (width >= 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildRecentActivity()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildQuickActions(context)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildRecentActivity(),
                        const SizedBox(height: 24),
                        _buildQuickActions(context),
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

  Widget _buildStatCards(List<Widget> cards, double width) {
    if (width >= 900) {
      return Row(
        children: cards
            .asMap()
            .entries
            .map(
              (e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: e.key == 0 ? 0 : 16),
                  child: e.value,
                ),
              ),
            )
            .toList(),
      );
    } else {
      // Stack cards vertically for mobile
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: c,
                  ),
                ))
            .toList(),
      );
    }
  }

  Widget _buildRecentActivity() {
    return _buildPanel(
      title: 'Recent Activity',
      icon: HugeIcons.strokeRoundedClock01,
      child: Column(
        children: _activities
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: a.icon,
                        color: a.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.event,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.time,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (
        label: 'New Order',
        icon: HugeIcons.strokeRoundedAdd01,
        color: const Color(0xFF42A5F5),
      ),
      (
        label: 'Add Product',
        icon: HugeIcons.strokeRoundedGridView,
        color: const Color(0xFF42A5F5),
      ),
      (
        label: 'View Reports',
        icon: HugeIcons.strokeRoundedChartIncrease,
        color: const Color(0xFF44CF6C),
      ),
    ];

    return _buildPanel(
      title: 'Quick Actions',
      icon: HugeIcons.strokeRoundedZap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: a.icon,
                          color: a.color,
                          size: 18,
                          strokeWidth: 2.1,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          a.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required dynamic icon,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
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
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
