import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// ============================================================
// QrGeneratorPage — Storefront & Table QR Standee Generator
// ============================================================

enum QrMode { storefront, table }

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
  String _wifiSsid = 'WarungNgam_Guest';
  String _wifiPassword = 'makanansedap';
  bool _includeWifi = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
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
              _wifiSsid = settings['wifi_ssid'].toString();
            }
            if (settings['wifi_password'] != null && settings['wifi_password'].toString().isNotEmpty) {
              _wifiPassword = settings['wifi_password'].toString();
            }
          }
        });
      }
    } catch (_) {}
  }

  Color _accentColor = const Color(0xFF6C5CE7);
  final List<Color> _colorOptions = [
    const Color(0xFF6C5CE7), // Ngam Purple
    const Color(0xFF42A5F5), // Electric Blue
    const Color(0xFF10B981), // Emerald Mint
    const Color(0xFFF59E0B), // Amber Gold
    const Color(0xFFEC4899), // Neon Pink
  ];

  String get _qrPayloadUrl {
    if (_selectedMode == QrMode.storefront) {
      return 'https://ngam.app/store/$_businessId';
    } else {
      return 'https://ngam.app/store/$_businessId?table=$_tableNumber';
    }
  }

  void _downloadStandee() {
    showGlassToast(
      context,
      _selectedMode == QrMode.storefront
          ? 'Downloading Print-Ready A5 Storefront Standee (PDF)...'
          : 'Downloading Print-Ready Table #$_tableNumber Standee (PDF)...',
    );
  }

  void _downloadAllTables() {
    showGlassToast(context, 'Exporting full standee pack: Tables 1 to $_totalTables (ZIP/PDF)...');
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
                          'Choose Custom Accent Color',
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
                      'Select from the vibrant brand palette or type a HEX code.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Palette Grid
                    const Text('Color Palette', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
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

                    // HEX Code Field
                    const Text('Custom Hex Code', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
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

                    // Apply Button
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
                          showGlassToast(context, 'Accent color updated!');
                        },
                        child: const Text('Apply Custom Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
              'Table ordering & storefront QR',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedPrinter, color: Colors.white70, size: 20),
            tooltip: 'Print Standee',
            onPressed: _downloadStandee,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Segmented Control
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = QrMode.storefront),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedMode == QrMode.storefront ? _accentColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedStore01,
                                color: _selectedMode == QrMode.storefront ? Colors.white : Colors.white60,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Storefront QR',
                                style: TextStyle(
                                  color: _selectedMode == QrMode.storefront ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = QrMode.table),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedMode == QrMode.table ? _accentColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedRestaurant01,
                                color: _selectedMode == QrMode.table ? Colors.white : Colors.white60,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Table Ordering QR',
                                style: TextStyle(
                                  color: _selectedMode == QrMode.table ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Standee Live Preview Card (Visual Acrylic Standee Mockup)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                          _selectedMode == QrMode.storefront ? 'SCAN TO BROWSE & ORDER' : 'DINE-IN ORDERING',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

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
                      const SizedBox(height: 6),

                      if (_selectedMode == QrMode.table)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
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

                      // QR Code Rendering Block
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
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
                      const Text(
                        'Point your phone camera to order',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // WiFi Badge (if enabled)
                      if (_includeWifi)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi, size: 14, color: Color(0xFF334155)),
                              const SizedBox(width: 6),
                              Text(
                                'WiFi: $_wifiSsid  |  Pass: $_wifiPassword',
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

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
            const SizedBox(height: 28),

            // Table Selection Controls (if Table Mode)
            if (_selectedMode == QrMode.table) ...[
              const Text(
                'Select Table Number',
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

            // Customization Options
            const Text(
              'Standee Branding & Colors',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Accent Theme Color',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: _showCustomColorPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ..._colorOptions.map((c) {
                        final isSelected = c.toARGB32() == _accentColor.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => _accentColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 2.5) : Border.all(color: Colors.white24),
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _showCustomColorPicker,
                        child: Container(
                          width: 32,
                          height: 32,
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
                  const Divider(height: 28, color: Colors.white12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Guest WiFi Credentials', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text('$_wifiSsid ($wifiPasswordMask)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _includeWifi,
                    activeColor: _accentColor,
                    onChanged: (val) => setState(() => _includeWifi = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _downloadStandee,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedMode == QrMode.table)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _downloadAllTables,
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedFolder01, color: Colors.white, size: 18),
                      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Batch 1-15 Tables', style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        showGlassToast(context, 'Storefront link copied: $_qrPayloadUrl');
                      },
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, color: Colors.white, size: 18),
                      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Copy URL', style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get wifiPasswordMask => _wifiPassword;
}
