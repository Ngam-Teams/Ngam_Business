import 'package:hugeicons/hugeicons.dart';

class BusinessTypeItem {
  final String id;
  final String categoryGroup;
  final String nameKey;
  final String descKey;
  final List<List<dynamic>> icon;

  const BusinessTypeItem({
    required this.id,
    required this.categoryGroup,
    required this.nameKey,
    required this.descKey,
    required this.icon,
  });
}

class BusinessTypeCatalog {
  static const List<String> categories = [
    'all',
    'pets',
    'fnb',
    'beauty',
    'automotive',
    'home_services',
    'sports',
    'health',
    'education',
    'retail',
    'professional',
  ];

  static final List<BusinessTypeItem> allTypes = [
    // ─── 1. Haiwan Peliharaan / Pets ──────────────────────────────────────────
    const BusinessTypeItem(
      id: 'pet_hotel',
      categoryGroup: 'pets',
      nameKey: 'business_type.items.pet_hotel.name',
      descKey: 'business_type.items.pet_hotel.desc',
      icon: HugeIcons.strokeRoundedHotel01,
    ),
    const BusinessTypeItem(
      id: 'pet_grooming',
      categoryGroup: 'pets',
      nameKey: 'business_type.items.pet_grooming.name',
      descKey: 'business_type.items.pet_grooming.desc',
      icon: HugeIcons.strokeRoundedBathtub01,
    ),
    const BusinessTypeItem(
      id: 'pet_clinic',
      categoryGroup: 'pets',
      nameKey: 'business_type.items.pet_clinic.name',
      descKey: 'business_type.items.pet_clinic.desc',
      icon: HugeIcons.strokeRoundedClinic,
    ),
    const BusinessTypeItem(
      id: 'pet_shop',
      categoryGroup: 'pets',
      nameKey: 'business_type.items.pet_shop.name',
      descKey: 'business_type.items.pet_shop.desc',
      icon: HugeIcons.strokeRoundedShoppingBasket02,
    ),
    const BusinessTypeItem(
      id: 'pet_cafe',
      categoryGroup: 'pets',
      nameKey: 'business_type.items.pet_cafe.name',
      descKey: 'business_type.items.pet_cafe.desc',
      icon: HugeIcons.strokeRoundedCoffee02,
    ),

    // ─── 2. Makanan & Minuman / F&B ──────────────────────────────────────────
    const BusinessTypeItem(
      id: 'restaurant',
      categoryGroup: 'fnb',
      nameKey: 'business_type.items.restaurant.name',
      descKey: 'business_type.items.restaurant.desc',
      icon: HugeIcons.strokeRoundedRestaurant,
    ),
    const BusinessTypeItem(
      id: 'cafe_bakery',
      categoryGroup: 'fnb',
      nameKey: 'business_type.items.cafe_bakery.name',
      descKey: 'business_type.items.cafe_bakery.desc',
      icon: HugeIcons.strokeRoundedCoffee01,
    ),
    const BusinessTypeItem(
      id: 'food_stall',
      categoryGroup: 'fnb',
      nameKey: 'business_type.items.food_stall.name',
      descKey: 'business_type.items.food_stall.desc',
      icon: HugeIcons.strokeRoundedStreetFood,
    ),
    const BusinessTypeItem(
      id: 'food_truck',
      categoryGroup: 'fnb',
      nameKey: 'business_type.items.food_truck.name',
      descKey: 'business_type.items.food_truck.desc',
      icon: HugeIcons.strokeRoundedTruck,
    ),
    const BusinessTypeItem(
      id: 'catering',
      categoryGroup: 'fnb',
      nameKey: 'business_type.items.catering.name',
      descKey: 'business_type.items.catering.desc',
      icon: HugeIcons.strokeRoundedServingFood,
    ),
    const BusinessTypeItem(
      id: 'dessert_drinks',
      categoryGroup: 'fnb',
      nameKey: 'business_type.items.dessert_drinks.name',
      descKey: 'business_type.items.dessert_drinks.desc',
      icon: HugeIcons.strokeRoundedNaturalFood,
    ),

    // ─── 3. Kecantikan & Dandanan / Beauty ──────────────────────────────────
    const BusinessTypeItem(
      id: 'barbershop',
      categoryGroup: 'beauty',
      nameKey: 'business_type.items.barbershop.name',
      descKey: 'business_type.items.barbershop.desc',
      icon: HugeIcons.strokeRoundedChairBarber,
    ),
    const BusinessTypeItem(
      id: 'muslimah_salon',
      categoryGroup: 'beauty',
      nameKey: 'business_type.items.muslimah_salon.name',
      descKey: 'business_type.items.muslimah_salon.desc',
      icon: HugeIcons.strokeRoundedScissor,
    ),
    const BusinessTypeItem(
      id: 'spa_massage',
      categoryGroup: 'beauty',
      nameKey: 'business_type.items.spa_massage.name',
      descKey: 'business_type.items.spa_massage.desc',
      icon: HugeIcons.strokeRoundedSparkles,
    ),
    const BusinessTypeItem(
      id: 'nail_lash',
      categoryGroup: 'beauty',
      nameKey: 'business_type.items.nail_lash.name',
      descKey: 'business_type.items.nail_lash.desc',
      icon: HugeIcons.strokeRoundedSmile,
    ),
    const BusinessTypeItem(
      id: 'aesthetic_clinic',
      categoryGroup: 'beauty',
      nameKey: 'business_type.items.aesthetic_clinic.name',
      descKey: 'business_type.items.aesthetic_clinic.desc',
      icon: HugeIcons.strokeRoundedClinic,
    ),

    // ─── 4. Automotif & Kenderaan / Automotive ──────────────────────────────
    const BusinessTypeItem(
      id: 'carwash',
      categoryGroup: 'automotive',
      nameKey: 'business_type.items.carwash.name',
      descKey: 'business_type.items.carwash.desc',
      icon: HugeIcons.strokeRoundedCar01,
    ),
    const BusinessTypeItem(
      id: 'detailing',
      categoryGroup: 'automotive',
      nameKey: 'business_type.items.detailing.name',
      descKey: 'business_type.items.detailing.desc',
      icon: HugeIcons.strokeRoundedClean,
    ),
    const BusinessTypeItem(
      id: 'workshop',
      categoryGroup: 'automotive',
      nameKey: 'business_type.items.workshop.name',
      descKey: 'business_type.items.workshop.desc',
      icon: HugeIcons.strokeRoundedWrench01,
    ),
    const BusinessTypeItem(
      id: 'tyre_battery',
      categoryGroup: 'automotive',
      nameKey: 'business_type.items.tyre_battery.name',
      descKey: 'business_type.items.tyre_battery.desc',
      icon: HugeIcons.strokeRoundedTools,
    ),
    const BusinessTypeItem(
      id: 'tint_accessories',
      categoryGroup: 'automotive',
      nameKey: 'business_type.items.tint_accessories.name',
      descKey: 'business_type.items.tint_accessories.desc',
      icon: HugeIcons.strokeRoundedCar02,
    ),
    const BusinessTypeItem(
      id: 'motorcycle_shop',
      categoryGroup: 'automotive',
      nameKey: 'business_type.items.motorcycle_shop.name',
      descKey: 'business_type.items.motorcycle_shop.desc',
      icon: HugeIcons.strokeRoundedMotorbike01,
    ),

    // ─── 5. Servis Rumah & Penjagaan / Home Services ────────────────────────
    const BusinessTypeItem(
      id: 'aircond_service',
      categoryGroup: 'home_services',
      nameKey: 'business_type.items.aircond_service.name',
      descKey: 'business_type.items.aircond_service.desc',
      icon: HugeIcons.strokeRoundedToolbox,
    ),
    const BusinessTypeItem(
      id: 'home_cleaning',
      categoryGroup: 'home_services',
      nameKey: 'business_type.items.home_cleaning.name',
      descKey: 'business_type.items.home_cleaning.desc',
      icon: HugeIcons.strokeRoundedCleaningBucket,
    ),
    const BusinessTypeItem(
      id: 'plumbing_electric',
      categoryGroup: 'home_services',
      nameKey: 'business_type.items.plumbing_electric.name',
      descKey: 'business_type.items.plumbing_electric.desc',
      icon: HugeIcons.strokeRoundedTools,
    ),
    const BusinessTypeItem(
      id: 'laundry_dobi',
      categoryGroup: 'home_services',
      nameKey: 'business_type.items.laundry_dobi.name',
      descKey: 'business_type.items.laundry_dobi.desc',
      icon: HugeIcons.strokeRoundedWashingMachine,
    ),
    const BusinessTypeItem(
      id: 'renovation_contractor',
      categoryGroup: 'home_services',
      nameKey: 'business_type.items.renovation_contractor.name',
      descKey: 'business_type.items.renovation_contractor.desc',
      icon: HugeIcons.strokeRoundedBuilding02,
    ),
    const BusinessTypeItem(
      id: 'pest_control',
      categoryGroup: 'home_services',
      nameKey: 'business_type.items.pest_control.name',
      descKey: 'business_type.items.pest_control.desc',
      icon: HugeIcons.strokeRoundedAlertCircle,
    ),

    // ─── 6. Sukan & Rekreasi / Sports ───────────────────────────────────────
    const BusinessTypeItem(
      id: 'badminton_court',
      categoryGroup: 'sports',
      nameKey: 'business_type.items.badminton_court.name',
      descKey: 'business_type.items.badminton_court.desc',
      icon: HugeIcons.strokeRoundedBadminton,
    ),
    const BusinessTypeItem(
      id: 'pickleball_court',
      categoryGroup: 'sports',
      nameKey: 'business_type.items.pickleball_court.name',
      descKey: 'business_type.items.pickleball_court.desc',
      icon: HugeIcons.strokeRoundedTennisRacket,
    ),
    const BusinessTypeItem(
      id: 'fitness_gym',
      categoryGroup: 'sports',
      nameKey: 'business_type.items.fitness_gym.name',
      descKey: 'business_type.items.fitness_gym.desc',
      icon: HugeIcons.strokeRoundedDumbbell01,
    ),
    const BusinessTypeItem(
      id: 'yoga_pilates',
      categoryGroup: 'sports',
      nameKey: 'business_type.items.yoga_pilates.name',
      descKey: 'business_type.items.yoga_pilates.desc',
      icon: HugeIcons.strokeRoundedGymnastic,
    ),
    const BusinessTypeItem(
      id: 'swimming_academy',
      categoryGroup: 'sports',
      nameKey: 'business_type.items.swimming_academy.name',
      descKey: 'business_type.items.swimming_academy.desc',
      icon: HugeIcons.strokeRoundedWorkoutSport,
    ),

    // ─── 7. Kesihatan & Terapi / Healthcare ─────────────────────────────────
    const BusinessTypeItem(
      id: 'medical_clinic',
      categoryGroup: 'health',
      nameKey: 'business_type.items.medical_clinic.name',
      descKey: 'business_type.items.medical_clinic.desc',
      icon: HugeIcons.strokeRoundedHospital02,
    ),
    const BusinessTypeItem(
      id: 'dental_clinic',
      categoryGroup: 'health',
      nameKey: 'business_type.items.dental_clinic.name',
      descKey: 'business_type.items.dental_clinic.desc',
      icon: HugeIcons.strokeRoundedDentalTooth,
    ),
    const BusinessTypeItem(
      id: 'physiotherapy',
      categoryGroup: 'health',
      nameKey: 'business_type.items.physiotherapy.name',
      descKey: 'business_type.items.physiotherapy.desc',
      icon: HugeIcons.strokeRoundedHospitalBed01,
    ),
    const BusinessTypeItem(
      id: 'optical_shop',
      categoryGroup: 'health',
      nameKey: 'business_type.items.optical_shop.name',
      descKey: 'business_type.items.optical_shop.desc',
      icon: HugeIcons.strokeRoundedGlasses,
    ),
    const BusinessTypeItem(
      id: 'pharmacy',
      categoryGroup: 'health',
      nameKey: 'business_type.items.pharmacy.name',
      descKey: 'business_type.items.pharmacy.desc',
      icon: HugeIcons.strokeRoundedMedicine02,
    ),
    const BusinessTypeItem(
      id: 'acupuncture_hijama',
      categoryGroup: 'health',
      nameKey: 'business_type.items.acupuncture_hijama.name',
      descKey: 'business_type.items.acupuncture_hijama.desc',
      icon: HugeIcons.strokeRoundedSparkles,
    ),

    // ─── 8. Pendidikan & Latihan / Education ────────────────────────────────
    const BusinessTypeItem(
      id: 'tuition_center',
      categoryGroup: 'education',
      nameKey: 'business_type.items.tuition_center.name',
      descKey: 'business_type.items.tuition_center.desc',
      icon: HugeIcons.strokeRoundedTeacher,
    ),
    const BusinessTypeItem(
      id: 'quran_class',
      categoryGroup: 'education',
      nameKey: 'business_type.items.quran_class.name',
      descKey: 'business_type.items.quran_class.desc',
      icon: HugeIcons.strokeRoundedBook02,
    ),
    const BusinessTypeItem(
      id: 'kindergarten_daycare',
      categoryGroup: 'education',
      nameKey: 'business_type.items.kindergarten_daycare.name',
      descKey: 'business_type.items.kindergarten_daycare.desc',
      icon: HugeIcons.strokeRoundedSmile,
    ),
    const BusinessTypeItem(
      id: 'music_art',
      categoryGroup: 'education',
      nameKey: 'business_type.items.music_art.name',
      descKey: 'business_type.items.music_art.desc',
      icon: HugeIcons.strokeRoundedMusicNote01,
    ),
    const BusinessTypeItem(
      id: 'driving_school',
      categoryGroup: 'education',
      nameKey: 'business_type.items.driving_school.name',
      descKey: 'business_type.items.driving_school.desc',
      icon: HugeIcons.strokeRoundedCar03,
    ),

    // ─── 9. Perniagaan Runcit / Retail ──────────────────────────────────────
    const BusinessTypeItem(
      id: 'minimarket',
      categoryGroup: 'retail',
      nameKey: 'business_type.items.minimarket.name',
      descKey: 'business_type.items.minimarket.desc',
      icon: HugeIcons.strokeRoundedStore03,
    ),
    const BusinessTypeItem(
      id: 'fresh_market',
      categoryGroup: 'retail',
      nameKey: 'business_type.items.fresh_market.name',
      descKey: 'business_type.items.fresh_market.desc',
      icon: HugeIcons.strokeRoundedShoppingBasket02,
    ),
    const BusinessTypeItem(
      id: 'florist',
      categoryGroup: 'retail',
      nameKey: 'business_type.items.florist.name',
      descKey: 'business_type.items.florist.desc',
      icon: HugeIcons.strokeRoundedFlower,
    ),
    const BusinessTypeItem(
      id: 'boutique_fashion',
      categoryGroup: 'retail',
      nameKey: 'business_type.items.boutique_fashion.name',
      descKey: 'business_type.items.boutique_fashion.desc',
      icon: HugeIcons.strokeRoundedTShirt,
    ),
    const BusinessTypeItem(
      id: 'jewelry_gold',
      categoryGroup: 'retail',
      nameKey: 'business_type.items.jewelry_gold.name',
      descKey: 'business_type.items.jewelry_gold.desc',
      icon: HugeIcons.strokeRoundedCoins01,
    ),

    // ─── 10. Servis Profesional & Kreatif / Professional ────────────────────
    const BusinessTypeItem(
      id: 'photography_studio',
      categoryGroup: 'professional',
      nameKey: 'business_type.items.photography_studio.name',
      descKey: 'business_type.items.photography_studio.desc',
      icon: HugeIcons.strokeRoundedCamera01,
    ),
    const BusinessTypeItem(
      id: 'printing_banner',
      categoryGroup: 'professional',
      nameKey: 'business_type.items.printing_banner.name',
      descKey: 'business_type.items.printing_banner.desc',
      icon: HugeIcons.strokeRoundedPrinter,
    ),
    const BusinessTypeItem(
      id: 'gadget_repair',
      categoryGroup: 'professional',
      nameKey: 'business_type.items.gadget_repair.name',
      descKey: 'business_type.items.gadget_repair.desc',
      icon: HugeIcons.strokeRoundedComputerCheck,
    ),
    const BusinessTypeItem(
      id: 'coworking_space',
      categoryGroup: 'professional',
      nameKey: 'business_type.items.coworking_space.name',
      descKey: 'business_type.items.coworking_space.desc',
      icon: HugeIcons.strokeRoundedBuilding06,
    ),
    const BusinessTypeItem(
      id: 'event_hall',
      categoryGroup: 'professional',
      nameKey: 'business_type.items.event_hall.name',
      descKey: 'business_type.items.event_hall.desc',
      icon: HugeIcons.strokeRoundedBuilding03,
    ),
  ];

  static BusinessTypeItem? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return allTypes.firstWhere(
        (element) => element.id.toLowerCase() == id.toLowerCase(),
      );
    } catch (_) {
      // Legacy mapping fallback
      final legacy = _legacyMap[id.toLowerCase()];
      if (legacy != null) {
        return findById(legacy);
      }
      return null;
    }
  }

  static const Map<String, String> _legacyMap = {
    'barber': 'barbershop',
    'salon': 'muslimah_salon',
    'spa': 'spa_massage',
    'tailor': 'boutique_fashion',
    'laundry': 'laundry_dobi',
    'car_wash': 'carwash',
    'cafe': 'cafe_bakery',
    'bakery': 'cafe_bakery',
    'gym': 'fitness_gym',
    'clinic': 'medical_clinic',
    'studio': 'photography_studio',
    'pets': 'pet_hotel',
    'fnb': 'restaurant',
    'beauty': 'barbershop',
    'auto': 'workshop',
    'retail': 'minimarket',
    'services': 'home_cleaning',
  };

  /// Converts any granular business type or category into one of the 4 strict
  /// PostgreSQL CHECK constraint values: ('fnb', 'barber', 'retail', 'services').
  static String toDbIndustry(String? typeOrCategory) {
    if (typeOrCategory == null || typeOrCategory.trim().isEmpty) return 'services';
    final lower = typeOrCategory.toLowerCase().trim();

    // Direct matches with valid DB constraint
    if (lower == 'fnb' || lower == 'barber' || lower == 'retail' || lower == 'services') {
      return lower;
    }

    final item = findById(lower);
    if (item != null) {
      switch (item.categoryGroup) {
        case 'fnb':
          return 'fnb';
        case 'beauty':
          return 'barber';
        case 'retail':
          return 'retail';
        case 'pets':
          if (item.id == 'pet_shop') return 'retail';
          if (item.id == 'pet_cafe') return 'fnb';
          return 'services';
        case 'automotive':
        case 'home_services':
        case 'sports':
        case 'health':
        case 'education':
        case 'professional':
        default:
          return 'services';
      }
    }

    // Heuristics fallback
    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('cafe') || lower.contains('fnb')) {
      return 'fnb';
    }
    if (lower.contains('barber') || lower.contains('salon') || lower.contains('beauty') || lower.contains('spa')) {
      return 'barber';
    }
    if (lower.contains('retail') || lower.contains('market') || lower.contains('shop') || lower.contains('store')) {
      return 'retail';
    }

    return 'services';
  }
}

