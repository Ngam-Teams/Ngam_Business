import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/services/sound_service.dart';
import '../../../customers/data/membership_service.dart';
import '../../../promotions/data/voucher_service.dart';
import '../../../promotions/models/voucher_model.dart';
import '../../models/product_model.dart';

// =============================================================================
// Dynamic Scan Result Enums & Models
// =============================================================================

enum DynamicScanType { member, voucherDiscount, freeRewardItem }

class DynamicScanResult {
  final DynamicScanType type;
  final CustomerMember? member;
  final String? voucherCode;
  final String? voucherId;
  final double discountAmount;
  final String? rewardItemName;
  final ProductModel? rewardProduct;
  final String message;

  const DynamicScanResult({
    required this.type,
    this.member,
    this.voucherCode,
    this.voucherId,
    this.discountAmount = 0.0,
    this.rewardItemName,
    this.rewardProduct,
    required this.message,
  });

  factory DynamicScanResult.member(CustomerMember member) => DynamicScanResult(
    type: DynamicScanType.member,
    member: member,
    message: 'Ahli "${member.name}" (${member.tierBadge}) berjaya dipautkan!',
  );

  factory DynamicScanResult.freeRewardItem({
    required String rewardItemName,
    String? voucherCode,
    String? voucherId,
    ProductModel? product,
  }) => DynamicScanResult(
    type: DynamicScanType.freeRewardItem,
    rewardItemName: rewardItemName,
    voucherCode: voucherCode,
    voucherId: voucherId,
    rewardProduct: product,
    message: 'Ganjaran Penebusan: Percuma 1x $rewardItemName dimasukkan ke dalam resit!',
  );

  factory DynamicScanResult.voucherDiscount({
    required String voucherCode,
    required String voucherId,
    required double discountAmount,
  }) => DynamicScanResult(
    type: DynamicScanType.voucherDiscount,
    voucherCode: voucherCode,
    voucherId: voucherId,
    discountAmount: discountAmount,
    message: 'Baucar "$voucherCode" berjaya digunakan! Jimat RM ${discountAmount.toStringAsFixed(2)}',
  );
}

// =============================================================================
// Dynamic POS Scanner Modal
// =============================================================================

class DynamicPosScannerModal extends StatefulWidget {
  final double currentSubtotal;
  final List<ProductModel> availableProducts;
  final CustomerMember? currentMember;

  const DynamicPosScannerModal({
    super.key,
    required this.currentSubtotal,
    this.availableProducts = const [],
    this.currentMember,
  });

  static Future<DynamicScanResult?> show({
    required BuildContext context,
    required double currentSubtotal,
    List<ProductModel> availableProducts = const [],
    CustomerMember? currentMember,
  }) async {
    return await showDialog<DynamicScanResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DynamicPosScannerModal(
        currentSubtotal: currentSubtotal,
        availableProducts: availableProducts,
        currentMember: currentMember,
      ),
    );
  }

  @override
  State<DynamicPosScannerModal> createState() => _DynamicPosScannerModalState();
}

class _DynamicPosScannerModalState extends State<DynamicPosScannerModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final MembershipService _memberService = MembershipService();
  final VoucherService _voucherService = VoucherService();

  late AnimationController _laserAnim;
  int _activeTab = 0; // 0: Auto Scanner HUD, 1: Pilih Ahli, 2: Daftar Baru, 3: Baucar & Reward
  bool _isResolving = false;
  String? _statusError;

  // Camera Scanner on Tablet / Phone
  MobileScannerController? _cameraController;
  bool _isCameraActive = true;
  bool _torchOn = false;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  bool get _isCameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  // New walk-in member registration controllers
  final TextEditingController _newNameCtrl = TextEditingController();
  final TextEditingController _newPhoneCtrl = TextEditingController();

  List<VoucherModel> _cachedVouchers = [];
  bool _loadingVouchers = false;

  @override
  void initState() {
    super.initState();
    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    if (_isCameraSupported) {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }

    _loadActiveVouchers();

    // Auto-focus the input field so physical scanner guns immediately work!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _laserAnim.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _newNameCtrl.dispose();
    _newPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null) return;
    try {
      await _cameraController!.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameraController == null) return;
    try {
      await _cameraController!.switchCamera();
    } catch (_) {}
  }

  void _toggleCameraPower() {
    setState(() {
      _isCameraActive = !_isCameraActive;
      if (_isCameraActive) {
        _cameraController?.start();
      } else {
        _cameraController?.stop();
      }
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isResolving) return;
    final now = DateTime.now();
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        final trimmed = code.trim();
        // Debounce if the same code was scanned within 2 seconds
        if (_lastScannedCode == trimmed &&
            _lastScannedTime != null &&
            now.difference(_lastScannedTime!).inMilliseconds < 2000) {
          return;
        }
        _lastScannedCode = trimmed;
        _lastScannedTime = now;
        _inputCtrl.text = trimmed;
        _resolveCode(trimmed);
        break;
      }
    }
  }

  Future<void> _loadActiveVouchers() async {
    setState(() => _loadingVouchers = true);
    try {
      final list = await _voucherService.fetchVouchers();
      if (mounted) {
        setState(() {
          _cachedVouchers = list.where((v) => v.isActive && !v.isExpired).toList();
          _loadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Dynamic Smart Resolver Engine
  // ---------------------------------------------------------------------------

  Future<void> _resolveCode(String rawInput) async {
    final query = rawInput.trim();
    if (query.isEmpty) return;

    setState(() {
      _isResolving = true;
      _statusError = null;
    });

    try {
      final upperQuery = query.toUpperCase();
      final digitsOnly = query.replaceAll(RegExp(r'\D'), '');

      // 1. Semak jika ia adalah KEAHLIAN PELANGGAN (Phone No. atau Kod Ahli)
      // Cth: '01123456789', '+6011...', 'MEM-xxxx', 'CUST-01', 'NGAM-MEM-...'
      final isLikelyPhone = digitsOnly.length >= 9 && (digitsOnly.startsWith('01') || digitsOnly.startsWith('601'));
      final isMemberQr = upperQuery.startsWith('NGAM-MEM') || upperQuery.startsWith('MEM-') || upperQuery.startsWith('CUST-');

      if (isLikelyPhone || isMemberQr) {
        final member = await _memberService.findMember(query);
        if (member != null) {
          SoundService.instance.playOrderChime();
          if (mounted) {
            Navigator.of(context).pop(DynamicScanResult.member(member));
          }
          return;
        }
      }

      // 2. Semak jika ia adalah BAUCAR PROMOSI atau PENEBUSAN GANJARAN
      final voucherVal = await _voucherService.validateVoucherCode(
        code: query,
        subtotal: widget.currentSubtotal,
      );

      if (voucherVal.isValid) {
        SoundService.instance.playOrderChime();

        if (voucherVal.isFreeItem || (voucherVal.rewardItemName != null && voucherVal.rewardItemName!.isNotEmpty)) {
          // Ganjaran Item / Servis Percuma -> Auto Masukkan ke resit!
          final rewardName = voucherVal.rewardItemName ?? voucherVal.title ?? 'Ganjaran Percuma';
          ProductModel? matchedProduct;

          for (final p in widget.availableProducts) {
            if (p.name.toLowerCase().contains(rewardName.toLowerCase()) ||
                rewardName.toLowerCase().contains(p.name.toLowerCase())) {
              matchedProduct = p;
              break;
            }
          }

          matchedProduct ??= ProductModel(
            id: 'reward-${DateTime.now().millisecondsSinceEpoch}',
            name: rewardName,
            itemType: 'product',
            price: 0.0,
          );

          if (mounted) {
            Navigator.of(context).pop(DynamicScanResult.freeRewardItem(
              rewardItemName: rewardName,
              voucherCode: voucherVal.code,
              voucherId: voucherVal.voucherId,
              product: matchedProduct,
            ));
          }
          return;
        } else {
          // Baucar Diskaun Tunai atau Peratusan
          if (mounted) {
            Navigator.of(context).pop(DynamicScanResult.voucherDiscount(
              voucherCode: voucherVal.code ?? query,
              voucherId: voucherVal.voucherId ?? '',
              discountAmount: voucherVal.discountAmount,
            ));
          }
          return;
        }
      }

      // 3. Jika bukan baucar sah, semak semula jika nama pelanggan wujud dalam direktori ahli
      final memberByName = await _memberService.findMember(query);
      if (memberByName != null) {
        SoundService.instance.playOrderChime();
        if (mounted) {
          Navigator.of(context).pop(DynamicScanResult.member(memberByName));
        }
        return;
      }

      // 4. Jika tiada padanan langsung
      setState(() {
        _statusError = 'Kod "$query" tidak ditemui dalam rekod keahlian atau senarai baucar.';
        _isResolving = false;
      });
    } catch (e) {
      setState(() {
        _statusError = 'Ralat pemprosesan imbasan: $e';
        _isResolving = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: const Color(0xFF10131E),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF00C853).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildTabBar(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: _buildCurrentTabContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C853).withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengimbas Pintar POS (Dynamic Scanner)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Imbas QR Keahlian, Baucar Diskaun, atau Tebus Ganjaran Percuma',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tabItem(0, 'Imbas Pintar', Icons.center_focus_strong_rounded),
          _tabItem(1, 'Pilih Ahli', Icons.badge_outlined),
          _tabItem(2, '+ Daftar Walk-in', Icons.person_add_alt_1_rounded),
          _tabItem(3, 'Baucar & Ganjaran', Icons.confirmation_number_outlined),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    final isSel = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF00C853).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSel
                ? Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSel ? const Color(0xFF00C853) : Colors.white60,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.white60,
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildAutoScannerTab();
      case 1:
        return _buildSelectMemberTab();
      case 2:
        return _buildRegisterWalkInTab();
      case 3:
      default:
        return _buildVouchersAndRewardsTab();
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 0: AUTO SCANNER HUD & BARCODE GUN LISTENER
  // ---------------------------------------------------------------------------

  Widget _buildAutoScannerTab() {
    return Column(
      children: [
        // Viewfinder HUD with Live Camera or Animated Laser & Scanner Gun HUD
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isCameraSupported && _isCameraActive) ...[
                  // Live Camera View
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _cameraController,
                      fit: BoxFit.cover,
                      onDetect: _onBarcodeDetected,
                      errorBuilder: (context, error) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 30),
                                const SizedBox(height: 6),
                                Text(
                                  'Akses kamera tidak aktif / peranti tidak menyokong.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Slight vignette overlay for reticle and laser contrast
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Desktop / Manual Barcode Gun Guidance
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.barcode_reader,
                          color: const Color(0xFF00C853).withValues(alpha: 0.85),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCameraSupported
                            ? 'Kamera Dimatikan (Mod Imbasan Teks / Gun)'
                            : 'Mod Desktop POS — Halakan Barcode Scanner Gun',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isCameraSupported
                            ? 'Tekan ikon kamera di atas untuk hidupkan kamera peranti'
                            : '📱 Kamera langsung aktif automatik apabila dibuka di tablet atau telefon',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],

                // Reticle Corners
                Positioned(
                  top: 14,
                  left: 14,
                  child: _hudCorner(top: true, left: true),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: _hudCorner(top: true, left: false),
                ),
                Positioned(
                  bottom: 14,
                  left: 14,
                  child: _hudCorner(top: false, left: true),
                ),
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: _hudCorner(top: false, left: false),
                ),

                // Animated Scanning Laser Line
                AnimatedBuilder(
                  animation: _laserAnim,
                  builder: (context, _) {
                    return Positioned(
                      top: 18 + (_laserAnim.value * 156),
                      left: 24,
                      right: 24,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF00C853),
                              Color(0xFF69F0AE),
                              Color(0xFF00C853),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00C853).withValues(alpha: 0.9),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Top HUD Bar (Badge + Controls)
                Positioned(
                  top: 10,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_isCameraSupported && _isCameraActive)
                                ? const Color(0xFF00C853).withValues(alpha: 0.6)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isCameraSupported && _isCameraActive)
                                    ? const Color(0xFF00C853)
                                    : Colors.white54,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (_isCameraSupported && _isCameraActive)
                                  ? 'KAMERA AKTIF'
                                  : 'SCANNER GUN / INPUT',
                              style: TextStyle(
                                color: (_isCameraSupported && _isCameraActive)
                                    ? const Color(0xFF00C853)
                                    : Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isCameraSupported) ...[
                        _hudIconButton(
                          icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _torchOn ? const Color(0xFFFFD600) : Colors.white70,
                          onPressed: _toggleTorch,
                          tooltip: 'Lampu Suluh',
                        ),
                        const SizedBox(width: 6),
                        _hudIconButton(
                          icon: Icons.cameraswitch_rounded,
                          color: Colors.white70,
                          onPressed: _switchCamera,
                          tooltip: 'Tukar Kamera',
                        ),
                        const SizedBox(width: 6),
                        _hudIconButton(
                          icon: _isCameraActive ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          color: _isCameraActive ? const Color(0xFF00C853) : Colors.white38,
                          onPressed: _toggleCameraPower,
                          tooltip: _isCameraActive ? 'Matikan Kamera' : 'Hidupkan Kamera',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Live Input TextField (Supports keyboard typing, paste, or hardware scanner gun)
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: (val) => _resolveCode(val),
                decoration: InputDecoration(
                  hintText: 'Taip no. telefon, kod baucar, atau scan QR...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00C853), size: 20),
                  suffixIcon: _inputCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                          onPressed: () {
                            _inputCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00C853), width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isResolving || _inputCtrl.text.trim().isEmpty
                  ? null
                  : () => _resolveCode(_inputCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isResolving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Proses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),

        if (_statusError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Quick Simulated Scan Shortcuts (Pintasan Pantas untuk Ujian & Kaunter Laju)
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Pintasan Pantas (Satu Tekan):',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickChip(
              icon: Icons.person_pin_circle_rounded,
              label: 'Ahli: Danish (Gold VIP)',
              color: Colors.amber,
              onTap: () => _resolveCode('01123456789'),
            ),
            _quickChip(
              icon: Icons.person_pin_circle_rounded,
              label: 'Ahli: Melissa (Cop Penuh)',
              color: const Color(0xFF42A5F5),
              onTap: () => _resolveCode('01233445566'),
            ),
            _quickChip(
              icon: Icons.card_giftcard_rounded,
              label: 'Ganjaran: Percuma Kopi',
              color: const Color(0xFFFF9800),
              onTap: () {
                // Auto insert free gift item
                Navigator.of(context).pop(DynamicScanResult.freeRewardItem(
                  rewardItemName: 'Kopi Latte Ais (Ganjaran Percuma)',
                  voucherCode: 'REDEEM-KOPI',
                  voucherId: 'reward-kopi-01',
                ));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _hudCorner({required bool top, required bool left}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Color(0xFF00C853), width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xFF00C853), width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: Color(0xFF00C853), width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xFF00C853), width: 3) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _hudIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _quickChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: PILIH AHLI WALK-IN (DIRECT LIST)
  // ---------------------------------------------------------------------------

  Widget _buildSelectMemberTab() {
    final members = _memberService.getAllPresetMembers();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih ahli berdaftar untuk pautkan ke pesanan ini:',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final m = members[idx];
            final isCurrent = widget.currentMember?.phone == m.phone;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF00C853).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF00C853).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                    child: Text(
                      m.name.isNotEmpty ? m.name[0] : 'U',
                      style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.tier.contains('Gold')
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : const Color(0xFF42A5F5).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                m.tierBadge,
                                style: TextStyle(
                                  color: m.tier.contains('Gold') ? Colors.amber : const Color(0xFF42A5F5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${m.phone} • ${m.stamps}/${m.totalStampsRequired} Cop • ${m.points} Mata',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      SoundService.instance.playOrderChime();
                      Navigator.of(context).pop(DynamicScanResult.member(m));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrent ? const Color(0xFF00C853) : Colors.white.withValues(alpha: 0.1),
                      foregroundColor: isCurrent ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isCurrent ? 'Dipautkan' : 'Pilih',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: DAFTAR AHLI WALK-IN PANTAS
  // ---------------------------------------------------------------------------

  Widget _buildRegisterWalkInTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF42A5F5), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daftarkan pelanggan walk-in serta-merta semasa pembayaran. Kad keahlian digital akan dibuka secara automatik!',
                  style: TextStyle(color: Color(0xFF90CAF9), fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newNameCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Nama Penuh Pelanggan *',
            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
            hintText: 'Cth: Encik Faizal',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPhoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'No. Telefon Bimbit *',
            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
            hintText: 'Cth: 0191234567',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final name = _newNameCtrl.text.trim();
              final phone = _newPhoneCtrl.text.trim();
              if (phone.isEmpty) {
                setState(() => _statusError = 'Sila masukkan no. telefon pelanggan.');
                return;
              }

              final newMem = await _memberService.registerWalkInMember(name: name, phone: phone);
              SoundService.instance.playOrderChime();
              if (mounted) {
                Navigator.of(context).pop(DynamicScanResult.member(newMem));
              }
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Daftar & Pautkan Ahli Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: SENARAI BAUCAR & GANJARAN AKTIF (ONE-TAP REDEEM)
  // ---------------------------------------------------------------------------

  Widget _buildVouchersAndRewardsTab() {
    if (_loadingVouchers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Color(0xFF00C853)),
        ),
      );
    }

    if (_cachedVouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Tiada baucar atau ganjaran aktif buat masa ini.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih baucar atau ganjaran untuk ditebus pada pesanan ini:',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cachedVouchers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final v = _cachedVouchers[idx];
            final isGift = v.isFreeItem;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGift
                    ? const Color(0xFFFF9800).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isGift
                      ? const Color(0xFFFF9800).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isGift
                          ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                          : const Color(0xFF42A5F5).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGift ? Icons.card_giftcard_rounded : Icons.confirmation_number_rounded,
                      color: isGift ? const Color(0xFFFF9800) : const Color(0xFF42A5F5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.code,
                          style: TextStyle(
                            color: isGift ? const Color(0xFFFF9800) : const Color(0xFF42A5F5),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          v.formattedDiscount,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          v.formattedMinSpend,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _resolveCode(v.code),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGift ? const Color(0xFFFF9800) : const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isGift ? 'Tebus Hadiah' : 'Guna Baucar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
