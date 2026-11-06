import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sound_service.dart';
import '../../../../widgets/glass_nav_button.dart';
import '../../../../widgets/glass_toast.dart';
import '../../../settings/data/business_service.dart';
import '../../data/orders_service.dart';

/// Futuristic Order Pickup QR Scanner Screen for Ngam Business.
/// Matches the exact cyberpunk / liquid glass design system of Ngam Customer App QR Scanner,
/// allowing merchants to scan customer pickup QR codes, pick from gallery, or input manually.
class OrderPickupQrScannerScreen extends StatefulWidget {
  final List<OrderModel> allOrders;

  const OrderPickupQrScannerScreen({
    super.key,
    required this.allOrders,
  });

  @override
  State<OrderPickupQrScannerScreen> createState() => _OrderPickupQrScannerScreenState();
}

class _OrderPickupQrScannerScreenState extends State<OrderPickupQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isProcessingImage = false;
  bool _torchEnabled = false;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Normalizes and verifies the scanned QR code against active and online orders
  Future<void> _processScannedCode(String rawCode) async {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty || _isProcessing) return;

    final now = DateTime.now();
    if (_lastScannedCode == trimmed &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!).inMilliseconds < 2500) {
      return;
    }

    _lastScannedCode = trimmed;
    _lastScannedTime = now;

    setState(() => _isProcessing = true);

    try {
      // Strip NGAM-ORDER prefix, #, and trailing whitespaces
      var cleaned = trimmed;
      final upper = trimmed.toUpperCase();
      if (upper.startsWith('NGAM-ORDER:')) {
        cleaned = trimmed.substring('NGAM-ORDER:'.length).trim();
      } else if (upper.startsWith('NGAM:ORDER:')) {
        cleaned = trimmed.substring('NGAM:ORDER:'.length).trim();
      } else if (upper.startsWith('NGAM:')) {
        cleaned = trimmed.substring('NGAM:'.length).trim();
      }
      cleaned = cleaned.replaceAll('#', '').trim().toLowerCase();

      if (cleaned.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      // 1. Search in local memory orders first (instant)
      OrderModel? matched;
      for (final o in widget.allOrders) {
        final idLower = o.id.toLowerCase();
        if (idLower == cleaned || idLower.startsWith(cleaned) || idLower.endsWith(cleaned)) {
          matched = o;
          break;
        }
      }

      // 2. Fallback: Search directly in Supabase if not found in current loaded list
      if (matched == null) {
        final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
        final shopId = profile?['id']?.toString();

        var query = Supabase.instance.client.from('orders').select();
        if (shopId != null && shopId.isNotEmpty) {
          query = query.eq('business_id', shopId);
        }

        final res = await query.or('id.eq.$cleaned,id.ilike.$cleaned%').limit(1);
        if (res.isNotEmpty) {
          matched = OrderModel.fromJson(res.first);
        }
      }

      if (matched != null) {
        // Success: Sound chime + haptic feedback
        await SoundService.instance.playOrderChime();
        await HapticFeedback.heavyImpact();

        if (mounted) {
          Navigator.pop(context, matched);
        }
        return;
      }

      // Not found: Error beep + subtle vibration + user toast
      await SoundService.instance.playErrorBeep();
      await HapticFeedback.vibrate();

      if (mounted) {
        showGlassToast(
          context,
          'Pesanan tidak ditemui untuk kod ini ($trimmed).',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('[OrderPickupQrScanner] Error resolving order code: $e');
      if (mounted) {
        showGlassToast(
          context,
          'Ralat memeriksa kod pesanan: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Pick QR image from user device gallery and analyze
  Future<void> _pickFromGallery() async {
    if (_isProcessingImage || _isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      setState(() => _isProcessingImage = true);

      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final code = barcode.rawValue;
          if (code != null && code.trim().isNotEmpty) {
            await _processScannedCode(code);
            return;
          }
        }
      }

      if (mounted) {
        showGlassToast(
          context,
          'Tiada kod QR dikesan dalam gambar ini. Sila pilih gambar yang lebih jelas.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(
          context,
          'Ralat memproses gambar: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  /// Open manual text input dialog for hardware barcode gun or manual typing
  void _openManualInputDialog() {
    final manualCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF141724),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),
              const Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedKeyboard,
                    color: Color(0xFF00E5FF),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Masukkan Kod Pesanan Manual',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Taipkan Kod Pesanan (cth: NGAM-ORDER:... atau 6 aksara ID seperti #A1B2C3), atau gunakan pengimbas USB Barcode:',
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: manualCtrl,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Cth: NGAM-ORDER:abc12345 atau #ABC123',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                  ),
                ),
                onSubmitted: (val) {
                  Navigator.pop(ctx);
                  _processScannedCode(val);
                },
              ),
              const SizedBox(height: 18),
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
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF0A0E1A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final val = manualCtrl.text;
                        Navigator.pop(ctx);
                        _processScannedCode(val);
                      },
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, size: 18, color: Color(0xFF0A0E1A)),
                      label: const Text('Cari & Sahkan', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Feed
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.trim().isNotEmpty) {
                  _processScannedCode(code);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kamera Tidak Dapat Diakses',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Peranti ini tiada akses kamera aktif atau kebenaran belum diberikan. Anda masih boleh menggunakan mod kod manual di bawah.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _openManualInputDialog,
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedKeyboard, size: 18, color: Colors.black),
                        label: const Text('Guna Kod Manual', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Futuristic Reticle Overlay (matching Customer App)
          _buildScannerOverlay(context),

          // 3. Top Floating Glass Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlassNavButton.close(
                    context: context,
                    isDark: true,
                    size: 42,
                    iconSize: 22,
                  ),
                  GlassNavPill(
                    isDark: true,
                    items: [
                      GlassNavPillItem(
                        icon: HugeIcons.strokeRoundedImage01,
                        tooltip: 'Pilih dari Galeri',
                        onTap: _pickFromGallery,
                      ),
                      GlassNavPillItem(
                        icon: _torchEnabled ? HugeIcons.strokeRoundedFlash : HugeIcons.strokeRoundedFlashOff,
                        iconColor: _torchEnabled ? Colors.amber : Colors.white,
                        tooltip: 'Lampu Kilat',
                        onTap: () {
                          _controller.toggleTorch();
                          setState(() => _torchEnabled = !_torchEnabled);
                        },
                      ),
                      GlassNavPillItem(
                        icon: Icons.cameraswitch_rounded,
                        tooltip: 'Tukar Kamera',
                        onTap: () {
                          _controller.switchCamera();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Instructions Glass Banner
          Positioned(
            bottom: 116,
            left: 28,
            right: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedQrCode,
                        color: Color(0xFF00E5FF),
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halakan kamera ke Kod QR pesanan pelanggan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Kod QR ada pada resit atau aplikasi Ngam pelanggan',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Bottom Fallback Actions (Manual Input & Gallery)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.65),
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _pickFromGallery,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18, color: Color(0xFF42A5F5)),
                  label: const Text(
                    'Galeri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A0E1A),
                    backgroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _openManualInputDialog,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedKeyboard, size: 18, color: Color(0xFF0A0E1A)),
                  label: const Text(
                    'Kod Manual / Barcode',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // 6. Loading Overlay when analyzing image from gallery or fetching order
          if (_isProcessing || _isProcessingImage)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    SizedBox(height: 16),
                    Text(
                      'Mengesahkan kod pesanan...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the futuristic punch-hole mask overlay matching Ngam app
  Widget _buildScannerOverlay(BuildContext context) {
    return Stack(
      children: [
        // 1. Dark Punch-Hole Layer
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Futuristic Neon Cyan Glowing Border
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                width: 2.2,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        // 3. Animated Neon Laser Line
        const _ScanningLaserLine(),
      ],
    );
  }
}

/// Animated scanning laser line moving continuously up and down
class _ScanningLaserLine extends StatefulWidget {
  const _ScanningLaserLine();

  @override
  State<_ScanningLaserLine> createState() => _ScanningLaserLineState();
}

class _ScanningLaserLineState extends State<_ScanningLaserLine> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 250,
            height: 250,
            alignment: Alignment(0, (_animCtrl.value * 2) - 1),
            child: Container(
              height: 2.5,
              width: 220,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.0),
                    const Color(0xFF00E5FF),
                    const Color(0xFF00E5FF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
