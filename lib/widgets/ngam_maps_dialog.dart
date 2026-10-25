import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// GrabMaps-inspired Dialog popup that showcases NgamMaps and provides
/// official OpenStreetMap & CARTO map data attribution in a sleek, premium way.
class NgamMapsDialog extends StatelessWidget {
  const NgamMapsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const NgamMapsDialog(),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    const linkColor = Color(0xFF2196F3);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Vector Illustration ─────────────────────────────
            SizedBox(
              width: 190,
              height: 150,
              child: CustomPaint(
                painter: _NgamMapsHeroPainter(isDark: isDark),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ───────────────────────────────────────────
            Text(
              'NgamMaps — the backbone of your Ngam experience',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 18),

            // ── Attribution Links ───────────────────────────────
            _buildLink(
              label: '© OpenMapTiles',
              url: 'https://openmaptiles.org/',
              color: linkColor,
            ),
            const SizedBox(height: 10),
            _buildLink(
              label: '© OpenStreetMap contributors',
              url: 'https://www.openstreetmap.org/copyright',
              color: linkColor,
            ),
            const SizedBox(height: 10),
            _buildLink(
              label: '© CARTO Basemaps',
              url: 'https://carto.com/attributions',
              color: linkColor,
            ),
            const SizedBox(height: 10),
            _buildLink(
              label: 'Terms of Service',
              url: 'https://ngam.dev',
              color: linkColor,
            ),
            const SizedBox(height: 24),

            // ── Explore / Confirm CTA Button ────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3), // Ngam Signature Electric Blue!
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Explore NgamMaps',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildLink({
    required String label,
    required String url,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A subtle Grab-style attribution pill that sits at the bottom-left of the map.
class NgamMapsAttributionBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isDark;

  const NgamMapsAttributionBadge({
    super.key,
    this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => NgamMapsDialog.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black54 : Colors.white70),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark ? Colors.white24 : Colors.black12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF2196F3),
              ),
              const SizedBox(width: 4),
              Text(
                'NgamMaps',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1976D2),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that draws the 3D isometric city, friendly mascot helmet,
/// road signs and glowing ring featured in NgamMaps' official modal.
class _NgamMapsHeroPainter extends CustomPainter {
  final bool isDark;
  const _NgamMapsHeroPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);

    // 1. Soft Ice-Blue Backdrop Halo
    final haloPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE3F2FD)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.45), 65, haloPaint);

    final outerRing = Paint()
      ..color = isDark
          ? const Color(0xFF2196F3).withValues(alpha: 0.3)
          : const Color(0xFFBBDEFB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.45), 68, outerRing);

    // 2. Road Signs behind the island (Ngam Blue)
    // Left: Direction Arrow Sign
    final signPaint = Paint()..color = const Color(0xFF2196F3);
    final signPole = Paint()
      ..color = isDark ? const Color(0xFF475569) : const Color(0xFF90CAF9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(45, 60), const Offset(45, 95), signPole);
    final signPath = Path()
      ..moveTo(30, 48)
      ..lineTo(55, 48)
      ..lineTo(65, 58)
      ..lineTo(55, 68)
      ..lineTo(30, 68)
      ..close();
    canvas.drawPath(signPath, signPaint);

    // Right: Round "No Entry" / Traffic Sign
    canvas.drawLine(const Offset(148, 55), const Offset(148, 95), signPole);
    canvas.drawCircle(const Offset(148, 52), 16, signPaint);
    final signBar = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(138, 52), const Offset(158, 52), signBar);

    // 3. Floating 3D Island Base (Lush Emerald Turf & Slate Base)
    final soilRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 12),
      width: 140,
      height: 48,
    );
    final soilPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8);
    canvas.drawOval(soilRect, soilPaint);

    final grassRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 6),
      width: 140,
      height: 44,
    );
    final grassPaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawOval(grassRect, grassPaint);

    // 4. Mascot with Ngam Signature Blue Helmet
    final skinPaint = Paint()..color = const Color(0xFFFFCC99);
    final helmetPaint = Paint()..color = const Color(0xFF2196F3);
    final visorPaint = Paint()..color = const Color(0xFF90CAF9);

    // Mascot Head
    canvas.drawCircle(Offset(center.dx, center.dy - 38), 24, skinPaint);
    // Helmet Shell
    final helmetPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(center.dx, center.dy - 38), radius: 25),
        math.pi * 0.8,
        math.pi * 1.4,
      );
    canvas.drawPath(
      helmetPath,
      helmetPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    // Visor / Stripe
    canvas.drawCircle(Offset(center.dx, center.dy - 46), 4, visorPaint..style = PaintingStyle.fill);

    // Mascot Face (Eyes & Smile)
    final eyePaint = Paint()..color = const Color(0xFF233038);
    canvas.drawCircle(Offset(center.dx - 7, center.dy - 38), 2.2, eyePaint);
    canvas.drawCircle(Offset(center.dx + 7, center.dy - 38), 2.2, eyePaint);
    final smilePaint = Paint()
      ..color = const Color(0xFF233038)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 34), width: 12, height: 8),
      0.1,
      math.pi - 0.2,
      false,
      smilePaint,
    );

    // 5. 3D Isometric Buildings in center (Vibrant Ngam Blues)
    // Building Left (Cyan skyscraper)
    _drawBuilding(canvas, Offset(center.dx - 28, center.dy - 22), 16, 32, const Color(0xFF40C4FF), const Color(0xFF00B0FF));
    // Building Center (Electric Blue skyscraper)
    _drawBuilding(canvas, Offset(center.dx - 10, center.dy - 30), 20, 42, const Color(0xFF2196F3), const Color(0xFF1565C0));
    // Building Right (Light Sky Blue tower)
    _drawBuilding(canvas, Offset(center.dx + 12, center.dy - 24), 16, 34, const Color(0xFF90CAF9), const Color(0xFF64B5F6));

    // Curving road on island
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F4FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final roadPath = Path()
      ..moveTo(center.dx - 55, center.dy + 8)
      ..quadraticBezierTo(center.dx, center.dy + 22, center.dx + 55, center.dy + 10);
    canvas.drawPath(roadPath, roadPaint);

    // 6. Giant Red Destination Pin in the very center
    final pinCenter = Offset(center.dx, center.dy - 2);
    _drawRedPin(canvas, pinCenter);

    // 7. Mascot Hands hugging the island base (Ngam Blue gloves)
    final handPaint = Paint()..color = const Color(0xFF2196F3);
    // Left hand/glove
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx - 56, center.dy + 10), width: 22, height: 16),
        const Radius.circular(8),
      ),
      handPaint,
    );
    // Right hand/glove
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx + 56, center.dy + 10), width: 22, height: 16),
        const Radius.circular(8),
      ),
      handPaint,
    );
  }

  void _drawBuilding(Canvas canvas, Offset pos, double width, double height, Color frontColor, Color sideColor) {
    // Front face
    final frontPaint = Paint()..color = frontColor;
    canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, width, height), frontPaint);

    // Roof highlight
    final roofPaint = Paint()..color = Colors.white70;
    canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, width, 3), roofPaint);

    // Window lines
    final windowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (double y = pos.dy + 6; y < pos.dy + height - 4; y += 6) {
      canvas.drawLine(Offset(pos.dx + 3, y), Offset(pos.dx + width - 3, y), windowPaint);
    }
  }

  void _drawRedPin(Canvas canvas, Offset tip) {
    final pinHead = Offset(tip.dx, tip.dy - 20);

    // Shadow below pin tip
    final shadowPaint = Paint()..color = Colors.black26;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tip.dx, tip.dy + 2), width: 12, height: 5),
      shadowPaint,
    );

    // Red teardrop pin
    final redPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
      ).createShader(Rect.fromCircle(center: pinHead, radius: 14));

    final pinPath = Path();
    pinPath.moveTo(tip.dx, tip.dy);
    // Left curve up to head
    pinPath.cubicTo(
      tip.dx - 14,
      tip.dy - 10,
      tip.dx - 14,
      pinHead.dy,
      tip.dx - 14,
      pinHead.dy,
    );
    // Top arc
    pinPath.arcToPoint(
      Offset(tip.dx + 14, pinHead.dy),
      radius: const Radius.circular(14),
      clockwise: true,
    );
    // Right curve down to tip
    pinPath.cubicTo(
      tip.dx + 14,
      pinHead.dy,
      tip.dx + 14,
      tip.dy - 10,
      tip.dx,
      tip.dy,
    );
    pinPath.close();
    canvas.drawPath(pinPath, redPaint);

    // Center white dot
    final whiteDot = Paint()..color = Colors.white;
    canvas.drawCircle(pinHead, 5.5, whiteDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
