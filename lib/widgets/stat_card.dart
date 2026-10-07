import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// StatCard — frosted glass metric card styled like Pusat Kawalan / Pusat Operasi.
/// Features a compact 2x2 grid form-factor, smooth micro-interactions,
/// glowing accent borders, and status badge pill.
class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final dynamic icon;
  final Color accentColor;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFF42A5F5),
    this.badgeColor,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBadgeColor = widget.badgeColor ?? widget.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.transparent,
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: _isHovered ? 0.08 : 0.05,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isHovered
                      ? widget.accentColor.withValues(alpha: 0.45)
                      : widget.accentColor.withValues(alpha: 0.22),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(
                      alpha: _isHovered ? 0.16 : 0.08,
                    ),
                    blurRadius: _isHovered ? 20 : 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row: Icon box on left + Badge on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: widget.icon is IconData
                            ? Icon(
                                widget.icon as IconData,
                                color: widget.accentColor,
                                size: 20,
                              )
                            : HugeIcon(
                                icon: widget.icon,
                                color: widget.accentColor,
                                size: 20,
                                strokeWidth: 2.1,
                              ),
                      ),
                      if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: effectiveBadgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: 10,
                              color: effectiveBadgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Middle: Value
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Bottom: Label
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
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
}
