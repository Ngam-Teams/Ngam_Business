import 'package:flutter/material.dart';

/// SkeletonBox provides a smooth, animated shimmer loading placeholder.
/// Styled for dark-mode and glassmorphic UI aesthetics.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(6);
    final base = widget.baseColor ?? Colors.white.withValues(alpha: 0.07);
    final highlight =
        widget.highlightColor ?? Colors.white.withValues(alpha: 0.22);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (progress * 4.0), -0.2),
              end: Alignment(-0.5 + (progress * 4.0), 0.2),
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
