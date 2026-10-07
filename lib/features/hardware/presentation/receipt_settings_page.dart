import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// ReceiptSettingsPage — Thermal Printer & Receipt Customizer
// ============================================================

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

  // Receipt Content
  final _storeNameCtrl = TextEditingController(text: 'WARUNG NGAM MELAKA');
  final _ssmCtrl = TextEditingController(text: 'SSM: 202401039821 (1560944-X)');
  final _sstCtrl = TextEditingController(text: 'SST ID: W10-1808-32000456');
  final _addressCtrl = TextEditingController(text: 'No 45, Jalan Hang Tuah, Bandar Hilir, Melaka');
  final _phoneCtrl = TextEditingController(text: '+60 17-234 5678');
  final _footerMsgCtrl = TextEditingController(text: 'Terima kasih daun keladi, sudilah datang lagi!');
  final _policyCtrl = TextEditingController(text: 'Valid for refund/exchange within 3 days with original receipt.');

  bool _showSst = true;
  bool _showBarcode = true;
  bool _enableWhatsappReceipt = true;

  // Real Receipt Image Capture
  final GlobalKey _receiptKey = GlobalKey();
  bool _isDownloadingReceipt = false;

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _ssmCtrl.dispose();
    _sstCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _footerMsgCtrl.dispose();
    _policyCtrl.dispose();
    super.dispose();
  }

  void _printTestReceipt() {
    showGlassToast(context, 'Printing test receipt to $_selectedPrinter (${_paperWidth}mm)...');
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Resit Digital Berjaya Dimuat Turun!',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Format: Thermal ${_paperWidth}mm • Resolusi Tinggi (300 DPI)',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Preview Box
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
                    child: Image.memory(
                      pngBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Path info
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
                const SizedBox(height: 18),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
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
                    label: const Text('Buka Fail Resit Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
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
              'Receipts & Printer',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Bluetooth/LAN printer & layout',
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
            tooltip: 'Print Test Receipt',
            onPressed: _printTestReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Printer Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isConnected ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
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
                      const SizedBox(width: 16),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                                    _isConnected ? 'CONNECTED' : 'OFFLINE',
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
                              'Bluetooth Serial (SPP) • ESC/POS Command',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isConnected,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() => _isConnected = val);
                          showGlassToast(context, val ? 'Printer connected' : 'Printer disconnected');
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('Auto-print when new order placed', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
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
                        child: Text('Auto cut paper roll after receipt', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _autoCutPaper,
                        activeColor: const Color(0xFF42A5F5),
                        onChanged: (val) => setState(() => _autoCutPaper = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Paper Width Selector
            const Text(
              'Thermal Paper Roll Width',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paperWidth = 58),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _paperWidth == 58 ? const Color(0xFF42A5F5) : const Color(0xFF141424),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _paperWidth == 58 ? const Color(0xFF42A5F5) : Colors.white12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '58mm',
                            style: TextStyle(
                              color: _paperWidth == 58 ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pocket / Handheld',
                            style: TextStyle(
                              color: _paperWidth == 58 ? Colors.white.withValues(alpha: 0.85) : Colors.white54,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paperWidth = 80),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _paperWidth == 80 ? const Color(0xFF42A5F5) : const Color(0xFF141424),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _paperWidth == 80 ? const Color(0xFF42A5F5) : Colors.white12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '80mm',
                            style: TextStyle(
                              color: _paperWidth == 80 ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Countertop POS',
                            style: TextStyle(
                              color: _paperWidth == 80 ? Colors.white.withValues(alpha: 0.85) : Colors.white54,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Live Receipt Paper Preview (Thermal Monospace Paper Mockup)
            const Text(
              'Live Receipt Paper Preview',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _receiptKey,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _paperWidth == 58 ? 260 : double.infinity,
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF5), // Warm thermal paper tint
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _storeNameCtrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _ssmCtrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Courier', color: Colors.black87, fontSize: 11),
                      ),
                      if (_showSst) ...[
                        Text(
                          _sstCtrl.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Courier', color: Colors.black87, fontSize: 10),
                        ),
                      ],
                      Text(
                        _addressCtrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Courier', color: Colors.black54, fontSize: 10),
                      ),
                      Text(
                        'Tel: ${_phoneCtrl.text}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Courier', color: Colors.black87, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      _buildReceiptDivider(),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text('Order: #NG-4029', style: TextStyle(fontFamily: 'Courier', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(width: 4),
                          Text('30/09/2026 12:45', style: TextStyle(fontFamily: 'Courier', color: Colors.black54, fontSize: 10)),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text('Table: 04 (Dine-in)', style: TextStyle(fontFamily: 'Courier', color: Colors.black, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(width: 4),
                          Text('Cashier: Ahmad', style: TextStyle(fontFamily: 'Courier', color: Colors.black54, fontSize: 10)),
                        ],
                      ),
                      _buildReceiptDivider(),

                      // Sample Items
                      _buildReceiptLine('1x Nasi Lemak Rendang Daging', '16.90'),
                      _buildReceiptLine('  + Extra Sambal Sotong', '3.50'),
                      _buildReceiptLine('1x Teh Tarik Kaw (Ais)', '3.80'),
                      _buildReceiptLine('1x Roti Bakar Kaya Butter', '4.50'),

                      _buildReceiptDivider(),

                      _buildReceiptLine('Subtotal', '28.70', isBold: false),
                      if (_showSst) _buildReceiptLine('SST (6%)', '1.72', isBold: false),
                      _buildReceiptLine('Rounding (Bancian)', '-0.02', isBold: false),
                      const SizedBox(height: 4),
                      _buildReceiptLine('TOTAL PAYABLE', 'RM 30.40', isBold: true, fontSize: 14),
                      _buildReceiptLine('PAID (DuitNow QR)', 'RM 30.40', isBold: false),

                      _buildReceiptDivider(),
                      const SizedBox(height: 6),

                      Text(
                        _footerMsgCtrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Courier', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _policyCtrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Courier', color: Colors.black54, fontSize: 9),
                      ),
                      const SizedBox(height: 12),

                      if (_showBarcode) ...[
                        // Simulated barcode lines
                        Container(
                          height: 32,
                          width: 180,
                          color: Colors.black,
                          child: Row(
                            children: List.generate(40, (i) {
                              return Expanded(
                                flex: (i % 3 == 0) ? 2 : 1,
                                child: Container(
                                  color: (i % 2 == 0) ? Colors.black : Colors.white,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('*NG4029-2026*', style: TextStyle(fontFamily: 'Courier', color: Colors.black87, fontSize: 9)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isDownloadingReceipt ? null : _captureAndSaveReceipt,
                icon: _isDownloadingReceipt
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18, color: Color(0xFF42A5F5)),
                label: const Text('Muat Turun & Buka Resit Digital (HD)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),

            // Form Customization Inputs
            const Text(
              'Header & Legal Details',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(controller: _storeNameCtrl, label: 'Store Name (Header)'),
            const SizedBox(height: 10),
            _buildTextField(controller: _ssmCtrl, label: 'SSM Company Registration No.'),
            const SizedBox(height: 10),
            _buildTextField(controller: _sstCtrl, label: 'SST Tax Registration ID'),
            const SizedBox(height: 10),
            _buildTextField(controller: _addressCtrl, label: 'Store Address'),
            const SizedBox(height: 10),
            _buildTextField(controller: _phoneCtrl, label: 'Contact Phone Number'),
            const SizedBox(height: 20),

            const Text(
              'Footer & Message Settings',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(controller: _footerMsgCtrl, label: 'Customer Greeting Note'),
            const SizedBox(height: 10),
            _buildTextField(controller: _policyCtrl, label: 'Exchange / Return Policy'),
            const SizedBox(height: 16),

            // Switches
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141424),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show SST Breakdown on Receipt', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: _showSst,
                    activeColor: const Color(0xFF42A5F5),
                    onChanged: (val) => setState(() => _showSst = val),
                  ),
                  const Divider(color: Colors.white12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Print Barcode at Bottom', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: _showBarcode,
                    activeColor: const Color(0xFF42A5F5),
                    onChanged: (val) => setState(() => _showBarcode = val),
                  ),
                  const Divider(color: Colors.white12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send WhatsApp e-Receipt Link', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Send digital PDF receipt directly to customer WhatsApp', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _enableWhatsappReceipt,
                    activeColor: const Color(0xFF44CF6C),
                    onChanged: (val) => setState(() => _enableWhatsappReceipt = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Save settings button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  showGlassToast(context, 'Thermal printer & receipt template saved!');
                },
                icon: const Icon(Icons.save_rounded, size: 20),
                label: const Text('Save Receipt Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF141424),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
      ),
    );
  }

  Widget _buildReceiptLine(String left, String right, {bool isBold = false, double fontSize = 11}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontFamily: 'Courier',
                color: Colors.black,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: fontSize,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            right,
            style: TextStyle(
              fontFamily: 'Courier',
              color: Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '- - - - - - - - - - - - - - - - - - - - - - - -',
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Courier', color: Colors.black38),
      ),
    );
  }
}
