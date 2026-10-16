// =============================================================================
// main.dart
// Entry point for Ngam Business – Merchant Portal.
// Bootstraps Supabase via .env, wires GoRouter, and applies the dark theme.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  final String url = dotenv.env['SUPABASE_URL'] ?? 'https://rsueaoglsdxhzpupjljd.supabase.co';
  final String key = dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_qP4whY5B6wxIasWOVGoPCw_vrhOXj_J';

  try {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  runApp(const NgamBusinessApp());
}

class NgamBusinessApp extends StatelessWidget {
  const NgamBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ngam Business',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        splashColor: Colors.transparent,
        highlightColor: Colors.white.withValues(alpha: 0.04),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0A0A),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF333333)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
