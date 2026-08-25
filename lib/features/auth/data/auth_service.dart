import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthService — handles sign in, sign out, and session state.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Returns the currently authenticated user, or null.
  get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.ngambusiness://login-callback',
    );
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.ngambusiness://login-callback',
    );
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
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
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
