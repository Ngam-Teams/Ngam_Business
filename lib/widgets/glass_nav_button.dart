import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

// =============================================================================
// NGAM BUSINESS — DESIGN SYSTEM: GLASS NAVIGATION & TOP BAR
// Standardized liquid glassmorphism components with unified 44px height.
// All circle buttons: 44x44. Combined pills: height 44, NO dividers between icons.
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
  final bool isDark;
  final double height;
  final EdgeInsetsGeometry? margin;

  const GlassNavPill({
    super.key,
    required this.items,
    this.isDark = true,
    this.height = 44.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    Widget pill = ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map(_buildItem).toList(),
          ),
        ),
      ),
    );

    if (margin != null) {
      pill = Padding(padding: margin!, child: pill);
    }

    return pill;
  }

  Widget _buildItem(GlassNavPillItem item) {
    final Color effectiveIconColor = item.iconColor ??
        (isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B));

    Widget content;
    if (item.isLoading) {
      content = Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: item.iconColor ?? const Color(0xFF42A5F5),
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
            top: 6,
            right: 6,
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
        splashColor: isDark ? Colors.white12 : Colors.black12,
        highlightColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
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
class GlassNavButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool isDark;
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
    this.isDark = true,
    this.margin,
    this.isLoading = false,
    this.badge,
  });

  /// Factory constructor for a standard circular back button
  factory GlassNavButton.back({
    Key? key,
    required BuildContext context,
    bool isDark = true,
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
    bool isDark = true,
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
    final Color effectiveIconColor = iconColor ??
        (isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B));

    Widget content;
    if (isLoading) {
      content = Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: iconColor ?? const Color(0xFF42A5F5),
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
            top: 6,
            right: 6,
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
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
              splashColor: isDark ? Colors.white12 : Colors.black12,
              highlightColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              child: content,
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      button = Padding(padding: margin!, child: button);
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// The signature Ngam Frosted Glass Title Capsule/Pill (44px height).
class GlassTitlePill extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isDark;
  final bool centerTitle;

  const GlassTitlePill({
    super.key,
    required this.title,
    this.subtitle,
    this.isDark = true,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: (subtitle != null && subtitle!.isNotEmpty) ? 13.5 : 15,
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
                    fontSize: 9.5,
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

/// PreferredSizeWidget implementation for drop-in `appBar: GlassAppBar(...)` usage.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool isDark;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.actionItems,
    this.isDark = true,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(60.0 + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor,
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: isDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: isDark,
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
        isDark: isDark,
        onBack: onBack,
        size: 44,
        iconSize: 20,
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 60.0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        isDark: isDark,
                        centerTitle: centerTitle,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: isDark,
                        centerTitle: centerTitle,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            rightWidget ?? const SizedBox(width: 44, height: 44),
          ],
        ),
      ),
      bottom: bottom,
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
  final bool isDark;
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
    this.isDark = true,
    this.centerTitle = true,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor,
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: isDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: isDark,
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
        isDark: isDark,
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
                        isDark: isDark,
                        centerTitle: centerTitle,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: isDark,
                        centerTitle: centerTitle,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            rightWidget ?? const SizedBox(width: 44, height: 44),
          ],
        ),
      ),
    );
  }
}

/// Floating Top Bar overlay placed inside a `Stack` (`Positioned(top: ..., left: ..., right: ...)`).
class FloatingTopBar extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool isDark;
  final double top;
  final double horizontal;
  final bool centerTitle;

  const FloatingTopBar({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.actions,
    this.actionItems,
    this.isDark = true,
    this.top = 12.0,
    this.horizontal = 16.0,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor,
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: isDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: isDark,
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

    Widget? titleWidget;
    if (title != null && title!.isNotEmpty) {
      titleWidget = GlassTitlePill(
        title: title!,
        subtitle: subtitle,
        isDark: isDark,
        centerTitle: centerTitle,
      );
    }

    return Positioned(
      top: top,
      left: horizontal,
      right: horizontal,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading ??
                GlassNavButton.back(
                  context: context,
                  isDark: isDark,
                  size: 44,
                  iconSize: 20,
                ),
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
            rightWidget ?? (titleWidget != null && centerTitle ? const SizedBox(width: 44, height: 44) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
