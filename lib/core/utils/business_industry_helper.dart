import '../../features/settings/data/business_service.dart';
import '../../features/settings/models/business_type_catalog.dart';

enum BusinessVertical { fnb, beauty, retail, services }

/// Central industry resolver for Ngam Business so POS, Orders, Live Board,
/// Modifiers, and QR Standees adapt naturally to F&B, Barber/Beauty, Retail,
/// and Service businesses instead of hardcoding restaurant-only labels.
class BusinessIndustryHelper {
  BusinessIndustryHelper._();

  static BusinessVertical resolve({
    String? granularType,
    String? industry,
    String? shopName,
  }) {
    final g = (granularType ?? '').trim().toLowerCase();
    final ind = (industry ?? '').trim().toLowerCase();
    final name = (shopName ?? '').trim().toLowerCase();

    // 1. Most specific: granular business_type (e.g. barbershop, restaurant, minimarket)
    if (g.isNotEmpty) {
      final byId = BusinessTypeCatalog.findById(g);
      if (byId != null) {
        if (byId.categoryGroup == 'fnb' || byId.id == 'pet_cafe') {
          return BusinessVertical.fnb;
        }
        if (byId.categoryGroup == 'beauty' || byId.id == 'pet_grooming') {
          return BusinessVertical.beauty;
        }
        if (byId.categoryGroup == 'retail' ||
            byId.id == 'pet_shop' ||
            byId.id == 'optical_shop' ||
            byId.id == 'pharmacy') {
          return BusinessVertical.retail;
        }
        return BusinessVertical.services;
      }
    }

    // 2. Canonical businesses.business_industry column ('fnb', 'barber', 'retail', 'services')
    if (ind == 'fnb') return BusinessVertical.fnb;
    if (ind == 'barber' || ind == 'beauty') return BusinessVertical.beauty;
    if (ind == 'retail') return BusinessVertical.retail;
    if (ind == 'services') return BusinessVertical.services;

    // 3. Heuristic token match from industry or shop name
    final combined = '$g $ind $name';
    if (combined.contains('barber') ||
        combined.contains('salon') ||
        combined.contains('salun') ||
        combined.contains('spa') ||
        combined.contains('beauty') ||
        combined.contains('gunting') ||
        combined.contains('hair') ||
        combined.contains('grooming')) {
      return BusinessVertical.beauty;
    }
    if (combined.contains('restoran') ||
        combined.contains('restaurant') ||
        combined.contains('cafe') ||
        combined.contains('kafe') ||
        combined.contains('warung') ||
        combined.contains('kopitiam') ||
        combined.contains('bakery') ||
        combined.contains('bistro') ||
        combined.contains('kitchen') ||
        combined.contains('dapur') ||
        combined.contains('makan') ||
        combined.contains('food')) {
      return BusinessVertical.fnb;
    }
    if (combined.contains('mart') ||
        combined.contains('runcit') ||
        combined.contains('butik') ||
        combined.contains('boutique') ||
        combined.contains('retail') ||
        combined.contains('florist') ||
        combined.contains('farmasi') ||
        combined.contains('pharmacy') ||
        combined.contains('optik')) {
      return BusinessVertical.retail;
    }

    return BusinessVertical.services;
  }

  static BusinessVertical fromProfile([Map<String, dynamic>? profile]) {
    final p = profile ?? BusinessService.cachedProfile;
    if (p == null) return BusinessVertical.services;

    String? granularType = p['business_type']?.toString();
    final settings = p['settings'];
    if (granularType == null && settings is Map) {
      final op = settings['operating_hours'];
      if (op is Map && op['business_type'] != null) {
        granularType = op['business_type'].toString();
      }
    }

    return resolve(
      granularType: granularType,
      industry: p['business_industry']?.toString(),
      shopName: (p['business_name'] ?? p['name'])?.toString(),
    );
  }

  static bool isFnbFromProfile([Map<String, dynamic>? profile]) {
    return fromProfile(profile) == BusinessVertical.fnb;
  }
}
