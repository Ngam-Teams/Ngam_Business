import 'package:easy_localization/easy_localization.dart';
import 'package:hugeicons/hugeicons.dart';

class BusinessTypeItem {
  final String id;
  final String categoryGroup;
  final String bookingMode; // 'none' | 'time_slot' | 'overnight'
  final String nameKey;
  final String descKey;
  final List<List<dynamic>> icon;
  final List<String> keywords;

  const BusinessTypeItem({
    required this.id,
    required this.categoryGroup,
    required this.bookingMode,
    required this.nameKey,
    required this.descKey,
    required this.icon,
    this.keywords = const [],
  });
}

class BusinessTypeCatalog {
  /// Ordered by real-world Malaysian merchant volume (most common first;
  /// niche sectors such as pets positioned further back).
  static const List<String> categories = [
    'all',
    'fnb',
    'retail',
    'beauty',
    'stay',
    'automotive',
    'home_services',
    'health',
    'sports',
    'pets',
    'education',
    'professional',
  ];

  static final List<BusinessTypeItem> allTypes = [
    // ─── 1. Makanan & Minuman / F&B ──────────────────────────────────────────
    const BusinessTypeItem(
      id: 'restaurant',
      categoryGroup: 'fnb',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.restaurant.name',
      descKey: 'business_type.items.restaurant.desc',
      icon: HugeIcons.strokeRoundedRestaurant,
      keywords: ['restoran', 'restaurant', 'makan', 'masakan', 'panas', 'dine', 'meja', 'bistro', 'mamak', 'seafood', 'western', 'thai', 'tomyam', 'keluarga', 'fnb'],
    ),
    const BusinessTypeItem(
      id: 'kedai_makan',
      categoryGroup: 'fnb',
      bookingMode: 'none',
      nameKey: 'business_type.items.kedai_makan.name',
      descKey: 'business_type.items.kedai_makan.desc',
      icon: HugeIcons.strokeRoundedRestaurant01,
      keywords: ['kedai', 'makan', 'kampung', 'nasi', 'campur', 'lauk', 'tomyam', 'goreng', 'eatery', 'local', 'dining', 'fnb', 'masakan', 'tengahari'],
    ),
    const BusinessTypeItem(
      id: 'cafe_bakery',
      categoryGroup: 'fnb',
      bookingMode: 'none',
      nameKey: 'business_type.items.cafe_bakery.name',
      descKey: 'business_type.items.cafe_bakery.desc',
      icon: HugeIcons.strokeRoundedCoffee01,
      keywords: ['kafe', 'cafe', 'kopi', 'coffee', 'bakeri', 'bakery', 'roti', 'kek', 'cake', 'pastri', 'pastry', 'latte', 'matcha', 'kopitiam'],
    ),
    const BusinessTypeItem(
      id: 'food_stall',
      categoryGroup: 'fnb',
      bookingMode: 'none',
      nameKey: 'business_type.items.food_stall.name',
      descKey: 'business_type.items.food_stall.desc',
      icon: HugeIcons.strokeRoundedStreetFood,
      keywords: ['gerai', 'warung', 'hawker', 'stall', 'medan', 'selera', 'nasi', 'lemak', 'burger', 'roti', 'canai', 'sarapan', 'street', 'food'],
    ),
    const BusinessTypeItem(
      id: 'food_truck',
      categoryGroup: 'fnb',
      bookingMode: 'none',
      nameKey: 'business_type.items.food_truck.name',
      descKey: 'business_type.items.food_truck.desc',
      icon: HugeIcons.strokeRoundedTruck,
      keywords: ['food', 'truck', 'trak', 'makanan', 'bergerak', 'pasar', 'malam', 'karnival', 'burger', 'taco'],
    ),
    const BusinessTypeItem(
      id: 'catering',
      categoryGroup: 'fnb',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.catering.name',
      descKey: 'business_type.items.catering.desc',
      icon: HugeIcons.strokeRoundedServingFood,
      keywords: ['katering', 'catering', 'kenduri', 'kahwin', 'bufet', 'buffet', 'jamuan', 'majlis', 'korporat', 'event'],
    ),
    const BusinessTypeItem(
      id: 'dessert_drinks',
      categoryGroup: 'fnb',
      bookingMode: 'none',
      nameKey: 'business_type.items.dessert_drinks.name',
      descKey: 'business_type.items.dessert_drinks.desc',
      icon: HugeIcons.strokeRoundedNaturalFood,
      keywords: ['minuman', 'air', 'boba', 'bubble', 'tea', 'teh', 'jus', 'aiskrim', 'ice', 'cream', 'wafel', 'waffle', 'pencuci', 'mulut', 'dessert', 'drinks', 'cendol', 'abc'],
    ),

    // ─── 2. Perniagaan Runcit / Retail ───────────────────────────────────────
    const BusinessTypeItem(
      id: 'minimarket',
      categoryGroup: 'retail',
      bookingMode: 'none',
      nameKey: 'business_type.items.minimarket.name',
      descKey: 'business_type.items.minimarket.desc',
      icon: HugeIcons.strokeRoundedStore03,
      keywords: ['runcit', 'kedai', 'minimarket', 'mini', 'market', 'grocery', 'mart', 'serbaneka', 'barangan', 'harian', 'retail'],
    ),
    const BusinessTypeItem(
      id: 'fresh_market',
      categoryGroup: 'retail',
      bookingMode: 'none',
      nameKey: 'business_type.items.fresh_market.name',
      descKey: 'business_type.items.fresh_market.desc',
      icon: HugeIcons.strokeRoundedShoppingBasket02,
      keywords: ['pasar', 'segar', 'fresh', 'market', 'sayur', 'buah', 'ikan', 'ayam', 'daging', 'basah', 'mart'],
    ),
    const BusinessTypeItem(
      id: 'boutique_fashion',
      categoryGroup: 'retail',
      bookingMode: 'none',
      nameKey: 'business_type.items.boutique_fashion.name',
      descKey: 'business_type.items.boutique_fashion.desc',
      icon: HugeIcons.strokeRoundedTShirt,
      keywords: ['butik', 'boutique', 'fesyen', 'fashion', 'baju', 'pakaian', 'tudung', 'jahit', 'tailor', 'kasut', 'beg', 'clothing'],
    ),
    const BusinessTypeItem(
      id: 'florist',
      categoryGroup: 'retail',
      bookingMode: 'none',
      nameKey: 'business_type.items.florist.name',
      descKey: 'business_type.items.florist.desc',
      icon: HugeIcons.strokeRoundedFlower,
      keywords: ['bunga', 'florist', 'bouquet', 'jambangan', 'hadiah', 'gift', 'hamper', 'surprise'],
    ),
    const BusinessTypeItem(
      id: 'jewelry_gold',
      categoryGroup: 'retail',
      bookingMode: 'none',
      nameKey: 'business_type.items.jewelry_gold.name',
      descKey: 'business_type.items.jewelry_gold.desc',
      icon: HugeIcons.strokeRoundedCoins01,
      keywords: ['emas', 'gold', 'barang', 'kemas', 'jewelry', 'cincin', 'rantai', 'gelang', 'perak'],
    ),

    // ─── 3. Kecantikan & Dandanan / Beauty ───────────────────────────────────
    const BusinessTypeItem(
      id: 'barbershop',
      categoryGroup: 'beauty',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.barbershop.name',
      descKey: 'business_type.items.barbershop.desc',
      icon: HugeIcons.strokeRoundedChairBarber,
      keywords: ['barber', 'barbershop', 'gunting', 'rambut', 'lelaki', 'haircut', 'janggut', 'pomade', 'cukur', 'fade', 'kedai'],
    ),
    const BusinessTypeItem(
      id: 'muslimah_salon',
      categoryGroup: 'beauty',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.muslimah_salon.name',
      descKey: 'business_type.items.muslimah_salon.desc',
      icon: HugeIcons.strokeRoundedScissor,
      keywords: ['salun', 'salon', 'muslimah', 'rambut', 'wanita', 'hijab', 'hair', 'rebonding', 'treatment', 'gunting'],
    ),
    const BusinessTypeItem(
      id: 'spa_massage',
      categoryGroup: 'beauty',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.spa_massage.name',
      descKey: 'business_type.items.spa_massage.desc',
      icon: HugeIcons.strokeRoundedSparkles,
      keywords: ['spa', 'urut', 'urutan', 'massage', 'refleksologi', 'reflexology', 'bekam', 'lulur', 'sauna', 'aromaterapi', 'pantang', 'confinement'],
    ),
    const BusinessTypeItem(
      id: 'nail_lash',
      categoryGroup: 'beauty',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.nail_lash.name',
      descKey: 'business_type.items.nail_lash.desc',
      icon: HugeIcons.strokeRoundedSmile,
      keywords: ['kuku', 'nail', 'manicure', 'pedicure', 'bulu', 'mata', 'lash', 'eyelash', 'brow', 'henna', 'inai'],
    ),
    const BusinessTypeItem(
      id: 'aesthetic_clinic',
      categoryGroup: 'beauty',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.aesthetic_clinic.name',
      descKey: 'business_type.items.aesthetic_clinic.desc',
      icon: HugeIcons.strokeRoundedClinic,
      keywords: ['estetik', 'aesthetic', 'facial', 'kulit', 'skin', 'jerawat', 'laser', 'kecantikan', 'medispa', 'klinik'],
    ),

    // ─── 4. Penginapan / Accommodation & Stays ───────────────────────────────
    const BusinessTypeItem(
      id: 'hotel',
      categoryGroup: 'stay',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.hotel.name',
      descKey: 'business_type.items.hotel.desc',
      icon: HugeIcons.strokeRoundedHotel01,
      keywords: ['hotel', 'boutique', 'bilik', 'suite', 'penginapan', 'inap', 'bermalam', 'overnight', 'stay', 'check', 'hospitality', 'motel', 'inn'],
    ),
    const BusinessTypeItem(
      id: 'homestay',
      categoryGroup: 'stay',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.homestay.name',
      descKey: 'business_type.items.homestay.desc',
      icon: HugeIcons.strokeRoundedHome11,
      keywords: ['homestay', 'rumah', 'tamu', 'guest', 'house', 'penginapan', 'inap', 'desa', 'cuti', 'percutian', 'keluarga', 'stay', 'airbnb', 'overnight'],
    ),
    const BusinessTypeItem(
      id: 'chalet',
      categoryGroup: 'stay',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.chalet.name',
      descKey: 'business_type.items.chalet.desc',
      icon: HugeIcons.strokeRoundedBuilding02,
      keywords: ['chalet', 'kabin', 'cabin', 'pantai', 'sungai', 'penginapan', 'inap', 'percutian', 'lodge', 'eco', 'stay', 'overnight'],
    ),
    const BusinessTypeItem(
      id: 'roomstay',
      categoryGroup: 'stay',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.roomstay.name',
      descKey: 'business_type.items.roomstay.desc',
      icon: HugeIcons.strokeRoundedBuilding06,
      keywords: ['roomstay', 'bilik', 'sewa', 'harian', 'bajet', 'budget', 'inn', 'penginapan', 'inap', 'stay', 'overnight', 'room'],
    ),
    const BusinessTypeItem(
      id: 'resort',
      categoryGroup: 'stay',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.resort.name',
      descKey: 'business_type.items.resort.desc',
      icon: HugeIcons.strokeRoundedBuilding03,
      keywords: ['resort', 'vila', 'villa', 'kolam', 'pool', 'percutian', 'holiday', 'retreat', 'penginapan', 'stay', 'overnight'],
    ),
    const BusinessTypeItem(
      id: 'glamping',
      categoryGroup: 'stay',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.glamping.name',
      descKey: 'business_type.items.glamping.desc',
      icon: HugeIcons.strokeRoundedSparkles,
      keywords: ['glamping', 'khemah', 'camp', 'campsite', 'perkhemahan', 'camping', 'tent', 'dome', 'alam', 'penginapan', 'stay', 'overnight'],
    ),

    // ─── 5. Automotif & Kenderaan / Automotive ───────────────────────────────
    const BusinessTypeItem(
      id: 'carwash',
      categoryGroup: 'automotive',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.carwash.name',
      descKey: 'business_type.items.carwash.desc',
      icon: HugeIcons.strokeRoundedCar01,
      keywords: ['cuci', 'kereta', 'carwash', 'car', 'wash', 'snow', 'vakum', 'wax', 'moto', 'motosikal', 'basuh'],
    ),
    const BusinessTypeItem(
      id: 'detailing',
      categoryGroup: 'automotive',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.detailing.name',
      descKey: 'business_type.items.detailing.desc',
      icon: HugeIcons.strokeRoundedClean,
      keywords: ['detailing', 'polish', 'coating', 'ceramic', 'ppf', 'kereta', 'kilat', 'wrap', 'auto'],
    ),
    const BusinessTypeItem(
      id: 'workshop',
      categoryGroup: 'automotive',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.workshop.name',
      descKey: 'business_type.items.workshop.desc',
      icon: HugeIcons.strokeRoundedWrench01,
      keywords: ['bengkel', 'workshop', 'servis', 'kereta', 'enjin', 'minyak', 'hitam', 'mekanik', 'repair', 'auto', 'aircond'],
    ),
    const BusinessTypeItem(
      id: 'tyre_battery',
      categoryGroup: 'automotive',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.tyre_battery.name',
      descKey: 'business_type.items.tyre_battery.desc',
      icon: HugeIcons.strokeRoundedTools,
      keywords: ['tayar', 'tyre', 'tire', 'bateri', 'battery', 'alignment', 'balancing', 'rim', 'kereta'],
    ),
    const BusinessTypeItem(
      id: 'tint_accessories',
      categoryGroup: 'automotive',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.tint_accessories.name',
      descKey: 'business_type.items.tint_accessories.desc',
      icon: HugeIcons.strokeRoundedCar02,
      keywords: ['tinted', 'tint', 'cermin', 'aksesori', 'accessories', 'dashcam', 'audio', 'kereta', 'android', 'player'],
    ),
    const BusinessTypeItem(
      id: 'motorcycle_shop',
      categoryGroup: 'automotive',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.motorcycle_shop.name',
      descKey: 'business_type.items.motorcycle_shop.desc',
      icon: HugeIcons.strokeRoundedMotorbike01,
      keywords: ['bengkel', 'motor', 'motosikal', 'motorcycle', 'bike', 'servis', 'sparepart', 'tayar', 'superbike'],
    ),

    // ─── 6. Servis Rumah & Penjagaan / Home Services ─────────────────────────
    const BusinessTypeItem(
      id: 'aircond_service',
      categoryGroup: 'home_services',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.aircond_service.name',
      descKey: 'business_type.items.aircond_service.desc',
      icon: HugeIcons.strokeRoundedToolbox,
      keywords: ['aircond', 'aircon', 'penyaman', 'udara', 'servis', 'chemical', 'wash', 'pasang', 'repair', 'rumah'],
    ),
    const BusinessTypeItem(
      id: 'home_cleaning',
      categoryGroup: 'home_services',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.home_cleaning.name',
      descKey: 'business_type.items.home_cleaning.desc',
      icon: HugeIcons.strokeRoundedCleaningBucket,
      keywords: ['cuci', 'rumah', 'cleaning', 'kemas', 'cleaner', 'maid', 'sofa', 'karpet', 'pejabat', 'housekeeping'],
    ),
    const BusinessTypeItem(
      id: 'plumbing_electric',
      categoryGroup: 'home_services',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.plumbing_electric.name',
      descKey: 'business_type.items.plumbing_electric.desc',
      icon: HugeIcons.strokeRoundedTools,
      keywords: ['paip', 'plumber', 'plumbing', 'elektrik', 'wiring', 'wireman', 'bocor', 'sumbat', 'repair', 'handyman'],
    ),
    const BusinessTypeItem(
      id: 'laundry_dobi',
      categoryGroup: 'home_services',
      bookingMode: 'none',
      nameKey: 'business_type.items.laundry_dobi.name',
      descKey: 'business_type.items.laundry_dobi.desc',
      icon: HugeIcons.strokeRoundedWashingMachine,
      keywords: ['dobi', 'laundry', 'basuh', 'baju', 'dry', 'clean', 'gosok', 'iron', 'toto', 'karpet'],
    ),
    const BusinessTypeItem(
      id: 'renovation_contractor',
      categoryGroup: 'home_services',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.renovation_contractor.name',
      descKey: 'business_type.items.renovation_contractor.desc',
      icon: HugeIcons.strokeRoundedBuilding02,
      keywords: ['ubah', 'suai', 'renovation', 'kontraktor', 'contractor', 'cat', 'kabinet', 'dapur', 'interior', 'grill', 'awning'],
    ),
    const BusinessTypeItem(
      id: 'pest_control',
      categoryGroup: 'home_services',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.pest_control.name',
      descKey: 'business_type.items.pest_control.desc',
      icon: HugeIcons.strokeRoundedAlertCircle,
      keywords: ['anai', 'pest', 'control', 'serangga', 'lipas', 'tikus', 'pepijat', 'sembur', 'fogging'],
    ),

    // ─── 7. Kesihatan & Terapi / Healthcare ──────────────────────────────────
    const BusinessTypeItem(
      id: 'medical_clinic',
      categoryGroup: 'health',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.medical_clinic.name',
      descKey: 'business_type.items.medical_clinic.desc',
      icon: HugeIcons.strokeRoundedHospital02,
      keywords: ['klinik', 'clinic', 'doktor', 'doctor', 'perubatan', 'medical', 'kesihatan', 'rawatan', 'vaksin', 'poliklinik'],
    ),
    const BusinessTypeItem(
      id: 'dental_clinic',
      categoryGroup: 'health',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.dental_clinic.name',
      descKey: 'business_type.items.dental_clinic.desc',
      icon: HugeIcons.strokeRoundedDentalTooth,
      keywords: ['gigi', 'pergigian', 'dental', 'dentist', 'scaling', 'braces', 'cabut', 'tampal', 'klinik'],
    ),
    const BusinessTypeItem(
      id: 'physiotherapy',
      categoryGroup: 'health',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.physiotherapy.name',
      descKey: 'business_type.items.physiotherapy.desc',
      icon: HugeIcons.strokeRoundedHospitalBed01,
      keywords: ['fisio', 'fisioterapi', 'physiotherapy', 'physio', 'rehab', 'chiropractic', 'kiropraktik', 'sakit', 'belakang', 'terapi'],
    ),
    const BusinessTypeItem(
      id: 'optical_shop',
      categoryGroup: 'health',
      bookingMode: 'none',
      nameKey: 'business_type.items.optical_shop.name',
      descKey: 'business_type.items.optical_shop.desc',
      icon: HugeIcons.strokeRoundedGlasses,
      keywords: ['cermin', 'mata', 'optik', 'optical', 'spek', 'kanta', 'lens', 'optometri'],
    ),
    const BusinessTypeItem(
      id: 'pharmacy',
      categoryGroup: 'health',
      bookingMode: 'none',
      nameKey: 'business_type.items.pharmacy.name',
      descKey: 'business_type.items.pharmacy.desc',
      icon: HugeIcons.strokeRoundedMedicine02,
      keywords: ['farmasi', 'pharmacy', 'ubat', 'vitamin', 'suplemen', 'kesihatan', 'medicine'],
    ),
    const BusinessTypeItem(
      id: 'acupuncture_hijama',
      categoryGroup: 'health',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.acupuncture_hijama.name',
      descKey: 'business_type.items.acupuncture_hijama.desc',
      icon: HugeIcons.strokeRoundedSparkles,
      keywords: ['bekam', 'hijama', 'akupunktur', 'acupuncture', 'tradisional', 'sunnah', 'terapi', 'rawatan'],
    ),

    // ─── 8. Sukan & Rekreasi / Sports ────────────────────────────────────────
    const BusinessTypeItem(
      id: 'badminton_court',
      categoryGroup: 'sports',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.badminton_court.name',
      descKey: 'business_type.items.badminton_court.desc',
      icon: HugeIcons.strokeRoundedBadminton,
      keywords: ['badminton', 'gelanggang', 'court', 'dewan', 'futsal', 'sukan', 'sewa', 'raket'],
    ),
    const BusinessTypeItem(
      id: 'pickleball_court',
      categoryGroup: 'sports',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.pickleball_court.name',
      descKey: 'business_type.items.pickleball_court.desc',
      icon: HugeIcons.strokeRoundedTennisRacket,
      keywords: ['pickleball', 'tenis', 'tennis', 'padel', 'court', 'gelanggang', 'sukan'],
    ),
    const BusinessTypeItem(
      id: 'fitness_gym',
      categoryGroup: 'sports',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.fitness_gym.name',
      descKey: 'business_type.items.fitness_gym.desc',
      icon: HugeIcons.strokeRoundedDumbbell01,
      keywords: ['gim', 'gym', 'fitness', 'senaman', 'workout', 'trainer', 'crossfit', 'muay', 'thai'],
    ),
    const BusinessTypeItem(
      id: 'yoga_pilates',
      categoryGroup: 'sports',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.yoga_pilates.name',
      descKey: 'business_type.items.yoga_pilates.desc',
      icon: HugeIcons.strokeRoundedGymnastic,
      keywords: ['yoga', 'pilates', 'zumba', 'studio', 'senamrobik', 'regangan'],
    ),
    const BusinessTypeItem(
      id: 'swimming_academy',
      categoryGroup: 'sports',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.swimming_academy.name',
      descKey: 'business_type.items.swimming_academy.desc',
      icon: HugeIcons.strokeRoundedWorkoutSport,
      keywords: ['renang', 'swimming', 'kolam', 'kelas', 'akademi', 'pool'],
    ),

    // ─── 9. Haiwan Peliharaan / Pets (moved further back by priority) ────────
    const BusinessTypeItem(
      id: 'pet_hotel',
      categoryGroup: 'pets',
      bookingMode: 'overnight',
      nameKey: 'business_type.items.pet_hotel.name',
      descKey: 'business_type.items.pet_hotel.desc',
      icon: HugeIcons.strokeRoundedHotel01,
      keywords: ['hotel', 'kucing', 'cat', 'asrama', 'boarding', 'pet', 'haiwan', 'peliharaan', 'inap', 'bermalam', 'overnight', 'sangkar', 'kabin', 'daycare'],
    ),
    const BusinessTypeItem(
      id: 'pet_grooming',
      categoryGroup: 'pets',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.pet_grooming.name',
      descKey: 'business_type.items.pet_grooming.desc',
      icon: HugeIcons.strokeRoundedBathtub01,
      keywords: ['grooming', 'mandi', 'kucing', 'haiwan', 'pet', 'cat', 'spa', 'potong', 'bulu', 'kutu', 'dandanan'],
    ),
    const BusinessTypeItem(
      id: 'pet_clinic',
      categoryGroup: 'pets',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.pet_clinic.name',
      descKey: 'business_type.items.pet_clinic.desc',
      icon: HugeIcons.strokeRoundedClinic,
      keywords: ['klinik', 'haiwan', 'veterinar', 'vet', 'kucing', 'pet', 'vaksin', 'neuter', 'kembiri', 'doktor'],
    ),
    const BusinessTypeItem(
      id: 'pet_shop',
      categoryGroup: 'pets',
      bookingMode: 'none',
      nameKey: 'business_type.items.pet_shop.name',
      descKey: 'business_type.items.pet_shop.desc',
      icon: HugeIcons.strokeRoundedShoppingBasket02,
      keywords: ['kedai', 'haiwan', 'pet', 'shop', 'kucing', 'makanan', 'kibbles', 'pasir', 'litter', 'sangkar', 'aksesori'],
    ),
    const BusinessTypeItem(
      id: 'pet_cafe',
      categoryGroup: 'pets',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.pet_cafe.name',
      descKey: 'business_type.items.pet_cafe.desc',
      icon: HugeIcons.strokeRoundedCoffee02,
      keywords: ['kafe', 'cafe', 'kucing', 'cat', 'pet', 'haiwan', 'lounge', 'kopi'],
    ),

    // ─── 10. Pendidikan & Latihan / Education ────────────────────────────────
    const BusinessTypeItem(
      id: 'tuition_center',
      categoryGroup: 'education',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.tuition_center.name',
      descKey: 'business_type.items.tuition_center.desc',
      icon: HugeIcons.strokeRoundedTeacher,
      keywords: ['tuisyen', 'tuition', 'kelas', 'belajar', 'pendidikan', 'pusat', 'akademik', 'cikgu'],
    ),
    const BusinessTypeItem(
      id: 'quran_class',
      categoryGroup: 'education',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.quran_class.name',
      descKey: 'business_type.items.quran_class.desc',
      icon: HugeIcons.strokeRoundedBook02,
      keywords: ['mengaji', 'quran', 'alquran', 'iqra', 'tajwid', 'kelas', 'agama', 'fardu', 'ain', 'kafa'],
    ),
    const BusinessTypeItem(
      id: 'kindergarten_daycare',
      categoryGroup: 'education',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.kindergarten_daycare.name',
      descKey: 'business_type.items.kindergarten_daycare.desc',
      icon: HugeIcons.strokeRoundedSmile,
      keywords: ['tadika', 'taska', 'kindergarten', 'daycare', 'preschool', 'prasekolah', 'asuhan', 'kanak', 'playschool'],
    ),
    const BusinessTypeItem(
      id: 'music_art',
      categoryGroup: 'education',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.music_art.name',
      descKey: 'business_type.items.music_art.desc',
      icon: HugeIcons.strokeRoundedMusicNote01,
      keywords: ['muzik', 'music', 'seni', 'art', 'lukis', 'piano', 'gitar', 'kelas', 'vokal'],
    ),
    const BusinessTypeItem(
      id: 'driving_school',
      categoryGroup: 'education',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.driving_school.name',
      descKey: 'business_type.items.driving_school.desc',
      icon: HugeIcons.strokeRoundedCar03,
      keywords: ['memandu', 'driving', 'lesen', 'sekolah', 'institut', 'kereta', 'motor'],
    ),

    // ─── 11. Servis Profesional & Kreatif / Professional ─────────────────────
    const BusinessTypeItem(
      id: 'photography_studio',
      categoryGroup: 'professional',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.photography_studio.name',
      descKey: 'business_type.items.photography_studio.desc',
      icon: HugeIcons.strokeRoundedCamera01,
      keywords: ['studio', 'foto', 'gambar', 'photography', 'kamera', 'raya', 'kahwin', 'video', 'selfie'],
    ),
    const BusinessTypeItem(
      id: 'printing_banner',
      categoryGroup: 'professional',
      bookingMode: 'none',
      nameKey: 'business_type.items.printing_banner.name',
      descKey: 'business_type.items.printing_banner.desc',
      icon: HugeIcons.strokeRoundedPrinter,
      keywords: ['cetak', 'printing', 'print', 'banner', 'bunting', 'stiker', 'sticker', 'tshirt', 'fotostat'],
    ),
    const BusinessTypeItem(
      id: 'gadget_repair',
      categoryGroup: 'professional',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.gadget_repair.name',
      descKey: 'business_type.items.gadget_repair.desc',
      icon: HugeIcons.strokeRoundedComputerCheck,
      keywords: ['telefon', 'phone', 'fon', 'laptop', 'komputer', 'pc', 'repair', 'baiki', 'skrin', 'bateri', 'gadget'],
    ),
    const BusinessTypeItem(
      id: 'coworking_space',
      categoryGroup: 'professional',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.coworking_space.name',
      descKey: 'business_type.items.coworking_space.desc',
      icon: HugeIcons.strokeRoundedBuilding06,
      keywords: ['coworking', 'pejabat', 'office', 'bilik', 'mesyuarat', 'meeting', 'seminar', 'ruang', 'kerja'],
    ),
    const BusinessTypeItem(
      id: 'event_hall',
      categoryGroup: 'professional',
      bookingMode: 'time_slot',
      nameKey: 'business_type.items.event_hall.name',
      descKey: 'business_type.items.event_hall.desc',
      icon: HugeIcons.strokeRoundedBuilding03,
      keywords: ['dewan', 'hall', 'majlis', 'kahwin', 'event', 'wedding', 'kanopi', 'pelamin', 'sewa'],
    ),
  ];

  static BusinessTypeItem? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    final lower = id.trim().toLowerCase();
    for (final element in allTypes) {
      if (element.id.toLowerCase() == lower) return element;
    }
    final legacy = _legacyMap[lower];
    if (legacy != null) {
      for (final element in allTypes) {
        if (element.id.toLowerCase() == legacy) return element;
      }
    }
    return null;
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
    'warung': 'food_stall',
    'gerai': 'food_stall',
    'kedai makan': 'kedai_makan',
    'gym': 'fitness_gym',
    'clinic': 'medical_clinic',
    'studio': 'photography_studio',
    'pets': 'pet_hotel',
    'kucing': 'pet_hotel',
    'cat_hotel': 'pet_hotel',
    'stay': 'homestay',
    'hospitality': 'hotel',
    'fnb': 'restaurant',
    'beauty': 'barbershop',
    'auto': 'workshop',
    'retail': 'minimarket',
  };

  /// Smart default service modes based on chosen business type (merchants can freely
  /// toggle Walk-In, Booking, or Order ON/OFF anytime in Business Profile).
  static ({bool walkIn, bool booking, bool order}) recommendedServiceModes(String? businessTypeId) {
    final item = findById(businessTypeId);
    if (item == null) {
      return (walkIn: false, booking: false, order: true);
    }
    if (item.categoryGroup == 'retail' || item.id == 'pet_shop') {
      return (walkIn: false, booking: false, order: true);
    }
    if (item.categoryGroup == 'fnb' || item.id == 'pet_cafe') {
      return (
        walkIn: false,
        booking: item.bookingMode == 'time_slot',
        order: true,
      );
    }
    if (item.categoryGroup == 'stay' || item.bookingMode == 'overnight') {
      return (walkIn: false, booking: true, order: false);
    }
    return (walkIn: true, booking: true, order: false);
  }

  static List<String> recommendedServiceModeList(String? businessTypeId) {
    final m = recommendedServiceModes(businessTypeId);
    return [
      if (m.walkIn) 'walkin',
      if (m.booking) 'booking',
      if (m.order) 'order',
    ];
  }

  /// Flexible multi-word search ranked by how many searched words match
  /// (plus field relevance weight), so items containing more matching words
  /// always appear at the top.
  static List<BusinessTypeItem> searchRanked(
    String rawQuery, {
    String categoryGroup = 'all',
  }) {
    final baseList = categoryGroup == 'all'
        ? allTypes
        : allTypes.where((e) => e.categoryGroup == categoryGroup).toList();

    final normalized = rawQuery
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim();
    if (normalized.isEmpty) return baseList;

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    if (tokens.isEmpty) return baseList;

    final scored = <({BusinessTypeItem item, int matchedWords, int score, int order})>[];

    for (int i = 0; i < baseList.length; i++) {
      final item = baseList[i];
      final name = item.nameKey.tr().toLowerCase();
      final desc = item.descKey.tr().toLowerCase();
      final cat = 'business_type.categories.${item.categoryGroup}'.tr().toLowerCase();
      final mode = 'business_type.booking_modes.${item.bookingMode}'.tr().toLowerCase();
      final idText = item.id.replaceAll('_', ' ').toLowerCase();
      final kwJoined = item.keywords.join(' ').toLowerCase();

      int matchedWords = 0;
      int score = 0;

      // Full-phrase bonus when typing multiple words that appear consecutively
      if (tokens.length > 1) {
        if (name.contains(normalized)) score += 45;
        if (desc.contains(normalized)) score += 15;
        if (kwJoined.contains(normalized)) score += 20;
      }

      for (final token in tokens) {
        bool tokenMatched = false;

        if (name.startsWith(token)) {
          score += 40;
          tokenMatched = true;
        } else if (name.contains(token)) {
          score += 28;
          tokenMatched = true;
        }

        if (idText.contains(token)) {
          score += 20;
          tokenMatched = true;
        }

        bool kwExact = false;
        bool kwPartial = false;
        for (final kw in item.keywords) {
          if (kw == token) {
            kwExact = true;
            break;
          } else if (kw.contains(token)) {
            kwPartial = true;
          }
        }
        if (kwExact) {
          score += 24;
          tokenMatched = true;
        } else if (kwPartial) {
          score += 14;
          tokenMatched = true;
        }

        if (cat.contains(token)) {
          score += 12;
          tokenMatched = true;
        }

        if (desc.contains(token)) {
          score += 9;
          tokenMatched = true;
        }

        if (mode.contains(token)) {
          score += 6;
          tokenMatched = true;
        }

        if (tokenMatched) {
          matchedWords++;
        }
      }

      if (matchedWords > 0) {
        scored.add((
          item: item,
          matchedWords: matchedWords,
          score: score,
          order: i,
        ));
      }
    }

    scored.sort((a, b) {
      // 1. More distinct searched words matched ALWAYS wins
      final byWords = b.matchedWords.compareTo(a.matchedWords);
      if (byWords != 0) return byWords;
      // 2. Higher relevance score (name > keyword > category > description)
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // 3. Preserve natural priority ordering
      return a.order.compareTo(b.order);
    });

    return scored.map((e) => e.item).toList();
  }

  /// Converts any granular business type or category into one of the 4 strict
  /// legacy PostgreSQL CHECK constraint values: ('fnb', 'barber', 'retail', 'services').
  static String toDbIndustry(String? typeOrCategory) {
    if (typeOrCategory == null || typeOrCategory.trim().isEmpty) return 'services';
    final lower = typeOrCategory.toLowerCase().trim();

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
        case 'stay':
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

    if (lower.contains('food') ||
        lower.contains('restaurant') ||
        lower.contains('makan') ||
        lower.contains('warung') ||
        lower.contains('cafe') ||
        lower.contains('fnb')) {
      return 'fnb';
    }
    if (lower.contains('barber') ||
        lower.contains('salon') ||
        lower.contains('beauty') ||
        lower.contains('spa')) {
      return 'barber';
    }
    if (lower.contains('retail') ||
        lower.contains('market') ||
        lower.contains('shop') ||
        lower.contains('store')) {
      return 'retail';
    }

    return 'services';
  }
}
