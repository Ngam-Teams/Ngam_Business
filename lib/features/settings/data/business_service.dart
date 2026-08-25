import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessService {
  final SupabaseClient _client;

  BusinessService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch the business record for the currently logged in owner
  Future<Map<String, dynamic>?> getBusinessProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('businesses')
          .select()
          .eq('owner_user_id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update the business record for the currently logged in owner
  Future<void> updateBusinessProfile(String businessId, Map<String, dynamic> updates) async {
    await _client.from('businesses').update(updates).eq('id', businessId);
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
      return null;
    }
  }
}
