import 'package:flutter/material.dart';

/// Automatically scales the application UI in landscape mode on mobile phones
/// and compact tablets so that the widescreen website layout fits gracefully
/// without overflowing or feeling oversized on screens with limited vertical height.
class ResponsiveLandscapeScale extends StatelessWidget {
  final Widget child;

  const ResponsiveLandscapeScale({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isLandscape = media.size.width > media.size.height;

    // Default scale: 1.0 (unaltered portrait or standard desktop monitor)
    double scale = 1.0;

    if (isLandscape) {
      if (media.size.height < 520) {
        // Mobile phone in landscape (typical height 340px - 440px):
        // Scale down to ~0.80 - 0.85 so full website landscape layouts fit comfortably!
        scale = (media.size.height / 460.0).clamp(0.78, 0.85);
      } else if (media.size.height < 850 && media.size.width < 1366) {
        // Tablet / compact window in landscape (typical height 500px - 820px):
        // Scale down gently to ~0.88 - 0.93 for an ultra-sleek desktop density!
        scale = (media.size.height / 800.0).clamp(0.88, 0.93);
      }
    }

    // If no scaling is needed (e.g. portrait or full 1080p desktop)
    if (scale >= 0.99) {
      return child;
    }

    final double scaledWidth = media.size.width / scale;
    final double scaledHeight = media.size.height / scale;

    final scaledPadding = EdgeInsets.fromLTRB(
      media.padding.left / scale,
      media.padding.top / scale,
      media.padding.right / scale,
      media.padding.bottom / scale,
    );

    final scaledViewInsets = EdgeInsets.fromLTRB(
      media.viewInsets.left / scale,
      media.viewInsets.top / scale,
      media.viewInsets.right / scale,
      media.viewInsets.bottom / scale,
    );

    final scaledViewPadding = EdgeInsets.fromLTRB(
      media.viewPadding.left / scale,
      media.viewPadding.top / scale,
      media.viewPadding.right / scale,
      media.viewPadding.bottom / scale,
    );

    return MediaQuery(
      data: media.copyWith(
        size: Size(scaledWidth, scaledHeight),
        padding: scaledPadding,
        viewInsets: scaledViewInsets,
        viewPadding: scaledViewPadding,
      ),
      child: SizedBox(
        width: media.size.width,
        height: media.size.height,
        child: ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: scaledWidth,
              height: scaledHeight,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
