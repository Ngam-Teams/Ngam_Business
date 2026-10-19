import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/data/business_service.dart';

class AuditService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final BusinessService _businessService = BusinessService();

  /// Log a security or operational event to the tamper-resistant audit trail.
  static Future<void> log({
    required String action,
    required String description,
    String severity = 'info', // 'info', 'warning', 'critical'
    String? targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final business = await _businessService.getBusinessProfile();
      final businessId = business?['id'];
      if (businessId == null) return;

      final actorName = user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'Staff';

      await _client.from('audit_logs').insert({
        'business_id': businessId,
        'actor_user_id': user.id,
        'actor_name': actorName,
        'actor_email': user.email,
        'actor_role': user.userMetadata?['role'] ?? 'tenant_admin',
        'action': action,
        'severity': severity,
        'target_type': targetType,
        'target_id': targetId,
        'description': description,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('AuditService error: $e');
      }
    }
  }

  /// Retrieve audit logs for the current business.
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? severity,
    String? searchQuery,
    int limit = 60,
  }) async {
    try {
      final business = await _businessService.getBusinessProfile();
      final businessId = business?['id'];
      if (businessId == null) return [];

      var query = _client
          .from('audit_logs')
          .select()
          .eq('business_id', businessId);

      if (severity != null && severity.isNotEmpty && severity != 'all') {
        query = query.eq('severity', severity);
      }

      final response = await query.order('created_at', ascending: false).limit(limit);
      final logs = List<Map<String, dynamic>>.from(response);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return logs.where((l) {
          final desc = (l['description'] ?? '').toString().toLowerCase();
          final action = (l['action'] ?? '').toString().toLowerCase();
          final actor = (l['actor_name'] ?? '').toString().toLowerCase();
          return desc.contains(q) || action.contains(q) || actor.contains(q);
        }).toList();
      }

      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching audit logs: $e');
      }
      return [];
    }
  }
}
