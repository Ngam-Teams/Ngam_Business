// =============================================================================
// main.dart
// Entry point for Ngam Business – Merchant Portal.
// Bootstraps Supabase via .env, wires GoRouter, and applies the dark theme.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NgamBusinessApp());
}

class NgamBusinessApp extends StatefulWidget {
  const NgamBusinessApp({super.key});

  @override
  State<NgamBusinessApp> createState() => _NgamBusinessAppState();
}

class _NgamBusinessAppState extends State<NgamBusinessApp> {
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Instant frame 1 UI: dismissed native Android splash immediately
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0A0A14),
            ),
            home: Scaffold(
              backgroundColor: const Color(0xFF0A0A14),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF42A5F5),
                            Color(0xFF1E88E5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ngam Business',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF42A5F5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MaterialApp.router(
          title: 'Ngam Business',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0A14),
            splashColor: Colors.transparent,
            highlightColor: Colors.white.withValues(alpha: 0.04),
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
      },
    );
  }
}
