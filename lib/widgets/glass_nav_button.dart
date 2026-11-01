import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

// =============================================================================
// NGAM BUSINESS — DESIGN SYSTEM: FLOATING GLASS NAVIGATION & TOP BAR
// Standardized liquid glassmorphism components with unified 44px height.
// All top bars are FLOATING in a Stack with NO parent background.
// All circle buttons: 44x44. Combined pills: height 44, NO dividers between icons.
// All icons: white in dark mode, black/charcoal in light mode.
// =============================================================================

/// Single action item within a [GlassNavPill].
class GlassNavPillItem {
  final dynamic icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final Widget? badge;
  final bool isLoading;

  const GlassNavPillItem({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
    this.badge,
    this.isLoading = false,
  });
}

/// A combined frosted glass pill that merges 2 or more buttons seamlessly
/// without any divider line between icons, maintaining exact 44px height.
class GlassNavPill extends StatelessWidget {
  final List<GlassNavPillItem> items;
  final bool? isDark;
  final double height;
  final EdgeInsetsGeometry? margin;

  const GlassNavPill({
    super.key,
    required this.items,
    this.isDark,
    this.height = 44.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget pill = ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: effectiveDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            border: Border.all(
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((it) => _buildItem(it, effectiveDark)).toList(),
          ),
        ),
      ),
    );

    if (margin != null) {
      pill = Padding(padding: margin!, child: pill);
    }

    return pill;
  }

  Widget _buildItem(GlassNavPillItem item, bool effectiveDark) {
    // Icons strictly white (dark) or black/charcoal (light)
    final Color effectiveIconColor = item.iconColor ??
        (effectiveDark ? Colors.white : const Color(0xFF0F172A));

    Widget content;
    if (item.isLoading) {
      content = Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: effectiveIconColor,
          ),
        ),
      );
    } else {
      content = Center(
        child: item.icon is IconData
            ? Icon(
                item.icon as IconData,
                size: 20,
                color: effectiveIconColor,
              )
            : HugeIcon(
                icon: item.icon,
                size: 20,
                color: effectiveIconColor,
              ),
      );
    }

    if (item.badge != null) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          content,
          Positioned(
            top: 4,
            right: 4,
            child: item.badge!,
          ),
        ],
      );
    }

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.isLoading ? null : item.onTap,
        borderRadius: BorderRadius.circular(100),
        splashColor: effectiveDark ? Colors.white12 : Colors.black12,
        highlightColor: effectiveDark
            ? Colors.white10
            : Colors.black.withValues(alpha: 0.05),
        child: SizedBox(
          width: height,
          height: height,
          child: content,
        ),
      ),
    );

    if (item.tooltip != null && item.tooltip!.isNotEmpty) {
      button = Tooltip(message: item.tooltip!, child: button);
    }

    return button;
  }
}

/// A circular 44x44 frosted glass navigation button with backdrop blur and border.
/// Follows Ngam theme: icon is white in dark mode, black/charcoal in light mode.
class GlassNavButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool? isDark;
  final EdgeInsetsGeometry? margin;
  final bool isLoading;
  final Widget? badge;

  const GlassNavButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.iconColor,
    this.isDark,
    this.margin,
    this.isLoading = false,
    this.badge,
  });

  /// Factory constructor for a standard circular back button
  factory GlassNavButton.back({
    Key? key,
    required BuildContext context,
    bool? isDark,
    VoidCallback? onBack,
    double size = 44.0,
    double iconSize = 20.0,
    EdgeInsetsGeometry? margin,
  }) {
    return GlassNavButton(
      key: key,
      icon: HugeIcons.strokeRoundedArrowLeft01,
      onTap: onBack ??
          () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              try {
                context.pop();
              } catch (_) {
                Navigator.maybePop(context);
              }
            }
          },
      isDark: isDark,
      size: size,
      iconSize: iconSize,
      tooltip: 'Kembali',
      margin: margin,
    );
  }

  /// Factory constructor for a standard circular close/cancel button
  factory GlassNavButton.close({
    Key? key,
    required BuildContext context,
    bool? isDark,
    VoidCallback? onClose,
    double size = 44.0,
    double iconSize = 20.0,
    EdgeInsetsGeometry? margin,
  }) {
    return GlassNavButton(
      key: key,
      icon: HugeIcons.strokeRoundedCancel01,
      onTap: onClose ??
          () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              try {
                context.pop();
              } catch (_) {
                Navigator.maybePop(context);
              }
            }
          },
      isDark: isDark,
      size: size,
      iconSize: iconSize,
      tooltip: 'Tutup',
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final Color effectiveIconColor = iconColor ??
        (effectiveDark ? Colors.white : const Color(0xFF0F172A));

    Widget content;
    if (isLoading) {
      content = Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: effectiveIconColor,
          ),
        ),
      );
    } else {
      content = Center(
        child: icon is IconData
            ? Icon(
                icon as IconData,
                size: iconSize,
                color: effectiveIconColor,
              )
            : HugeIcon(
                icon: icon,
                size: iconSize,
                color: effectiveIconColor,
              ),
      );
    }

    if (badge != null) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          content,
          Positioned(
            top: 3,
            right: 3,
            child: badge!,
          ),
        ],
      );
    }

    Widget button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            border: Border.all(
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onTap,
              customBorder: const CircleBorder(),
              splashColor: effectiveDark ? Colors.white12 : Colors.black12,
              highlightColor: effectiveDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              child: content,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    if (margin != null) {
      button = Padding(padding: margin!, child: button);
    }

    return button;
  }
}

/// Centered frosted glass capsule for title and subtitle (height: 44px).
/// Uses default theme text colors for dark and light mode.
class GlassTitlePill extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool? isDark;
  final bool centerTitle;
  final double height;
  final EdgeInsetsGeometry padding;

  const GlassTitlePill({
    super.key,
    required this.title,
    this.subtitle,
    this.isDark,
    this.centerTitle = true,
    this.height = 44.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final textPrimary =
        effectiveDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        effectiveDark ? Colors.white60 : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: effectiveDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            border: Border.all(
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: (subtitle != null && subtitle!.isNotEmpty) ? 14 : 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating Top Bar overlay placed inside a `Stack` (`Positioned(top: ..., left: ..., right: ...)`).
/// All elements have standardized height (44px) matching Ngam.
/// Has NO parent background container so body content floats and scrolls underneath.
class FloatingTopBar extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool? isDark;
  final double top;
  final double horizontal;
  final bool centerTitle;
  final VoidCallback? onBack;
  final bool showBack;
  final PreferredSizeWidget? bottomTabBar;

  const FloatingTopBar({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.actions,
    this.actionItems,
    this.isDark,
    this.top = 12.0,
    this.horizontal = 16.0,
    this.centerTitle = true,
    this.onBack,
    this.showBack = true,
    this.bottomTabBar,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor ??
              (effectiveDark ? Colors.white : const Color(0xFF0F172A)),
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: effectiveDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: effectiveDark,
          height: 44,
        );
      }
    } else if (actions != null && actions!.isNotEmpty) {
      if (actions!.length == 1) {
        rightWidget = actions!.first;
      } else {
        rightWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        );
      }
    }

    Widget? leftWidget = leading;
    if (leftWidget == null && showBack) {
      leftWidget = GlassNavButton.back(
        context: context,
        isDark: effectiveDark,
        onBack: onBack,
        size: 44,
        iconSize: 20,
      );
    }

    Widget? titleWidget;
    if (title != null && title!.isNotEmpty) {
      titleWidget = GlassTitlePill(
        title: title!,
        subtitle: subtitle,
        isDark: effectiveDark,
        centerTitle: centerTitle,
      );
    }

    final topRow = SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leftWidget ?? const SizedBox(width: 44, height: 44),
          if (titleWidget != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: centerTitle
                  ? Center(child: titleWidget)
                  : Align(alignment: Alignment.centerLeft, child: titleWidget),
            ),
            const SizedBox(width: 10),
          ] else
            const Spacer(),
          rightWidget ??
              (titleWidget != null && centerTitle
                  ? const SizedBox(width: 44, height: 44)
                  : const SizedBox.shrink()),
        ],
      ),
    );

    return Positioned(
      top: top,
      left: horizontal,
      right: horizontal,
      child: bottomTabBar == null
          ? topRow
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                topRow,
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: effectiveDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.75),
                        border: Border.all(
                          color: effectiveDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      child: bottomTabBar,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Standard floating Scaffold that embeds content in a Stack with a floating top bar.
/// Follows the Ngam design system: NO parent background for the top bar!
/// Content scrolls underneath with safe padding.
class GlassScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final List<GlassNavPillItem>? actionItems;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? bottomTabBar;
  final bool? isDark;
  final Color? backgroundColor;
  final bool centerTitle;
  final double contentTopPadding;

  const GlassScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.actionItems,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomTabBar,
    this.isDark,
    this.backgroundColor,
    this.centerTitle = true,
    this.contentTopPadding = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final double computedTopPadding =
        bottomTabBar != null ? (contentTopPadding + 52.0) : contentTopPadding;

    return Scaffold(
      backgroundColor: backgroundColor ??
          (effectiveDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC)),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: computedTopPadding),
                child: body,
              ),
            ),
            FloatingTopBar(
              title: title,
              subtitle: subtitle,
              leading: leading,
              showBack: showBack,
              onBack: onBack,
              actionItems: actionItems,
              actions: actions,
              isDark: effectiveDark,
              centerTitle: centerTitle,
              bottomTabBar: bottomTabBar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard in-body Glass Top Bar for screens that build headers inside a `Column` or `SafeArea`.
class GlassTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool? isDark;
  final bool centerTitle;
  final EdgeInsetsGeometry padding;

  const GlassTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.actionItems,
    this.isDark,
    this.centerTitle = true,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor ??
              (effectiveDark ? Colors.white : const Color(0xFF0F172A)),
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: effectiveDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: effectiveDark,
          height: 44,
        );
      }
    } else if (actions != null && actions!.isNotEmpty) {
      if (actions!.length == 1) {
        rightWidget = actions!.first;
      } else {
        rightWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        );
      }
    }

    Widget? leftWidget = leading;
    if (leftWidget == null && showBack) {
      leftWidget = GlassNavButton.back(
        context: context,
        isDark: effectiveDark,
        onBack: onBack,
        size: 44,
        iconSize: 20,
      );
    }

    return Padding(
      padding: padding,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leftWidget ?? const SizedBox(width: 44, height: 44),
            const SizedBox(width: 10),
            Expanded(
              child: centerTitle
                  ? Center(
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            rightWidget ??
                (centerTitle
                    ? const SizedBox(width: 44, height: 44)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// PreferredSizeWidget drop-in replacement for standard `AppBar`.
/// Has transparent background, zero elevation, and standard 44px elements.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool? isDark;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.actionItems,
    this.isDark,
    this.centerTitle = true,
    this.bottom,
    this.toolbarHeight = 60.0,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor ??
              (effectiveDark ? Colors.white : const Color(0xFF0F172A)),
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: effectiveDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: effectiveDark,
          height: 44,
        );
      }
    } else if (actions != null && actions!.isNotEmpty) {
      if (actions!.length == 1) {
        rightWidget = actions!.first;
      } else {
        rightWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        );
      }
    }

    Widget? leftWidget = leading;
    if (leftWidget == null && showBack) {
      leftWidget = GlassNavButton.back(
        context: context,
        isDark: effectiveDark,
        onBack: onBack,
        size: 44,
        iconSize: 20,
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: toolbarHeight,
      titleSpacing: 16,
      title: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leftWidget ?? const SizedBox(width: 44, height: 44),
            const SizedBox(width: 10),
            Expanded(
              child: centerTitle
                  ? Center(
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            rightWidget ??
                (centerTitle
                    ? const SizedBox(width: 44, height: 44)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
      bottom: bottom,
    );
  }
}
