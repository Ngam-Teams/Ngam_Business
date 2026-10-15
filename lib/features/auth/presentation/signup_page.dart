import 'package:flutter/material.dart';
import 'login_page.dart';

// =============================================================================
// Ngam Business — Signup Page
// Delegates directly to unified LoginPage in Register mode.
// =============================================================================

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginPage(initialMode: AuthScreenMode.register);
  }
}
