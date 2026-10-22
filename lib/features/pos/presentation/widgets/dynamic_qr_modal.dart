import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/chip_payment_service.dart';
import '../../../../core/services/sound_service.dart';

class DynamicQrModal extends StatefulWidget {
  final double amount;
  final String orderTitle;
  final String? customerName;

  const DynamicQrModal({
    super.key,
    required this.amount,
    required this.orderTitle,
    this.customerName,
  });

  static Future<bool> show({
    required BuildContext context,
    required double amount,
    required String orderTitle,
    String? customerName,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DynamicQrModal(
        amount: amount,
        orderTitle: orderTitle,
        customerName: customerName,
      ),
    );
    return res ?? false;
  }

  @override
  State<DynamicQrModal> createState() => _DynamicQrModalState();
}

class _DynamicQrModalState extends State<DynamicQrModal> with SingleTickerProviderStateMixin {
  ChipPurchaseResult? _purchase;
  bool _loading = true;
  String? _errorMessage;
  bool _isSuccess = false;
  Timer? _pollTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initiatePayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await ChipPaymentService.instance.createDuitNowPurchase(
        amount: widget.amount,
        orderTitle: widget.orderTitle,
        clientName: widget.customerName,
      );

      if (!mounted) return;

      setState(() {
        _purchase = res;
        _loading = false;
      });

      _startPolling(res.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _startPolling(String purchaseId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final status = await ChipPaymentService.instance.checkPurchaseStatus(purchaseId);
      if (status == 'paid') {
        timer.cancel();
        _onPaymentVerified();
      }
    });
  }

  Future<void> _onPaymentVerified() async {
    if (_isSuccess || !mounted) return;
    setState(() => _isSuccess = true);

    // Audio chime feedback
    await SoundService.instance.playOrderChime();

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCheckoutPage() async {
    if (_purchase == null) return;
    final uri = Uri.parse(_purchase!.duitNowUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF131324),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isSuccess
                ? const Color(0xFF10B981)
                : const Color(0xFFE91E63).withValues(alpha: 0.3),
            width: _isSuccess ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : const Color(0xFFE91E63).withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isSuccess ? _buildSuccessView(fmt) : _buildActiveView(fmt),
      ),
    );
  }

  Widget _buildSuccessView(NumberFormat fmt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10B981), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              color: Color(0xFF10B981),
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Bayaran Berjaya Disahkan!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${fmt.format(widget.amount)} telah diterima melalui DuitNow QR (CHIP)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        const LinearProgressIndicator(
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
        ),
      ],
    );
  }

  Widget _buildActiveView(NumberFormat fmt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Header: DuitNow branding
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFED1164).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFED1164).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedQrCode,
                    color: Color(0xFFED1164),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'DuitNow QR Dinamik',
                    style: TextStyle(
                      color: Color(0xFFED1164),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              tooltip: 'Batal',
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Amount Display
        Text(
          fmt.format(widget.amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.orderTitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 18),

        // QR Box
        if (_loading)
          Container(
            height: 220,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFED1164)),
                ),
                SizedBox(height: 16),
                Text(
                  'Menjana Kod QR Dinamik dari CHIP...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _initiatePayment,
                  child: const Text('Cuba Semula'),
                ),
              ],
            ),
          )
        else if (_purchase != null) ...[
          // QR Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _purchase!.duitNowUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF131324),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF131324),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pulse Listening Bar
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFED1164).withValues(
                    alpha: 0.08 + (_pulseController.value * 0.10),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFED1164).withValues(
                      alpha: 0.2 + (_pulseController.value * 0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFED1164),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Menunggu bayaran disahkan...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 20),

        // Action Buttons: Open Page & Simulate Button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openCheckoutPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Buka Laman (Ujian)', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _onPaymentVerified,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Simulasi Lulus',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
