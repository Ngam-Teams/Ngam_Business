import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../utils/file_saver/file_saver.dart';

/// Pure Dart PDF Receipt Generator Service for Ngam Business.
/// Produces 100% compliant, standard PDF 1.4 documents without any external native dependencies.
/// Fully compatible with Flutter Web (blob download) and Android/iOS/Desktop (native open/save).
class ReceiptPdfService {
  ReceiptPdfService._();

  static String _escapePdf(String? text) {
    if (text == null || text.isEmpty) return '';
    
    final clean = text
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");

    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      final code = clean.codeUnitAt(i);
      if (code <= 255) {
        final char = clean[i];
        if (char == '\\') {
          buffer.write(r'\\');
        } else if (char == '(') {
          buffer.write(r'\(');
        } else if (char == ')') {
          buffer.write(r'\)');
        } else {
          buffer.write(char);
        }
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 2)}..';
  }

  static Uint8List generateReceiptPdfBytes({
    required String orderId,
    required String shopName,
    String? shopPhone,
    String? shopAddress,
    String? customerName,
    String? customerPhone,
    DateTime? orderCreatedAt,
    DateTime? paymentTime,
    String? paymentMethod,
    String? paymentStatus,
    String? fulfillmentType,
    String? pickupTime,
    String? tableNumber,
    String? notes,
    List<Map<String, dynamic>> items = const [],
    double subtotal = 0.0,
    double tax = 0.0,
    double discount = 0.0,
    required double totalAmount,
  }) {
    final currency = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

    final displayRef = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final createdStr = orderCreatedAt != null ? dateFormat.format(orderCreatedAt) : dateFormat.format(DateTime.now());
    final isPaid = (paymentStatus?.toLowerCase() ?? 'paid') == 'paid';
    final payMethodStr = (paymentMethod == null || paymentMethod.isEmpty) ? 'DuitNow QR / FPX' : paymentMethod.toUpperCase();
    final paidTimeStr = paymentTime != null ? dateFormat.format(paymentTime) : (isPaid ? createdStr : '-');

    final commands = <String>[];

    // 1. BRAND HEADER CARD (#0B132B)
    commands.add('0.043 0.075 0.169 rg 40 735 515.28 75 re f');
    commands.add('0.0 0.898 1.0 rg 40 732 515.28 3 re f');
    commands.add('BT /F2 20 Tf 1 1 1 rg 55 776 Td (${_escapePdf("NGAM BUSINESS")}) Tj ET');
    commands.add('BT /F1 8.5 Tf 0.7 0.82 0.95 rg 55 758 Td (${_escapePdf("RESIT PESANAN RASMI / OFFICIAL ORDER RECEIPT")}) Tj ET');
    commands.add('BT /F2 10.5 Tf 1 1 1 rg 350 776 Td (${_escapePdf("NO. PESANAN: #$displayRef")}) Tj ET');
    commands.add('BT /F1 8.5 Tf 0.7 0.82 0.95 rg 350 758 Td (${_escapePdf("Tarikh Pesanan: $createdStr")}) Tj ET');

    // 2. STORE & TRANSACTION DETAILS CARD (#F8FAFC)
    commands.add('0.97 0.98 0.99 rg 40 622 515.28 98 re f');
    commands.add('0.88 0.91 0.94 RG 1 w 40 622 515.28 98 re S');

    final displayShopName = _truncate(shopName.isNotEmpty ? shopName : 'Perniagaan Ngam', 36);
    commands.add('BT /F2 11 Tf 0.08 0.12 0.2 rg 55 698 Td (${_escapePdf("KEDAI: $displayShopName")}) Tj ET');

    if (shopAddress != null && shopAddress.trim().isNotEmpty) {
      final addr = _truncate(shopAddress.trim(), 45);
      commands.add('BT /F1 8.5 Tf 0.35 0.42 0.52 rg 55 683 Td (${_escapePdf("Alamat: $addr")}) Tj ET');
    } else {
      commands.add('BT /F1 8.5 Tf 0.35 0.42 0.52 rg 55 683 Td (${_escapePdf("Platform: Peniaga Sah Berdaftar Ngam")}) Tj ET');
    }

    if (shopPhone != null && shopPhone.trim().isNotEmpty) {
      commands.add('BT /F1 8.5 Tf 0.35 0.42 0.52 rg 55 668 Td (${_escapePdf("Hubungi Kedai: $shopPhone")}) Tj ET');
    } else {
      commands.add('BT /F1 8.5 Tf 0.35 0.42 0.52 rg 55 668 Td (${_escapePdf("Sokongan: support@ngam.my")}) Tj ET');
    }

    final fulfill = fulfillmentType ?? 'Bungkus / Takeaway';
    final slot = pickupTime != null && pickupTime.isNotEmpty ? ' • $pickupTime' : '';
    commands.add('BT /F1 8.5 Tf 0.0 0.55 0.7 rg 55 653 Td (${_escapePdf("Kaedah: $fulfill$slot")}) Tj ET');

    if (isPaid) {
      commands.add('0.9 0.98 0.94 rg 350 660 190 44 re f');
      commands.add('0.06 0.72 0.5 RG 1 w 350 660 190 44 re S');
      commands.add('BT /F2 10 Tf 0.04 0.5 0.3 rg 362 686 Td (${_escapePdf("STATUS: SUDAH DIBAYAR")}) Tj ET');
      commands.add('BT /F1 8 Tf 0.1 0.4 0.25 rg 362 672 Td (${_escapePdf("Kaedah: $payMethodStr")}) Tj ET');
    } else {
      commands.add('1.0 0.97 0.9 rg 350 660 190 44 re f');
      commands.add('0.95 0.6 0.05 RG 1 w 350 660 190 44 re S');
      commands.add('BT /F2 10 Tf 0.8 0.45 0.0 rg 362 686 Td (${_escapePdf("STATUS: BAYAR DI KAUNTER")}) Tj ET');
      commands.add('BT /F1 8 Tf 0.6 0.35 0.0 rg 362 672 Td (${_escapePdf("Menunggu Pembayaran di Kaunter")}) Tj ET');
    }
    commands.add('BT /F1 8 Tf 0.4 0.45 0.55 rg 350 642 Td (${_escapePdf("Masa Bayaran: $paidTimeStr")}) Tj ET');

    // 3. TABLE HEADER (#0F172A)
    commands.add('0.08 0.12 0.2 rg 40 580 515.28 24 re f');
    commands.add('BT /F2 9 Tf 1 1 1 rg 52 588 Td (${_escapePdf("ITEM / PERKHIDMATAN")}) Tj ET');
    commands.add('BT /F2 9 Tf 1 1 1 rg 330 588 Td (${_escapePdf("KTY")}) Tj ET');
    commands.add('BT /F2 9 Tf 1 1 1 rg 385 588 Td (${_escapePdf("HARGA SEUNIT")}) Tj ET');
    commands.add('BT /F2 9 Tf 1 1 1 rg 480 588 Td (${_escapePdf("JUMLAH")}) Tj ET');

    // 4. ITEMIZED ROWS
    double y = 556;
    final displayItems = items.isNotEmpty
        ? items
        : [
            {
              'name': notes?.isNotEmpty == true ? notes! : 'Pesanan Jualan',
              'qty': 1,
              'unit_price': totalAmount,
              'price': totalAmount,
            }
          ];

    for (final it in displayItems) {
      final rawName = it['name'] ?? it['product_name'] ?? it['title'] ?? 'Item';
      final name = _truncate(rawName.toString(), 42);
      final qty = (it['qty'] ?? it['quantity'] ?? 1).toString();
      final unitPrice = (it['unit_price'] as num?)?.toDouble() ??
          (((it['price'] ?? it['subtotal'] as num?)?.toDouble() ?? 0.0) /
              (int.tryParse(qty) ?? 1));
      final lineTotal = (it['price'] ?? it['subtotal'] as num?)?.toDouble() ?? (unitPrice * (int.tryParse(qty) ?? 1));

      final qtyStr = '${qty}x';
      final unitPriceStr = currency.format(unitPrice);
      final lineTotalStr = currency.format(lineTotal);

      commands.add('0.9 0.92 0.95 RG 0.5 w 40 $y m 555.28 $y l S');
      y -= 16;

      commands.add('BT /F1 9 Tf 0.1 0.15 0.22 rg 52 $y Td (${_escapePdf(name)}) Tj ET');
      commands.add('BT /F1 9 Tf 0.1 0.15 0.22 rg 335 $y Td (${_escapePdf(qtyStr)}) Tj ET');
      commands.add('BT /F1 9 Tf 0.1 0.15 0.22 rg 385 $y Td (${_escapePdf(unitPriceStr)}) Tj ET');
      commands.add('BT /F2 9 Tf 0.1 0.15 0.22 rg 480 $y Td (${_escapePdf(lineTotalStr)}) Tj ET');
      y -= 10;
    }

    commands.add('0.85 0.88 0.92 RG 1 w 40 $y m 555.28 $y l S');
    y -= 22;

    // 5. TOTALS SUMMARY BOX (Right Aligned)
    final calcSubtotal = subtotal > 0 ? subtotal : totalAmount;
    final subtotalStr = currency.format(calcSubtotal);
    commands.add('BT /F1 9 Tf 0.35 0.4 0.5 rg 330 $y Td (${_escapePdf("Jumlah Kecil:")}) Tj ET');
    commands.add('BT /F1 9.5 Tf 0.1 0.15 0.22 rg 480 $y Td (${_escapePdf(subtotalStr)}) Tj ET');
    y -= 18;

    if (discount > 0) {
      final discountStr = '- ${currency.format(discount)}';
      commands.add('BT /F1 9 Tf 0.05 0.6 0.35 rg 330 $y Td (${_escapePdf("Diskaun / Baucar:")}) Tj ET');
      commands.add('BT /F1 9.5 Tf 0.05 0.6 0.35 rg 480 $y Td (${_escapePdf(discountStr)}) Tj ET');
      y -= 18;
    }

    if (tax > 0) {
      final taxStr = currency.format(tax);
      commands.add('BT /F1 9 Tf 0.35 0.4 0.5 rg 330 $y Td (${_escapePdf("Cukai & Caj Servis:")}) Tj ET');
      commands.add('BT /F1 9.5 Tf 0.1 0.15 0.22 rg 480 $y Td (${_escapePdf(taxStr)}) Tj ET');
      y -= 18;
    }

    commands.add('0.043 0.075 0.169 rg 315 ${y - 8} 240.28 28 re f');
    commands.add('BT /F2 10.5 Tf 1 1 1 rg 325 $y Td (${_escapePdf("JUMLAH KESELURUHAN:")}) Tj ET');
    commands.add('BT /F2 12 Tf 0.0 0.898 1.0 rg 475 $y Td (${_escapePdf(currency.format(totalAmount))}) Tj ET');
    y -= 32;

    if (notes != null && notes.trim().isNotEmpty) {
      final cleanNote = notes.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (cleanNote.isNotEmpty) {
        commands.add('0.98 0.98 0.95 rg 40 ${y - 20} 515.28 26 re f');
        commands.add('0.9 0.85 0.6 RG 0.8 w 40 ${y - 20} 515.28 26 re S');
        final displayNote = _truncate(cleanNote, 70);
        commands.add('BT /F1 8.5 Tf 0.4 0.35 0.1 rg 50 ${y - 8} Td (${_escapePdf("Nota Pelanggan: $displayNote")}) Tj ET');
      }
    }

    // 6. FOOTER & VERIFICATION
    commands.add('0.85 0.88 0.92 RG 0.8 w 40 75 m 555.28 75 l S');
    commands.add('BT /F2 8.5 Tf 0.25 0.32 0.42 rg 135 56 Td (${_escapePdf("Terima kasih atas sokongan anda! Dijana oleh Platform Ngam Business.")}) Tj ET');
    commands.add('BT /F1 7.5 Tf 0.45 0.5 0.6 rg 148 42 Td (${_escapePdf("Resit digital ini sah dan diperakui untuk tujuan rekod perniagaan & pelanggan.")}) Tj ET');

    final contentStream = utf8.encode(commands.join('\n'));
    final objs = <List<int>>[];

    objs.add(utf8.encode('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'));
    objs.add(utf8.encode('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'));
    objs.add(utf8.encode('3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n'));
    objs.add(utf8.encode('4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n'));
    objs.add(utf8.encode('5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n'));
    final streamHeader = utf8.encode('6 0 obj\n<< /Length ${contentStream.length} >>\nstream\n');
    final streamFooter = utf8.encode('\nendstream\nendobj\n');
    objs.add([...streamHeader, ...contentStream, ...streamFooter]);

    final header = utf8.encode('%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');
    final out = <int>[...header];
    final offsets = <int>[0];
    int currentOffset = header.length;

    for (final obj in objs) {
      offsets.add(currentOffset);
      out.addAll(obj);
      currentOffset += obj.length;
    }

    final xrefOffset = currentOffset;
    final xrefBuffer = StringBuffer();
    xrefBuffer.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
    for (int i = 1; i < offsets.length; i++) {
      xrefBuffer.write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
    }
    xrefBuffer.write('trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');
    out.addAll(utf8.encode(xrefBuffer.toString()));

    return Uint8List.fromList(out);
  }

  static Future<String?> downloadReceiptPdf({
    required String orderId,
    required String shopName,
    String? shopPhone,
    String? shopAddress,
    String? customerName,
    String? customerPhone,
    DateTime? orderCreatedAt,
    DateTime? paymentTime,
    String? paymentMethod,
    String? paymentStatus,
    String? fulfillmentType,
    String? pickupTime,
    String? tableNumber,
    String? notes,
    List<Map<String, dynamic>> items = const [],
    double subtotal = 0.0,
    double tax = 0.0,
    double discount = 0.0,
    required double totalAmount,
  }) async {
    final pdfBytes = generateReceiptPdfBytes(
      orderId: orderId,
      shopName: shopName,
      shopPhone: shopPhone,
      shopAddress: shopAddress,
      customerName: customerName,
      customerPhone: customerPhone,
      orderCreatedAt: orderCreatedAt,
      paymentTime: paymentTime,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      fulfillmentType: fulfillmentType,
      pickupTime: pickupTime,
      tableNumber: tableNumber,
      notes: notes,
      items: items,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      totalAmount: totalAmount,
    );

    final cleanId = orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final shortId = cleanId.length > 8 ? cleanId.substring(0, 8).toUpperCase() : cleanId.toUpperCase();
    final fileName = 'Resit_Ngam_$shortId.pdf';

    return await saveAndDownloadFile(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }
}
