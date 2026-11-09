import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'skeleton_box.dart';

// =============================================================================
// StatCard
// Compact form-factor, ambient sparkline wave, glowing pulse status pill,
// and zero-overflow metric display matching Ngam's signature design system.
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
    // Default subtle aesthetic wave
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: widget.accentColor.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accentColor.withValues(alpha: _isHovered ? 0.09 : 0.045),
                  const Color(0xFF111422).withValues(alpha: 0.94),
                  const Color(0xFF0C0E18).withValues(alpha: 0.98),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.50)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.28 : 0.14),
                  blurRadius: _isHovered ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
                if (_isHovered)
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top row: Icon box on left + Status pill badge on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: widget.accentColor.withValues(
                            alpha: _isHovered ? 0.40 : 0.25,
                          ),
                          width: 1,
                        ),
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
                          horizontal: 7.5,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: effectiveBadgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: effectiveBadgeColor.withValues(alpha: 0.32),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4.5,
                              height: 4.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: effectiveBadgeColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: effectiveBadgeColor.withValues(alpha: 0.8),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4.5),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: effectiveBadgeColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2. Middle: Metric Value on left + Sparkline Curve on right (SIDE-BY-SIDE)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: widget.isLoading || widget.value == '...'
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: SkeletonBox(
                                width: 75,
                                height: 20,
                                borderRadius: BorderRadius.all(Radius.circular(6)),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.value,
                                style: const TextStyle(
                                  fontSize: 19.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 62,
                      height: 26,
                      child: CustomPaint(
                        size: const Size(62, 26),
                        painter: _StatCardSparklinePainter(
                          data: sparkline,
                          color: widget.accentColor,
                          isHovered: _isHovered,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 3. Bottom: Metric Label (Full width, guaranteed zero overlap)
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
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

// =============================================================================
// _StatCardSparklinePainter
// Lightweight cubic-bezier sparkline with smooth gradient fill and terminal pulse dot.
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
    if (data.length < 2 || size.width <= 0 || size.height <= 0) return;

    final double minVal = data.reduce(math.min);
    final double maxVal = data.reduce(math.max);
    final bool isAllZero = maxVal == 0.0 && minVal == 0.0;
    final List<double> drawData;
    if (isAllZero) {
      // Subtle baseline telemetry ripple when no transactions yet
      drawData = const [0.8, 1.4, 1.0, 2.0, 1.8, 2.6, 2.1, 2.8, 3.2];
    } else if (maxVal == minVal) {
      drawData = [minVal * 0.8, minVal, minVal * 0.9, minVal * 1.05, minVal];
    } else {
      drawData = data;
    }

    final double effMin = drawData.reduce(math.min);
    final double effMax = drawData.reduce(math.max);
    final double range = (effMax - effMin) == 0 ? 1.0 : (effMax - effMin);

    final path = Path();
    final fillPath = Path();

    // Leave a small 4px margin on the right for the terminal pulse dot halo
    final double drawWidth = math.max(1.0, size.width - 4.0);
    final stepX = drawWidth / (drawData.length - 1);

    double getY(double val) {
      final normalized = (val - effMin) / range;
      return size.height - (normalized * (size.height * 0.70) + (size.height * 0.15));
    }

    final pStart = Offset(0, getY(drawData[0]));
    path.moveTo(pStart.dx, pStart.dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(pStart.dx, pStart.dy);

    for (int i = 0; i < drawData.length - 1; i++) {
      final p0 = Offset(i * stepX, getY(drawData[i]));
      final p1 = Offset((i + 1) * stepX, getY(drawData[i + 1]));

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

    fillPath.lineTo(drawWidth, size.height);
    fillPath.close();

    final double fillAlpha = isAllZero
        ? (isHovered ? 0.15 : 0.08)
        : (isHovered ? 0.24 : 0.14);
    final double strokeAlpha = isAllZero
        ? (isHovered ? 0.55 : 0.38)
        : (isHovered ? 0.88 : 0.65);

    // 1. Soft vertical gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: fillAlpha),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, drawWidth, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 2. Glowing curved stroke line
    final linePaint = Paint()
      ..color = color.withValues(alpha: strokeAlpha)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // 3. Terminal live pulse dot at the end of the sparkline
    final lastPoint = Offset(drawWidth, getY(drawData.last));
    final dotPaint = Paint()
      ..color = color.withValues(alpha: isHovered ? 1.0 : 0.85)
      ..style = PaintingStyle.fill;
    final dotGlow = Paint()
      ..color = color.withValues(alpha: isAllZero ? 0.20 : 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(lastPoint, 3.8, dotGlow);
    canvas.drawCircle(lastPoint, 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _StatCardSparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.isHovered != isHovered;
  }
}
