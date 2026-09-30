import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessService {
  final SupabaseClient _client;

  // In-flight request deduplication to prevent parallel calls creating race-condition duplicates
  static Future<Map<String, dynamic>?>? _inflightFetch;

  BusinessService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch the business record for the currently logged in owner.
  /// Also loads associated business_settings and business_compliance if available.
  /// Uses mutex/in-flight caching so concurrent widget requests share one call.
  Future<Map<String, dynamic>?> getBusinessProfile({bool autoCreate = true}) async {
    if (_inflightFetch != null) return _inflightFetch!;
    _inflightFetch = _doGetBusinessProfile(autoCreate: autoCreate);
    try {
      return await _inflightFetch!;
    } finally {
      _inflightFetch = null;
    }
  }

  Future<Map<String, dynamic>?> _doGetBusinessProfile({bool autoCreate = true}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      // Query businesses for this owner, newest first.
      // We avoid .maybeSingle() because if an owner has multiple businesses (e.g. branches),
      // PostgREST maybeSingle() throws error PGRST116 (multiple rows returned).
      final response = await _client
          .from('businesses')
          .select()
          .eq('owner_user_id', user.id)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();

      if (list.isNotEmpty) {
        final profile = Map<String, dynamic>.from(list.first);

        // Fetch settings if available
        try {
          final settings = await _client
              .from('business_settings')
              .select()
              .eq('business_id', profile['id'])
              .maybeSingle();
          if (settings != null) {
            profile['settings'] = Map<String, dynamic>.from(settings);
          }
        } catch (e) {
          debugPrint('Error fetching business_settings: $e');
        }

        // Fetch compliance if available
        try {
          final compliance = await _client
              .from('business_compliance')
              .select()
              .eq('business_id', profile['id'])
              .maybeSingle();
          if (compliance != null) {
            profile['compliance'] = Map<String, dynamic>.from(compliance);
          }
        } catch (e) {
          debugPrint('Error fetching business_compliance: $e');
        }

        return profile;
      }

      if (!autoCreate) return null;

      // Auto-create initial business only if no business exists
      final businessName = user.userMetadata?['business_name'] ?? 'My Business';
      final cleanName = (businessName as String).trim().isNotEmpty ? businessName.trim() : 'My Business';

      // Double check before insert to prevent race conditions
      final doubleCheck = await _client
          .from('businesses')
          .select('id')
          .eq('owner_user_id', user.id)
          .limit(1);

      if ((doubleCheck as List).isNotEmpty) {
        final existingId = doubleCheck.first['id'] as String;
        final existingRecord = await _client.from('businesses').select().eq('id', existingId).single();
        return Map<String, dynamic>.from(existingRecord);
      }

      final newProfile = await _client.from('businesses').insert({
        'owner_user_id': user.id,
        'business_name': cleanName,
        'business_industry': 'services',
        'business_registration_number': 'PENDING-REG',
        'address_line': '',
        'postcode': '',
        'business_city': '',
        'state': '',
        'business_country': 'Malaysia',
        'status': 'active',
        'platform_fee_percent': 2.00,
      }).select().maybeSingle();

      if (newProfile != null) {
        final profile = Map<String, dynamic>.from(newProfile);
        // Initialize default settings row
        await initDefaultSettings(profile['id']);
        return profile;
      }

      return null;
    } catch (e) {
      debugPrint('Error in getBusinessProfile: $e');
      return null;
    }
  }

  /// Returns all businesses owned by current user (for multi-business owners)
  Future<List<Map<String, dynamic>>> getOwnerBusinesses() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('businesses')
          .select()
          .eq('owner_user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (e) {
      debugPrint('Error fetching owner businesses: $e');
      return [];
    }
  }

  /// Create a brand new business profile (Add Business Details).
  /// Checks for duplicates with the same name for this owner to prevent accidental duplicates.
  Future<Map<String, dynamic>> createBusinessProfile({
    required String businessName,
    String businessIndustry = 'services',
    String? registrationNumber,
    String? sstNumber,
    String? email,
    String? phone,
    String? website,
    String? addressLine,
    String? postcode,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    String? logoUrl,
    String? coverUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final cleanName = businessName.trim();

    // Check if owner already has a business with this exact name
    final existingSameName = await _client
        .from('businesses')
        .select()
        .eq('owner_user_id', user.id)
        .ilike('business_name', cleanName)
        .limit(1);

    final payload = <String, dynamic>{
      'owner_user_id': user.id,
      'business_name': cleanName,
      'business_industry': businessIndustry.trim(),
      'business_registration_number': registrationNumber?.trim() ?? 'PENDING-REG',
      'address_line': addressLine?.trim() ?? '',
      'postcode': postcode?.trim() ?? '',
      'business_city': city?.trim() ?? '',
      'state': state?.trim() ?? '',
      'business_country': country?.trim() ?? 'Malaysia',
      'status': 'active',
      'platform_fee_percent': 2.00,
    };

    if (sstNumber != null && sstNumber.trim().isNotEmpty) {
      payload['sst_number'] = sstNumber.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      payload['business_email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      payload['business_phone'] = phone.trim();
    }
    if (website != null && website.trim().isNotEmpty) {
      payload['business_website'] = website.trim();
    }
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      payload['business_logo_url'] = logoUrl.trim();
    }
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      payload['business_cover_url'] = coverUrl.trim();
    }

    if ((existingSameName as List).isNotEmpty) {
      // Business with this name already exists for this owner: alter existing instead of duplicating!
      final existingId = existingSameName.first['id'] as String;
      await updateBusinessProfile(existingId, payload);
      final updated = await _client.from('businesses').select().eq('id', existingId).single();
      return Map<String, dynamic>.from(updated);
    }

    final response = await _client.from('businesses').insert(payload).select().single();
    final newBusiness = Map<String, dynamic>.from(response);

    // Initialize associated settings row
    await initDefaultSettings(newBusiness['id']);

    return newBusiness;
  }

  /// Update / alter existing business details
  Future<void> updateBusinessProfile(String businessId, Map<String, dynamic> updates) async {
    await _client.from('businesses').update(updates).eq('id', businessId);
  }

  /// Initialize default settings row for a business
  Future<void> initDefaultSettings(String businessId) async {
    try {
      await _client.from('business_settings').upsert({
        'business_id': businessId,
        'operating_hours': {
          'open_time': '09:00',
          'close_time': '22:00',
          'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
        },
        'is_halal': false,
        'total_chairs': 1,
        'slot_duration': 30,
      });
    } catch (e) {
      debugPrint('initDefaultSettings failed: $e');
    }
  }

  /// Save or alter business settings (operating hours, halal, slot duration, chairs)
  Future<void> saveBusinessSettings(String businessId, Map<String, dynamic> settings) async {
    try {
      final payload = {
        'business_id': businessId,
        ...settings,
      };
      await _client.from('business_settings').upsert(payload);
    } catch (e) {
      debugPrint('Upsert business_settings failed, trying fallback: $e');
      try {
        final existing = await _client
            .from('business_settings')
            .select('business_id')
            .eq('business_id', businessId)
            .maybeSingle();

        if (existing != null) {
          await _client.from('business_settings').update(settings).eq('business_id', businessId);
        } else {
          await _client.from('business_settings').insert({
            'business_id': businessId,
            ...settings,
          });
        }
      } catch (err) {
        debugPrint('Fallback business_settings failed: $err');
      }
    }
  }

  /// Save or alter business compliance & banking info
  Future<void> saveBusinessCompliance(String businessId, Map<String, dynamic> compliance) async {
    try {
      final payload = {
        'business_id': businessId,
        ...compliance,
      };
      await _client.from('business_compliance').upsert(payload);
    } catch (e) {
      debugPrint('Upsert business_compliance failed, trying fallback: $e');
      try {
        final existing = await _client
            .from('business_compliance')
            .select('business_id')
            .eq('business_id', businessId)
            .maybeSingle();

        if (existing != null) {
          await _client.from('business_compliance').update(compliance).eq('business_id', businessId);
        } else {
          await _client.from('business_compliance').insert({
            'business_id': businessId,
            ...compliance,
          });
        }
      } catch (err) {
        debugPrint('Fallback business_compliance failed: $err');
      }
    }
  }

  /// Save or alter all business details in a unified transaction/flow
  Future<void> saveFullBusinessDetails({
    String? businessId,
    required Map<String, dynamic> businessData,
    Map<String, dynamic>? settingsData,
    Map<String, dynamic>? complianceData,
  }) async {
    String currentBusinessId;

    if (businessId == null || businessId.isEmpty) {
      // Create new business profile (or update if same name already exists)
      final created = await createBusinessProfile(
        businessName: businessData['business_name'] ?? 'My Business',
        businessIndustry: businessData['business_industry'] ?? 'services',
        registrationNumber: businessData['business_registration_number'],
        sstNumber: businessData['sst_number'],
        email: businessData['business_email'],
        phone: businessData['business_phone'],
        website: businessData['business_website'],
        addressLine: businessData['address_line'],
        postcode: businessData['postcode'],
        city: businessData['business_city'],
        state: businessData['state'],
        country: businessData['business_country'],
        latitude: businessData['latitude'],
        longitude: businessData['longitude'],
        logoUrl: businessData['business_logo_url'],
        coverUrl: businessData['business_cover_url'],
      );
      currentBusinessId = created['id'];
    } else {
      // Alter existing business profile
      await updateBusinessProfile(businessId, businessData);
      currentBusinessId = businessId;
    }

    // Save settings if provided
    if (settingsData != null && settingsData.isNotEmpty) {
      await saveBusinessSettings(currentBusinessId, settingsData);
    }

    // Save compliance if provided
    if (complianceData != null && complianceData.isNotEmpty) {
      await saveBusinessCompliance(currentBusinessId, complianceData);
    }
  }

  /// Clean up duplicate businesses with the same name for this owner, keeping the newest one
  Future<int> removeDuplicateBusinesses() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    try {
      final list = await getOwnerBusinesses();
      final seenNames = <String, String>{};
      final duplicateIds = <String>[];

      for (final b in list) {
        final name = (b['business_name'] as String? ?? '').trim().toLowerCase();
        if (name.isEmpty) continue;
        final id = b['id'] as String;

        if (seenNames.containsKey(name)) {
          duplicateIds.add(id);
        } else {
          seenNames[name] = id;
        }
      }

      for (final id in duplicateIds) {
        await _client.from('businesses').delete().eq('id', id);
      }

      return duplicateIds.length;
    } catch (e) {
      debugPrint('Error removing duplicate businesses: $e');
      return 0;
    }
  }

  /// Upload an image to the Supabase Storage bucket 'business-assets'
  Future<String?> uploadBusinessImage(String businessId, String folder, XFile file) async {
    try {
      final fileName = '${businessId}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = '$folder/$fileName';

      // Read as bytes to support cross-platform (Web/Mobile/Desktop)
      final bytes = await file.readAsBytes();

      await _client.storage.from('business-assets').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg', upsert: true),
          );

      return _client.storage.from('business-assets').getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadBusinessImage error: $e');
      return null;
    }
  }
}
