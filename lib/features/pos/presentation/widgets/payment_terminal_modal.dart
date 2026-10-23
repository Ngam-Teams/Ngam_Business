import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/chip_payment_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../widgets/glass_toast.dart';

enum TerminalStep {
  chooseMethod, // Step 2 in flow
  showQr,       // Step 3 in flow
  cashTender,   // Cash calculator
  cardPayment,  // Card tap
  success,      // Step 4 in flow
}

class PaymentTerminalResult {
  final bool isSuccess;
  final String paymentMethod;
  final double amount;
  final double cashTendered;
  final double change;

  PaymentTerminalResult({
    required this.isSuccess,
    required this.paymentMethod,
    required this.amount,
    this.cashTendered = 0.0,
    this.change = 0.0,
  });
}

class PaymentTerminalModal extends StatefulWidget {
  final double amount;
  final String orderTitle;
  final String? customerName;
  final TerminalStep initialStep;

  const PaymentTerminalModal({
    super.key,
    required this.amount,
    required this.orderTitle,
    this.customerName,
    this.initialStep = TerminalStep.chooseMethod,
  });

  static Future<PaymentTerminalResult?> show({
    required BuildContext context,
    required double amount,
    required String orderTitle,
    String? customerName,
    TerminalStep initialStep = TerminalStep.chooseMethod,
  }) async {
    return await showDialog<PaymentTerminalResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentTerminalModal(
        amount: amount,
        orderTitle: orderTitle,
        customerName: customerName,
        initialStep: initialStep,
      ),
    );
  }

  @override
  State<PaymentTerminalModal> createState() => _PaymentTerminalModalState();
}

class _PaymentTerminalModalState extends State<PaymentTerminalModal>
    with SingleTickerProviderStateMixin {
  late TerminalStep _currentStep;
  String _selectedMethod = 'duitnow';

  // DuitNow CHIP state
  ChipPurchaseResult? _purchase;
  bool _loadingQr = false;
  String? _qrError;
  Timer? _pollTimer;
  late AnimationController _pulseController;

  // Cash state
  final TextEditingController _cashTenderedCtrl = TextEditingController();
  double _cashTendered = 0.0;
  double _change = 0.0;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _cashTendered = widget.amount;
    _cashTenderedCtrl.text = widget.amount.toStringAsFixed(2);
    _calculateChange();

    if (_currentStep == TerminalStep.showQr) {
      _initiateDuitNowPayment();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    _cashTenderedCtrl.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final tendered = double.tryParse(_cashTenderedCtrl.text) ?? 0.0;
    _cashTendered = tendered;
    _change = (tendered - widget.amount).clamp(0.0, double.infinity);
  }

  Future<void> _initiateDuitNowPayment() async {
    setState(() {
      _loadingQr = true;
      _qrError = null;
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
        _loadingQr = false;
      });

      _startPolling(res.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingQr = false;
        _qrError = e.toString();
      });
    }
  }

  void _startPolling(String purchaseId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final status = await ChipPaymentService.instance.checkPurchaseStatus(purchaseId);
      if (status == 'paid') {
        timer.cancel();
        _onPaymentSuccess('duitnow');
      }
    });
  }

  Future<void> _onPaymentSuccess(String method) async {
    _pollTimer?.cancel();
    if (_currentStep == TerminalStep.success || !mounted) return;

    setState(() {
      _selectedMethod = method;
      _currentStep = TerminalStep.success;
    });

    // Melodic dual-tone audio chime alert
    await SoundService.instance.playOrderChime();
  }

  Future<void> _openCheckoutPage() async {
    if (_purchase == null) return;
    if (_purchase!.isWebFallback || _purchase!.checkoutUrl.isEmpty) {
      showGlassToast(
        context,
        'Pelayar Web (Chrome) menyekat CORS. Jalankan Chrome dengan "--disable-web-security" atau uji di Windows Desktop / Android untuk membuka laman CHIP.',
        isError: true,
      );
      return;
    }
    final uri = Uri.parse(_purchase!.duitNowUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _finishAndClose() {
    Navigator.of(context).pop(
      PaymentTerminalResult(
        isSuccess: true,
        paymentMethod: _selectedMethod,
        amount: widget.amount,
        cashTendered: _selectedMethod == 'cash' ? _cashTendered : widget.amount,
        change: _selectedMethod == 'cash' ? _change : 0.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: 440,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: const Color(0xFF111122),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _currentStep == TerminalStep.success
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12),
              width: _currentStep == TerminalStep.success ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _currentStep == TerminalStep.success
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: _buildCurrentStepView(fmt),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(NumberFormat fmt) {
    switch (_currentStep) {
      case TerminalStep.chooseMethod:
        return _buildStep2ChooseMethod(fmt);
      case TerminalStep.showQr:
        return _buildStep3ShowQr(fmt);
      case TerminalStep.cashTender:
        return _buildCashTenderView(fmt);
      case TerminalStep.cardPayment:
        return _buildCardPaymentView(fmt);
      case TerminalStep.success:
        return _buildStep4Success(fmt);
    }
  }

  // ===========================================================================
  // STEP 2: CHOOSE PAYMENT METHOD (Sama seperti Step 2 dalam gambar)
  // ===========================================================================
  Widget _buildStep2ChooseMethod(NumberFormat fmt) {
    return Column(
      key: const ValueKey('step2_choose_method'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Langkah 2: Kaedah Bayaran',
                style: TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(null),
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Total Amount Display
        Text(
          fmt.format(widget.amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih kaedah bayaran • Choose payment method',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Option 1: DuitNow QR (Recommended & Highlighted)
        _buildMethodCard(
          title: 'DuitNow QR',
          subtitle: 'Imbas guna MAE, TNG, CIMB & semua bank',
          badgeText: 'Pantas ⭐',
          badgeColor: const Color(0xFFED1164),
          iconWidget: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFED1164).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFED1164).withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedQrCode,
                color: Color(0xFFED1164),
                size: 22,
                strokeWidth: 2.2,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              _selectedMethod = 'duitnow';
              _currentStep = TerminalStep.showQr;
            });
            _initiateDuitNowPayment();
          },
        ),
        const SizedBox(height: 12),

        // Option 2: Tunai (Cash)
        _buildMethodCard(
          title: 'Tunai (Cash)',
          subtitle: 'Kira duit diterima & baki pulangan',
          badgeText: 'Kaunter',
          badgeColor: const Color(0xFF10B981),
          iconWidget: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMoney01,
                color: Color(0xFF10B981),
                size: 22,
                strokeWidth: 2.2,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              _selectedMethod = 'cash';
              _currentStep = TerminalStep.cashTender;
            });
          },
        ),
        const SizedBox(height: 12),

        // Option 3: Kad Bank (Debit / Kredit)
        _buildMethodCard(
          title: 'Kad Bank (Tap to Pay)',
          subtitle: 'Visa, Mastercard & MyDebit',
          badgeText: 'Kad',
          badgeColor: const Color(0xFF42A5F5),
          iconWidget: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCreditCard,
                color: Color(0xFF42A5F5),
                size: 22,
                strokeWidth: 2.2,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              _selectedMethod = 'card';
              _currentStep = TerminalStep.cardPayment;
            });
          },
        ),
        const SizedBox(height: 12),

        // Option 4: E-Wallet & SPayLater (via CHIP)
        _buildMethodCard(
          title: 'E-Wallet & SPayLater',
          subtitle: 'Touch n Go, GrabPay & ShopeePay',
          badgeText: 'Online',
          badgeColor: const Color(0xFF8B5CF6),
          iconWidget: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedWallet01,
                color: Color(0xFF8B5CF6),
                size: 22,
                strokeWidth: 2.2,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              _selectedMethod = 'ewallet';
              _currentStep = TerminalStep.showQr;
            });
            _initiateDuitNowPayment();
          },
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? const Color(0xFF42A5F5)).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor ?? const Color(0xFF42A5F5),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 3: SHOW DUITNOW NATIONAL QR CODE (Sama seperti Step 3 dalam gambar)
  // ===========================================================================
  Widget _buildStep3ShowQr(NumberFormat fmt) {
    return Column(
      key: const ValueKey('step3_show_qr'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top Bar Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                _pollTimer?.cancel();
                setState(() => _currentStep = TerminalStep.chooseMethod);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
              tooltip: 'Tukar Kaedah',
            ),
            Text(
              fmt.format(widget.amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(null),
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              tooltip: 'Batal',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Imbas kod QR di bawah untuk bayar',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 18),

        // QR Presentation Card (Malaysia National QR Authentic Pink Frame Style!)
        if (_loadingQr)
          Container(
            height: 290,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFED1164))),
                SizedBox(height: 16),
                Text('Menjana DuitNow QR Dinamik dari CHIP...', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          )
        else if (_qrError != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                const SizedBox(height: 8),
                Text(_qrError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: _initiateDuitNowPayment, child: const Text('Cuba Semula')),
              ],
            ),
          )
        else if (_purchase != null) ...[
          // THE AUTHENTIC NATIONAL DUITNOW QR CARD
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFED1164).withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Pink Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFED1164),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'DuitNow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center QR Code
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

                // Bottom Pink Bar: "MALAYSIA NATIONAL QR" (Exact standard!)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFED1164),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: const Center(
                    child: Text(
                      'MALAYSIA NATIONAL QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pulse Listening Bar
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFED1164).withValues(
                    alpha: 0.08 + (_pulseController.value * 0.12),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFED1164).withValues(
                      alpha: 0.2 + (_pulseController.value * 0.35),
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
                      'Menunggu bayaran pelanggan...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_purchase?.isWebFallback == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Mod Ujian Web (CORS Aktif) • Tekan "Simulasi Lulus"',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 20),

        // Action Testing Buttons (Open Web & Fast Simulate)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openCheckoutPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Buka Laman (Ujian)', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _onPaymentSuccess('duitnow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Simulasi Lulus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // CASH TENDER SCREEN (Untuk Tunai Kaunter)
  // ===========================================================================
  Widget _buildCashTenderView(NumberFormat fmt) {
    return Column(
      key: const ValueKey('step_cash_tender'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = TerminalStep.chooseMethod),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
            const Text(
              'Bayaran Tunai',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(null),
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Total Due
        Text(
          fmt.format(widget.amount),
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text('Jumlah Perlu Dibayar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        const SizedBox(height: 18),

        // Cash Input Field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Duit Tunai Diterima', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _cashTenderedCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: 'RM ',
                  prefixStyle: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(_calculateChange),
              ),
              const SizedBox(height: 12),

              // Quick Cash Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCashChip('Genap', widget.amount),
                    const SizedBox(width: 6),
                    _buildCashChip('+RM 5', _cashTendered + 5.0),
                    const SizedBox(width: 6),
                    _buildCashChip('+RM 10', _cashTendered + 10.0),
                    const SizedBox(width: 6),
                    _buildCashChip('+RM 50', _cashTendered + 50.0),
                  ],
                ),
              ),

              const Divider(height: 24, color: Colors.white12),

              // Change Output
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Baki Pulangan:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    fmt.format(_change),
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _cashTendered >= widget.amount ? () => _onPaymentSuccess('cash') : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Sahkan Bayaran Tunai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildCashChip(String label, double val) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: const Color(0xFF1A1A2E),
      side: const BorderSide(color: Colors.white12),
      onPressed: () {
        setState(() {
          _cashTenderedCtrl.text = val.toStringAsFixed(2);
          _calculateChange();
        });
      },
    );
  }

  // ===========================================================================
  // CARD PAYMENT SCREEN
  // ===========================================================================
  Widget _buildCardPaymentView(NumberFormat fmt) {
    return Column(
      key: const ValueKey('step_card_payment'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = TerminalStep.chooseMethod),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
            const Text('Kad Bank', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () => Navigator.of(context).pop(null),
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4), width: 2),
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCreditCard,
              color: Color(0xFF42A5F5),
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(fmt.format(widget.amount), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Sentuhkan Kad atau Masukkan Cip ke Terminal', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () => _onPaymentSuccess('card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Simulasi Kad Lulus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 4: VERIFY SUCCESSFUL PAYMENT STATUS (Sama seperti Step 4 dalam gambar)
  // ===========================================================================
  Widget _buildStep4Success(NumberFormat fmt) {
    final methodLabel = _selectedMethod == 'duitnow'
        ? 'DuitNow QR (CHIP)'
        : (_selectedMethod == 'cash' ? 'Tunai (Cash)' : 'Kad Bank');

    return Column(
      key: const ValueKey('step4_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),

        // Green Success Circle (Exact match with Step 4 screenshot)
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10B981), width: 2.2),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 52),
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Bayaran Berjaya!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          fmt.format(widget.amount),
          style: const TextStyle(
            color: Color(0xFF10B981),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),

        // Method Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _selectedMethod == 'duitnow'
                    ? Icons.qr_code_2_rounded
                    : (_selectedMethod == 'cash' ? Icons.money_rounded : Icons.credit_card_rounded),
                size: 15,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              Text(
                methodLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Options (Exact cards as in Step 4: Print Receipt / Share Receipt)
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.print_rounded, color: Color(0xFF42A5F5), size: 20),
                title: const Text('Cetak Resit Terminal', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 13),
                dense: true,
                onTap: () {
                  showGlassToast(context, 'Mencetak resit ke pencetak Bluetooth...');
                },
              ),
              const Divider(height: 1, color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
                title: const Text('Hantar Resit e-WhatsApp', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 13),
                dense: true,
                onTap: () {
                  final text = '''
🧾 RESIT BAYARAN — NGAM
📅 Tarikh: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}
💰 Jumlah: ${fmt.format(widget.amount)}
💳 Kaedah: $methodLabel
✅ Status: LULUS
Terima kasih kerana berniaga bersama kami!
''';
                  Clipboard.setData(ClipboardData(text: text));
                  showGlassToast(context, 'Teks resit telah disalin untuk WhatsApp!');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Big Primary Button: Pesanan Baharu (Sama seperti "New Payment" dalam gambar)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _finishAndClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Pesanan Baharu / New Payment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
            SizedBox(width: 4),
            Text(
              'Pengesahan masa nyata • Real-time confirmation',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
