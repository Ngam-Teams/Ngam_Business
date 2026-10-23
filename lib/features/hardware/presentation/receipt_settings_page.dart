import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// =============================================================================
// ReceiptSettingsPage — Thermal Printer & Dynamic Receipt Customizer Studio
// Modul Pengurusan Resit & Penyesuaian Penuh Resit Terma (58mm / 80mm)
// =============================================================================

enum DividerStyle { dashed, dotted, solidDouble, stars }
enum BottomCodeType { qrReceipt, qrPromo, qrWifi, barcode, none }
enum LogoSize { small, medium, large }

class ReceiptSettingsPage extends StatefulWidget {
  const ReceiptSettingsPage({super.key});

  @override
  State<ReceiptSettingsPage> createState() => _ReceiptSettingsPageState();
}

class _ReceiptSettingsPageState extends State<ReceiptSettingsPage> {
  // Printer connection state
  final String _selectedPrinter = 'Sunmi V2 Built-in Thermal';
  bool _isConnected = true;
  bool _autoPrintOnOrder = true;
  bool _autoCutPaper = true;
  int _paperWidth = 80; // 58mm or 80mm

  // Layout & Alignment Customization
  TextAlign _headerAlign = TextAlign.center;
  DividerStyle _dividerStyle = DividerStyle.dashed;
  LogoSize _logoSize = LogoSize.medium;

  // Logo & Branding
  bool _includeLogo = true;
  String _logoUrl = '';
  Uint8List? _customLogoBytes;

  // Receipt Content Controllers
  final _storeNameCtrl = TextEditingController(text: 'WARUNG NGAM MELAKA');
  final _taglineCtrl = TextEditingController(text: 'Port Santai Makanan & Kopi Padu');
  final _ssmCtrl = TextEditingController(text: 'SSM: 202401039821 (1560944-X)');
  final _sstCtrl = TextEditingController(text: 'SST ID: W10-1808-32000456');
  final _addressCtrl = TextEditingController(text: 'No 45, Jalan Hang Tuah, Bandar Hilir, Melaka');
  final _phoneCtrl = TextEditingController(text: '+60 17-234 5678');
  final _socialCtrl = TextEditingController(text: 'IG/TikTok: @warungngam');
  final _footerMsgCtrl = TextEditingController(text: 'Terima kasih daun keladi, sudilah datang lagi!');
  final _policyCtrl = TextEditingController(text: 'Sah untuk pertukaran dalam 3 hari bersama resit asal.');

  // Info Visibility Toggles
  bool _showTagline = true;
  bool _showSsm = true;
  bool _showSst = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showSocial = true;

  // Transaction & Finance Toggles
  bool _showTableNo = true;
  bool _showCashier = true;
  bool _showDateTime = true;
  bool _showSstTax = true;
  bool _showServiceCharge = false;
  bool _showRounding = true;
  bool _showPaymentMethod = true;

  // Bottom Code Selector
  BottomCodeType _bottomCode = BottomCodeType.qrReceipt;
  bool _enableWhatsappReceipt = true;

  // Real Receipt Image Capture
  final GlobalKey _receiptKey = GlobalKey();
  bool _isDownloadingReceipt = false;

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
          final profileName = (profile['business_name'] ?? profile['name'])?.toString().trim();
          if (profileName != null && profileName.isNotEmpty) {
            _storeNameCtrl.text = profileName.toUpperCase();
          }
          final logo = (profile['business_logo_url'] ?? profile['logo_url'])?.toString().trim();
          if (logo != null && logo.isNotEmpty) {
            _logoUrl = logo;
          }
          final addr = (profile['address_line'] ?? profile['business_city'])?.toString().trim();
          if (addr != null && addr.isNotEmpty) {
            _addressCtrl.text = addr;
          }
          final phone = (profile['business_phone'] ?? profile['phone'])?.toString().trim();
          if (phone != null && phone.isNotEmpty) {
            _phoneCtrl.text = phone;
          }
          final ssm = profile['ssm_number']?.toString().trim();
          if (ssm != null && ssm.isNotEmpty) {
            _ssmCtrl.text = 'SSM: $ssm';
          }
          final sst = profile['sst_id']?.toString().trim();
          if (sst != null && sst.isNotEmpty) {
            _sstCtrl.text = 'SST ID: $sst';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickCustomLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _customLogoBytes = bytes;
          _includeLogo = true;
        });
        showGlassToast(context, 'Logo resit berjaya dikemaskini!');
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memilih logo: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _taglineCtrl.dispose();
    _ssmCtrl.dispose();
    _sstCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _socialCtrl.dispose();
    _footerMsgCtrl.dispose();
    _policyCtrl.dispose();
    super.dispose();
  }

  void _printTestReceipt() {
    showGlassToast(context, 'Menghantar cetakan ujian ke $_selectedPrinter (${_paperWidth}mm)...');
  }

  Future<void> _captureAndSaveReceipt() async {
    if (_isDownloadingReceipt) return;
    setState(() => _isDownloadingReceipt = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Kawasan paparan resit tidak dijumpai');

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Gagal menukar grafik kepada fail imej');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Ngam_Resit_${_paperWidth}mm_$timestamp.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        _showReceiptDownloadModal(file, pngBytes);
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Ralat memuat turun resit: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingReceipt = false);
      }
    }
  }

  void _showReceiptDownloadModal(File file, Uint8List pngBytes) {
    final double fileSizeKb = file.lengthSync() / 1024.0;
    final String sizeStr = '${fileSizeKb.toStringAsFixed(1)} KB';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Resit Digital Berjaya Dijana! 🧾',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Fail grafik resit resolusi tinggi sedia untuk dicetak atau dikongsi.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(pngBytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saiz Fail:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(sizeStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final result = await OpenFilex.open(file.path);
                    if (result.type != ResultType.done && mounted) {
                      showGlassToast(context, 'Membuka fail: ${result.message}');
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Buka Fail Imej Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
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
              'Studio Resit & Pencetak Terma',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Kustomisasi penuh susun atur, logo kedai & garisan pemisah dinamik',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload04, color: Color(0xFF42A5F5), size: 20),
            tooltip: 'Muat Turun Resit Digital (HD)',
            onPressed: _isDownloadingReceipt ? null : _captureAndSaveReceipt,
          ),
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedPrinter, color: Color(0xFF44CF6C), size: 22),
            tooltip: 'Uji Cetak Resit',
            onPressed: _printTestReceipt,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 880;

          if (isWide) {
            // ─── LANDSCAPE / DUAL COLUMN LAYOUT ───
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: All Controls & Customization Cards (Flex 6)
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 24, right: 20, top: 16, bottom: 40),
                    child: _buildControlsColumn(),
                  ),
                ),

                // Vertical Divider
                Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),

                // Right Column: Interactive Live Receipt Preview (Flex 5, Sticky/Centered)
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFF07070F),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                'Pratonton Resit Fizikal (${_paperWidth}mm)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _paperWidth == 58
                                ? 'Mod 58mm: Garisan pemisah dinamik 32-kolum (muat penuh tanpa turun line kedua).'
                                : 'Mod 80mm: Garisan pemisah lebar 46-kolum standard F&B.',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _buildReceiptPaper(),
                          const SizedBox(height: 20),
                          _buildDownloadButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // ─── PORTRAIT / MOBILE LAYOUT ───
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildReceiptPaper(),
                const SizedBox(height: 16),
                _buildDownloadButton(),
                const SizedBox(height: 28),
                _buildControlsColumn(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // CONTROLS & SETTINGS COLUMN
  // ===========================================================================
  Widget _buildControlsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Paper Width Selector Card (58mm vs 80mm)
        _buildSectionHeader('1. Saiz Kertas Pencetak (Roll Width)', HugeIcons.strokeRoundedReceiptText),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildPaperWidthTab(
                width: 58,
                title: '58mm (2-Inci)',
                desc: 'Kompak, Bluetooth Mobile & Kiosk (32 Kolum Dinamik)',
                icon: Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaperWidthTab(
                width: 80,
                title: '80mm (3-Inci)',
                desc: 'Standard F&B, Kaunter POS & Resit Penuh (46 Kolum)',
                icon: Icons.receipt_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. Divider Style Customization (Dashed, Dotted, Solid Double, Stars)
        _buildSectionHeader('2. Gaya Garisan Pemisah (Divider Bars)', HugeIcons.strokeRoundedSlidersHorizontal),
        const SizedBox(height: 10),
        _buildDividerStyleSelector(),
        const SizedBox(height: 24),

        // 3. Logo & Store Branding Customization
        _buildSectionHeader('3. Logo & Penjenamaan Resit', HugeIcons.strokeRoundedImage01),
        const SizedBox(height: 10),
        _buildLogoCustomizerCard(),
        const SizedBox(height: 24),

        // 4. Alignment & Header Style
        _buildSectionHeader('4. Penjajaran Teks Kepala Resit', HugeIcons.strokeRoundedTextAlignCenter),
        const SizedBox(height: 10),
        _buildAlignmentSelector(),
        const SizedBox(height: 24),

        // 5. Store Info & Legal Details
        _buildSectionHeader('5. Maklumat Rasmi Kedai & Cukai', HugeIcons.strokeRoundedBuilding02),
        const SizedBox(height: 12),
        _buildTextField(controller: _storeNameCtrl, label: 'Nama Kedai / Syarikat (Kepala Resit)'),
        const SizedBox(height: 10),
        _buildTextFieldWithToggle(controller: _taglineCtrl, label: 'Slogan / Tagline Kedai', value: _showTagline, onChanged: (v) => setState(() => _showTagline = v)),
        const SizedBox(height: 10),
        _buildTextFieldWithToggle(controller: _ssmCtrl, label: 'No. Pendaftaran Syarikat (SSM)', value: _showSsm, onChanged: (v) => setState(() => _showSsm = v)),
        const SizedBox(height: 10),
        _buildTextFieldWithToggle(controller: _sstCtrl, label: 'No. Cukai SST (Jika Berdaftar)', value: _showSst, onChanged: (v) => setState(() => _showSst = v)),
        const SizedBox(height: 10),
        _buildTextFieldWithToggle(controller: _addressCtrl, label: 'Alamat Cawangan Kedai', value: _showAddress, onChanged: (v) => setState(() => _showAddress = v)),
        const SizedBox(height: 10),
        _buildTextFieldWithToggle(controller: _phoneCtrl, label: 'No. Telefon Hubungi / WhatsApp', value: _showPhone, onChanged: (v) => setState(() => _showPhone = v)),
        const SizedBox(height: 10),
        _buildTextFieldWithToggle(controller: _socialCtrl, label: 'Akaun Media Sosial (IG / TikTok)', value: _showSocial, onChanged: (v) => setState(() => _showSocial = v)),
        const SizedBox(height: 24),

        // 6. Transaction & Pricing Toggles
        _buildSectionHeader('6. Butiran Transaksi & Pengiraan Cukai', HugeIcons.strokeRoundedInvoice),
        const SizedBox(height: 10),
        _buildTransactionTogglesCard(),
        const SizedBox(height: 24),

        // 7. Bottom Code Customization (QR Receipt, Promo, WiFi, Barcode, None)
        _buildSectionHeader('7. Kod Interaktif Bawah Resit (Bottom Code)', HugeIcons.strokeRoundedQrCode),
        const SizedBox(height: 10),
        _buildBottomCodeSelector(),
        const SizedBox(height: 24),

        // 8. Footer Notes & Return Policy
        _buildSectionHeader('8. Mesej Bawah & Dasar Pulangan', HugeIcons.strokeRoundedNote01),
        const SizedBox(height: 12),
        _buildTextField(controller: _footerMsgCtrl, label: 'Ucapan Terima Kasih (Footer Note)'),
        const SizedBox(height: 10),
        _buildTextField(controller: _policyCtrl, label: 'Syarat & Dasar Pertukaran / Bayaran Balik'),
        const SizedBox(height: 24),

        // 9. Hardware Connection Status
        _buildSectionHeader('9. Sambungan Pencetak Terma', HugeIcons.strokeRoundedPrinter),
        const SizedBox(height: 10),
        _buildPrinterStatusCard(),
        const SizedBox(height: 28),

        // 10. Save Template Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: () {
              showGlassToast(context, 'Tetapan templat resit berjaya disimpan!');
            },
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: const Text(
              'Simpan Tetapan Templat Resit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION HEADER WIDGET
  // ===========================================================================
  Widget _buildSectionHeader(String title, dynamic icon) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: const Color(0xFF42A5F5), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PAPER WIDTH TAB
  // ===========================================================================
  Widget _buildPaperWidthTab({
    required int width,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _paperWidth == width;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _paperWidth = width),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3).withValues(alpha: 0.15) : const Color(0xFF141424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isSelected ? const Color(0xFF2196F3) : Colors.white54, size: 22),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.white38,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIVIDER STYLE SELECTOR
  // ===========================================================================
  Widget _buildDividerStyleSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Corak Garisan Pemisah Seksyen:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDividerOptionChip(DividerStyle.dashed, '- - - - (Putus-putus)'),
              _buildDividerOptionChip(DividerStyle.dotted, '. . . . (Titik Dot)'),
              _buildDividerOptionChip(DividerStyle.solidDouble, '════ (Garis Berganda)'),
              _buildDividerOptionChip(DividerStyle.stars, '* * * * (Bintang)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDividerOptionChip(DividerStyle style, String label) {
    final isSelected = _dividerStyle == style;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _dividerStyle = style),
      selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.25),
      backgroundColor: const Color(0xFF0A0A14),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF42A5F5) : Colors.white70,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF42A5F5) : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ===========================================================================
  // ALIGNMENT SELECTOR
  // ===========================================================================
  Widget _buildAlignmentSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildAlignButton(TextAlign.center, 'Tengah (Center)', Icons.format_align_center_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildAlignButton(TextAlign.left, 'Rapat Kiri (Left)', Icons.format_align_left_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignButton(TextAlign align, String label, IconData icon) {
    final isSelected = _headerAlign == align;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _headerAlign = align),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3).withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF42A5F5) : Colors.white54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // LOGO CUSTOMIZER CARD
  // ===========================================================================
  Widget _buildLogoCustomizerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipOval(
                  child: _customLogoBytes != null
                      ? Image.memory(_customLogoBytes!, fit: BoxFit.cover)
                      : _logoUrl.isNotEmpty
                          ? Image.network(
                              _logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Colors.white70, size: 24),
                            )
                          : const Icon(Icons.storefront_rounded, color: Colors.white70, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sertakan Logo Kedai di Atas Resit',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _includeLogo ? 'Logo aktif pada kepala resit' : 'Logo disembunyikan',
                      style: TextStyle(color: _includeLogo ? const Color(0xFF10B981) : Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _includeLogo,
                activeColor: const Color(0xFF42A5F5),
                onChanged: (val) => setState(() => _includeLogo = val),
              ),
            ],
          ),
          if (_includeLogo) ...[
            const Divider(height: 20, color: Colors.white10),
            Row(
              children: [
                const Text('Saiz Logo:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Kecil (36px)'),
                  selected: _logoSize == LogoSize.small,
                  onSelected: (_) => setState(() => _logoSize = LogoSize.small),
                  selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.25),
                  backgroundColor: const Color(0xFF0A0A14),
                  labelStyle: TextStyle(color: _logoSize == LogoSize.small ? const Color(0xFF42A5F5) : Colors.white60, fontSize: 10.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Sedang (48px)'),
                  selected: _logoSize == LogoSize.medium,
                  onSelected: (_) => setState(() => _logoSize = LogoSize.medium),
                  selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.25),
                  backgroundColor: const Color(0xFF0A0A14),
                  labelStyle: TextStyle(color: _logoSize == LogoSize.medium ? const Color(0xFF42A5F5) : Colors.white60, fontSize: 10.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Besar (60px)'),
                  selected: _logoSize == LogoSize.large,
                  onSelected: (_) => setState(() => _logoSize = LogoSize.large),
                  selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.25),
                  backgroundColor: const Color(0xFF0A0A14),
                  labelStyle: TextStyle(color: _logoSize == LogoSize.large ? const Color(0xFF42A5F5) : Colors.white60, fontSize: 10.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _pickCustomLogo,
                    icon: const Icon(Icons.upload_rounded, size: 16, color: Color(0xFF42A5F5)),
                    label: const Text('Muat Naik Logo Resit Baharu', style: TextStyle(fontSize: 12)),
                  ),
                ),
                if (_customLogoBytes != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 18),
                    tooltip: 'Gunakan logo asal profil kedai',
                    onPressed: () {
                      setState(() => _customLogoBytes = null);
                      showGlassToast(context, 'Kembali ke logo asal profil kedai.');
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // TRANSACTION TOGGLES CARD
  // ===========================================================================
  Widget _buildTransactionTogglesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildCompactSwitchTile('Papar No. Meja / Dine-in Status', _showTableNo, (v) => setState(() => _showTableNo = v)),
          const Divider(color: Colors.white10, height: 1),
          _buildCompactSwitchTile('Papar Nama Kasir / Staf', _showCashier, (v) => setState(() => _showCashier = v)),
          const Divider(color: Colors.white10, height: 1),
          _buildCompactSwitchTile('Papar Tarikh & Waktu Cetakan', _showDateTime, (v) => setState(() => _showDateTime = v)),
          const Divider(color: Colors.white10, height: 1),
          _buildCompactSwitchTile('Pecahan Cukai SST (6%)', _showSstTax, (v) => setState(() => _showSstTax = v)),
          const Divider(color: Colors.white10, height: 1),
          _buildCompactSwitchTile('Caj Servis (Service Charge 10%)', _showServiceCharge, (v) => setState(() => _showServiceCharge = v)),
          const Divider(color: Colors.white10, height: 1),
          _buildCompactSwitchTile('Penyelarasan 5 Sen (Rounding Bancian)', _showRounding, (v) => setState(() => _showRounding = v)),
          const Divider(color: Colors.white10, height: 1),
          _buildCompactSwitchTile('Papar Kaedah Bayaran (DuitNow/Tunai/Kad)', _showPaymentMethod, (v) => setState(() => _showPaymentMethod = v)),
        ],
      ),
    );
  }

  Widget _buildCompactSwitchTile(String title, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
          Switch(
            value: val,
            activeColor: const Color(0xFF42A5F5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM CODE SELECTOR
  // ===========================================================================
  Widget _buildBottomCodeSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilih Jenis Kod di Bahagian Bawah Resit:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCodeOptionChip(BottomCodeType.qrReceipt, '📱 QR e-Resit (Pelanggan)'),
              _buildCodeOptionChip(BottomCodeType.qrPromo, '🎟️ QR Baucar / Promosi'),
              _buildCodeOptionChip(BottomCodeType.qrWifi, '📶 QR WiFi Tetamu Kedai'),
              _buildCodeOptionChip(BottomCodeType.barcode, '📊 Kod Bar (Barcode)'),
              _buildCodeOptionChip(BottomCodeType.none, '❌ Tiada Kod (Kompak)'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pilihan Hantar e-Resit WhatsApp', style: TextStyle(color: Colors.white, fontSize: 13)),
                    Text('Boleh kongsi pautan PDF digital terus ke telefon', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _enableWhatsappReceipt,
                activeColor: const Color(0xFF44CF6C),
                onChanged: (v) => setState(() => _enableWhatsappReceipt = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodeOptionChip(BottomCodeType type, String label) {
    final isSelected = _bottomCode == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _bottomCode = type),
      selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.25),
      backgroundColor: const Color(0xFF0A0A14),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF42A5F5) : Colors.white70,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF42A5F5) : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ===========================================================================
  // PRINTER STATUS CARD
  // ===========================================================================
  Widget _buildPrinterStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isConnected
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPrinter,
                  color: _isConnected ? const Color(0xFF10B981) : Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          _selectedPrinter,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isConnected ? 'TERHUBUNG' : 'LUAR TALIAN',
                            style: TextStyle(
                              color: _isConnected ? const Color(0xFF10B981) : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kIsWeb
                          ? 'Mod Web: Boleh terus cetak ke USB/WiFi Thermal Printer & PDF'
                          : 'Bluetooth Serial (SPP) / USB ESC-POS Protocol',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isConnected,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() => _isConnected = val);
                  showGlassToast(context, val ? 'Pencetak terhubung' : 'Pencetak diputuskan');
                },
              ),
            ],
          ),
          const Divider(height: 22, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Cetak automatik bila pesanan baharu masuk', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ),
              Switch(
                value: _autoPrintOnOrder,
                activeColor: const Color(0xFF42A5F5),
                onChanged: (val) => setState(() => _autoPrintOnOrder = val),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Potong kertas secara automatik (Auto-Cutter)', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ),
              Switch(
                value: _autoCutPaper,
                activeColor: const Color(0xFF42A5F5),
                onChanged: (val) => setState(() => _autoCutPaper = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIVE THERMAL RECEIPT PAPER (DYNAMIC 58MM VS 80MM)
  // ===========================================================================
  Widget _buildReceiptPaper() {
    // Dynamic Width: 58mm -> ~255px, 80mm -> ~335px
    final double targetWidth = _paperWidth == 58 ? 255.0 : 335.0;
    final double logoDim = _logoSize == LogoSize.small ? 36.0 : _logoSize == LogoSize.medium ? 48.0 : 60.0;

    return RepaintBoundary(
      key: _receiptKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: targetWidth,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8), // Natural warm thermal paper tint
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Serrated Paper Cut Edge (Zigzag teeth)
            _buildSerratedCutEdge(isTop: true),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: _headerAlign == TextAlign.center
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  // Optional Store Logo
                  if (_includeLogo) ...[
                    Align(
                      alignment: _headerAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft,
                      child: Container(
                        width: logoDim,
                        height: logoDim,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26, width: 1.5),
                        ),
                        child: ClipOval(
                          child: _customLogoBytes != null
                              ? Image.memory(_customLogoBytes!, fit: BoxFit.cover)
                              : _logoUrl.isNotEmpty
                                  ? Image.network(
                                      _logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Colors.black87, size: 24),
                                    )
                                  : const Icon(Icons.storefront_rounded, color: Colors.black87, size: 24),
                        ),
                      ),
                    ),
                  ],

                  // Store Name Header
                  Text(
                    _storeNameCtrl.text.isNotEmpty ? _storeNameCtrl.text : 'KEDAI NGAM',
                    textAlign: _headerAlign,
                    style: GoogleFonts.spaceMono(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: _paperWidth == 58 ? 13.0 : 15.0,
                      letterSpacing: 0.3,
                    ),
                  ),

                  // Tagline
                  if (_showTagline && _taglineCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      _taglineCtrl.text,
                      textAlign: _headerAlign,
                      style: GoogleFonts.spaceMono(color: Colors.black54, fontSize: 8.5, fontStyle: FontStyle.italic),
                    ),
                  ],

                  const SizedBox(height: 2),

                  // SSM
                  if (_showSsm && _ssmCtrl.text.isNotEmpty)
                    Text(
                      _ssmCtrl.text,
                      textAlign: _headerAlign,
                      style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 9.0),
                    ),

                  // SST
                  if (_showSst && _sstCtrl.text.isNotEmpty)
                    Text(
                      _sstCtrl.text,
                      textAlign: _headerAlign,
                      style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 9.0),
                    ),

                  // Address
                  if (_showAddress && _addressCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        _addressCtrl.text,
                        textAlign: _headerAlign,
                        style: GoogleFonts.spaceMono(color: Colors.black54, fontSize: 8.5),
                      ),
                    ),

                  // Phone
                  if (_showPhone && _phoneCtrl.text.isNotEmpty)
                    Text(
                      'Tel: ${_phoneCtrl.text}',
                      textAlign: _headerAlign,
                      style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 9.0),
                    ),

                  // Social Media
                  if (_showSocial && _socialCtrl.text.isNotEmpty)
                    Text(
                      _socialCtrl.text,
                      textAlign: _headerAlign,
                      style: GoogleFonts.spaceMono(color: Colors.black54, fontSize: 8.5),
                    ),

                  const SizedBox(height: 4),
                  _buildDynamicDivider(),

                  // Meta Row (Order No & Date)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pesanan: #NG-4029',
                        style: GoogleFonts.spaceMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9.5),
                      ),
                      if (_showDateTime)
                        Text(
                          '30/09/2026 12:45',
                          style: GoogleFonts.spaceMono(color: Colors.black54, fontSize: 9.0),
                        ),
                    ],
                  ),
                  if (_showTableNo || _showCashier)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_showTableNo)
                          Text('Meja: 04 (Makan Sini)', style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 9.0))
                        else
                          const SizedBox.shrink(),
                        if (_showCashier)
                          Text('Kasir: Ahmad', style: GoogleFonts.spaceMono(color: Colors.black54, fontSize: 9.0))
                        else
                          const SizedBox.shrink(),
                      ],
                    ),

                  _buildDynamicDivider(),

                  // Items List (Clean Row with Exact Padding)
                  _buildReceiptItemRow('1x', 'Nasi Lemak Rendang Daging', '16.90'),
                  _buildReceiptItemRow('', '  + Sambal Sotong Extra', '3.50', isSub: true),
                  _buildReceiptItemRow('1x', 'Teh Tarik Kaw Ais', '3.80'),
                  _buildReceiptItemRow('1x', 'Roti Bakar Kaya Butter', '4.50'),

                  _buildDynamicDivider(),

                  // Subtotal & Calculations
                  _buildReceiptSummaryRow('Jumlah Bersih (Subtotal)', 'RM 28.70'),
                  if (_showSstTax)
                    _buildReceiptSummaryRow('Cukai SST (6%)', 'RM 1.72'),
                  if (_showServiceCharge)
                    _buildReceiptSummaryRow('Caj Servis (10%)', 'RM 2.87'),
                  if (_showRounding)
                    _buildReceiptSummaryRow('Penyelarasan (Rounding)', '-RM 0.02'),

                  const SizedBox(height: 2),
                  _buildDynamicDivider(),

                  // TOTAL PAYABLE (Grand Total)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'JUMLAH BESAR',
                          style: GoogleFonts.spaceMono(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: _paperWidth == 58 ? 11.5 : 13.0,
                          ),
                        ),
                        Text(
                          _showServiceCharge ? 'RM 33.25' : 'RM 30.40',
                          style: GoogleFonts.spaceMono(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: _paperWidth == 58 ? 12.5 : 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_showPaymentMethod) ...[
                    _buildReceiptSummaryRow('BAYARAN (DuitNow QR)', _showServiceCharge ? 'RM 33.25' : 'RM 30.40', isBold: false),
                    _buildReceiptSummaryRow('BAKI (Change)', 'RM 0.00', isBold: false),
                  ],

                  _buildDynamicDivider(),
                  const SizedBox(height: 4),

                  // Greeting & Exchange Policy
                  if (_footerMsgCtrl.text.isNotEmpty)
                    Center(
                      child: Text(
                        _footerMsgCtrl.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceMono(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.0,
                        ),
                      ),
                    ),
                  if (_policyCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        _policyCtrl.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceMono(color: Colors.black45, fontSize: 8.0),
                      ),
                    ),
                  ],

                  // Dynamic Bottom Interactive Code
                  _buildBottomCodeSection(),
                ],
              ),
            ),

            // Bottom Serrated Paper Cut Edge
            _buildSerratedCutEdge(isTop: false),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DYNAMIC DIVIDER (EXACT COLUMN WIDTH — NEVER SPILLS TO 2ND LINE!)
  // ===========================================================================
  Widget _buildDynamicDivider() {
    String pattern;
    switch (_dividerStyle) {
      case DividerStyle.dashed:
        pattern = _paperWidth == 58
            ? '- - - - - - - - - - - - - - - -' // 32 chars
            : '- - - - - - - - - - - - - - - - - - - - - - -'; // 47 chars
        break;
      case DividerStyle.dotted:
        pattern = _paperWidth == 58
            ? '. . . . . . . . . . . . . . . .'
            : '. . . . . . . . . . . . . . . . . . . . . . .';
        break;
      case DividerStyle.solidDouble:
        pattern = _paperWidth == 58
            ? '════════════════════════════════'
            : '══════════════════════════════════════════════';
        break;
      case DividerStyle.stars:
        pattern = _paperWidth == 58
            ? '* * * * * * * * * * * * * * * *'
            : '* * * * * * * * * * * * * * * * * * * * * * *';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Text(
          pattern,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            color: Colors.black38,
            fontSize: _dividerStyle == DividerStyle.solidDouble ? 8.5 : 9.0,
            letterSpacing: _dividerStyle == DividerStyle.solidDouble ? -0.3 : 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // RECEIPT ITEM ROW (PINNED PRICE ON RIGHT, ADAPTS TO COLUMN WIDTH)
  // ===========================================================================
  Widget _buildReceiptItemRow(String qty, String name, String price, {bool isSub = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (qty.isNotEmpty) ...[
            Text(
              qty,
              style: GoogleFonts.spaceMono(
                color: Colors.black,
                fontSize: _paperWidth == 58 ? 9.0 : 10.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.spaceMono(
                color: isSub ? Colors.black54 : Colors.black,
                fontSize: _paperWidth == 58 ? 9.0 : 10.0,
                fontWeight: isSub ? FontWeight.normal : FontWeight.w600,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            price,
            style: GoogleFonts.spaceMono(
              color: Colors.black,
              fontSize: _paperWidth == 58 ? 9.0 : 10.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY ROW
  // ===========================================================================
  Widget _buildReceiptSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: isBold ? Colors.black : Colors.black87,
              fontSize: _paperWidth == 58 ? 8.5 : 9.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: Colors.black,
              fontSize: _paperWidth == 58 ? 8.5 : 9.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM CODE SECTION (QR e-Receipt, Promo, WiFi, Barcode, None)
  // ===========================================================================
  Widget _buildBottomCodeSection() {
    switch (_bottomCode) {
      case BottomCodeType.qrReceipt:
        return Center(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: QrImageView(
                  data: 'https://ngam.dev/receipt/NG4029',
                  version: QrVersions.auto,
                  size: _paperWidth == 58 ? 68 : 80,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Imbas Simpan e-Resit & Poin Ngam',
                style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 7.5, fontWeight: FontWeight.bold),
              ),
              Text(
                'ngam.dev/receipt/NG4029',
                style: GoogleFonts.spaceMono(color: Colors.black38, fontSize: 7.0),
              ),
            ],
          ),
        );

      case BottomCodeType.qrPromo:
        return Center(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: QrImageView(
                  data: 'https://ngam.dev/@warungngam?promo=NGAM10',
                  version: QrVersions.auto,
                  size: _paperWidth == 58 ? 68 : 80,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '🎁 10% OFF Lawatan Seterusnya! (KOD: NGAM10)',
                style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 7.5, fontWeight: FontWeight.bold),
              ),
              Text(
                'Tunjuk atau imbas resit ini untuk tebus',
                style: GoogleFonts.spaceMono(color: Colors.black38, fontSize: 7.0),
              ),
            ],
          ),
        );

      case BottomCodeType.qrWifi:
        return Center(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: QrImageView(
                  data: 'WIFI:T:WPA;S:WarungNgam_Guest;P:ngamsedap2026;;',
                  version: QrVersions.auto,
                  size: _paperWidth == 58 ? 68 : 80,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '📶 Imbas Untuk Sambung WiFi Tetamu Kedai',
                style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 7.5, fontWeight: FontWeight.bold),
              ),
              Text(
                'SSID: WarungNgam_Guest',
                style: GoogleFonts.spaceMono(color: Colors.black45, fontSize: 7.0),
              ),
            ],
          ),
        );

      case BottomCodeType.barcode:
        return Center(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                height: 30,
                width: _paperWidth == 58 ? 160 : 200,
                color: Colors.black,
                child: Row(
                  children: List.generate(42, (i) {
                    return Expanded(
                      flex: (i % 3 == 0) ? 2 : 1,
                      child: Container(
                        color: (i % 2 == 0) ? Colors.black : Colors.white,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '*NG-4029-2026*',
                style: GoogleFonts.spaceMono(color: Colors.black87, fontSize: 8.0, letterSpacing: 1.5),
              ),
            ],
          ),
        );

      case BottomCodeType.none:
        return const SizedBox(height: 6);
    }
  }

  // ===========================================================================
  // SERRATED CUT EDGE PAINTER (ZIGZAG TEETH)
  // ===========================================================================
  Widget _buildSerratedCutEdge({required bool isTop}) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(
        painter: _SerratedPainter(isTop: isTop),
      ),
    );
  }

  // ===========================================================================
  // DOWNLOAD BUTTON
  // ===========================================================================
  Widget _buildDownloadButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _isDownloadingReceipt ? null : _captureAndSaveReceipt,
      icon: _isDownloadingReceipt
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.download_rounded, size: 18, color: Color(0xFF42A5F5)),
      label: const Text('Muat Turun Resit Resolusi Tinggi (HD)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
    );
  }

  // ===========================================================================
  // TEXT FIELD HELPERS
  // ===========================================================================
  Widget _buildTextField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 13.0),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12.0),
        filled: true,
        fillColor: const Color(0xFF141424),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
      ),
    );
  }

  Widget _buildTextFieldWithToggle({
    required TextEditingController controller,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(controller: controller, label: label),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: value ? 'Papar pada resit' : 'Sembunyi daripada resit',
          child: Switch(
            value: value,
            activeColor: const Color(0xFF42A5F5),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SERRATED ZIGZAG EDGE PAINTER (PHYSICAL TEAR CUT)
// =============================================================================
class _SerratedPainter extends CustomPainter {
  final bool isTop;
  const _SerratedPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFDF8)
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 8.0;
    const toothHeight = 5.0;
    final teeth = (size.width / toothWidth).ceil();

    if (isTop) {
      path.moveTo(0.0, size.height);
      for (int i = 0; i < teeth; i++) {
        final x1 = i * toothWidth + (toothWidth / 2);
        final y1 = size.height - toothHeight;
        final x2 = (i + 1) * toothWidth;
        final y2 = size.height;
        path.lineTo(x1, y1);
        path.lineTo(x2, y2);
      }
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0.0, 0.0);
      for (int i = 0; i < teeth; i++) {
        final x1 = i * toothWidth + (toothWidth / 2);
        final y1 = toothHeight;
        final x2 = (i + 1) * toothWidth;
        const y2 = 0.0;
        path.lineTo(x1, y1);
        path.lineTo(x2, y2);
      }
      path.lineTo(size.width, 0.0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
