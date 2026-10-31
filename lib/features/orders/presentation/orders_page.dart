import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/orders_service.dart';
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
        FlutterRingtonePlayer().playNotification();
        
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

  Future<void> _updateStatus(OrderModel order, String newStatus) async {
    final success = await _ordersService.updateOrderStatus(order.id, newStatus);
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
    return StreamBuilder<List<OrderModel>>(
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

        // Group by status
        final pendingOrders = allOrders.where((o) => o.status == 'pending').toList();
        final completedOrders = allOrders.where((o) => o.status != 'pending').toList();

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
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final isPending = order.status == 'pending';
    
    return Container(
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
                  if (isPending) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(order, 'completed'),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Colors.white, size: 18),
                      label: const Text('Complete'),
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
    );
  }
}
