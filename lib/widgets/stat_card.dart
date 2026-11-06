import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'skeleton_box.dart';

// =============================================================================
// StatCard
// Ultra-modern, frosted glass metric card styled like a high-end FinTech /
// Operations Command Center. Features ambient glow, dynamic mini sparklines,
// live status pill badges, and smooth hover micro-interactions.
// =============================================================================

class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final dynamic icon;
  final Color accentColor;
  final Color? badgeColor;
  final List<double>? sparklineData;
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
    this.sparklineData,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  List<double> _resolveSparkline() {
    if (widget.sparklineData != null && widget.sparklineData!.length >= 2) {
      return widget.sparklineData!;
    }
    // Default pleasant aesthetic wave
    return const [2.5, 3.8, 3.2, 5.0, 5.8, 7.2, 6.9, 8.8, 9.5];
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBadgeColor = widget.badgeColor ?? widget.accentColor;
    final sparkline = _resolveSparkline();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -3.0 : 0.0, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: widget.accentColor.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 114),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor.withValues(alpha: _isHovered ? 0.14 : 0.07),
                    const Color(0xFF111422).withValues(alpha: 0.94),
                    const Color(0xFF0C0E18).withValues(alpha: 0.98),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isHovered
                      ? widget.accentColor.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.10),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovered ? 0.38 : 0.20),
                    blurRadius: _isHovered ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: _isHovered ? 0.20 : 0.05),
                    blurRadius: _isHovered ? 16 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // 1. Ambient radial corner glow
                    Positioned(
                      top: -18,
                      left: -18,
                      child: IgnorePointer(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accentColor.withValues(
                              alpha: _isHovered ? 0.18 : 0.09,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Ambient decorative mini sparkline in the bottom-right corner
                    Positioned(
                      right: 12,
                      bottom: 8,
                      width: 115,
                      height: 52,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _StatCardSparklinePainter(
                            data: sparkline,
                            color: widget.accentColor,
                            isHovered: _isHovered,
                          ),
                        ),
                      ),
                    ),

                    // 3. Main Foreground Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top row: Icon squircle on left + Status badge on right
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Icon squircle with glowing gradient & border
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: widget.accentColor.withValues(
                                      alpha: _isHovered ? 0.50 : 0.32,
                                    ),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accentColor.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: widget.icon is IconData
                                      ? Icon(
                                          widget.icon as IconData,
                                          color: widget.accentColor,
                                          size: 18,
                                        )
                                      : HugeIcon(
                                          icon: widget.icon,
                                          color: widget.accentColor,
                                          size: 18,
                                          strokeWidth: 2.1,
                                        ),
                                ),
                              ),

                              // Status Pill Badge with live glowing dot
                              if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: effectiveBadgeColor.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: effectiveBadgeColor.withValues(alpha: 0.32),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5.5,
                                        height: 5.5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: effectiveBadgeColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: effectiveBadgeColor.withValues(alpha: 0.8),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 5.5),
                                      Text(
                                        widget.subtitle!,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: effectiveBadgeColor,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Middle: Prominent Metric Value
                          if (widget.isLoading || widget.value == '...')
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: SkeletonBox(
                                width: 85,
                                height: 24,
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
                                  fontSize: 22.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.6,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),

                          // Bottom: Metric Label
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.white.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
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
        ),
      ),
    );
  }
}

// =============================================================================
// _StatCardSparklinePainter
// Smooth cubic-bezier sparkline painter with gradient fill and terminal pulse dot.
// =============================================================================

class _StatCardSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isHovered;

  _StatCardSparklinePainter({
    required this.data,
    required this.color,
    this.isHovered = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final double minVal = data.reduce(math.min);
    final double maxVal = data.reduce(math.max);
    final double range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);

    double getY(double val) {
      final normalized = (val - minVal) / range;
      // Invert Y and restrict to 15% - 85% of height for breathing room
      return size.height - (normalized * (size.height * 0.70) + (size.height * 0.15));
    }

    final pStart = Offset(0, getY(data[0]));
    path.moveTo(pStart.dx, pStart.dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(pStart.dx, pStart.dy);

    for (int i = 0; i < data.length - 1; i++) {
      final p0 = Offset(i * stepX, getY(data[i]));
      final p1 = Offset((i + 1) * stepX, getY(data[i + 1]));

      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 1. Soft vertical gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isHovered ? 0.28 : 0.16),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 2. Glowing curved stroke line
    final linePaint = Paint()
      ..color = color.withValues(alpha: isHovered ? 0.85 : 0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // 3. Terminal live pulse dot at the end of the sparkline
    final lastPoint = Offset(size.width, getY(data.last));
    final dotPaint = Paint()
      ..color = color.withValues(alpha: isHovered ? 1.0 : 0.85)
      ..style = PaintingStyle.fill;
    final dotGlow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(lastPoint, isHovered ? 5.5 : 4.0, dotGlow);
    canvas.drawCircle(lastPoint, isHovered ? 3.0 : 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _StatCardSparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.isHovered != isHovered;
  }
}
