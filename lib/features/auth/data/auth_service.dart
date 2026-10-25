import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/order_alert_service.dart';
import '../../loyalty/data/loyalty_service.dart';
import '../../payroll/data/payroll_service.dart';
import '../../queue/data/queue_service.dart';
import '../../settings/data/business_service.dart';

/// AuthService — handles sign in, sign out, and session state.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Returns the currently authenticated user, or null.
  get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Completely purge all user and business caches, singletons, and active subscriptions.
  static Future<void> cleanSessionData() async {
    try {
      await BusinessService.clearCacheAsync();
    } catch (_) {}
    try {
      OrderAlertService.instance.dispose();
    } catch (_) {}
    try {
      LoyaltyService.reset();
    } catch (_) {}
    try {
      PayrollService.reset();
    } catch (_) {}
    try {
      QueueService.reset();
    } catch (_) {}
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // Purge any stale cache from previous sessions before authenticating
    await cleanSessionData();

    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    // Eagerly pre-load the new business profile for the newly signed in merchant
    try {
      await BusinessService(client: _client).getBusinessProfile(forceRefresh: true);
    } catch (e) {
      debugPrint('[AuthService] Error fetching business profile after sign in: $e');
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    await cleanSessionData();
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'io.supabase.ngambusiness://login-callback',
    );
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    await cleanSessionData();
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kIsWeb ? Uri.base.origin : 'io.supabase.ngambusiness://login-callback',
    );
  }

  /// Reset password for email
  Future<void> resetPassword(String email) async {
    final redirectUrl = kIsWeb
        ? '${Uri.base.origin}/reset-password'
        : 'https://business.ngam.dev/reset-password';
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectUrl,
    );
  }

  

  /// Lookup account email by phone number (if merchant forgot email)
  Future<Map<String, dynamic>> lookupAccountByPhone(String phone) async {
    try {
      final res = await _client.rpc('lookup_account_by_phone', params: {
        'phone_input': phone.trim(),
      });
      if (res is Map<String, dynamic>) {
        return res;
      }
      return {'success': false, 'message': 'Ralat memproses carian akaun.'};
    } catch (e) {
      debugPrint('[AuthService] Error lookupAccountByPhone: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update password during recovery flow
  Future<void> updateRecoveryPassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Sign up a new business user.
  Future<void> signUp({
    required String email,
    required String password,
    required String businessName,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'business_name': businessName},
    );
    
    // Attempt to manually assign the tenant_admin role if RLS allows it
    // Usually, this should be done via a secure Supabase trigger on user creation,
    // but we can try to do it here for rapid development if policies permit.
    if (response.user != null) {
      try {
        await _client.from('user_roles').insert({
          'user_id': response.user!.id,
          'role': 'tenant_admin',
        });
      } catch (_) {
        // Ignore errors; might fail due to RLS, in which case trigger must handle it
      }

      try {
        await _client.from('businesses').insert({
          'owner_user_id': response.user!.id,
          'business_name': businessName.trim().isNotEmpty ? businessName.trim() : 'My Business',
          'business_industry': 'services',
          'business_registration_number': 'PENDING-REG',
          'status': 'active',
          'platform_fee_percent': 2.00,
        });
      } catch (_) {
        // Handled lazily by BusinessService.getBusinessProfile
      }
    }
  }

  /// Sign out the current user and wipe all session caches.
  Future<void> signOut() async {
    await cleanSessionData();
    await _client.auth.signOut();
  }

  /// Fetch the role of the current user from `user_roles` table.
  /// Returns null if not found or not authenticated.
  Future<String?> fetchUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      return response?['role'] as String?;
    } on PostgrestException {
      return null;
    }
  }

  /// Returns true if the user has a business-facing role (tenant_admin or staff).
  Future<bool> isTenantUser() async {
    final role = await fetchUserRole();
    return role == 'tenant_admin' || role == 'staff';
  }
}
