import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/orders_service.dart';
import 'package:flutter/services.dart';
import '../../appointments/presentation/appointments_page.dart';

import '../../../core/utils/file_saver/file_saver.dart';
import '../../../core/services/receipt_pdf_service.dart';

import '../../settings/data/business_service.dart';

import '../../../core/services/sound_service.dart';
import 'widgets/order_pickup_qr_scanner_screen.dart';
import '../../../widgets/glass_toast.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OrdersService _ordersService = OrdersService();
  late Stream<List<OrderModel>> _ordersStream;
  
  // Track previous order IDs to detect new incoming ones
  Set<String> _knownOrderIds = {};
  bool _isFirstLoad = true;
  int _selectedMainTab = 0; // 0: Pesanan Kedai, 1: Tempahan & Slots
  final Map<String, List<Map<String, dynamic>>> _orderItemsCache = {};

  // Offline cache & resilience state
  List<OrderModel>? _lastOrders;
  bool _isReconnecting = false;
  bool _hasShownOfflineToast = false;

  void _initOrdersStream() {
    setState(() {
      _ordersStream = _ordersService.streamOrders();
    });
  }

  @override
  void initState() {
    super.initState();
    _initOrdersStream();
  }

  void _checkForNewOrders(List<OrderModel> orders) {
    if (_isFirstLoad) {
      _knownOrderIds = orders.map((o) => o.id).toSet();
      _isFirstLoad = false;
      return;
    }

    final newIds = orders.map((o) => o.id).toSet();
    final newlyAdded = newIds.difference(_knownOrderIds);
    
    if (newlyAdded.isNotEmpty) {
      // PENTING: Hanya semak pesanan dari Ngam App (pelanggan luar).
      // Abaikan pesanan yang dibuat oleh juruwang / cashier di kaunter POS (source == 'pos').
      final hasNewOnlineOrder = orders.any((o) =>
          newlyAdded.contains(o.id) &&
          o.status == 'pending' &&
          o.source != 'pos');
      
      if (hasNewOnlineOrder) {
        // Play notification sound
        try {
          if (!kIsWeb) {
            FlutterRingtonePlayer().playNotification();
          }
        } catch (e) {
          debugPrint('[OrdersPage] Sound notification error: $e');
        }
        
        if (mounted) {
          showGlassToast(
            context,
            'orders.new_order_received'.tr(),
            type: GlassToastType.info,
            color: const Color(0xFF42A5F5),
          );
        }
      }
      
      _knownOrderIds = newIds;
    }
  }

  Future<void> _updateStatus(OrderModel order, String newStatus, {String? paymentStatus}) async {
    final success = await _ordersService.updateOrderStatus(order.id, newStatus, paymentStatus: paymentStatus);
    if (!mounted) return;
    
    if (success) {
      showGlassToast(
        context,
        'orders.status_updated'.tr(args: [newStatus]),
        type: GlassToastType.success,
      );
    } else {
      showGlassToast(
        context,
        'orders.status_update_failed'.tr(),
        isError: true,
      );
    }
  }

  Future<void> _openPickupQrVerifier(List<OrderModel> allOrders) async {
    final matched = await Navigator.push<OrderModel>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPickupQrScannerScreen(allOrders: allOrders),
      ),
    );

    if (matched != null && mounted) {
      await _handlePickupQrVerification(matched);
    }
  }

  Future<void> _handlePickupQrVerification(OrderModel order) async {
    final shortId = order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase();
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    // 1. JIKA PESANAN SUDAH BERSTATUS 'READY' (Alur Sah Pengesahan Pengambilan di Kaunter):
    if (order.status == 'ready') {
      final success = await _ordersService.updateOrderStatus(order.id, 'completed', paymentStatus: 'paid');
      if (!mounted) return;

      if (success) {
        await SoundService.instance.playOrderChime();
        await HapticFeedback.heavyImpact();
        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF141724),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF00E676), width: 1.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pengambilan Pesanan Disahkan!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pesanan #$shortId (${order.customerName ?? "Pelanggan"}) telah berjaya diambil dan ditandakan SELESAI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('orders.payment_amount'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 13)),
                      Text(fmt.format(order.total), style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('orders.action_done'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        showGlassToast(context, 'orders.verify_pickup_failed'.tr(), isError: true);
      }
      return;
    }

    // 2. JIKA PESANAN MASIH BELUM SIAP DIMASAK ('pending' / 'preparing'):
    if (order.status == 'pending' || order.status == 'preparing' || order.status == 'in_progress') {
      final statusLabel = order.status == 'pending' ? 'Diterima (Belum Dimasak)' : 'Sedang Dimasak di Dapur';
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF141724),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.amber, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pesanan Belum Sedia di Dapur!',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Pesanan #$shortId masih dalam status "$statusLabel" dan belum ditandakan "Sedia".\n\nAdakah pesanan sudah siap dan anda ingin terus serahkan kepada pelanggan sekarang?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('common.cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _updateStatus(order, 'completed', paymentStatus: 'paid');
                        if (mounted) {
                          showGlassToast(context, 'orders.order_pickup_confirmed'.tr(args: [shortId]), type: GlassToastType.success);
                        }
                      },
                      child: Text('orders.order_pickup_verified'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return;
    }

    // 3. JIKA PESANAN SUDAH SELESAI ATAU DIBATALKAN:
    if (order.status == 'completed') {
      showGlassToast(context, 'orders.order_already_completed'.tr(args: [shortId]), type: GlassToastType.info);
      return;
    }

    if (order.status == 'cancelled') {
      showGlassToast(context, 'orders.order_already_cancelled'.tr(args: [shortId]), isError: true);
      return;
    }

    // Fallback paparan butiran
    _showOrderDetailsModal(order);
  }

  Future<void> _exportOrdersCsv(List<OrderModel> orders) async {
    showGlassToast(context, 'export.preparing'.tr());
    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizName = profile?['business_name']?.toString() ?? 'Perniagaan Ngam';

      final fmt = DateFormat('yyyy-MM-dd_HHmm');
      final nowStr = fmt.format(DateTime.now());

      final buffer = StringBuffer();
      buffer.writeln('LAPORAN PESANAN & TRANSAKSI - $bizName');
      buffer.writeln('Tarikh Dijana: ${DateTime.now().toLocal()}');
      buffer.writeln('Jumlah Pesanan: ${orders.length}');
      buffer.writeln('');
      buffer.writeln('ID_Pesanan,Tarikh_Masa,Pelanggan,Telefon,Kaedah_Bayaran,Status_Pesanan,Status_Bayaran,Jumlah_RM,Sumber,Nota');

      double totalRev = 0.0;
      for (final o in orders) {
        final id = o.id.replaceAll(',', ' ');
        final date = o.createdAt.toIso8601String();
        final cust = (o.customerName ?? 'Pelanggan').replaceAll(',', ' ');
        final phone = (o.customerPhone ?? '-').replaceAll(',', ' ');
        final method = o.paymentMethod.replaceAll(',', ' ');
        final status = o.status;
        final payStatus = o.paymentStatus;
        final tot = o.total;
        totalRev += tot;
        final source = o.source;
        final notes = (o.notes ?? '').replaceAll('\n', ' ').replaceAll(',', ' ');

        buffer.writeln('$id,$date,$cust,$phone,$method,$status,$payStatus,${tot.toStringAsFixed(2)},$source,$notes');
      }

      buffer.writeln('');
      buffer.writeln('JUMLAH HASIL KESELURUHAN (RM),,,,,,,$totalRev,,');

      await saveAndDownloadCsv(
        csvContent: buffer.toString(),
        fileName: 'Laporan_Pesanan_$nowStr.csv',
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

  Future<void> _downloadOrderReceipt(OrderModel order, List<Map<String, dynamic>>? items) async {
    showGlassToast(context, 'export.preparing'.tr());
    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizName = profile?['business_name']?.toString() ?? 'Perniagaan Ngam';
      final bizPhone = profile?['business_phone']?.toString() ?? '';
      final bizAddress = profile?['address_line']?.toString() ?? '';

      final orderItems = items ?? _orderItemsCache[order.id] ?? [];

      await ReceiptPdfService.downloadReceiptPdf(
        orderId: order.id,
        shopName: bizName,
        shopPhone: bizPhone,
        shopAddress: bizAddress,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        orderCreatedAt: order.createdAt,
        paymentTime: order.createdAt,
        paymentMethod: order.paymentMethod,
        paymentStatus: order.paymentStatus,
        notes: order.notes,
        items: orderItems,
        totalAmount: order.total,
      );

      if (mounted) {
        showGlassToast(context, 'export.receipt_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'export.export_failed'.tr(), isError: true);
      }
    }
  }

  void _showOrderDetailsModal(OrderModel order) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 650;

    if (isLargeScreen) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (modalCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 580,
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.88,
              ),
              child: _buildOrderDetailsContent(order, modalCtx, isDialog: true),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (modalCtx) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalCtx).size.height * 0.88,
          ),
          child: _buildOrderDetailsContent(order, modalCtx, isDialog: false),
        ),
      );
    }
  }

  Widget _buildOrderDetailsContent(OrderModel order, BuildContext modalCtx, {required bool isDialog}) {
    final shortId = order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase();
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    Color statusColor;
    Color statusBgColor;
    switch (order.status.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFF39C12);
        statusBgColor = const Color(0xFFF39C12).withValues(alpha: 0.2);
        break;
      case 'preparing':
      case 'in_progress':
        statusColor = const Color(0xFF00B0FF);
        statusBgColor = const Color(0xFF00B0FF).withValues(alpha: 0.2);
        break;
      case 'ready':
        statusColor = const Color(0xFF00E676);
        statusBgColor = const Color(0xFF00E676).withValues(alpha: 0.2);
        break;
      case 'completed':
        statusColor = const Color(0xFF2ECC71);
        statusBgColor = const Color(0xFF2ECC71).withValues(alpha: 0.2);
        break;
      case 'cancelled':
      default:
        statusColor = const Color(0xFFFF5252);
        statusBgColor = const Color(0xFFFF5252).withValues(alpha: 0.2);
        break;
    }

    return StatefulBuilder(
      builder: (ctx, setModalState) {
        final cachedItems = _orderItemsCache[order.id];

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: isDialog
                ? BorderRadius.circular(28)
                : const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDialog
                ? Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2)
                : const Border(top: BorderSide(color: Colors.white12, width: 1.2)),
            boxShadow: isDialog
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. FIXED HEADER (Never scrolls away)
              Padding(
                padding: EdgeInsets.fromLTRB(24, isDialog ? 20 : 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isDialog) ...[
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'orders.order_details'.tr(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: '#$shortId'));
                                  showGlassToast(context, 'orders.order_id_copied'.tr());
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '#$shortId',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF00B0FF),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF00B0FF)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          onPressed: () => Navigator.pop(modalCtx),
                          tooltip: 'common.close'.tr(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

              // 2. SCROLLABLE BODY
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Profile Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B0FF).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.person_outline_rounded, color: Color(0xFF00B0FF), size: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.customerName?.isNotEmpty == true ? order.customerName! : 'orders.counter_customer'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM d, yyyy • h:mm a').format(order.createdAt.toLocal()),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedWhatsapp,
                                  color: Color(0xFF25D366),
                                  size: 20,
                                ),
                                tooltip: 'orders.whatsapp_customer'.tr(),
                                onPressed: () => _sendWhatsAppToCustomer(order),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Order Metadata Details Card (Tarikh & Masa, Saluran, Bayaran)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 15, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Text(
                                      'orders.date_and_time'.tr(),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy • hh:mm a').format(order.createdAt.toLocal()),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 15, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Text(
                                      'orders.order_source'.tr(),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: order.source == 'online'
                                        ? const Color(0xFF00B0FF).withValues(alpha: 0.2)
                                        : (order.source == 'table'
                                            ? const Color(0xFF00E676).withValues(alpha: 0.2)
                                            : (order.source == 'pre_order'
                                                ? Colors.purpleAccent.withValues(alpha: 0.2)
                                                : Colors.white.withValues(alpha: 0.1))),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.source == 'online'
                                        ? 'orders.online_order'.tr()
                                        : (order.source == 'table'
                                            ? 'orders.table_order'.tr()
                                            : (order.source == 'pre_order' ? 'Pre-Order' : 'orders.counter_order'.tr())),
                                    style: TextStyle(
                                      color: order.source == 'online'
                                          ? const Color(0xFF00B0FF)
                                          : (order.source == 'table'
                                              ? const Color(0xFF00E676)
                                              : (order.source == 'pre_order' ? Colors.purpleAccent : Colors.white70)),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.payment_rounded, size: 15, color: Colors.white54),
                                    const SizedBox(width: 6),
                                    Text(
                                      'orders.payment_status'.tr(),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      order.paymentMethod.toUpperCase(),
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: order.paymentStatus.toLowerCase() == 'paid'
                                            ? Colors.green.withValues(alpha: 0.2)
                                            : Colors.orangeAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        order.paymentStatus.toLowerCase() == 'paid'
                                            ? 'orders.paid'.tr()
                                            : (order.paymentStatus.toLowerCase() == 'pending'
                                                ? 'common.pending'.tr()
                                                : 'orders.unpaid'.tr()),
                                        style: TextStyle(
                                          color: order.paymentStatus.toLowerCase() == 'paid'
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Items Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'orders.ordered_items_title'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Items List Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: (cachedItems != null && cachedItems.isNotEmpty)
                            ? Column(
                                children: cachedItems.map((item) {
                                  final name = item['product_name'] ?? 'Item';
                                  final qty = item['quantity'] ?? 1;
                                  final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${qty}x',
                                            style: const TextStyle(
                                              color: Color(0xFF00B0FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          fmt.format(subtotal),
                                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              )
                            : (cachedItems != null && cachedItems.isEmpty)
                                ? _buildFallbackOrderItemRow(order, fmt)
                                : FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _ordersService.fetchOrderItems(order.id),
                                    builder: (context, itemSnap) {
                                      if (itemSnap.connectionState == ConnectionState.waiting) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B0FF)),
                                          ),
                                        );
                                      }
                                      final items = itemSnap.data ?? [];
                                      _orderItemsCache[order.id] = items;
                                      if (items.isEmpty) {
                                        return _buildFallbackOrderItemRow(order, fmt);
                                      }
                                      return Column(
                                        children: items.map((item) {
                                          final name = item['product_name'] ?? 'Item';
                                          final qty = item['quantity'] ?? 1;
                                          final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${qty}x',
                                                    style: const TextStyle(
                                                      color: Color(0xFF00B0FF),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                Text(
                                                  fmt.format(subtotal),
                                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                      ),

                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notes_rounded, size: 16, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Text(
                                    'orders.notes_title'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                order.notes!,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Total Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00E5FF).withValues(alpha: 0.08),
                              const Color(0xFF0072FF).withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'orders.total'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              fmt.format(order.total),
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

              // 3. PINNED BOTTOM ACTION BAR (Always visible, fully padded, never cut off)
              Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 14,
                  bottom: isDialog ? 24 : (MediaQuery.of(modalCtx).padding.bottom + 16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download Receipt Button (Ngam PDF style)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _downloadOrderReceipt(order, cachedItems),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF00E5FF)),
                                const SizedBox(width: 8),
                                Text(
                                  '${'export.download_receipt'.tr()} (PDF)',
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Actions (Lifecycle: pending -> preparing -> ready -> completed)
                    if (order.status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                _updateStatus(
                                  order,
                                  'cancelled',
                                  paymentStatus: order.paymentStatus.toLowerCase() == 'paid' ? 'refund_pending' : null,
                                );
                              },
                              child: Text('orders.reject_order'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00B0FF), Color(0xFF0072FF)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00B0FF).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _updateStatus(order, 'preparing');
                                },
                                icon: const HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01, color: Colors.white, size: 18),
                                label: Text('orders.accept_order'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (order.status == 'preparing' || order.status == 'in_progress') ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            _updateStatus(order, 'ready');
                          },
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedShoppingBag01, color: Colors.black, size: 18),
                          label: Text('orders.mark_ready'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ),
                    ] else if (order.status == 'ready') ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C853), Color(0xFF2E7D32)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            _updateStatus(order, 'completed', paymentStatus: 'paid');
                          },
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Colors.white, size: 18),
                          label: Text('orders.confirm_pickup_completed'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                          onPressed: () => Navigator.pop(modalCtx),
                          child: Text('common.close'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackOrderItemRow(OrderModel order, NumberFormat fmt) {
    final fallbackName = order.notes != null && order.notes!.isNotEmpty
        ? (order.notes!.replaceAll(RegExp(r'\[.*?\]'), '').trim().isNotEmpty
            ? order.notes!.replaceAll(RegExp(r'\[.*?\]'), '').trim()
            : (order.source == 'table' ? 'orders.table_order'.tr() : (order.source == 'pre_order' ? 'Pre-Order' : 'orders.counter_order'.tr())))
        : (order.source == 'table' ? 'orders.table_order'.tr() : (order.source == 'pre_order' ? 'Pre-Order' : 'orders.counter_order'.tr()));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '1x',
              style: TextStyle(
                color: Color(0xFF00B0FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fallbackName,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            fmt.format(order.total),
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItemsPreview(OrderModel order, NumberFormat fmt) {
    final cached = _orderItemsCache[order.id];
    if (cached != null) {
      if (cached.isEmpty) {
        return _buildFallbackOrderItemRow(order, fmt);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...cached.take(3).map((item) {
            final name = item['product_name'] ?? 'Item';
            final qty = item['quantity'] ?? 1;
            final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${qty}x',
                      style: const TextStyle(
                        color: Color(0xFF42A5F5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    fmt.format(subtotal),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
          if (cached.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'orders.more_items'.tr(args: [(cached.length - 3).toString()]),
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersService.fetchOrderItems(order.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF42A5F5)),
                ),
                const SizedBox(width: 8),
                Text('orders.loading_items'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          );
        }
        final items = snapshot.data ?? [];
        _orderItemsCache[order.id] = items;
        if (items.isEmpty) {
          return _buildFallbackOrderItemRow(order, fmt);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...items.take(3).map((item) {
              final name = item['product_name'] ?? 'Item';
              final qty = item['quantity'] ?? 1;
              final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${qty}x',
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      fmt.format(subtotal),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'orders.more_items'.tr(args: [(items.length - 3).toString()]),
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
  }

  void _sendWhatsAppToCustomer(OrderModel order) async {
    String? rawPhone = order.customerPhone;
    
    // Check if phone was written in notes (e.g., "0123456789")
    if (rawPhone == null || rawPhone.isEmpty) {
      if (order.notes != null) {
        final phoneMatch = RegExp(r'(01[0-9]{8,9}|\+?601[0-9]{8,9})').firstMatch(order.notes!);
        if (phoneMatch != null) {
          rawPhone = phoneMatch.group(0);
        }
      }
    }

    if (rawPhone == null || rawPhone.isEmpty) {
      showGlassToast(context, 'orders.no_customer_phone'.tr(), isError: true);
      return;
    }

    String phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = '6$phone';
    } else if (!phone.startsWith('60') && phone.length >= 9) {
      phone = '60$phone';
    }

    final shortId = order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase();
    final message = Uri.encodeComponent(
      'Hai ${order.customerName ?? 'Pelanggan'}, pesanan anda (#$shortId) bernilai RM ${order.total.toStringAsFixed(2)} di kedai kami sedang disiapkan/diproses. Terima kasih!'
    );

    final url = Uri.parse('https://wa.me/$phone?text=$message');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) showGlassToast(context, 'orders.cannot_open_whatsapp'.tr(), isError: true);
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'orders.whatsapp_launch_error'.tr(args: [e.toString()]), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Segmented Switcher: Pesanan (Orders) vs Tempahan (Bookings)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMainTab = 0),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedMainTab == 0 ? const Color(0xFF42A5F5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedMainTab == 0
                          ? [
                              BoxShadow(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedInvoice01,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'orders.title'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMainTab = 1),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedMainTab == 1 ? const Color(0xFF42A5F5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedMainTab == 1
                          ? [
                              BoxShadow(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'appointments.title'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body Content based on selected tab (IndexedStack preserves state & stream across tabs)
        Expanded(
          child: IndexedStack(
            index: _selectedMainTab,
            children: [
              StreamBuilder<List<OrderModel>>(
                stream: _ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    _lastOrders = snapshot.data;
                    _hasShownOfflineToast = false;
                  }

                  final allOrders = (snapshot.hasData && snapshot.data != null)
                      ? snapshot.data!
                      : (_lastOrders ?? []);

                  final isOffline = snapshot.hasError;

                  // 1. Jika ralat berlaku tetapi data cache wujud, maklumkan peniaga dengan glass toast
                  if (isOffline && allOrders.isNotEmpty) {
                    if (!_hasShownOfflineToast) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_hasShownOfflineToast) {
                          _hasShownOfflineToast = true;
                          showGlassToast(
                            context,
                            'orders.connection_offline_toast'.tr(),
                            type: GlassToastType.warning,
                            customIcon: Icons.wifi_off_rounded,
                          );
                        }
                      });
                    }
                  }

                  // 2. Jika ralat DAN tiada sebarang data (offline sepenuhnya & cache kosong)
                  if (isOffline && allOrders.isEmpty) {
                    return _buildGlassErrorState();
                  }

                  // 3. Masih menunggu muatan pertama dan tiada data cache
                  if (snapshot.connectionState == ConnectionState.waiting && allOrders.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
                  }

                  // Check for new incoming orders to trigger sound
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _checkForNewOrders(allOrders);
                  });

                  // Group by active lifecycle vs completed/cancelled
                  final pendingOrders = allOrders.where((o) =>
                      o.status == 'pending' ||
                      o.status == 'preparing' ||
                      o.status == 'in_progress' ||
                      o.status == 'ready').toList();
                  final completedOrders = allOrders.where((o) =>
                      o.status == 'completed' || o.status == 'cancelled').toList();

                  if (allOrders.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      // Offline Cache Status Banner (muncul jika sambungan terputus tetapi pesanan cache dipaparkan)
                      if (isOffline)
                        _buildOfflineCacheBanner(),
                        // 1-Row Quick Action Buttons (Live Board, Export CSV, Verify QR)
                        _buildQuickActionsRow(allOrders),
                        const SizedBox(height: 16),

                        // Section: Aktif (Pending, Preparing, Ready)
                        if (pendingOrders.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF42A5F5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'orders.filter_all'.tr().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...pendingOrders.map((o) => _buildOrderCard(o)),
                          const SizedBox(height: 16),
                        ],

                        // Section: Selesai / Dibatalkan
                        if (completedOrders.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SELESAI SEJARAH',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...completedOrders.map((o) => _buildOrderCard(o)),
                        ],
                      ],
                    );
                  },
                ),
              const AppointmentsPage(isEmbedded: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineCacheBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF39C12).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF39C12).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF39C12).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFF39C12),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'orders.offline_cache_notice'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'orders.offline_cache_subnotice'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              _initOrdersStream();
              showGlassToast(
                context,
                'orders.retrying'.tr(),
                type: GlassToastType.info,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'orders.retry_button'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF141724).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Frosted Icon Badge
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF39C12).withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_off_rounded,
                        color: Color(0xFFF39C12),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'orders.connection_error_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'orders.connection_error_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Modern Glass Retry Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isReconnecting
                          ? null
                          : () async {
                              setState(() {
                                _isReconnecting = true;
                              });
                              _initOrdersStream();
                              await Future.delayed(const Duration(milliseconds: 1000));
                              if (mounted) {
                                setState(() {
                                  _isReconnecting = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isReconnecting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'orders.retrying'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'orders.retry_button'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(List<OrderModel> allOrders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 640;

        return Row(
          children: [
            // 1. Kitchen Display (KDS) Live Board
            Expanded(
              child: _buildQuickActionButton(
                icon: HugeIcons.strokeRoundedTv01,
                color: const Color(0xFFF9C80E),
                shortLabel: 'orders.action_live_board_short'.tr(),
                title: 'orders.action_live_board_title'.tr(),
                subtitle: 'orders.action_live_board_desc'.tr(),
                isWide: isWide,
                onTap: () => context.push('/kds'),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Export Orders CSV
            Expanded(
              child: _buildQuickActionButton(
                icon: HugeIcons.strokeRoundedDownload01,
                color: const Color(0xFF44CF6C),
                shortLabel: 'orders.action_export_csv_short'.tr(),
                title: 'orders.action_export_csv_title'.tr(),
                subtitle: 'orders.action_export_csv_desc'.tr(),
                isWide: isWide,
                onTap: () => _exportOrdersCsv(allOrders),
              ),
            ),
            const SizedBox(width: 8),

            // 3. Scan & Verify Pickup QR
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF00E5FF),
                shortLabel: 'orders.action_scan_qr_short'.tr(),
                title: 'orders.action_scan_qr_title'.tr(),
                subtitle: 'orders.action_scan_qr_desc'.tr(),
                isWide: isWide,
                onTap: () => _openPickupQrVerifier(allOrders),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required dynamic icon,
    required Color color,
    required String shortLabel,
    required String title,
    required String subtitle,
    required bool isWide,
    required VoidCallback onTap,
  }) {
    if (isWide) {
      // ─── WIDE SCREEN: 1 Row with full title, subtitle details, & badge ───
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: icon is IconData
                    ? Icon(icon, color: color, size: 18)
                    : HugeIcon(icon: icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.45),
                size: 12,
              ),
            ],
          ),
        ),
      );
    }

    // ─── COMPACT / MOBILE SCREEN: 1 Row with icon + simple label (space-saving) ───
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon is IconData)
              Icon(icon, color: color, size: 17)
            else
              HugeIcon(icon: icon, color: color, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                shortLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInvoice01,
            color: Colors.white.withValues(alpha: 0.2),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'orders.no_orders_found'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    try {
      final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final isPending = order.status == 'pending';
    
    return GestureDetector(
      onTap: () => _showOrderDetailsModal(order),
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPending ? const Color(0xFF42A5F5).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFF42A5F5).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        color: isPending ? Colors.orangeAccent : Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.source == 'online'
                          ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
                          : (order.source == 'table'
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : (order.source == 'pre_order'
                                  ? Colors.purpleAccent.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1))),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.source == 'online'
                          ? 'Ngam App'
                          : (order.source == 'table'
                              ? 'Ngam App (Meja)'
                              : (order.source == 'pre_order'
                                  ? 'Pre-Order'
                                  : 'Kaunter POS')),
                      style: TextStyle(
                        color: order.source == 'online'
                            ? const Color(0xFF42A5F5)
                            : (order.source == 'table'
                                ? const Color(0xFF00E676)
                                : (order.source == 'pre_order'
                                    ? Colors.purpleAccent
                                    : Colors.white70)),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('MMM d, h:mm a').format(order.createdAt.toLocal()),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName?.isNotEmpty == true ? order.customerName! : 'Guest Customer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(order.total),
                      style: const TextStyle(
                        color: Color(0xFF42A5F5),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedWhatsapp,
                        color: Color(0xFF25D366),
                        size: 20,
                      ),
                      tooltip: 'orders.whatsapp_customer'.tr(),
                      onPressed: () => _sendWhatsAppToCustomer(order),
                    ),
                  ),
                  if (order.status == 'pending') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(order, 'preparing'),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01, color: Colors.white, size: 16),
                      label: Text('orders.action_cook'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B0FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else if (order.status == 'preparing' || order.status == 'in_progress') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(order, 'ready'),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedShoppingBag01, color: Colors.black, size: 16),
                      label: Text('orders.action_ready'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ] else if (order.status == 'ready') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(order, 'completed', paymentStatus: 'paid'),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Colors.white, size: 16),
                      label: Text('orders.action_done'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          
          // Items Breakdown Container
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: _buildCardItemsPreview(order, fmt),
          ),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Notes: ${order.notes}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ]
        ],
      ),
    ),
    );
    } catch (e, st) {
      debugPrint('[OrdersPage] Error building order card for #${order.id}: $e\n$st');
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pesanan #${order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ralat paparan butiran: $e',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
