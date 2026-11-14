import 'package:flutter/material.dart';
import 'liquid_glass_compat.dart';

/// ModalSheet — standardised expandable glassmorphic bottom sheet.
class ModalSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, ScrollController scrollController) builder,
    double initialChildSize = 0.6,
    double minChildSize = 0.4,
    double maxChildSize = 1.0,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 12),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          final topPadding = initialChildSize >= 0.96
              ? MediaQuery.of(context).padding.top
              : 0.0;

          return GlassContainer(
            useOwnLayer: true,
            quality: GlassQuality.standard,
            shape: const LiquidRoundedSuperellipse(borderRadius: 28.0),
            settings: LiquidGlassSettings(
              thickness: 0.1,
              blur: 18.0,
              refractiveIndex: 1.0,
              glassColor: Colors.transparent,
              lightAngle: 45.0,
              lightIntensity: isDark ? 0.1 : 0.2,
              ambientStrength: 1.0,
              saturation: 1.0,
              chromaticAberration: 0.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0E1222).withValues(alpha: 0.94)
                    : const Color(0xFF14192C).withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.28),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  children: [
                    SizedBox(height: topPadding + 10),
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: contentPadding,
                        child: builder(context, scrollController),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
