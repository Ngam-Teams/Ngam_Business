import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/utils/file_saver/file_saver.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// ============================================================
// QrGeneratorPage — Modern Storefront, Table, WiFi & Promo QR Standee Generator
// Redesigned with Ngam Signature Modern Aesthetic & Cross-Platform Download Support
// ============================================================

enum QrMode { storefront, table, promo, wifi, queue }

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  QrMode _selectedMode = QrMode.storefront;

  // Store Information (Fully Customizable)
  final _storeNameCtrl = TextEditingController(text: 'Kedai Saya');
  String _businessId = 'store';

  // Customizable Table Identifier (Supports any number/name e.g. 1, 12, A-01, VIP)
  final _tableCtrl = TextEditingController(text: '1');

  // Quick Preset Table Options
  final List<String> _quickTablePresets = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '12', '15', '20', 'VIP', 'A-01', 'Bar 1'
  ];

  // WiFi Settings Controllers (Editable)
  final _wifiSsidCtrl = TextEditingController(text: 'WarungNgam_Guest');
  final _wifiPasswordCtrl = TextEditingController(text: 'makanansedap');
  bool _includeWifi = true;
  bool _obscureWifiPassword = false;

  // Promo Code Settings Controllers (Customizable)
  final _promoCodeCtrl = TextEditingController(text: 'NGAM10');
  final _promoDiscountCtrl = TextEditingController(text: '10% OFF Semua Menu');
  bool _includePromoBadge = false;

  // Custom Tagline Controller
  final _customTaglineCtrl = TextEditingController(text: 'Imbas Untuk Pesan & Bayar Terus');
  bool _includeCustomTagline = false;

  // RepaintBoundary Key for Real Image Generation
  final GlobalKey _standeeKey = GlobalKey();
  bool _isDownloading = false;

  Color _accentColor = const Color(0xFF2196F3); // Ngam Signature Electric Blue
  final List<Color> _colorOptions = [
    const Color(0xFF2196F3), // Ngam Electric Blue
    const Color(0xFF6C5CE7), // Ngam Purple
    const Color(0xFF10B981), // Emerald Mint
    const Color(0xFFF59E0B), // Amber Gold
    const Color(0xFFEC4899), // Neon Pink
  ];

  Color _qrColor = const Color(0xFF0F172A); // Default dark / black
  final List<Color> _qrColorOptions = [
    const Color(0xFF0F172A), // Dark Slate
    const Color(0xFF000000), // Pure Black
    const Color(0xFF1E3A8A), // Deep Navy
    const Color(0xFF065F46), // Deep Forest Green
    const Color(0xFF581C87), // Deep Purple
    const Color(0xFF881337), // Deep Rose / Burgundy
    const Color(0xFF451A03), // Deep Roasted Coffee
    const Color(0xFF2196F3), // Electric Blue
  ];

  static const String _pwaBaseUrl = 'https://ngam.dev';

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _tableCtrl.dispose();
    _wifiSsidCtrl.dispose();
    _wifiPasswordCtrl.dispose();
    _promoCodeCtrl.dispose();
    _promoDiscountCtrl.dispose();
    _customTaglineCtrl.dispose();
    super.dispose();
  }

  void _loadBusinessProfile() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      if (profile != null && mounted) {
        setState(() {
          final profileName = profile['name']?.toString().trim();
          if (profileName != null && profileName.isNotEmpty) {
            _storeNameCtrl.text = profileName;
          }
          _businessId = profile['id']?.toString() ?? 'store';

          final settings = profile['settings'] as Map<String, dynamic>?;
          if (settings != null) {
            if (settings['wifi_ssid'] != null && settings['wifi_ssid'].toString().isNotEmpty) {
              _wifiSsidCtrl.text = settings['wifi_ssid'].toString();
            }
            if (settings['wifi_password'] != null && settings['wifi_password'].toString().isNotEmpty) {
              _wifiPasswordCtrl.text = settings['wifi_password'].toString();
            }
          }
        });
      }
    } catch (_) {}
  }

  void _saveWifiToProfile() async {
    final ssid = _wifiSsidCtrl.text.trim();
    final pass = _wifiPasswordCtrl.text.trim();
    try {
      await BusinessService().saveBusinessSettings(_businessId, {
        'wifi_ssid': ssid,
        'wifi_password': pass,
      });
      if (mounted) {
        showGlassToast(context, 'Maklumat WiFi kedai berjaya disimpan!');
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'WiFi dikemaskini pada paparan!');
      }
    }
  }

  String get _qrPayloadUrl {
    final encodedStore = Uri.encodeComponent(_businessId);
    switch (_selectedMode) {
      case QrMode.storefront:
        return '$_pwaBaseUrl/store/$encodedStore';
      case QrMode.table:
        final table = _tableCtrl.text.trim().isEmpty ? '1' : _tableCtrl.text.trim();
        return '$_pwaBaseUrl/store/$encodedStore?table=${Uri.encodeComponent(table)}';
      case QrMode.promo:
        final code = _promoCodeCtrl.text.trim().toUpperCase();
        return '$_pwaBaseUrl/store/$encodedStore?promo=${Uri.encodeComponent(code)}';
      case QrMode.wifi:
        final ssid = _wifiSsidCtrl.text.trim().replaceAll(';', r'\;').replaceAll(':', r'\:');
        final pass = _wifiPasswordCtrl.text.trim().replaceAll(';', r'\;').replaceAll(':', r'\:');
        return 'WIFI:T:WPA;S:$ssid;P:$pass;;';
      case QrMode.queue:
        return '$_pwaBaseUrl/queue/$encodedStore';
    }
  }

  Future<void> _captureAndSaveStandee() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _standeeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Kawasan paparan standee tidak dijumpai.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal menukar grafik kepada format PNG.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final modeName = _selectedMode.name.toUpperCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Ngam_Standee_${modeName}_$timestamp.png';

      // Cross-platform downloader (Uses Web Blob on Web, PathProvider on Mobile/Desktop)
      final savedPath = await downloadStandeeImage(
        bytes: pngBytes,
        fileName: fileName,
      );

      if (mounted) {
        showGlassToast(
          context,
          kIsWeb
              ? 'Standee HD berjaya dimuat turun ke folder Downloads anda!'
              : 'Standee HD berjaya disimpan!',
        );

        _showFileDownloadModal(
          pngBytes: pngBytes,
          title: _getModeTitle(),
          fileName: fileName,
          savedPath: savedPath,
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Ralat memuat turun standee: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _getModeTitle() {
    switch (_selectedMode) {
      case QrMode.storefront:
        return 'Standee Menu & Katalog Kedai';
      case QrMode.table:
        final t = _tableCtrl.text.trim().isEmpty ? '1' : _tableCtrl.text.trim();
        return 'Standee Meja #$t (Dine-in)';
      case QrMode.promo:
        return 'Standee Baucar & Diskaun Khas';
      case QrMode.wifi:
        return 'Standee Sambung WiFi Tetamu';
      case QrMode.queue:
        return 'Standee Giliran Pintar Walk-in';
    }
  }

  void _showFileDownloadModal({
    required Uint8List pngBytes,
    required String title,
    required String fileName,
    String? savedPath,
  }) {
    final double fileSizeKb = pngBytes.lengthInBytes / 1024.0;
    final String sizeStr = fileSizeKb > 1024
        ? '${(fileSizeKb / 1024).toStringAsFixed(2)} MB'
        : '${fileSizeKb.toStringAsFixed(1)} KB';

    final String locationDisplay = kIsWeb
        ? 'Tersimpan dalam folder Downloads pelayar web anda'
        : (savedPath ?? 'Tersimpan dalam memori peranti');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),

                // Success Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  kIsWeb
                      ? 'Fail imej resolusi tinggi (HD) telah dimuat turun ke komputer / peranti anda!'
                      : 'Fail imej resolusi tinggi sedia untuk dicetak atau dikongsi!',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Captured Image Preview Box
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      pngBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // File Path Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Saiz Fail:', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                          Text(sizeStr, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lokasi: ', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                          Expanded(
                            child: Text(
                              locationDisplay,
                              style: GoogleFonts.inter(color: const Color(0xFF42A5F5), fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    if (!kIsWeb && savedPath != null) ...[
                      // Open File Button (Mobile/Desktop)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final result = await OpenFilex.open(savedPath);
                            if (result.type != ResultType.done && mounted) {
                              showGlassToast(context, 'Membuka fail: ${result.message}');
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text('Buka Fail Sekarang', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      // Web Re-download Button
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            await downloadStandeeImage(bytes: pngBytes, fileName: fileName);
                            if (mounted) {
                              showGlassToast(context, 'Muat turun semula dimulakan!');
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text('Muat Turun Semula', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    // Copy URL Button
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _qrPayloadUrl));
                          showGlassToast(context, 'Pautan QR disalin!');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text('Salin Pautan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showColorPickerDialog({
    required String title,
    required String subtitle,
    required Color initialColor,
    required ValueChanged<Color> onSelected,
  }) {
    final hexCtrl = TextEditingController(
      text: initialColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );
    Color tempColor = initialColor;

    final List<Color> extendedPalette = [
      const Color(0xFF0F172A), // Dark Slate
      const Color(0xFF000000), // Pure Black
      const Color(0xFF2196F3), // Ngam Blue
      const Color(0xFF6C5CE7), // Ngam Purple
      const Color(0xFF10B981), // Emerald Mint
      const Color(0xFFF59E0B), // Amber Gold
      const Color(0xFFEC4899), // Neon Pink
      const Color(0xFFEF4444), // Coral Red
      const Color(0xFF8B5CF6), // Royal Violet
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF14B8A6), // Deep Teal
      const Color(0xFF1E3A8A), // Deep Navy
      const Color(0xFF065F46), // Deep Green
      const Color(0xFF581C87), // Deep Purple
      const Color(0xFF881337), // Deep Rose
      const Color(0xFF451A03), // Deep Coffee
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: tempColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: tempColor.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Extended Palette Grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: extendedPalette.map((c) {
                        final isSelected = c.toARGB32() == tempColor.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempColor = c;
                              hexCtrl.text = c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(color: Colors.white24, width: 1),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Manual HEX Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hexCtrl,
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            decoration: InputDecoration(
                              labelText: 'Kod Warna HEX',
                              labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                              prefixText: '# ',
                              prefixStyle: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                              filled: true,
                              fillColor: const Color(0xFF0F0F1B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
                            ),
                            onChanged: (val) {
                              final clean = val.replaceAll('#', '').trim();
                              if (clean.length == 6) {
                                final parsed = int.tryParse('0xFF$clean');
                                if (parsed != null) {
                                  setModalState(() {
                                    tempColor = Color(parsed);
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: tempColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tempColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          onSelected(tempColor);
                          Navigator.pop(ctx);
                        },
                        child: Text('Gunakan Warna Ini', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomColorPicker() {
    _showColorPickerDialog(
      title: 'Pilih Warna Aksen Standee',
      subtitle: 'Pilih tema jenama anda atau masukkan kod HEX.',
      initialColor: _accentColor,
      onSelected: (color) {
        setState(() {
          _accentColor = color;
          if (!_colorOptions.any((c) => c.toARGB32() == color.toARGB32())) {
            _colorOptions.insert(0, color);
          }
        });
        showGlassToast(context, 'Warna tema standee dikemaskini!');
      },
    );
  }

  void _showCustomQrColorPicker() {
    _showColorPickerDialog(
      title: 'Pilih Warna Kod QR (Petak)',
      subtitle: 'Pilih warna untuk petak QR code (disyorkan warna berkontras tinggi).',
      initialColor: _qrColor,
      onSelected: (color) {
        setState(() {
          _qrColor = color;
          if (!_qrColorOptions.any((c) => c.toARGB32() == color.toARGB32())) {
            _qrColorOptions.insert(0, color);
          }
        });
        showGlassToast(context, 'Warna kod QR dikemaskini!');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR & Standee Generator',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Menu, Meja, WiFi & Baucar Standee HD',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload04, color: Color(0xFF42A5F5), size: 22),
            tooltip: 'Muat Turun Standee',
            onPressed: _captureAndSaveStandee,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;

          if (isWide) {
            // ─── LANDSCAPE / WIDE DISPLAY (2-Column Layout) ───
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: All Controls & Customization Cards
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 24, right: 20, top: 20, bottom: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModeSelector(),
                        const SizedBox(height: 20),
                        _buildStoreNameCustomizerCard(),
                        const SizedBox(height: 16),
                        if (_selectedMode == QrMode.table) ...[
                          _buildTableCustomizerCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildWifiCustomizerCard(),
                        const SizedBox(height: 16),
                        if (_selectedMode == QrMode.promo || _includePromoBadge) ...[
                          _buildPromoCustomizerCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildModularTogglesCard(),
                        const SizedBox(height: 16),
                        _buildBrandingAndColorsCard(),
                      ],
                    ),
                  ),
                ),

                // Subtle Vertical Divider
                Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),

                // Right Column: Standee Live Preview & Action Buttons
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildPreviewHeader(),
                        const SizedBox(height: 20),
                        _buildStandeePreview(),
                        const SizedBox(height: 24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: _buildActionButtons(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            // ─── PORTRAIT / MOBILE DISPLAY (Neat Stacked Layout) ───
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeSelector(),
                  const SizedBox(height: 20),
                  Center(child: _buildStandeePreview()),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildStoreNameCustomizerCard(),
                  const SizedBox(height: 16),
                  if (_selectedMode == QrMode.table) ...[
                    _buildTableCustomizerCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildWifiCustomizerCard(),
                  const SizedBox(height: 16),
                  if (_selectedMode == QrMode.promo || _includePromoBadge) ...[
                    _buildPromoCustomizerCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildModularTogglesCard(),
                  const SizedBox(height: 16),
                  _buildBrandingAndColorsCard(),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Pratonton Langsung Standee Meja',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: _isDownloading ? null : _captureAndSaveStandee,
            icon: _isDownloading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(
              _isDownloading ? 'Menjana Fail...' : 'Muat Turun Standee (HD)',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _qrPayloadUrl));
            showGlassToast(context, 'Pautan QR disalin ke papan klip!');
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: Text('Salin URL', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStandeePreview() {
    return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: RepaintBoundary(
                  key: _standeeKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.18),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Brand Accent Bar (Modern Acrylic Aesthetic)
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Header Badge with Dot Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accentColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getHeaderBadgeText().toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: _accentColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Store Title (Live from Controller)
                        Text(
                          _storeNameCtrl.text.trim().isEmpty ? 'Kedai Saya' : _storeNameCtrl.text.trim(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF0F172A),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Table Badge (if table mode) — Supports Custom Table Number/Name
                        if (_selectedMode == QrMode.table)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _tableCtrl.text.trim().toUpperCase().startsWith('MEJA') ||
                                      _tableCtrl.text.trim().toUpperCase().startsWith('TABLE')
                                  ? _tableCtrl.text.trim().toUpperCase()
                                  : 'TABLE ${_tableCtrl.text.trim().toUpperCase()}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),

                        // Promo Badge (if promo mode or toggle on)
                        if (_selectedMode == QrMode.promo || _includePromoBadge)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer_rounded, color: Color(0xFFD97706), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'KOD: ${_promoCodeCtrl.text.toUpperCase()} (${_promoDiscountCtrl.text})',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Custom Tagline Badge (if enabled)
                        if (_includeCustomTagline && _customTaglineCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 6),
                            child: Text(
                              _customTaglineCtrl.text,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF475569),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Standard Square QR Code Frame
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: QrImageView(
                            data: _qrPayloadUrl,
                            version: QrVersions.auto,
                            size: 190.0,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: _qrColor,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: _qrColor,
                            ),
                          ),
                        ),

                        // Instructions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              _getInstructionText(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // WiFi Badge (if enabled or if mode is wifi)
                        if (_includeWifi || _selectedMode == QrMode.wifi)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi, size: 14, color: Color(0xFF334155)),
                                const SizedBox(width: 6),
                                Text(
                                  'WiFi: ${_wifiSsidCtrl.text}  |  Pass: ${_wifiPasswordCtrl.text}',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF334155),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),

                        // ─── Footer: Powered by Ngam with Splash Icon (Bucu Lembut) ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5.5),
                              child: Image.asset(
                                'assets/splash.png',
                                width: 19,
                                height: 19,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 19,
                                  height: 19,
                                  decoration: BoxDecoration(
                                    color: _accentColor,
                                    borderRadius: BorderRadius.circular(5.5),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'N',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Powered by Ngam',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
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

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Pilih Mod Kod QR Standee',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModeChip(QrMode.storefront, 'Storefront', HugeIcons.strokeRoundedStore01),
              const SizedBox(width: 8),
              _buildModeChip(QrMode.table, 'Meja Dine-in', HugeIcons.strokeRoundedRestaurant01),
              const SizedBox(width: 8),
              _buildModeChip(QrMode.promo, 'Kod Promo', HugeIcons.strokeRoundedCoupon02),
              const SizedBox(width: 8),
              _buildModeChip(QrMode.wifi, 'Auto WiFi', HugeIcons.strokeRoundedWifi01),
              const SizedBox(width: 8),
              _buildModeChip(QrMode.queue, 'Giliran Walk-in', HugeIcons.strokeRoundedTicket01),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required dynamic icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    Color? focusColor,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: (val) {
            setState(() {});
            if (onChanged != null) onChanged(val);
          },
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: icon is IconData
                  ? Icon(icon, color: Colors.white54, size: 20)
                  : HugeIcon(icon: icon, color: Colors.white54, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: focusColor ?? const Color(0xFF42A5F5), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernSwitchTile({
    required String title,
    required String subtitle,
    required dynamic icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? _accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? effectiveColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? effectiveColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: value
                  ? effectiveColor.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon is IconData
                ? Icon(icon, color: value ? effectiveColor : Colors.white54, size: 18)
                : HugeIcon(icon: icon, color: value ? effectiveColor : Colors.white54, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: effectiveColor,
            activeTrackColor: effectiveColor.withValues(alpha: 0.4),
            inactiveThumbColor: Colors.white60,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(QrMode mode, String label, dynamic icon) {
    final isSel = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? _accentColor : const Color(0xFF141424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSel ? _accentColor : Colors.white12),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: isSel ? Colors.white : Colors.white60,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSel ? Colors.white : Colors.white70,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreNameCustomizerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF42A5F5), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama Kedai pada Standee',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nama ini dipaparkan terus di bahagian atas standee fizikal kedai anda.',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Nama Kedai / Jenama',
            controller: _storeNameCtrl,
            icon: Icons.edit_note_rounded,
            hint: 'Contoh: Warung Kopi Bangi / Barber Chop',
          ),
        ],
      ),
    );
  }

  Widget _buildTableCustomizerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF42A5F5), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombor & Nama Meja',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Taip sebarang nombor atau nama meja (cth: 1, 12, A-04, VIP 1).',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInputField(
            label: 'Nombor / Nama Meja',
            controller: _tableCtrl,
            icon: Icons.tag_rounded,
            hint: 'Contoh: 1, 14, A-02, VIP',
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Pilihan Pantas (Tekan untuk set terus):',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickTablePresets.length,
              itemBuilder: (ctx, idx) {
                final preset = _quickTablePresets[idx];
                final isSelected = _tableCtrl.text.trim().toUpperCase() == preset.toUpperCase();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tableCtrl.text = preset;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? _accentColor : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _accentColor : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        preset,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderBadgeText() {
    switch (_selectedMode) {
      case QrMode.storefront:
        return 'Scan To Browse & Order';
      case QrMode.table:
        return 'Dine-In Table Order';
      case QrMode.promo:
        return 'Special Promo Voucher';
      case QrMode.wifi:
        return 'Free Guest Wi-Fi Access';
      case QrMode.queue:
        return 'Smart Walk-In Queue';
    }
  }

  String _getInstructionText() {
    switch (_selectedMode) {
      case QrMode.wifi:
        return 'Halakan kamera telefon untuk sambung WiFi';
      case QrMode.promo:
        return 'Imbas kamera untuk tebus tawaran ini';
      case QrMode.queue:
        return 'Imbas kamera untuk ambil giliran walk-in';
      case QrMode.table:
        return 'Imbas kamera untuk pesan terus ke meja';
      case QrMode.storefront:
        return 'Halakan kamera telefon anda untuk memesan';
    }
  }

  Widget _buildWifiCustomizerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi_rounded, color: Color(0xFF42A5F5), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tetapan WiFi Kedai',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _saveWifiToProfile,
                icon: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF42A5F5)),
                label: Text('Simpan', style: GoogleFonts.inter(color: const Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInputField(
            label: 'Nama Rangkaian (SSID)',
            controller: _wifiSsidCtrl,
            icon: Icons.router_rounded,
            hint: 'Contoh: Cafe_Guest_WiFi',
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Kata Laluan WiFi (Password)',
            controller: _wifiPasswordCtrl,
            icon: Icons.lock_outline_rounded,
            hint: 'Masukkan kata laluan WiFi',
            obscureText: _obscureWifiPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureWifiPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
              onPressed: () => setState(() => _obscureWifiPassword = !_obscureWifiPassword),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCustomizerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.discount_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Tetapan Kod Promo & Baucar',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInputField(
            label: 'Kod Promosi',
            controller: _promoCodeCtrl,
            icon: Icons.qr_code_rounded,
            hint: 'Contoh: NGAM10 / RAYA26',
            focusColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 14),

          _buildInputField(
            label: 'Keterangan Diskaun',
            controller: _promoDiscountCtrl,
            icon: Icons.info_outline_rounded,
            hint: 'Contoh: 10% OFF Semua Item',
            focusColor: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildModularTogglesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedToggleOn, color: _accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Modul & Kandungan Tambahan Standee',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildModernSwitchTile(
            title: 'Papar Maklumat WiFi Tetamu',
            subtitle: 'SSID: ${_wifiSsidCtrl.text.isEmpty ? "Belum diisi" : _wifiSsidCtrl.text}',
            icon: HugeIcons.strokeRoundedWifi01,
            value: _includeWifi,
            onChanged: (val) => setState(() => _includeWifi = val),
          ),

          _buildModernSwitchTile(
            title: 'Papar Banner Promosi Khas',
            subtitle: 'Kod: ${_promoCodeCtrl.text.isEmpty ? "Tiada kod" : _promoCodeCtrl.text}',
            icon: HugeIcons.strokeRoundedCoupon02,
            value: _includePromoBadge,
            onChanged: (val) => setState(() => _includePromoBadge = val),
          ),

          _buildModernSwitchTile(
            title: 'Papar Tagline / Mesej Khas',
            subtitle: _customTaglineCtrl.text.isEmpty ? 'Tulis mesej atau ucapan khas' : _customTaglineCtrl.text,
            icon: HugeIcons.strokeRoundedMessage01,
            value: _includeCustomTagline,
            onChanged: (val) => setState(() => _includeCustomTagline = val),
          ),

          if (_includeCustomTagline) ...[
            const SizedBox(height: 8),
            _buildInputField(
              label: 'Teks Tagline / Mesej Standee',
              controller: _customTaglineCtrl,
              icon: Icons.chat_bubble_outline_rounded,
              hint: 'Contoh: Selamat Menikmati Hidangan!',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrandingAndColorsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_rounded, color: Color(0xFF42A5F5), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Penjenamaan & Warna',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Warna Tema Standee',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: _showCustomColorPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${_accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                        style: GoogleFonts.inter(color: _accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 12, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._colorOptions.map((c) {
                final isSelected = c.toARGB32() == _accentColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _accentColor = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2.5) : Border.all(color: Colors.white24),
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                  ),
                );
              }),
              GestureDetector(
                onTap: _showCustomColorPicker,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                  ),
                  child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF42A5F5)),
                ),
              ),
            ],
          ),

          const Divider(height: 32, color: Colors.white10),

          // ─── 2. Warna Kod QR (Petak Standard) ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Warna Kod QR (Petak Standard)',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: _showCustomQrColorPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _qrColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _qrColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _qrColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${_qrColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 12, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih warna untuk petak kod QR (disyorkan warna gelap berkontras tinggi agar mudah diimbas).',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11.5),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._qrColorOptions.map((c) {
                final isSelected = c.toARGB32() == _qrColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _qrColor = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2.5)
                          : Border.all(color: Colors.white24),
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                  ),
                );
              }),
              GestureDetector(
                onTap: _showCustomQrColorPicker,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                  ),
                  child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF42A5F5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
