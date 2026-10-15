import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass Quality presets for compatibility
enum GlassQuality {
  standard,
  high,
  low,
}

/// Compatibility replacement for LiquidRoundedSuperellipse
class LiquidRoundedSuperellipse {
  final double borderRadius;
  const LiquidRoundedSuperellipse({this.borderRadius = 16.0});
}

/// Compatibility replacement for LiquidGlassSettings
class LiquidGlassSettings {
  final double thickness;
  final double blur;
  final Color glassColor;
  final double lightIntensity;
  final double lightAngle;
  final double specularIntensity;
  final double chromaticAberration;
  final double refraction;
  final double refractiveIndex;
  final double ambientStrength;
  final dynamic blendMode;
  final dynamic saturation;
  final dynamic brightness;

  const LiquidGlassSettings({
    this.thickness = 0.1,
    this.blur = 15.0,
    this.glassColor = Colors.transparent,
    this.lightIntensity = 0.1,
    this.lightAngle = 0.0,
    this.specularIntensity = 0.0,
    this.chromaticAberration = 0.0,
    this.refraction = 0.0,
    this.refractiveIndex = 1.0,
    this.ambientStrength = 0.1,
    this.blendMode,
    this.saturation,
    this.brightness,
  });
}

/// High-performance, cross-platform GlassContainer using BackdropFilter.
/// Eliminates fragile SkSL fragment shaders that cause web compilation failure.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final dynamic shape;
  final dynamic settings;
  final dynamic quality;
  final bool? useOwnLayer;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.shape,
    this.settings,
    this.quality,
    this.useOwnLayer,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    double radius = 16.0;
    if (shape is LiquidRoundedSuperellipse) {
      radius = (shape as LiquidRoundedSuperellipse).borderRadius;
    } else if (shape is BorderRadius) {
      radius = (shape as BorderRadius).topLeft.x;
    } else if (shape is double) {
      radius = shape as double;
    }

    double blurVal = 15.0;
    if (settings is LiquidGlassSettings) {
      blurVal = (settings as LiquidGlassSettings).blur;
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            color: color,
            child: child,
          ),
        ),
      ),
    );
  }
}
