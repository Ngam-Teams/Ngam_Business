/// Formats raw database / gateway payment method codes (including legacy CHIP /
/// Razer Merchant Services tokens like `razer`, `razer_tng`, `chip_online`,
/// `CHIP DuitNow QR / FPX`) into clean merchant-facing labels with NO raw
/// processor names or ugly slashes.
class PaymentMethodFormatter {
  PaymentMethodFormatter._();

  static String format(String? raw) {
    final trimmed = (raw ?? '').trim();
    final lower = trimmed.toLowerCase();

    if (lower.isEmpty ||
        lower == 'online' ||
        lower == 'chip' ||
        lower == 'chip_online' ||
        lower == 'chip_asia' ||
        lower == 'razer' ||
        lower == 'razerpay' ||
        lower == 'rms' ||
        lower == 'molpay') {
      return 'Bayaran Dalam Talian';
    }

    if (lower == 'razer_tng' || lower == 'tng' || lower.contains('touch') || lower.contains('tng')) {
      return "Touch 'n Go eWallet";
    }
    if (lower == 'razer_grabpay' || lower == 'grabpay' || lower.contains('grab')) {
      return 'GrabPay';
    }
    if (lower == 'razer_shopeepay' || lower == 'shopeepay' || lower.contains('shopee')) {
      return 'ShopeePay';
    }
    if (lower == 'razer_boost' || lower == 'boost' || lower.contains('boost')) {
      return 'Boost';
    }
    if (lower == 'razer_atome' || lower == 'atome' || lower.contains('atome')) {
      return 'Atome';
    }

    if (lower == 'duitnow' ||
        lower == 'duitnow_qr' ||
        lower == 'duitnowqr' ||
        lower == 'dnqr' ||
        lower == 'dn_qr' ||
        lower == 'razer_maybankqr' ||
        lower == 'maybankqr' ||
        lower == 'maybank_qr' ||
        lower == 'qr' ||
        lower.contains('dnqr') ||
        (lower.contains('duitnow') &&
            !lower.contains('obw') &&
            !lower.contains('online') &&
            !lower.contains('transfer') &&
            !lower.contains('fpx'))) {
      return 'DuitNow QR';
    }

    if (lower == 'duitnow_obw' ||
        lower == 'dnobw' ||
        lower == 'obw' ||
        lower == 'duitnow_transfer' ||
        lower == 'fpx' ||
        lower == 'fpx_b2b1' ||
        lower == 'fpx_card' ||
        lower == 'online_banking' ||
        lower.contains('duitnow online') ||
        lower.contains('duitnow transfer') ||
        lower.contains('fpx')) {
      return 'DuitNow Online Banking';
    }

    if (lower == 'visa') return 'Visa';
    if (lower == 'mastercard') return 'Mastercard';
    if (lower == 'card' ||
        lower.contains('credit') ||
        lower.contains('debit') ||
        lower.contains('visa') ||
        lower.contains('mastercard') ||
        lower.contains('kad')) {
      return 'Kad Kredit / Debit';
    }

    if (lower == 'ngampay' || lower == 'wallet' || lower.contains('ngampay')) {
      return 'NgamPay';
    }

    if (lower == 'cash' ||
        lower == 'tunai' ||
        lower == 'counter' ||
        lower == 'cod' ||
        lower.contains('cash') ||
        lower.contains('tunai')) {
      return 'Tunai';
    }

    final cleaned = trimmed
        .replaceAll(RegExp(r'\s*\(?chip(\s+asia)?\)?', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'Bayaran Dalam Talian';
  }
}
