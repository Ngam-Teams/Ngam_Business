// =============================================================================
// main.dart
// Entry point for Ngam Business – Merchant Portal.
// Bootstraps Supabase via .env, wires GoRouter, and applies the dark theme.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  
  final String url = dotenv.env['SUPABASE_URL'] ?? '';
  final String key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  debugPrint('DEBUG - Loaded URL: $url');
  debugPrint('DEBUG - Loaded Key starts with: ${key.isNotEmpty ? key.substring(0, 10) : "EMPTY"}');
  debugPrint('DEBUG - Key length: ${key.length}');

  await Supabase.initialize(
    url: url,
    publishableKey: key,
  );

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
        scaffoldBackgroundColor: const Color(0xFF0A0A14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42A5F5),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0A14),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF42A5F5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
