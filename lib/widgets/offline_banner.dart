import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../core/services/network_status_service.dart';

/// OfflineBanner renders a sleek floating notification pill when the internet
/// connection drops, and smoothly displays a green recovery pill when reconnected.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _wasOffline = false;
  bool _showRestoredBanner = false;
  Timer? _restoredTimer;

  @override
  void initState() {
    super.initState();
    NetworkStatusService.instance.isOnlineNotifier.addListener(_onNetworkChange);
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    NetworkStatusService.instance.isOnlineNotifier.removeListener(_onNetworkChange);
    super.dispose();
  }

  void _onNetworkChange() {
    final isOnline = NetworkStatusService.instance.isOnlineNotifier.value;
    if (!isOnline) {
      _wasOffline = true;
      _restoredTimer?.cancel();
      if (_showRestoredBanner) {
        setState(() => _showRestoredBanner = false);
      }
    } else if (_wasOffline) {
      // Transitioned from offline to online
      _wasOffline = false;
      setState(() => _showRestoredBanner = true);
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showRestoredBanner = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkStatusService.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        final showOffline = !isOnline;
        final showRestored = _showRestoredBanner;

        if (!showOffline && !showRestored) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: showOffline
                    ? const Color(0xFF1E1500).withValues(alpha: 0.95)
                    : const Color(0xFF0D2818).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: showOffline
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                      : const Color(0xFF10B981).withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: showOffline
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: showOffline
                          ? HugeIcons.strokeRoundedWifiDisconnected01
                          : HugeIcons.strokeRoundedWifi01,
                      color: showOffline
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      size: 16,
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showOffline
                              ? 'Tiada Sambungan Internet'
                              : 'Sambungan Internet Pulih',
                          style: TextStyle(
                            color: showOffline
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF34D399),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (showOffline) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Sesetengah fungsi (pesanan masa nyata & pembayaran) memerlukan talian.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showOffline)
                    TextButton.icon(
                      onPressed: () =>
                          NetworkStatusService.instance.checkConnectivity(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedRefresh,
                        color: Colors.white,
                        size: 13,
                        strokeWidth: 2.2,
                      ),
                      label: const Text(
                        'Semak',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
