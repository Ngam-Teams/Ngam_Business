import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/data/business_service.dart';

class AuditService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final BusinessService _businessService = BusinessService();

  static String? lastError;
  static bool isMissingTableError = false;

  static bool _looksLikeMissingTable(Object err) {
    final msg = err.toString().toLowerCase();
    return msg.contains('pgrst205') ||
        msg.contains('42p01') ||
        msg.contains('audit_logs') &&
            (msg.contains('does not exist') ||
                msg.contains('could not find the table') ||
                msg.contains('schema cache'));
  }

  /// Log a security or operational event to the tamper-resistant audit trail.
  /// Returns `true` if inserted successfully, `false` otherwise.
  static Future<bool> log({
    required String action,
    required String description,
    String severity = 'info', // 'info', 'warning', 'critical'
    String? targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final business = BusinessService.cachedProfile ??
          await _businessService.getBusinessProfile();
      final businessId = business?['id'];
      if (businessId == null) return false;

      final actorName = (user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email?.split('@').first ??
              'Staff')
          .toString()
          .trim();

      final isOwner = business?['owner_user_id'] == user.id;
      final actorRole = isOwner
          ? 'tenant_admin'
          : (business?['_user_role'] ?? user.userMetadata?['role'] ?? 'staff')
              .toString();

      await _client.from('audit_logs').insert({
        'business_id': businessId,
        'actor_user_id': user.id,
        'actor_name': actorName.isNotEmpty ? actorName : 'Staff',
        'actor_email': user.email,
        'actor_role': actorRole,
        'action': action,
        'severity': severity,
        'target_type': targetType,
        'target_id': targetId,
        'description': description,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      lastError = null;
      isMissingTableError = false;
      return true;
    } catch (e) {
      lastError = e.toString();
      isMissingTableError = _looksLikeMissingTable(e);
      if (kDebugMode) {
        print('AuditService error: $e');
      }
      return false;
    }
  }

  /// Retrieve audit logs for the current business.
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? severity,
    String? searchQuery,
    int limit = 100,
  }) async {
    lastError = null;
    isMissingTableError = false;
    try {
      final business = BusinessService.cachedProfile ??
          await _businessService.getBusinessProfile();
      final businessId = business?['id'];
      if (businessId == null) return [];

      var query = _client
          .from('audit_logs')
          .select()
          .eq('business_id', businessId);

      if (severity != null && severity.isNotEmpty && severity != 'all') {
        query = query.eq('severity', severity);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      final logs = List<Map<String, dynamic>>.from(response);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return logs.where((l) {
          final desc = (l['description'] ?? '').toString().toLowerCase();
          final action = (l['action'] ?? '').toString().toLowerCase();
          final actor = (l['actor_name'] ?? '').toString().toLowerCase();
          final targetId = (l['target_id'] ?? '').toString().toLowerCase();
          return desc.contains(q) ||
              action.contains(q) ||
              actor.contains(q) ||
              targetId.contains(q);
        }).toList();
      }

      return logs;
    } catch (e) {
      lastError = e.toString();
      isMissingTableError = _looksLikeMissingTable(e);
      if (kDebugMode) {
        print('Error fetching audit logs: $e');
      }
      return [];
    }
  }

  /// Builds a clean RFC-4180 CSV export string from audit log rows.
  static String buildCsv(List<Map<String, dynamic>> logs) {
    String esc(dynamic v) {
      final s = (v ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }

    final buf = StringBuffer();
    buf.writeln(
      'Timestamp,Severity,Action,Actor,Role,Email,TargetType,TargetId,Description',
    );
    for (final l in logs) {
      buf.writeln([
        esc(l['created_at']),
        esc(l['severity']),
        esc(l['action']),
        esc(l['actor_name']),
        esc(l['actor_role']),
        esc(l['actor_email']),
        esc(l['target_type']),
        esc(l['target_id']),
        esc(l['description']),
      ].join(','));
    }
    return buf.toString();
  }
}
