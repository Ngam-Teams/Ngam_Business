import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/glass_toast.dart';

/// NgamTeamsService — Centralized service to coordinate interactions
/// between Ngam Business (Owner / Manager) and Ngam Teams (Staff / Crew).
class NgamTeamsService {
  static const String appScheme = 'ngamteams://open';
  static const String apkDownloadUrl = 'https://github.com/Ngam-Teams/Ngam_Teams/releases';
  static const String packageName = 'com.ngam.teams';

  /// Attempts to launch the Ngam Teams application.
  /// If not installed or cannot be opened, gracefully redirects to the APK release page.
  static Future<void> launchTeamsApp(BuildContext context) async {
    try {
      final schemeUri = Uri.parse(appScheme);
      final apkUri = Uri.parse(apkDownloadUrl);

      bool launched = false;
      if (await canLaunchUrl(schemeUri)) {
        launched = await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        if (context.mounted) {
          showGlassToast(
            context,
            'Aplikasi Ngam Teams belum dipasang. Membuka pautan muat turun APK...',
          );
        }
        await launchUrl(apkUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[NgamTeamsService] Error launching Ngam Teams: $e');
      final apkUri = Uri.parse(apkDownloadUrl);
      await launchUrl(apkUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Directly opens the GitHub releases download page in external browser.
  static Future<void> openDownloadReleases(BuildContext context) async {
    try {
      final uri = Uri.parse(apkDownloadUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        showGlassToast(context, 'Gagal membuka pautan muat turun: $e', isError: true);
      }
    }
  }

  /// Copies a WhatsApp-ready invitation message with steps and APK download link.
  static void copyStaffInvite(
    BuildContext context, {
    String? businessName,
    String? staffName,
    String? staffCode,
    String? email,
  }) {
    final biz = businessName ?? 'perniagaan ini';
    final name = staffName != null && staffName.trim().isNotEmpty ? staffName.trim() : 'krew';
    final codeLine = staffCode != null && staffCode.trim().isNotEmpty
        ? '\n👉 Kod Staf anda: $staffCode'
        : '';
    final emailLine = email != null && email.trim().isNotEmpty
        ? '\n👉 Emel berdaftar: $email'
        : '';

    final message = '''
👋 Halo $name! Anda dijemput menyertai pasukan "$biz" di aplikasi Ngam Teams.

📲 Muat Turun Aplikasi (Android APK):
$apkDownloadUrl
$codeLine$emailLine

Langkah-langkah Mudah:
1. Pasang aplikasi Ngam Teams menggunakan pautan di atas.
2. Log masuk menggunakan emel berdaftar anda, ATAU buka menu Profil dan masukkan Kod Staf di atas.
3. Anda akan terus dipautkan ke akaun kedai untuk mula bertugas!
'''.trim();

    Clipboard.setData(ClipboardData(text: message));
    showGlassToast(context, 'Mesej jemputan krew Ngam Teams berjaya disalin!');
  }

  /// Displays the interactive "Ngam Teams Hub" Bottom Sheet with Trio Quick Actions.
  static void showTeamsHubModal(BuildContext context, {String? businessName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hab Pasukan & Ngam Teams',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          businessName != null ? 'Operasi Krew — $businessName' : 'Pusat Akses Aplikasi Krew Lapangan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      color: Color(0xFF60A5FA),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aplikasi Ngam Teams dikhaskan untuk krew (kaunter, dapur, servis) bagi tugasan harian, kehadiran & panggil giliran.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'TINDAKAN PANTAS (QUICK ACTIONS)',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // 3 Quick Action Cards
              _buildHubActionTile(
                icon: HugeIcons.strokeRoundedSmartPhone01,
                iconColor: const Color(0xFF38BDF8),
                title: 'Buka Aplikasi Ngam Teams',
                subtitle: 'Lancar app terus pada peranti ini atau semak APK terkini',
                onTap: () {
                  Navigator.pop(ctx);
                  launchTeamsApp(context);
                },
              ),
              const SizedBox(height: 8),

              _buildHubActionTile(
                icon: HugeIcons.strokeRoundedUserAdd01,
                iconColor: const Color(0xFFA78BFA),
                title: 'Urus Akaun Staf & QR Kod Jemputan',
                subtitle: 'Daftar staf, pautkan emel, atau jana QR imbasan pantas',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/staff-management');
                },
              ),
              const SizedBox(height: 8),

              _buildHubActionTile(
                icon: HugeIcons.strokeRoundedCoins01,
                iconColor: const Color(0xFF34D399),
                title: 'Kiraan Komisen & Payroll Pasukan',
                subtitle: 'Pantau jualan staf, komisen perkhidmatan & bayaran gaji',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/payroll');
                },
              ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),

              // Bottom secondary buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedShare01,
                        color: Color(0xFF25D366),
                        size: 16,
                      ),
                      label: const Text(
                        'Salin Jemputan Krew',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        copyStaffInvite(context, businessName: businessName);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedDownload04,
                        color: Colors.white70,
                        size: 16,
                      ),
                      label: const Text(
                        'Muat Turun APK',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        openDownloadReleases(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildHubActionTile({
    required dynamic icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: HugeIcon(icon: icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
