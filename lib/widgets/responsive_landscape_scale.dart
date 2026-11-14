import 'package:flutter/material.dart';

/// Automatically scales the application UI in landscape mode on mobile phones
/// and compact tablets so that the widescreen website layout fits gracefully
/// across 100% of the viewport without overflowing or leaving empty margins.
class ResponsiveLandscapeScale extends StatelessWidget {
  final Widget child;

  const ResponsiveLandscapeScale({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final double viewportWidth =
            constraints.hasBoundedWidth && constraints.maxWidth > 0
                ? constraints.maxWidth
                : media.size.width;
        final double viewportHeight =
            constraints.hasBoundedHeight && constraints.maxHeight > 0
                ? constraints.maxHeight
                : media.size.height;

        if (viewportWidth <= 0 ||
            viewportHeight <= 0 ||
            !viewportWidth.isFinite ||
            !viewportHeight.isFinite) {
          return child;
        }

        // Guard against portrait phones with an open virtual keyboard temporarily
        // reducing height below width. Real phone/tablet landscape widths >= 500dp.
        final bool isLandscape =
            viewportWidth > viewportHeight && viewportWidth >= 500;

        // Default scale: 1.0 (unaltered portrait or standard desktop monitor)
        double scale = 1.0;

        if (isLandscape) {
          if (viewportHeight < 520) {
            // Mobile phone in landscape (typical height 330px - 440px):
            // Scale down to ~0.74 - 0.85 so full website landscape layouts fit comfortably!
            scale = (viewportHeight / 460.0).clamp(0.74, 0.85);
          } else if (viewportHeight < 850 && viewportWidth < 1366) {
            // Tablet / compact window in landscape (typical height 520px - 849px):
            // Scale down gently to ~0.88 - 0.93 for an ultra-sleek desktop density!
            scale = (viewportHeight / 800.0).clamp(0.88, 0.93);
          }
        }

        // If no scaling is needed (e.g. portrait or full 1080p desktop)
        if (scale >= 0.99) {
          return SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: child,
          );
        }

        final double scaledWidth = viewportWidth / scale;
        final double scaledHeight = viewportHeight / scale;

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
            width: viewportWidth,
            height: viewportHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: scaledWidth,
                height: scaledHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
