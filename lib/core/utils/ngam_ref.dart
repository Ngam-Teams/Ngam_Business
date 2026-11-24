import 'dart:math';

/// Standard penomboran rujukan rasmi Ekosistem Ngam (14 aksara, sifar sempang, gaya Shopee):
/// Format: `N` + `<Kod Jenis 1 Huruf>` + `<YYMMDD (MYT)>` + `<6 Aksara Base32 Bersih>`
///
/// Kamus Kod Rasmi:
/// - `NO` : Ngam Order      (cth: `NO261123K7M9P2`)
/// - `NB` : Ngam Booking    (cth: `NB261123H4W8X3`)
/// - `NP` : Ngam POS        (cth: `NP261123R5T2V9`)
/// - `NS` : Ngam Support    (cth: `NS261123C6N4Y8`)
/// - `ND` : Ngam Dispute    (cth: `ND2611238F2A1C`)
/// - `NR` : Ngam Refund     (cth: `NR2611233D9E4B`)
/// - `NW` : Ngam Withdrawal (cth: `NW2611237C1B5A`)
/// - `NT` : Ngam Top-up     (cth: `NT2611235A2F9D`)
class NgamRef {
  NgamRef._();

  /// 32 aksara alfanumerik bersih (tiada 0, O, 1, I untuk elak kekeliruan bacaan)
  /// 32^6 = 1,073,741,824 (1.07 bilion kombinasi unik sehari)
  static const String alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static final RegExp _ngamRefRegex =
      RegExp(r'^N[OBPSDRWT]\d{6}[A-Z0-9]{6}$', caseSensitive: false);
  static final RegExp _uuidHexRegex =
      RegExp(r'^[0-9a-f]{32}$', caseSensitive: false);

  /// Tarikh `YYMMDD` mengikut Waktu Malaysia (UTC+8) supaya konsisten antara aplikasi & pelayan.
  static String datePart([DateTime? dt]) {
    final myt = (dt ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
    final yy = (myt.year % 100).toString().padLeft(2, '0');
    final mm = myt.month.toString().padLeft(2, '0');
    final dd = myt.day.toString().padLeft(2, '0');
    return '$yy$mm$dd';
  }

  /// Jana 6 aksara rawak kriptografi daripada [alphabet].
  static String randomCode6() {
    Random rnd;
    try {
      rnd = Random.secure();
    } catch (_) {
      rnd = Random();
    }
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
      ),
    );
  }

  /// Jana 6 aksara Base32 secara deterministik daripada UUID (6 bait pertama mod 32 = taburan 100% sekata).
  static String code6FromId(String rawId) {
    final clean = rawId.trim().replaceAll('#', '');
    if (_ngamRefRegex.hasMatch(clean)) {
      return clean.substring(8).toUpperCase();
    }
    final hex = clean.replaceAll('-', '').toLowerCase();
    if (hex.length >= 12 && _uuidHexRegex.hasMatch(hex.padRight(32, '0').substring(0, 32))) {
      final sb = StringBuffer();
      for (int i = 0; i < 6; i++) {
        final byteVal = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16) ?? 0;
        sb.write(alphabet[byteVal % 32]);
      }
      return sb.toString();
    }
    final alnum = clean.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (alnum.length >= 6) {
      return alnum.substring(alnum.length - 6);
    }
    return alnum.padRight(6, '2');
  }

  /// Format mana-mana ID kepada standard 14-aksara `N<Type><YYMMDD><6Code>`.
  static String format(
    String prefix,
    String? rawId, {
    DateTime? createdAt,
  }) {
    final p = prefix.trim().toUpperCase();
    final clean = (rawId ?? '').trim().replaceAll('#', '');
    if (clean.isEmpty) {
      return '$p${datePart(createdAt)}${randomCode6()}';
    }
    if (_ngamRefRegex.hasMatch(clean)) {
      return clean.toUpperCase();
    }
    final upper = clean.toUpperCase();
    if (upper.startsWith('RZRV-')) {
      return upper;
    }
    return '$p${datePart(createdAt)}${code6FromId(clean)}';
  }

  // ── 8 Jenis Rujukan Rasmi Ekosistem Ngam ──

  /// `NO` — Ngam Order (Pesanan Produk / Makanan)
  static String order(String? id, {DateTime? createdAt}) =>
      format('NO', id, createdAt: createdAt);

  /// `NB` — Ngam Booking (Tempahan Servis / Temujanji)
  static String booking([String? id, DateTime? createdAt]) =>
      format('NB', id, createdAt: createdAt);

  /// `NP` — Ngam POS (Jualan Kaunter POS)
  static String pos([String? id, DateTime? createdAt]) =>
      format('NP', id, createdAt: createdAt);

  /// `NS` — Ngam Support (Tiket Bantuan & Sokongan)
  static String support([String? id, DateTime? createdAt]) =>
      format('NS', id, createdAt: createdAt);

  /// `ND` — Ngam Dispute (Kes Pertikaian Pesanan)
  static String dispute(String? id, {DateTime? createdAt}) =>
      format('ND', id, createdAt: createdAt);

  /// `NR` — Ngam Refund (Rekod Pemulangan Wang)
  static String refund(String? id, {DateTime? createdAt}) =>
      format('NR', id, createdAt: createdAt);

  /// `NW` — Ngam Withdrawal (Pengeluaran Hasil Jualan Peniaga)
  static String withdrawal(String? id, {DateTime? createdAt}) =>
      format('NW', id, createdAt: createdAt);

  /// `NT` — Ngam Top-up (Tambah Nilai Dompet NgamPay)
  static String topup(String? id, {DateTime? createdAt}) =>
      format('NT', id, createdAt: createdAt);

  /// Semak sama ada kod rujukan sudah mengikut format rasmi 14 aksara (`N[OBPSDRWT]YYMMDDXXXXXX`).
  static bool isValid(String? ref) {
    final clean = (ref ?? '').trim().replaceAll('#', '');
    return _ngamRefRegex.hasMatch(clean);
  }

  /// Semak sama ada kod rujukan ialah rujukan Tempahan (`NB...` atau `RZRV-...`).
  static bool isBookingReference(String? ref) {
    final clean = (ref ?? '').trim().replaceAll('#', '').toUpperCase();
    if (clean.startsWith('RZRV-')) return true;
    return RegExp(r'^NB\d{6}[A-Z0-9]{6}$').hasMatch(clean);
  }

  /// Semak sama ada carian/imbasan [query] sepadan dengan rekod [recordId].
  static bool matches(
    String query,
    String recordId, {
    String prefix = 'NO',
    DateTime? createdAt,
  }) {
    var q = query.trim().toUpperCase();
    for (final tag in [
      'NGAM-ORDER:',
      'NGAM:ORDER:',
      'NGAM-BOOKING:',
      'NGAM:BOOKING:',
      'NGAM:',
      'ID:',
    ]) {
      if (q.startsWith(tag)) {
        q = q.substring(tag.length).trim();
      }
    }
    q = q.replaceAll('#', '').trim();
    if (q.isEmpty) return false;

    final idUpper = recordId.trim().replaceAll('#', '').toUpperCase();
    if (idUpper == q) return true;
    if (q.length >= 6 && (idUpper.startsWith(q) || idUpper.endsWith(q))) {
      return true;
    }

    final code6 = code6FromId(recordId);
    if (q == code6) return true;
    if (_ngamRefRegex.hasMatch(q) && q.substring(8) == code6) {
      return true;
    }
    final formatted = format(prefix, recordId, createdAt: createdAt);
    if (formatted == q || (q.length >= 6 && formatted.endsWith(q))) {
      return true;
    }
    return false;
  }
}
