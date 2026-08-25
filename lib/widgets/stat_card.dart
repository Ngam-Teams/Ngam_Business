import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// StatCard — frosted glass metric card with hover micro-interaction.
/// Mirrors ngam_console's StatCard exactly.
class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final dynamic icon;
  final Color accentColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFF42A5F5),
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
          settings: const LiquidGlassSettings(
            thickness: 0.1,
            blur: 15.0,
            refractiveIndex: 1.0,
            glassColor: Colors.transparent,
            lightAngle: 45.0,
            lightIntensity: 0.1,
            ambientStrength: 1.0,
            saturation: 1.0,
            chromaticAberration: 0.0,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: _isHovered ? 0.08 : 0.05,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(
                    alpha: _isHovered ? 0.15 : 0.0,
                  ),
                  blurRadius: _isHovered ? 24 : 16,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon (Left)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: HugeIcon(
                    icon: widget.icon,
                    color: widget.accentColor,
                    size: 24,
                    strokeWidth: 2.1,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Text (Middle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.greenAccent.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.greenAccent,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.greenAccent.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.value,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
