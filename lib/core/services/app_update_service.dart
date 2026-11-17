import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/pwa_reloader.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/liquid_glass_compat.dart';

class AppReleaseInfo {
  final String version;
  final String title;
  final String changelog;
  final String downloadUrl;
  final String releaseUrl;
  final DateTime? publishedAt;
  final bool isWebReloadReady;

  AppReleaseInfo({
    required this.version,
    required this.title,
    required this.changelog,
    required this.downloadUrl,
    required this.releaseUrl,
    this.publishedAt,
    this.isWebReloadReady = false,
  });
}

class AppUpdateService {
  static const String fallbackVersion = '1.0.48';
  static String? _cachedVersion;
  static bool _startupDialogShown = false;
  static String? _lastNotifiedVersion;
  static Timer? _periodicTimer;

  static final ValueNotifier<String> versionNotifier = ValueNotifier<String>(fallbackVersion);
  static final ValueNotifier<AppReleaseInfo?> availableUpdateNotifier = ValueNotifier<AppReleaseInfo?>(null);

  static String get currentVersion => _cachedVersion ?? fallbackVersion;

  static const String appName = 'Ngam Business';
  static const String repoName = 'Ngam_Business';
  static const String orgName = 'Ngam-Teams';

  /// Get active installed app version dynamically from platform.
  /// On Web/PWA, PackageInfo.fromPlatform() fetches /version.json from the server,
  /// which would return the NEW server version instead of the running JS bundle!
  /// Always use the compiled-in fallbackVersion on Web.
  static Future<String> getAppVersion() async {
    if (_cachedVersion != null && _cachedVersion!.isNotEmpty) {
      return _cachedVersion!;
    }
    if (kIsWeb) {
      _cachedVersion = fallbackVersion;
      versionNotifier.value = fallbackVersion;
      return fallbackVersion;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _cachedVersion = info.version;
        versionNotifier.value = _cachedVersion!;
        return _cachedVersion!;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error fetching package version: $e');
    }
    versionNotifier.value = fallbackVersion;
    return fallbackVersion;
  }

  /// Compare semantic versions (e.g. "1.0.22" vs "1.0.21")
  static bool isNewerVersion(String remote, String current) {
    try {
      final cleanRemote = remote.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');

      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      while (rParts.length < maxLen) {
        rParts.add(0);
      }
      while (cParts.length < maxLen) {
        cParts.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch live deployed Web / PWA version and changelog from root /version.json
  static Future<({String version, String changelog})?> _fetchWebLiveVersion() async {
    if (!kIsWeb) return null;
    try {
      final uri = Uri.base.resolve('/version.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['version'] != null) {
          final ver = decoded['version'].toString().trim();
          final changelog = (decoded['changelog'] ?? '').toString().trim();
          if (ver.isNotEmpty) return (version: ver, changelog: changelog);
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error fetching web /version.json: $e');
    }
    return null;
  }

  /// Check live Web /version.json and GitHub Releases API for latest update
  static Future<AppReleaseInfo?> checkForUpdate({
    String? current,
    String repo = repoName,
  }) async {
    try {
      final activeVersion = current ?? await getAppVersion();

      final futures = await Future.wait([
        (kIsWeb && repo == repoName)
            ? _fetchWebLiveVersion()
            : Future<({String version, String changelog})?>.value(null),
        _fetchGitHubRelease(repo),
      ]);

      final webInfo = futures[0] as ({String version, String changelog})?;
      final ghRelease = futures[1] as AppReleaseInfo?;

      final bool hasWebNewer = webInfo != null && isNewerVersion(webInfo.version, activeVersion);
      final bool hasGhNewer = ghRelease != null && isNewerVersion(ghRelease.version, activeVersion);

      AppReleaseInfo? result;
      if (hasWebNewer) {
        final bool sameGhVersion =
            ghRelease != null && !isNewerVersion(ghRelease.version, webInfo.version) && !isNewerVersion(webInfo.version, ghRelease.version);
        result = AppReleaseInfo(
          version: webInfo.version,
          title: sameGhVersion ? ghRelease.title : '$appName v${webInfo.version}',
          changelog: webInfo.changelog.isNotEmpty
              ? webInfo.changelog
              : (sameGhVersion ? ghRelease.changelog : ''),
          downloadUrl: ghRelease?.downloadUrl ?? 'https://github.com/$orgName/$repo/releases',
          releaseUrl: ghRelease?.releaseUrl ?? 'https://github.com/$orgName/$repo/releases',
          publishedAt: ghRelease?.publishedAt,
          isWebReloadReady: true,
        );
      } else if (hasGhNewer) {
        result = AppReleaseInfo(
          version: ghRelease.version,
          title: ghRelease.title,
          changelog: ghRelease.changelog,
          downloadUrl: ghRelease.downloadUrl,
          releaseUrl: ghRelease.releaseUrl,
          publishedAt: ghRelease.publishedAt,
          isWebReloadReady: false,
        );
      }

      if (repo == repoName) {
        availableUpdateNotifier.value = result;
      }
      return result;
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for update: $e');
      return null;
    }
  }

  static Future<AppReleaseInfo?> _fetchGitHubRelease(String repo) async {
    try {
      final uri = Uri.parse('https://api.github.com/repos/$orgName/$repo/releases/latest');
      final response = await http
          .get(
            uri,
            headers: kIsWeb
                ? const {'Accept': 'application/vnd.github.v3+json'}
                : const {
                    'User-Agent': 'NgamBusinessApp',
                    'Accept': 'application/vnd.github.v3+json',
                  },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final releaseName = data['name'] as String? ?? tagName;
      final changelog = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$orgName/$repo/releases';

      final publishedStr = data['published_at'] as String?;
      DateTime? publishedAt;
      if (publishedStr != null) {
        publishedAt = DateTime.tryParse(publishedStr);
      }

      String downloadUrl = htmlUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
          break;
        }
      }

      final remoteVersion = tagName.replaceFirst('v', '').trim();
      if (remoteVersion.isEmpty) return null;

      return AppReleaseInfo(
        version: remoteVersion,
        title: releaseName,
        changelog: changelog,
        downloadUrl: downloadUrl,
        releaseUrl: htmlUrl,
        publishedAt: publishedAt,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] GitHub release lookup error: $e');
      return null;
    }
  }

  /// Launch download URL
  static Future<void> launchDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Show gorgeous modern glassmorphic dialog when an update is found
  static Future<void> showUpdateDialog(
    BuildContext context,
    AppReleaseInfo update, {
    String? current,
  }) async {
    final activeCurrent = current ?? await getAppVersion();
    if (!context.mounted) return;

    final String changelogText = update.changelog.trim().isNotEmpty
        ? update.changelog.trim()
        : 'app_update.fallback_changelog'.tr();

    final frostedGlow = [
      Shadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 8),
      Shadow(
        color: Colors.black.withValues(alpha: 0.25),
        offset: const Offset(0.5, 0.5),
        blurRadius: 0,
      ),
    ];

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: GlassContainer(
                useOwnLayer: true,
                quality: GlassQuality.standard,
                shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
                settings: const LiquidGlassSettings(
                  thickness: 0.1,
                  blur: 16.0,
                  glassColor: Colors.transparent,
                  lightAngle: 45.0,
                  lightIntensity: 0.1,
                  ambientStrength: 1.0,
                  saturation: 1.0,
                  chromaticAberration: 0.0,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top header with glowing rocket icon & title
                        Row(
                          children: [
                            const Icon(
                              Icons.rocket_launch_rounded,
                              color: Color(0xFF38BDF8),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'app_update.update_available'.tr(),
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: frostedGlow,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    kIsWeb && update.isWebReloadReady
                                        ? 'app_update.web_update_ready_subtitle'.tr()
                                        : 'app_update.ready_subtitle'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Version Pill Badge + optional release link on Web
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'app_update.current_version_label'.tr(args: [activeCurrent]),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'v${update.version}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (kIsWeb && update.releaseUrl.isNotEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(100),
                                onTap: () => launchDownload(update.releaseUrl),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF38BDF8)),
                                      const SizedBox(width: 5),
                                      Text(
                                        'app_update.view_release'.tr(),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          kIsWeb
                              ? 'app_update.web_update_desc'.tr(args: [appName, update.version])
                              : 'app_update.update_desc'.tr(args: ['v${update.version}']),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Changelog Box
                        if (changelogText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 110),
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                changelogText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontFamily: 'monospace',
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Action buttons (Frosted Glass Pill + Vibrant Pill)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(ctx).pop(),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(100),
                                      color: Colors.white.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'app_update.remind_later'.tr(),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    if (kIsWeb) {
                                      if (context.mounted) {
                                        showGlassToast(
                                          context,
                                          'app_update.reloading_web'.tr(),
                                          type: GlassToastType.info,
                                          color: const Color(0xFF0284C7),
                                        );
                                      }
                                      reloadWebPwa(update.version);
                                    } else {
                                      launchDownload(update.downloadUrl);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(100),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF0284C7).withValues(alpha: 0.90),
                                          const Color(0xFF0369A1).withValues(alpha: 0.78),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.60),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0284C7).withValues(alpha: 0.30),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            kIsWeb ? Icons.refresh_rounded : Icons.download_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            kIsWeb ? 'app_update.reload_now'.tr() : 'app_update.update_now'.tr(),
                                            maxLines: 1,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Automatically check on app startup (and periodically) and notify via toast + dialog
  static Future<void> checkOnStartup(
    BuildContext context, {
    String? current,
    String repo = repoName,
  }) async {
    Future<void> runCheck() async {
      if (!context.mounted) return;
      final activeCurrent = current ?? await getAppVersion();
      final update = await checkForUpdate(current: activeCurrent, repo: repo);
      if (update != null && context.mounted) {
        if (_lastNotifiedVersion != update.version) {
          _lastNotifiedVersion = update.version;
          showGlassToast(
            context,
            'app_update.update_available_tap'.tr(args: [update.version]),
            type: GlassToastType.info,
            color: const Color(0xFF0284C7),
            duration: const Duration(seconds: 5),
          );
        }
        if (!_startupDialogShown) {
          _startupDialogShown = true;
          await showUpdateDialog(context, update, current: activeCurrent);
        }
      }
    }

    _periodicTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      runCheck();
    });

    await Future.delayed(const Duration(seconds: 2));
    await runCheck();
  }

  /// Explicit check triggered from Settings / Sidebar / Login page with user feedback
  static Future<void> checkManually(
    BuildContext context, {
    String? current,
    String repo = repoName,
  }) async {
    showGlassToast(
      context,
      'app_update.checking'.tr(),
      type: GlassToastType.info,
      color: Colors.blueAccent,
      duration: const Duration(seconds: 2),
    );

    final activeCurrent = current ?? await getAppVersion();
    final update = await checkForUpdate(current: activeCurrent, repo: repo);
    if (!context.mounted) return;

    if (update != null) {
      await showUpdateDialog(context, update, current: activeCurrent);
    } else {
      showGlassToast(
        context,
        'app_update.latest_version'.tr(args: ['v$activeCurrent']),
        type: GlassToastType.success,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
