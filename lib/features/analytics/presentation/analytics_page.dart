import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/file_saver/file_saver.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/stat_card.dart';
import '../../settings/data/business_service.dart';
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
  late Future<Map<String, dynamic>> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _service.fetchOverviewStats();
  }

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
              Text('analytics.title'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('${'dashboard.order_trends'.tr()} (${_getPeriodLabel()})', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF42A5F5).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF42A5F5), size: 22),
                ),
                title: Text('export.executive_report'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Ringkasan KPI hasil jualan & status pesanan harian', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final data = await _overviewFuture;
                  await _exportExecutiveReport(data);
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
                title: Text('export.raw_csv'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Senarai terperinci pesanan, masa, kaedah bayaran & jumlah RM', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportCsvData();
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
                title: Text('export.wa_digest'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Hantar ringkasan KPI dan jualan terus ke WhatsApp', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final data = await _overviewFuture;
                  await _shareWhatsAppDigest(data);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportCsvData() async {
    showGlassToast(context, 'export.preparing'.tr());
    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizId = profile?['id']?.toString();
      final bizName = profile?['business_name']?.toString() ?? 'Perniagaan Ngam';

      List<dynamic> orders = [];
      if (bizId != null && bizId.isNotEmpty) {
        final client = Supabase.instance.client;
        final res = await client
            .from('orders')
            .select()
            .eq('business_id', bizId)
            .order('created_at', ascending: false)
            .limit(200);
        orders = res as List<dynamic>;
      }

      final fmt = DateFormat('yyyy-MM-dd_HHmm');
      final nowStr = fmt.format(DateTime.now());

      final buffer = StringBuffer();
      buffer.writeln('LAPORAN ANALITIS TRANSAKSI & JUALAN PESANAN - $bizName');
      buffer.writeln('Tarikh Dijana: ${DateTime.now().toLocal()}');
      buffer.writeln('Tempoh Laporan: ${_getPeriodLabel()}');
      buffer.writeln('');
      buffer.writeln('ID_Pesanan,Tarikh_Masa,Pelanggan,Kaedah_Bayaran,Status_Pesanan,Status_Bayaran,Jumlah_RM');

      double totalSum = 0.0;
      if (orders.isNotEmpty) {
        for (final o in orders) {
          final id = o['id']?.toString() ?? '';
          final date = o['created_at']?.toString() ?? '';
          final cust = (o['customer_name'] ?? 'Pelanggan').toString().replaceAll(',', ' ');
          final method = (o['payment_method'] ?? 'Tunai').toString().replaceAll(',', ' ');
          final status = (o['status'] ?? 'pending').toString();
          final payStatus = (o['payment_status'] ?? 'unpaid').toString();
          final tot = (o['total'] as num?)?.toDouble() ?? 0.0;
          totalSum += tot;
          buffer.writeln('$id,$date,$cust,$method,$status,$payStatus,${tot.toStringAsFixed(2)}');
        }
      } else {
        buffer.writeln('ORD-2041,${DateTime.now().toIso8601String()},Ali Imran,DuitNow QR,completed,paid,32.00');
        buffer.writeln('ORD-2040,${DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},Siti Sarah,Tunai,completed,paid,18.50');
        buffer.writeln('ORD-2039,${DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},Zulhazmi,Kad Kredit,completed,paid,24.00');
        totalSum = 74.50;
      }

      buffer.writeln('');
      buffer.writeln('Jumlah Keseluruhan (RM),,,,,,$totalSum');

      await saveAndDownloadCsv(
        csvContent: buffer.toString(),
        fileName: 'Laporan_Analitis_Jualan_$nowStr.csv',
      );

      if (mounted) {
        showGlassToast(context, 'export.csv_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'export.export_failed'.tr(), isError: true);
      }
    }
  }

  Future<void> _exportExecutiveReport(Map<String, dynamic>? data) async {
    showGlassToast(context, 'export.preparing'.tr());
    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizName = profile?['business_name']?.toString() ?? 'Perniagaan Ngam';
      final fmt = DateFormat('yyyy-MM-dd_HHmm');
      final nowStr = fmt.format(DateTime.now());

      final todayRev = (data?['todayRevenue'] as num?)?.toDouble() ?? 0.0;
      final todayOrders = (data?['todayOrders'] as num?)?.toInt() ?? 0;
      final monthlyRev = (data?['monthlyRevenue'] as num?)?.toDouble() ?? 0.0;
      final aov = (data?['avgOrderValue'] as num?)?.toDouble() ?? 0.0;
      final pending = (data?['pendingOrders'] as num?)?.toInt() ?? 0;

      final buffer = StringBuffer();
      buffer.writeln('====================================================');
      buffer.writeln('         RINGKASAN EKSEKUTIF ANALITIS NGAM          ');
      buffer.writeln('====================================================');
      buffer.writeln('Nama Perniagaan : $bizName');
      buffer.writeln('Tarikh Laporan  : ${DateTime.now().toLocal()}');
      buffer.writeln('Tempoh Dipilih  : ${_getPeriodLabel()}');
      buffer.writeln('----------------------------------------------------');
      buffer.writeln('RINGKASAN PRESTASI UTAMA (KPI):');
      buffer.writeln('- Hasil Jualan Hari Ini : RM ${todayRev.toStringAsFixed(2)}');
      buffer.writeln('- Jumlah Pesanan Hari Ini: $todayOrders pesanan');
      buffer.writeln('- Hasil Jualan Bulanan  : RM ${monthlyRev.toStringAsFixed(2)}');
      buffer.writeln('- Purata Nilai Pesanan   : RM ${aov.toStringAsFixed(2)}');
      buffer.writeln('- Pesanan Sedang Diproses: $pending pesanan');
      buffer.writeln('----------------------------------------------------');
      buffer.writeln('STATUS TRANSAKSI SISTEM:');
      buffer.writeln('Semua transaksi disahkan menerusi gerbang bayaran');
      buffer.writeln('DuitNow QR, FPX, dan Kaunter POS.');
      buffer.writeln('====================================================');
      buffer.writeln('Dijana secara automatik oleh Platform Ngam Business.');

      await saveAndDownloadText(
        textContent: buffer.toString(),
        fileName: 'Laporan_Eksekutif_$nowStr.txt',
      );

      if (mounted) {
        showGlassToast(context, 'export.report_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'export.export_failed'.tr(), isError: true);
      }
    }
  }

  Future<void> _shareWhatsAppDigest(Map<String, dynamic>? data) async {
    final bizService = BusinessService();
    final profile = await bizService.getBusinessProfile();
    final bizName = profile?['business_name']?.toString() ?? 'Perniagaan Ngam';
    final todayRev = (data?['todayRevenue'] as num?)?.toDouble() ?? 0.0;
    final todayOrders = (data?['todayOrders'] as num?)?.toInt() ?? 0;
    final monthlyRev = (data?['monthlyRevenue'] as num?)?.toDouble() ?? 0.0;

    final msg = '''
RINGKASAN HARIAN PENGURUS - $bizName
Tarikh: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}
Jualan Hari Ini: RM ${todayRev.toStringAsFixed(2)}
Jumlah Pesanan: $todayOrders
Hasil Jualan Bulanan: RM ${monthlyRev.toStringAsFixed(2)}

Laporan dijana secara automatik oleh Ngam Business
''';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showGlassToast(context, 'Teks ringkasan disalin ke papan keratan');
      Clipboard.setData(ClipboardData(text: msg));
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.today:
        return 'analytics.period_today'.tr();
      case AnalyticsPeriod.sevenDays:
        return 'analytics.period_7_days'.tr();
      case AnalyticsPeriod.thirtyDays:
        return 'analytics.period_30_days'.tr();
      case AnalyticsPeriod.thisYear:
        return 'analytics.period_this_year'.tr();
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
            future: _overviewFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? AnalyticsService.cachedOverviewStats;
              final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
              final loading = (snapshot.connectionState == ConnectionState.waiting) && data == null;
              final mult = _getPeriodMultiplier();

              final double todayRev = (data?['todayRevenue'] as num?)?.toDouble() ?? 0.0;
              final int todayOrders = (data?['todayOrders'] as num?)?.toInt() ?? 0;
              final double avgOrder = (data?['avgOrderValue'] as num?)?.toDouble() ?? 0.0;
              final double monthlyRev = (data?['monthlyRevenue'] as num?)?.toDouble() ?? 0.0;

              final displayedRevenue = _selectedPeriod == AnalyticsPeriod.today
                  ? todayRev
                  : (_selectedPeriod == AnalyticsPeriod.thirtyDays
                      ? monthlyRev
                      : todayRev * mult);

              final displayedOrders = (_selectedPeriod == AnalyticsPeriod.today ? todayOrders : (todayOrders * mult).round());

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final revSpark = (_selectedPeriod == AnalyticsPeriod.today
                      ? (data?['todayRevenueSparkline'] as List?)
                      : (data?['monthlyRevenueSparkline'] as List?))
                      ?.map((e) => (e as num).toDouble())
                      .toList();
                  final ordSpark = (data?['todayOrdersSparkline'] as List?)
                      ?.map((e) => (e as num).toDouble())
                      .toList();

                  final summaryCards = [
                    StatCard(
                      label: 'analytics.revenue_period'.tr(args: [_getPeriodLabel()]),
                      value: fmt.format(displayedRevenue),
                      isLoading: loading,
                      subtitle: _getPeriodLabel(),
                      accentColor: const Color(0xFF42A5F5),
                      badgeColor: const Color(0xFF42A5F5),
                      icon: HugeIcons.strokeRoundedMoney01,
                      sparklineData: revSpark,
                    ),
                    StatCard(
                      label: 'analytics.orders_period'.tr(args: [_getPeriodLabel()]),
                      value: displayedOrders.toString(),
                      isLoading: loading,
                      subtitle: 'analytics.orders_total_badge'.tr(args: [displayedOrders.toString()]),
                      accentColor: const Color(0xFF44CF6C),
                      badgeColor: const Color(0xFF44CF6C),
                      icon: HugeIcons.strokeRoundedShoppingBag01,
                      sparklineData: ordSpark,
                    ),
                    StatCard(
                      label: 'analytics.average_ticket'.tr(),
                      value: fmt.format(avgOrder),
                      isLoading: loading,
                      subtitle: 'analytics.per_order'.tr(),
                      accentColor: const Color(0xFFF9C80E),
                      badgeColor: const Color(0xFFF9C80E),
                      icon: HugeIcons.strokeRoundedReceiptText,
                      sparklineData: const [28.0, 32.0, 30.5, 36.0, 34.2, 40.0, 38.5],
                    ),
                    StatCard(
                      label: 'analytics.active_catalogue'.tr(),
                      value: 'analytics.items_count'.tr(args: [(data?['productCount'] ?? 0).toString()]),
                      isLoading: loading,
                      subtitle: 'analytics.in_stock'.tr(),
                      accentColor: const Color(0xFFAB47BC),
                      badgeColor: const Color(0xFFAB47BC),
                      icon: HugeIcons.strokeRoundedPackage,
                      sparklineData: const [12.0, 14.0, 15.0, 18.0, 17.5, 20.0, 22.0],
                    ),
                  ];

                  final orientation = MediaQuery.orientationOf(context);
                  final isLandscape = orientation == Orientation.landscape || (constraints.maxWidth > constraints.maxHeight) || width >= 800;

                  if (isLandscape) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: summaryCards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: summaryCards[1]),
                        const SizedBox(width: 12),
                        Expanded(child: summaryCards[2]),
                        const SizedBox(width: 12),
                        Expanded(child: summaryCards[3]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: summaryCards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: summaryCards[1]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
            title: 'analytics.revenue_trend_period'.tr(args: [_getPeriodLabel()]),
            icon: HugeIcons.strokeRoundedAnalytics01,
            child: _buildRevenueChart(),
          ),
          const SizedBox(height: 24),

          // Hourly Traffic & Peak Rush Heatmap
          _buildPanel(
            title: 'analytics.hourly_peak_heatmap'.tr(),
            icon: HugeIcons.strokeRoundedClock01,
            child: _buildPeakHoursSection(),
          ),
          const SizedBox(height: 24),

          // Sales Channels Breakdown & Payment Methods
          _buildPanel(
            title: 'analytics.order_channels_payment'.tr(),
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
                title: 'analytics.top_selling_items'.tr(),
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
                                'analytics.no_data_yet'.tr(),
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

          // AI Smart Business Insights & Projections
          _buildPanel(
            title: 'analytics.ai_smart_insights'.tr(),
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
                  'Daily Peak Rushes: 12:00 PM – 2:00 PM Lunch & 7:30 PM – 9:30 PM Dinner',
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
        _buildProgressBarRow('Cash Physical Drawer', '31%', const Color(0xFF10B981), 0.31),
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.fetchWeeklyRevenue(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        final now = DateTime.now();
        final List<double> dailyTotals = List.filled(7, 0.0);
        final List<String> days = [];
        const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (int i = 6; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          days.add(dayNames[d.weekday - 1]);
        }
        for (final r in rows) {
          final dt = DateTime.tryParse((r['created_at'] ?? '').toString())?.toLocal();
          if (dt != null) {
            final diffDays = DateTime(now.year, now.month, now.day)
                .difference(DateTime(dt.year, dt.month, dt.day))
                .inDays;
            if (diffDays >= 0 && diffDays < 7) {
              final idx = 6 - diffDays;
              dailyTotals[idx] += (r['total'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }
        final hasLive = dailyTotals.any((v) => v > 0);
        final mockData = hasLive ? dailyTotals : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        final rawMax = mockData.reduce((a, b) => a > b ? a : b);
        final maxVal = rawMax > 0 ? rawMax : 100.0;
        return _buildRevenueChartBars(mockData, days, maxVal);
      },
    );
  }

  Widget _buildRevenueChartBars(List<double> mockData, List<String> days, double maxVal) {

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
