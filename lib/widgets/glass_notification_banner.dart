import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../core/router/app_router.dart';

enum NotificationBannerCategory { order, booking, message, promotion, system }

void showInAppNotificationBanner({
  required String title,
  required String body,
  NotificationBannerCategory category = NotificationBannerCategory.system,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 5),
}) {
  final overlayState = rootNavigatorKey.currentState?.overlay;
  if (overlayState == null) return;

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _GlassNotificationBannerWidget(
      title: title,
      body: body,
      category: category,
      duration: duration,
      onTap: () {
        overlayEntry.remove();
        onTap?.call();
      },
      onDismiss: () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      },
    ),
  );

  overlayState.insert(overlayEntry);
}

class _GlassNotificationBannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final NotificationBannerCategory category;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _GlassNotificationBannerWidget({
    required this.title,
    required this.body,
    required this.category,
    required this.duration,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_GlassNotificationBannerWidget> createState() =>
      _GlassNotificationBannerWidgetState();
}

class _GlassNotificationBannerWidgetState
    extends State<_GlassNotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case NotificationBannerCategory.order:
        return const Color(0xFFF59E0B); // Amber / Gold
      case NotificationBannerCategory.booking:
        return const Color(0xFF38BDF8); // Cyan / Blue
      case NotificationBannerCategory.message:
        return const Color(0xFF10B981); // Emerald
      case NotificationBannerCategory.promotion:
        return const Color(0xFFA855F7); // Purple
      case NotificationBannerCategory.system:
        return const Color(0xFF64748B); // Slate
    }
  }

  dynamic _getCategoryIcon() {
    switch (widget.category) {
      case NotificationBannerCategory.order:
        return HugeIcons.strokeRoundedInvoice01;
      case NotificationBannerCategory.booking:
        return HugeIcons.strokeRoundedCalendar03;
      case NotificationBannerCategory.message:
        return HugeIcons.strokeRoundedChatting01;
      case NotificationBannerCategory.promotion:
        return HugeIcons.strokeRoundedTicket01;
      case NotificationBannerCategory.system:
        return HugeIcons.strokeRoundedNotification01;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0 ? mediaQuery.padding.top + 8 : 16.0;
    final catColor = _getCategoryColor();
    final dynamic iconData = _getCategoryIcon();

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: child,
                ),
              );
            },
            child: Dismissible(
              key: const Key('in_app_banner_dismiss'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    _dismissTimer?.cancel();
                    widget.onTap();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: catColor.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Glowing category icon
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: catColor.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: iconData,
                                  color: catColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Title & Body
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Sekarang',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.45),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.body,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.82),
                                      fontSize: 12.5,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Quick Close Icon
                            GestureDetector(
                              onTap: _dismiss,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
