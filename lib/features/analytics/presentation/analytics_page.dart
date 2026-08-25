import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../data/analytics_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _service = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue summary panel
          FutureBuilder<Map<String, dynamic>>(
            future: _service.fetchOverviewStats(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final fmt =
                  NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final summaryCards = [
                    _SummaryCard(
                      label: "Today's Revenue",
                      value: loading
                          ? '...'
                          : fmt.format(data?['todayRevenue'] ?? 0.0),
                      color: const Color(0xFF42A5F5),
                      icon: HugeIcons.strokeRoundedMoney01,
                    ),
                    _SummaryCard(
                      label: 'Monthly Revenue',
                      value: loading
                          ? '...'
                          : fmt.format(data?['monthlyRevenue'] ?? 0.0),
                      color: const Color(0xFF42A5F5),
                      icon: HugeIcons.strokeRoundedChartIncrease,
                    ),
                    _SummaryCard(
                      label: "Today's Orders",
                      value: loading
                          ? '...'
                          : (data?['todayOrders'] ?? 0).toString(),
                      color: const Color(0xFF44CF6C),
                      icon: HugeIcons.strokeRoundedShoppingBag01,
                    ),
                    _SummaryCard(
                      label: 'Avg Order Value',
                      value: loading
                          ? '...'
                          : fmt.format(data?['avgOrderValue'] ?? 0.0),
                      color: const Color(0xFFF9C80E),
                      icon: HugeIcons.strokeRoundedReceiptText,
                    ),
                  ];

                  if (width >= 800) {
                    return Row(
                      children: summaryCards
                          .asMap()
                          .entries
                          .map((e) => Expanded(
                                child: Padding(
                                  padding:
                                      EdgeInsets.only(left: e.key == 0 ? 0 : 16),
                                  child: e.value,
                                ),
                              ))
                          .toList(),
                    );
                  }
                  // For mobile, use a 2x2 grid (two rows of two Expanded items)
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: summaryCards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: summaryCards[1]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: summaryCards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: summaryCards[3]),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),

          // Top products panel
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _service.fetchTopProducts(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;

              return _buildPanel(
                title: 'Top Selling Products',
                icon: HugeIcons.strokeRoundedAward01,
                child: loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: Color(0xFF42A5F5),
                          ),
                        ),
                      )
                    : products.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No data yet',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: products
                                .asMap()
                                .entries
                                .map((e) => _buildProductRow(
                                      e.key + 1,
                                      e.value['product_name'] as String? ??
                                          'Unknown',
                                      (e.value['quantity'] as num?)
                                              ?.toInt() ??
                                          0,
                                      products
                                          .map((p) =>
                                              (p['quantity'] as num?)
                                                  ?.toInt() ??
                                              0)
                                          .reduce((a, b) => a > b ? a : b),
                                    ))
                                .toList(),
                          ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Placeholder chart area
          _buildPanel(
            title: 'Revenue Trend (Last 7 Days)',
            icon: HugeIcons.strokeRoundedAnalytics01,
            child: _buildRevenueChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(
    int rank,
    String name,
    int qty,
    int maxQty,
  ) {
    final progress = maxQty > 0 ? qty / maxQty : 0.0;
    final colors = [
      const Color(0xFF42A5F5),
      const Color(0xFF42A5F5),
      const Color(0xFF44CF6C),
      const Color(0xFFF9C80E),
      const Color(0xFFFF6B6B),
    ];
    final color = colors[(rank - 1) % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$qty sold',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    // Placeholder bars showing a simulated weekly trend
    final mockData = [42.0, 85.0, 60.0, 95.0, 72.0, 110.0, 88.0];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = mockData.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(mockData.length, (i) {
          final heightFraction = mockData[i] / maxVal;
          final isToday = i == 6;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 60),
                    curve: Curves.easeOutCubic,
                    height: 120 * heightFraction,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isToday
                            ? [
                                const Color(0xFF42A5F5),
                                const Color(0xFF42A5F5),
                              ]
                            : [
                                const Color(0xFF42A5F5)
                                    .withValues(alpha: 0.5),
                                const Color(0xFF42A5F5)
                                    .withValues(alpha: 0.2),
                              ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[i],
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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
                      color:
                          const Color(0xFF42A5F5).withValues(alpha: 0.15),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final dynamic icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: color, size: 22, strokeWidth: 2.1),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
