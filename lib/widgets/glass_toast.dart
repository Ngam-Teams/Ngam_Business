import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum GlassToastType { success, error, warning, info }

/// Global glassmorphic toast helper
void showGlassToast(
  BuildContext context,
  String message, {
  bool isError = false,
  GlassToastType? type,
  Color? customColor,
  Color? color,
  dynamic customIcon,
  dynamic icon,
  bool showIcon = true,
  Duration duration = const Duration(seconds: 3),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  final resolvedType = type ?? (isError ? GlassToastType.error : GlassToastType.success);
  
  final resolvedColor = customColor ?? color ?? _colorForType(resolvedType);
  final resolvedIcon = customIcon ?? icon ?? _iconForType(resolvedType);

  ScaffoldMessenger.of(context).removeCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? resolvedColor.withValues(alpha: 0.18)
                  : resolvedColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: resolvedColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showIcon) ...[
                  if (resolvedIcon is IconData)
                    Icon(resolvedIcon, color: resolvedColor, size: 20)
                  else
                    Icon(Icons.info_outline_rounded, color: resolvedColor, size: 20),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Color _colorForType(GlassToastType type) {
  switch (type) {
    case GlassToastType.success:
      return const Color(0xFF2ECC71);
    case GlassToastType.error:
      return Colors.redAccent;
    case GlassToastType.warning:
      return const Color(0xFFF39C12);
    case GlassToastType.info:
      return const Color(0xFF3498DB);
  }
}

IconData _iconForType(GlassToastType type) {
  switch (type) {
    case GlassToastType.success:
      return Icons.check_circle_rounded;
    case GlassToastType.error:
      return Icons.error_outline_rounded;
    case GlassToastType.warning:
      return Icons.warning_amber_rounded;
    case GlassToastType.info:
      return Icons.info_outline_rounded;
  }
}
