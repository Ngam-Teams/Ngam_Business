import 'package:easy_localization/easy_localization.dart';
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
import 'core/router/url_strategy.dart';
import 'core/services/network_status_service.dart';
import 'features/auth/data/auth_service.dart';
import 'features/settings/data/business_service.dart';
import 'widgets/offline_banner.dart';
import 'widgets/responsive_landscape_scale.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  setCleanUrlStrategy();

  // Initialize network connectivity monitoring
  NetworkStatusService.instance.initialize();

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

    // Listen for auth events globally
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.go('/reset-password');
        });
      } else if (data.event == AuthChangeEvent.signedOut) {
        AuthService.cleanSessionData();
      }
    });
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Pre-load business profile from persistent local cache for instant zero-latency UI
  try {
    await BusinessService.loadCachedProfile();
  } catch (e) {
    debugPrint('loadCachedProfile error: $e');
  }

  // Custom error widget so Flutter Web/Desktop never displays a solid grey screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF10121D),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Ralat Memuatkan Komponen',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ms')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ms'),
      startLocale: const Locale('ms'),
      useOnlyLangCode: true,
      child: const NgamBusinessApp(),
    ),
  );
}

class NgamBusinessApp extends StatelessWidget {
  const NgamBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ngam Business',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        final content = child != null
            ? ResponsiveLandscapeScale(child: child)
            : const SizedBox.shrink();
        return Stack(
          children: [
            content,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OfflineBanner(),
            ),
          ],
        );
      },
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
