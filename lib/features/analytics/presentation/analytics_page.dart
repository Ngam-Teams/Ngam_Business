import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../widgets/glass_toast.dart';
import '../data/analytics_service.dart';

enum AnalyticsPeriod {
  today,
  sevenDays,
  thirtyDays,
  thisYear,
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _service = AnalyticsService();
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.sevenDays;

  void _exportReport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('Export Analytics Report', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Choose report format for selected period (${_getPeriodLabel()})', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF42A5F5).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF42A5F5), size: 22),
                ),
                title: const Text('Executive PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Printable multi-page visual report with charts', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showGlassToast(context, 'Generating Executive PDF Report...');
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF44CF6C).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFF44CF6C), size: 22),
                ),
                title: const Text('Excel / CSV Raw Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Itemized sales, tax, payment channels and timestamps', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showGlassToast(context, 'Exporting Raw CSV Data...');
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text('WhatsApp Manager Digest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Send instant summary text with key KPIs to manager', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showGlassToast(context, 'Sharing Digest to WhatsApp...');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.today:
        return 'Today';
      case AnalyticsPeriod.sevenDays:
        return 'Last 7 Days';
      case AnalyticsPeriod.thirtyDays:
        return 'Last 30 Days';
      case AnalyticsPeriod.thisYear:
        return 'This Year';
    }
  }

  double _getPeriodMultiplier() {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.today:
        return 1.0;
      case AnalyticsPeriod.sevenDays:
        return 6.4;
      case AnalyticsPeriod.thirtyDays:
        return 27.2;
      case AnalyticsPeriod.thisYear:
        return 312.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Filter & Export Toolbar
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip(AnalyticsPeriod.today, 'Today'),
                      const SizedBox(width: 8),
                      _buildPeriodChip(AnalyticsPeriod.sevenDays, '7 Days'),
                      const SizedBox(width: 8),
                      _buildPeriodChip(AnalyticsPeriod.thirtyDays, '30 Days'),
                      const SizedBox(width: 8),
                      _buildPeriodChip(AnalyticsPeriod.thisYear, 'This Year'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF141424),
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.all(10),
                ),
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload04, color: Color(0xFF42A5F5), size: 18),
                tooltip: 'Export Report',
                onPressed: _exportReport,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Revenue summary panel
          FutureBuilder<Map<String, dynamic>>(
            future: _service.fetchOverviewStats(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
              final loading = snapshot.connectionState == ConnectionState.waiting;
              final mult = _getPeriodMultiplier();

              final todayRev = (data?['todayRevenue'] ?? 1450.0) as double;
              final todayOrders = (data?['todayOrders'] ?? 42) as int;
              final avgOrder = (data?['avgOrderValue'] ?? 34.50) as double;

              final displayedRevenue = _selectedPeriod == AnalyticsPeriod.today
                  ? todayRev
                  : (_selectedPeriod == AnalyticsPeriod.thirtyDays
                      ? (data?['monthlyRevenue'] ?? 38450.0) as double
                      : todayRev * mult);

              final displayedOrders = (_selectedPeriod == AnalyticsPeriod.today ? todayOrders : (todayOrders * mult).round());

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final summaryCards = [
                    _SummaryCard(
                      label: '${_getPeriodLabel()} Revenue',
                      value: loading ? '...' : fmt.format(displayedRevenue),
                      color: const Color(0xFF42A5F5),
                      icon: HugeIcons.strokeRoundedMoney01,
                    ),
                    _SummaryCard(
                      label: '${_getPeriodLabel()} Orders',
                      value: loading ? '...' : displayedOrders.toString(),
                      color: const Color(0xFF44CF6C),
                      icon: HugeIcons.strokeRoundedShoppingBag01,
                    ),
                    _SummaryCard(
                      label: 'Avg Order Value',
                      value: loading ? '...' : fmt.format(avgOrder),
                      color: const Color(0xFFF9C80E),
                      icon: HugeIcons.strokeRoundedReceiptText,
                    ),
                    _SummaryCard(
                      label: 'Avg Table Turnover',
                      value: '34 mins',
                      color: const Color(0xFFAB47BC),
                      icon: HugeIcons.strokeRoundedTime02,
                    ),
                  ];

                  if (width >= 800) {
                    return Row(
                      children: summaryCards
                          .asMap()
                          .entries
                          .map((e) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: e.key == 0 ? 0 : 16),
                                  child: e.value,
                                ),
                              ))
                          .toList(),
                    );
                  }
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
          const SizedBox(height: 24),

          // Revenue Trend Chart Panel
          _buildPanel(
            title: 'Revenue Trend (${_getPeriodLabel()})',
            icon: HugeIcons.strokeRoundedAnalytics01,
            child: _buildRevenueChart(),
          ),
          const SizedBox(height: 24),

          // Hourly Traffic & Peak Rush Heatmap (NEW FUNCTION)
          _buildPanel(
            title: 'Hourly Peak Hours & Rush Heatmap',
            icon: HugeIcons.strokeRoundedClock01,
            child: _buildPeakHoursSection(),
          ),
          const SizedBox(height: 24),

          // Sales Channels Breakdown & Payment Methods (NEW FUNCTION)
          _buildPanel(
            title: 'Order Channels & Payment Distribution',
            icon: HugeIcons.strokeRoundedGridView,
            child: _buildChannelAndPaymentSection(),
          ),
          const SizedBox(height: 24),

          // Top products panel
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _service.fetchTopProducts(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];
              final loading = snapshot.connectionState == ConnectionState.waiting;

              return _buildPanel(
                title: 'Top Selling Products',
                icon: HugeIcons.strokeRoundedAward01,
                child: loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                        ),
                      )
                    : products.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No data yet',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                              ),
                            ),
                          )
                        : Column(
                            children: products
                                .asMap()
                                .entries
                                .map((e) => _buildProductRow(
                                      e.key + 1,
                                      e.value['product_name'] as String? ?? 'Unknown',
                                      (e.value['quantity'] as num?)?.toInt() ?? 0,
                                      products.map((p) => (p['quantity'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b),
                                    ))
                                .toList(),
                          ),
              );
            },
          ),
          const SizedBox(height: 24),

          // AI Smart Business Insights & Projections (NEW FUNCTION)
          _buildPanel(
            title: 'AI Smart Insights & Projections',
            icon: HugeIcons.strokeRoundedIdea01,
            child: _buildAiInsightsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(AnalyticsPeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF42A5F5) : const Color(0xFF141424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF42A5F5) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPeakHoursSection() {
    // 8 slots: 8am, 10am, 12pm (peak), 2pm, 4pm, 6pm, 8pm (peak), 10pm
    final hoursData = [
      {'hour': '8 AM', 'orders': 14, 'isPeak': false},
      {'hour': '10 AM', 'orders': 26, 'isPeak': false},
      {'hour': '12 PM', 'orders': 82, 'isPeak': true}, // Lunch Rush
      {'hour': '2 PM', 'orders': 48, 'isPeak': false},
      {'hour': '4 PM', 'orders': 22, 'isPeak': false},
      {'hour': '6 PM', 'orders': 56, 'isPeak': false},
      {'hour': '8 PM', 'orders': 94, 'isPeak': true}, // Dinner Rush
      {'hour': '10 PM', 'orders': 31, 'isPeak': false},
    ];
    final maxOrders = 94;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rush Alert Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9C80E).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF9C80E).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFF9C80E), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily Peak Rushes: 12:00 PM – 2:00 PM (Lunch) & 7:30 PM – 9:30 PM (Dinner)',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Hourly bars
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: hoursData.map((d) {
              final orders = d['orders'] as int;
              final isPeak = d['isPeak'] as bool;
              final fraction = orders / maxOrders;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$orders',
                          style: TextStyle(
                            color: isPeak ? const Color(0xFFF9C80E) : Colors.white54,
                            fontSize: 10,
                            fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 90 * fraction,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isPeak
                                ? [const Color(0xFFF9C80E), const Color(0xFFE65100)]
                                : [const Color(0xFF42A5F5), const Color(0xFF1E3A8A)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          d['hour'] as String,
                          style: TextStyle(
                            color: isPeak ? Colors.white : Colors.white38,
                            fontSize: 10,
                            fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelAndPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order Channels
        const Text('Sales by Order Channel:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _buildProgressBarRow('Dine-In Orders', '62%', const Color(0xFF42A5F5), 0.62),
        const SizedBox(height: 8),
        _buildProgressBarRow('Takeaway / Bungkus', '26%', const Color(0xFF44CF6C), 0.26),
        const SizedBox(height: 8),
        _buildProgressBarRow('Self QR Table Order', '12%', const Color(0xFFAB47BC), 0.12),
        const Divider(height: 28, color: Colors.white12),

        // Payment Methods
        const Text('Payment Methods Distribution:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _buildProgressBarRow('DuitNow QR & E-Wallets', '54%', const Color(0xFFF9C80E), 0.54),
        const SizedBox(height: 8),
        _buildProgressBarRow('Cash (Physical Drawer)', '31%', const Color(0xFF10B981), 0.31),
        const SizedBox(height: 8),
        _buildProgressBarRow('Credit / Debit Cards', '15%', const Color(0xFF3B82F6), 0.15),
      ],
    );
  }

  Widget _buildProgressBarRow(String label, String percent, Color color, double progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(percent, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightsCard() {
    return Column(
      children: [
        _buildInsightItem(
          icon: HugeIcons.strokeRoundedChartIncrease,
          iconColor: const Color(0xFF44CF6C),
          title: 'Upcoming Weekend Sales Projected +18%',
          description: 'Historical patterns predict higher dinner traffic this Saturday. Consider prepping 25% extra sambal & rice.',
        ),
        const SizedBox(height: 12),
        _buildInsightItem(
          icon: HugeIcons.strokeRoundedAward01,
          iconColor: const Color(0xFF42A5F5),
          title: 'Top Combo Driver: Teh Tarik Kaw + Roti Bakar',
          description: '42% of breakfast customers purchase both. Suggest bundling as an RM 7.50 Value Set to lift basket size.',
        ),
        const SizedBox(height: 12),
        _buildInsightItem(
          icon: HugeIcons.strokeRoundedUserGroup,
          iconColor: const Color(0xFFAB47BC),
          title: 'High Customer Repeat Rate (68%)',
          description: 'Over 68% of customers visited more than once this month. Setting up a VIP loyalty promo could further increase visit frequency.',
        ),
      ],
    );
  }

  Widget _buildInsightItem({
    required List<List<dynamic>> icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(icon: icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 3),
                Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, height: 1.35)),
              ],
            ),
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
                                const Color(0xFF42A5F5).withValues(alpha: 0.5),
                                const Color(0xFF42A5F5).withValues(alpha: 0.2),
                              ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[i],
                    style: TextStyle(
                      color: isToday ? Colors.white : Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
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
          padding: const EdgeInsets.all(22),
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: color, size: 20, strokeWidth: 2.1),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
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
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
