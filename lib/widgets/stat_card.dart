import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'skeleton_box.dart';

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
  final bool isLoading;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFF42A5F5),
    this.badgeColor,
    this.onTap,
    this.isLoading = false,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.transparent,
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: _isHovered ? 0.07 : 0.045,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.22 : 0.12),
                  blurRadius: _isHovered ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
                if (_isHovered)
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: widget.icon is IconData
                            ? Icon(
                                widget.icon as IconData,
                                color: widget.accentColor,
                                size: 16,
                              )
                            : HugeIcon(
                                icon: widget.icon,
                                color: widget.accentColor,
                                size: 16,
                                strokeWidth: 2.1,
                              ),
                      ),
                      if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: effectiveBadgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: effectiveBadgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Middle: Value
                  if (widget.isLoading || widget.value == '...')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: SkeletonBox(
                        width: 75,
                        height: 20,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.value,
                        style: const TextStyle(
                          fontSize: 19.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),

                  // Bottom: Label
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
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
