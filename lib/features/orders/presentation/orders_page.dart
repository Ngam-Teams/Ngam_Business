import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/orders_service.dart';
import 'package:flutter/services.dart';
import '../../appointments/presentation/appointments_page.dart';

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


  @override
  void initState() {
    super.initState();
    _ordersStream = _ordersService.streamOrders();
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
            'Pesanan Ngam App baru diterima!',
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
        'Pesanan dikemaskini kepada status: $newStatus',
        type: GlassToastType.success,
      );
    } else {
      showGlassToast(
        context,
        'Gagal mengemaskini status pesanan',
        isError: true,
      );
    }
  }

    Future<void> _openPickupQrVerifier(List<OrderModel> allOrders) async {
    final codeCtrl = TextEditingController();
    final matched = await showDialog<OrderModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sahkan QR Ambil Pesanan',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imbas dengan pengimbas barcode/QR atau masukkan Kod Pesanan pelanggan (cth: NGAM-ORDER:... atau 6 aksara pertama ID):',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'NGAM-ORDER:... atau #A1B2C3',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                final cleaned = val.trim().replaceAll('NGAM-ORDER:', '').replaceAll('#', '').toLowerCase();
                if (cleaned.isEmpty) return;
                for (final o in allOrders) {
                  if (o.id.toLowerCase() == cleaned || o.id.toLowerCase().startsWith(cleaned)) {
                    Navigator.pop(ctx, o);
                    return;
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final cleaned = codeCtrl.text.trim().replaceAll('NGAM-ORDER:', '').replaceAll('#', '').toLowerCase();
              if (cleaned.isEmpty) return;
              for (final o in allOrders) {
                if (o.id.toLowerCase() == cleaned || o.id.toLowerCase().startsWith(cleaned)) {
                  Navigator.pop(ctx, o);
                  return;
                }
              }
              showGlassToast(context, 'Pesanan tidak ditemui untuk kod tersebut.', isError: true);
            },
            child: const Text('Cari & Sahkan', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (matched != null && mounted) {
      _showOrderDetailsModal(matched);
    }
  }

  void _showOrderDetailsModal(OrderModel order) {
    final shortId = order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase();
    final isPending = order.status == 'pending';
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final cachedItems = _orderItemsCache[order.id];

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF141724),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top Header: Title, Order ID & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Butiran Pesanan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: '#$shortId'));
                              showGlassToast(context, 'ID Pesanan disalin!');
                            },
                            child: Row(
                              children: [
                                Text(
                                  '#$shortId',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF42A5F5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF42A5F5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPending ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPending ? Colors.orangeAccent.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            color: isPending ? Colors.orangeAccent : Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

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
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.person_outline_rounded, color: Color(0xFF42A5F5), size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName?.isNotEmpty == true ? order.customerName! : 'Pelanggan Kaunter',
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
                            tooltip: 'WhatsApp Pelanggan',
                            onPressed: () => _sendWhatsAppToCustomer(order),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Items Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Item Yang Dipesan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                  : (order.source == 'pre_order' ? 'Pre-Order' : 'Kaunter POS')),
                          style: TextStyle(
                            color: order.source == 'online'
                                ? const Color(0xFF42A5F5)
                                : (order.source == 'table'
                                    ? const Color(0xFF00E676)
                                    : (order.source == 'pre_order' ? Colors.purpleAccent : Colors.white70)),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
                    child: cachedItems != null
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
                                          color: Color(0xFF42A5F5),
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
                        : FutureBuilder<List<Map<String, dynamic>>>(
                            future: _ordersService.fetchOrderItems(order.id),
                            builder: (context, itemSnap) {
                              if (itemSnap.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5)),
                                  ),
                                );
                              }
                              final items = itemSnap.data ?? [];
                              if (items.isNotEmpty) {
                                _orderItemsCache[order.id] = items;
                              }
                              if (items.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('1x Pesanan Am', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                );
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
                                              color: Color(0xFF42A5F5),
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
                          const Row(
                            children: [
                              Icon(Icons.notes_rounded, size: 16, color: Colors.white54),
                              SizedBox(width: 6),
                              Text(
                                'Nota & Mod Pesanan:',
                                style: TextStyle(
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
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 16),

                  // Total Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jumlah Keseluruhan',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fmt.format(order.total),
                        style: const TextStyle(
                          color: Color(0xFF44CF6C),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Actions (4-Stage Lifecycle: pending -> preparing -> ready -> completed)
                  Column(
                    children: [
                      if (order.status == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _updateStatus(
                                    order,
                                    'cancelled',
                                    paymentStatus: order.paymentStatus.toLowerCase() == 'paid' ? 'refund_pending' : null,
                                  );
                                },
                                child: const Text('Batal Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00B0FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _updateStatus(order, 'preparing');
                                },
                                icon: const HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01, color: Colors.white, size: 18),
                                label: const Text('Terima & Sediakan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ] else if (order.status == 'preparing' || order.status == 'in_progress') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _updateStatus(order, 'ready');
                                },
                                icon: const HugeIcon(icon: HugeIcons.strokeRoundedShoppingBag01, color: Colors.black, size: 18),
                                label: const Text('Sedia Untuk Diambil (Ready)', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ] else if (order.status == 'ready') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _updateStatus(order, 'completed', paymentStatus: 'paid');
                                },
                                icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Colors.white, size: 18),
                                label: const Text('Sahkan Pengambilan & Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(modalCtx),
                            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
      showGlassToast(context, 'Tiada nombor telefon pelanggan untuk pesanan ini', isError: true);
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
        if (mounted) showGlassToast(context, 'Tidak dapat membuka WhatsApp', isError: true);
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'Ralat melancarkan WhatsApp: $e', isError: true);
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedInvoice01,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Pesanan Kedai',
                          style: TextStyle(
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tempahan & Slots',
                          style: TextStyle(
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

        // Body Content based on selected tab
        Expanded(
          child: _selectedMainTab == 1
              ? const AppointmentsPage(isEmbedded: true)
              : StreamBuilder<List<OrderModel>>(
                  stream: _ordersStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading orders: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
                    }

                    final allOrders = snapshot.data ?? [];
                    
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
                      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                      children: [
                        // Kitchen Display (KDS) Quick Access Banner
            InkWell(
              onTap: () => context.push('/kds'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF9C80E).withValues(alpha: 0.15),
                      const Color(0xFF10B981).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF9C80E).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9C80E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedTv01,
                        color: Color(0xFFF9C80E),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buka Live Order Board',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Paparan langsung status penyediaan & giliran pesanan',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFFF9C80E),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _openPickupQrVerifier(allOrders),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Imbas / Sahkan Kod QR Pengambilan Pelanggan (NGAM-ORDER)',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (pendingOrders.isNotEmpty) ...[
              const Text(
                'New / Pending',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...pendingOrders.map((o) => _buildOrderCard(o)),
              const SizedBox(height: 24),
            ],
            
            if (completedOrders.isNotEmpty) ...[
              const Text(
                'Completed / History',
                style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...completedOrders.map((o) => _buildOrderCard(o)),
            ],
          ],
        );
      },
    ),
    ),
    ],
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
            'No orders yet',
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
                      tooltip: 'WhatsApp Pelanggan',
                      onPressed: () => _sendWhatsAppToCustomer(order),
                    ),
                  ),
                  if (order.status == 'pending') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(order, 'preparing'),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01, color: Colors.white, size: 16),
                      label: const Text('Masak'),
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
                      label: const Text('Sedia', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      label: const Text('Selesai'),
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
