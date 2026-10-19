import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/audit_service.dart';
import '../../../widgets/glass_toast.dart';

class MfaSetupPage extends StatefulWidget {
  const MfaSetupPage({super.key});

  @override
  State<MfaSetupPage> createState() => _MfaSetupPageState();
}

class _MfaSetupPageState extends State<MfaSetupPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _verifying = false;
  bool _isMfaEnabled = false;

  String? _factorId;
  String? _qrUri;
  String? _secretKey;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    try {
      final factors = await _client.auth.mfa.listFactors();
      final verifiedTotp = factors.totp.where((f) => f.status == FactorStatus.verified).toList();

      if (verifiedTotp.isNotEmpty) {
        setState(() {
          _isMfaEnabled = true;
          _factorId = verifiedTotp.first.id;
          _loading = false;
        });
      } else {
        await _initEnrollment();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Ralat menyemak status MFA: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _initEnrollment() async {
    try {
      final res = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Ngam Business',
      );
      setState(() {
        _isMfaEnabled = false;
        _factorId = res.id;
        _qrUri = res.totp?.uri;
        _secretKey = res.totp?.secret;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memulakan persediaan 2FA: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyAndActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      showGlassToast(context, 'Sila masukkan 6 digit kod keselamatan yang sah.', isError: true);
      return;
    }

    if (_factorId == null) return;

    setState(() => _verifying = true);
    try {
      await _client.auth.mfa.challengeAndVerify(
        factorId: _factorId!,
        code: code,
      );

      await AuditService.log(
        action: 'MFA_ENABLED',
        severity: 'critical',
        targetType: 'auth',
        targetId: _factorId,
        description: 'Pemilik akaun mengaktifkan Two-Factor Authentication (TOTP)',
      );

      if (mounted) {
        showGlassToast(context, 'Tahniah! Two-Factor Authentication (2FA) berjaya diaktifkan.');
        _codeController.clear();
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Kod pengesahan tidak tepat. Sila cuba lagi.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _confirmDisableMfa() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Matikan 2FA?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Mematikan Two-Factor Authentication akan mengurangkan tahap perlindungan akaun anda. Adakah anda pasti?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Matikan 2FA'),
          ),
        ],
      ),
    );

    if (confirm != true || _factorId == null) return;

    setState(() => _loading = true);
    try {
      await _client.auth.mfa.unenroll(_factorId!);

      await AuditService.log(
        action: 'MFA_DISABLED',
        severity: 'warning',
        targetType: 'auth',
        targetId: _factorId,
        description: 'Pemilik akaun mematikan Two-Factor Authentication (TOTP)',
      );

      if (mounted) {
        showGlassToast(context, 'Two-Factor Authentication telah dimatikan.');
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal mematikan 2FA: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Two-Factor Authentication (2FA)',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: _isMfaEnabled ? _buildEnabledView() : _buildSetupView(),
                ),
              ),
            ),
    );
  }

  Widget _buildEnabledView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF44CF6C).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF44CF6C).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedShield02,
              color: Color(0xFF44CF6C),
              size: 48,
              strokeWidth: 2.2,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Akaun Anda Dilindungi 2FA',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Two-Factor Authentication (TOTP) aktif. Log masuk memerlukan kod masa nyata dari aplikasi pengesah anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF44CF6C), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kaedah: Google Authenticator / TOTP App',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF44CF6C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AKTIF',
                    style: TextStyle(color: Color(0xFF44CF6C), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _confirmDisableMfa,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Matikan 2FA (Nyahaktifkan)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intro Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF42A5F5).withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedShield01,
                  color: Color(0xFF42A5F5),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tingkatkan Keselamatan Kedai',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lindungi pesanan, data jualan dan tetapan kedai daripada diceroboh menggunakan kod masa nyata (TOTP).',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Step 1: Scan QR Code
        _buildStepHeader(
          stepNumber: '1',
          title: 'Imbas Kod QR dengan Aplikasi Pengesah',
          subtitle: 'Gunakan Google Authenticator, Microsoft Authenticator, atau Apple Passwords.',
        ),
        const SizedBox(height: 14),
        if (_qrUri != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: _qrUri!,
                version: QrVersions.auto,
                size: 190.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 24),

        // Step 2: Or enter key manually
        _buildStepHeader(
          stepNumber: '2',
          title: 'Atau Masukkan Kunci Rahsia Secara Manual',
          subtitle: 'Jika kamera peranti tidak dapat mengimbas, salin kunci ini ke dalam aplikasi anda.',
        ),
        const SizedBox(height: 10),
        if (_secretKey != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _secretKey!,
                    style: const TextStyle(
                      color: Color(0xFFF9C80E),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Salin Kunci Rahsia',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _secretKey!));
                    showGlassToast(context, 'Kunci rahsia 2FA telah disalin!');
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),

        // Step 3: Enter 6 digit code
        _buildStepHeader(
          stepNumber: '3',
          title: 'Masukkan 6-Digit Kod Pengesahan',
          subtitle: 'Masukkan kod 6 digit yang dipaparkan dalam aplikasi authenticator anda.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Step 4: Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _verifying ? null : _verifyAndActivate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _verifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sahkan & Aktifkan 2FA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStepHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.5)),
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
