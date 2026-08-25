import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/glass_toast.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _client = Supabase.instance.client;
  bool _signingOut = false;

  String get _userEmail =>
      _client.auth.currentUser?.email ?? 'Unknown';

  String get _userId =>
      _client.auth.currentUser?.id.substring(0, 8) ?? '—';

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _client.auth.signOut();
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Sign out failed.', isError: true);
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            _buildPanel(
              title: 'Account',
              icon: HugeIcons.strokeRoundedUser,
              child: Column(
                children: [
                  _buildInfoRow(
                    label: 'Email',
                    value: _userEmail,
                    icon: HugeIcons.strokeRoundedMail01,
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildInfoRow(
                    label: 'User ID',
                    value: '$_userId...',
                    icon: HugeIcons.strokeRoundedIdentification,
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildInfoRow(
                    label: 'Role',
                    value: 'Tenant Admin',
                    icon: HugeIcons.strokeRoundedShield01,
                    valueColor: const Color(0xFF42A5F5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Business settings
            _buildPanel(
              title: 'Business',
              icon: HugeIcons.strokeRoundedBuilding03,
              child: Column(
                children: [
                  _buildNavRow(
                    label: 'Business Profile',
                    icon: HugeIcons.strokeRoundedNote01,
                    onTap: () => context.push('/business-profile'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Staff Management',
                    icon: HugeIcons.strokeRoundedUserGroup,
                    onTap: () => context.push('/staff-management'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Items & Services',
                    icon: HugeIcons.strokeRoundedGridView,
                    onTap: () => context.push('/product-catalogue'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Subscription tier
            _buildPanel(
              title: 'Subscription',
              icon: HugeIcons.strokeRoundedDiamond,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      'Free Plan',
                      style: TextStyle(
                        color: Color(0xFF42A5F5),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => showGlassToast(
                      context,
                      'Upgrade feature coming soon',
                      customColor: const Color(0xFF42A5F5),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF42A5F5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App info
            _buildPanel(
              title: 'App',
              icon: HugeIcons.strokeRoundedInformationCircle,
              child: Column(
                children: [
                  _buildInfoRow(
                    label: 'Version',
                    value: '1.0.0',
                    icon: HugeIcons.strokeRoundedCode,
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildInfoRow(
                    label: 'Platform',
                    value: 'Ngam Business',
                    icon: HugeIcons.strokeRoundedBuilding03,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sign out button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _signingOut ? null : _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                  foregroundColor: Colors.redAccent,
                  disabledBackgroundColor:
                      Colors.redAccent.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _signingOut
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedLogout02,
                            color: Colors.redAccent,
                            size: 18,
                            strokeWidth: 2.1,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required dynamic icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          color: Colors.white38,
          size: 18,
          strokeWidth: 2.1,
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNavRow({
    required String label,
    required dynamic icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: Colors.white38,
            size: 18,
            strokeWidth: 2.1,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: Colors.white.withValues(alpha: 0.3),
            size: 18,
            strokeWidth: 2.1,
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required dynamic icon,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: icon,
                      color: const Color(0xFF42A5F5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
