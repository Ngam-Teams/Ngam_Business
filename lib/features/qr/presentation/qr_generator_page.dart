import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// ============================================================
// QrGeneratorPage — Storefront, Table, WiFi & Promo QR Standee Generator
// ============================================================

enum QrMode { storefront, table, promo, wifi, queue }

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  QrMode _selectedMode = QrMode.storefront;
  int _tableNumber = 1;
  final int _totalTables = 15;

  String _storeName = 'Kedai Saya';
  String _businessId = 'store';

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

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  @override
  void dispose() {
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
          _storeName = profile['name'] ?? 'Kedai Saya';
          _businessId = profile['id'] ?? 'store';
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

  Color _accentColor = const Color(0xFF6C5CE7);
  final List<Color> _colorOptions = [
    const Color(0xFF6C5CE7), // Ngam Purple
    const Color(0xFF42A5F5), // Electric Blue
    const Color(0xFF10B981), // Emerald Mint
    const Color(0xFFF59E0B), // Amber Gold
    const Color(0xFFEC4899), // Neon Pink
  ];

  static const String _pwaBaseUrl = 'https://ngam.pages.dev';

  String get _qrPayloadUrl {
    switch (_selectedMode) {
      case QrMode.storefront:
        return '$_pwaBaseUrl/store/$_businessId';
      case QrMode.table:
        return '$_pwaBaseUrl/store/$_businessId?table=$_tableNumber';
      case QrMode.promo:
        final code = _promoCodeCtrl.text.trim().toUpperCase();
        return '$_pwaBaseUrl/store/$_businessId?promo=$code';
      case QrMode.wifi:
        final ssid = _wifiSsidCtrl.text.trim().replaceAll(';', r'\;').replaceAll(':', r'\:');
        final pass = _wifiPasswordCtrl.text.trim().replaceAll(';', r'\;').replaceAll(':', r'\:');
        return 'WIFI:T:WPA;S:$ssid;P:$pass;;';
      case QrMode.queue:
        return '$_pwaBaseUrl/queue/$_businessId';
    }
  }

  Future<void> _captureAndSaveStandee() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 120));

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
      final dir = await getApplicationDocumentsDirectory();
      final modeName = _selectedMode.name.toUpperCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Ngam_Standee_${modeName}_$timestamp.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        _showFileDownloadModal(
          file: file,
          title: _getModeTitle(),
          pngBytes: pngBytes,
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
        return 'Standee Meja #$_tableNumber (Dine-in)';
      case QrMode.promo:
        return 'Standee Baucar & Diskaun Khas';
      case QrMode.wifi:
        return 'Standee Sambung WiFi Tetamu';
      case QrMode.queue:
        return 'Standee Giliran Pintar Walk-in';
    }
  }

  void _showFileDownloadModal({
    required File file,
    required String title,
    required Uint8List pngBytes,
  }) {
    final double fileSizeKb = file.lengthSync() / 1024.0;
    final String sizeStr = fileSizeKb > 1024
        ? '${(fileSizeKb / 1024).toStringAsFixed(2)} MB'
        : '${fileSizeKb.toStringAsFixed(1)} KB';

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
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fail imej resolusi tinggi sedia untuk dicetak atau dikongsi!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
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
                          const Text('Saiz Fail:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(sizeStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lokasi: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          Expanded(
                            child: Text(
                              file.path,
                              style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 11),
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
                    // Open File Button
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
                          final result = await OpenFilex.open(file.path);
                          if (result.type != ResultType.done && mounted) {
                            showGlassToast(context, 'Membuka fail: ${result.message}');
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Buka Fail Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),

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
                        label: const Text('Salin Pautan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

  void _showCustomColorPicker() {
    final hexCtrl = TextEditingController(
      text: _accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );
    Color tempColor = _accentColor;

    final List<Color> extendedPalette = [
      const Color(0xFF6C5CE7), // Ngam Purple
      const Color(0xFF42A5F5), // Electric Blue
      const Color(0xFF10B981), // Emerald Mint
      const Color(0xFFF59E0B), // Amber Gold
      const Color(0xFFEC4899), // Neon Pink
      const Color(0xFFEF4444), // Coral Red
      const Color(0xFF8B5CF6), // Royal Violet
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF14B8A6), // Deep Teal
      const Color(0xFFF97316), // Sunset Orange
      const Color(0xFFE11D48), // Crimson Rose
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF84CC16), // Lime Green
      const Color(0xFF0EA5E9), // Sky Blue
      const Color(0xFFA855F7), // Purple Orchid
      const Color(0xFFD946EF), // Fuchsia
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
                        const Text(
                          'Pilih Warna Aksen Standee',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                      'Pilih tema jenama anda atau masukkan kod HEX.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: extendedPalette.map((c) {
                        final isSel = c.toARGB32() == tempColor.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempColor = c;
                              hexCtrl.text = c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSel
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              boxShadow: isSel
                                  ? [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSel ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hexCtrl,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            maxLength: 6,
                            decoration: InputDecoration(
                              counterText: '',
                              prefixText: '# ',
                              prefixStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                              hintText: '6C5CE7',
                              hintStyle: const TextStyle(color: Colors.white24),
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
                          setState(() {
                            _accentColor = tempColor;
                            if (!_colorOptions.any((c) => c.toARGB32() == tempColor.toARGB32())) {
                              _colorOptions.insert(0, tempColor);
                            }
                          });
                          Navigator.pop(ctx);
                          showGlassToast(context, 'Warna tema standee dikemaskini!');
                        },
                        child: const Text('Gunakan Warna Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR & Standee Generator',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Menu, Meja, WiFi & Baucar Standee',
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selector (5 Modes)
            const Text(
              'Pilih Mod Kod QR',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 24),

            // Standee Live Preview Card (Wrapped with RepaintBoundary for REAL export)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: RepaintBoundary(
                  key: _standeeKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with Brand Color
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getHeaderBadgeText(),
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Store Title
                        Text(
                          _storeName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Table Badge (if table mode)
                        if (_selectedMode == QrMode.table)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'TABLE $_tableNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
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
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
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
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
                              style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // QR Code Rendering Block
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
                              color: _accentColor,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),

                        // Instructions
                        Text(
                          _getInstructionText(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Powered by Ngam badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('N', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Powered by Ngam App',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Table Selection Controls (if Table Mode)
            if (_selectedMode == QrMode.table) ...[
              const Text(
                'Pilih Nombor Meja',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalTables,
                  itemBuilder: (ctx, idx) {
                    final tNum = idx + 1;
                    final isSel = tNum == _tableNumber;
                    return GestureDetector(
                      onTap: () => setState(() => _tableNumber = tNum),
                      child: Container(
                        width: 52,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSel ? _accentColor : const Color(0xFF141424),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? _accentColor : Colors.white12,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '#$tNum',
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Editable WiFi Settings Section
            _buildWifiCustomizerCard(),
            const SizedBox(height: 20),

            // Editable Promo Code Section
            if (_selectedMode == QrMode.promo || _includePromoBadge) ...[
              _buildPromoCustomizerCard(),
              const SizedBox(height: 20),
            ],

            // Modular Standee Toggles Card
            _buildModularTogglesCard(),
            const SizedBox(height: 20),

            // Standee Branding & Color Picker Card
            _buildBrandingAndColorsCard(),
            const SizedBox(height: 28),

            // Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isDownloading ? null : _captureAndSaveStandee,
                    icon: _isDownloading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _isDownloading ? 'Menjana Fail...' : 'Muat Turun Standee (HD)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  label: const Text('Salin URL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
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
              style: TextStyle(
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

  String _getHeaderBadgeText() {
    switch (_selectedMode) {
      case QrMode.storefront:
        return 'SCAN TO BROWSE & ORDER';
      case QrMode.table:
        return 'DINE-IN ORDERING';
      case QrMode.promo:
        return 'SCAN FOR SPECIAL PROMO';
      case QrMode.wifi:
        return 'FREE GUEST WI-FI ACCESS';
      case QrMode.queue:
        return 'SMART WALK-IN QUEUE';
    }
  }

  String _getInstructionText() {
    switch (_selectedMode) {
      case QrMode.wifi:
        return 'Halakan kamera telefon untuk sambung ke WiFi kedai';
      case QrMode.promo:
        return 'Imbas kamera untuk tebus tawaran diskaun ini';
      case QrMode.queue:
        return 'Imbas kamera untuk ambil giliran walk-in';
      case QrMode.table:
        return 'Imbas untuk lihat menu & pesan terus ke meja anda';
      case QrMode.storefront:
        return 'Point your phone camera to order';
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
              const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Color(0xFF42A5F5), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Tetapan WiFi Kedai (Boleh Ubah)',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: _saveWifiToProfile,
                child: const Text('Simpan', style: TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // SSID Field
          TextField(
            controller: _wifiSsidCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nama Rangkaian (SSID)',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.router_rounded, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
            ),
          ),
          const SizedBox(height: 10),

          // Password Field
          TextField(
            controller: _wifiPasswordCtrl,
            obscureText: _obscureWifiPassword,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Kata Laluan WiFi (Password)',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureWifiPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                onPressed: () => setState(() => _obscureWifiPassword = !_obscureWifiPassword),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
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
          const Row(
            children: [
              Icon(Icons.discount_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Tetapan Kod Promo & Baucar',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Promo Code Field
          TextField(
            controller: _promoCodeCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            decoration: InputDecoration(
              labelText: 'Kod Promosi (cth: NGAM10 / RAYA26)',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.qr_code_rounded, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
            ),
          ),
          const SizedBox(height: 10),

          // Discount Description Field
          TextField(
            controller: _promoDiscountCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Keterangan Diskaun (cth: 10% OFF Semua Item)',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
            ),
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
          const Text(
            'Modul & Kandungan Tambahan Standee',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Papar Maklumat WiFi Tetamu', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('SSID: ${_wifiSsidCtrl.text}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            value: _includeWifi,
            activeColor: _accentColor,
            onChanged: (val) => setState(() => _includeWifi = val),
          ),
          const Divider(height: 16, color: Colors.white10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Papar Banner Promosi Khas', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Kod: ${_promoCodeCtrl.text}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            value: _includePromoBadge,
            activeColor: _accentColor,
            onChanged: (val) => setState(() => _includePromoBadge = val),
          ),
          const Divider(height: 16, color: Colors.white10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Papar Tagline / Mesej Khas', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(_customTaglineCtrl.text, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            value: _includeCustomTagline,
            activeColor: _accentColor,
            onChanged: (val) => setState(() => _includeCustomTagline = val),
          ),

          if (_includeCustomTagline) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customTaglineCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tulis mesej khas anda...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Warna Tema Standee',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
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
                        style: TextStyle(color: _accentColor, fontSize: 11, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}
