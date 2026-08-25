import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class NavItem {
  final String title;
  final dynamic icon;

  const NavItem({required this.title, required this.icon});
}

/// Glassmorphic floating pill bottom navigation bar.
/// Mirrors the BottomNav widget from ngam_console exactly.
class BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bool isKeyboardOpen = keyboardHeight > 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final double adjustedBottomPadding = safeBottom > 0 ? safeBottom + 0 : 20;

    const Duration animDuration = Duration(milliseconds: 450);
    const Curve animCurve = Curves.easeOutQuint;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isKeyboardOpen ? 0.0 : 1.0,
      child: isKeyboardOpen
          ? const SizedBox.shrink()
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: adjustedBottomPadding,
                  top: 10,
                ),
                child: GlassContainer(
                  useOwnLayer: true,
                  quality: GlassQuality.standard,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 50.0),
                  settings: LiquidGlassSettings(
                    thickness: 0.1,
                    blur: 2.0,
                    refractiveIndex: 1.0,
                    glassColor: Colors.transparent,
                    lightAngle: 45.0,
                    lightIntensity: isDark ? 0.1 : 0.2,
                    ambientStrength: 1.0,
                    saturation: 1.0,
                    chromaticAberration: 0.0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.15 : 0.4,
                        ),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double totalWidth = constraints.maxWidth;
                        const int inactiveFlex = 2;
                        const int activeFlex = 5;

                        final int totalFlex =
                            ((widget.items.length - 1) * inactiveFlex) +
                            activeFlex;
                        final double inactiveWidth =
                            totalWidth * (inactiveFlex / totalFlex);
                        final double activeWidth =
                            totalWidth * (activeFlex / totalFlex);
                        final double pillLeftOffset =
                            widget.currentIndex * inactiveWidth;

                        return SizedBox(
                          height: 48,
                          child: Stack(
                            children: [
                              // Sliding pill
                              AnimatedPositioned(
                                duration: animDuration,
                                curve: animCurve,
                                left: pillLeftOffset,
                                width: activeWidth,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: isDark ? 0.2 : 0.8,
                                      ),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.2 : 0.05,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Icons
                              Row(
                                children: List.generate(
                                  widget.items.length,
                                  (i) {
                                    final isSelected =
                                        widget.currentIndex == i;
                                    final double targetWidth = isSelected
                                        ? activeWidth
                                        : inactiveWidth;
                                    final Color itemColor = isDark
                                        ? (isSelected
                                            ? Colors.white
                                            : Colors.white70)
                                        : (isSelected
                                            ? Colors.grey.shade900
                                            : Colors.grey.shade600);

                                    return GestureDetector(
                                      onTap: () => widget.onTap(i),
                                      behavior: HitTestBehavior.opaque,
                                      child: AnimatedContainer(
                                        duration: animDuration,
                                        curve: animCurve,
                                        width: targetWidth,
                                        height: 48,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            HugeIcon(
                                              icon: widget.items[i].icon,
                                              color: itemColor,
                                              size: 20,
                                              strokeWidth: 2.1,
                                            ),
                                            AnimatedSize(
                                              duration: animDuration,
                                              curve: animCurve,
                                              alignment: Alignment.centerLeft,
                                              child: isSelected
                                                  ? AnimatedOpacity(
                                                      duration: const Duration(
                                                        milliseconds: 250,
                                                      ),
                                                      opacity:
                                                          isSelected ? 1.0 : 0.0,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                          left: 6,
                                                        ),
                                                        child: Text(
                                                          widget.items[i].title,
                                                          maxLines: 1,
                                                          style: TextStyle(
                                                            color: itemColor,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
