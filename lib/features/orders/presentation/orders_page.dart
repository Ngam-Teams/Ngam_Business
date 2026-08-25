import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../data/orders_service.dart';

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
      // Check if any of the new orders are "pending" (online orders)
      final hasNewOnlineOrder = orders.any((o) => newlyAdded.contains(o.id) && o.status == 'pending');
      
      if (hasNewOnlineOrder) {
        // Play notification sound
        FlutterRingtonePlayer().playNotification();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('New online order received!', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: const Color(0xFF42A5F5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as $newStatus'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.source == 'online' ? 'Ngam App' : 'In-Store',
                      style: const TextStyle(
                        color: Colors.white70,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName?.isNotEmpty == true ? order.customerName! : 'Guest Customer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
              
              if (isPending)
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
