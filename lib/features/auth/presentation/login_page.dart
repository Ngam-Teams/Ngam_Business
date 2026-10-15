import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../data/auth_service.dart';

// =============================================================================
// Ngam Business — Unified Auth Portal (Static Left Branding + Dynamic Right Card)
// Exactly matching Ngam design, formatting, and spacing ("sebijik-sebijik")
// Single OAuth: Continue with Google
// =============================================================================

enum AuthScreenMode { login, register, forgotPassword }

class LoginPage extends StatefulWidget {
  final AuthScreenMode initialMode;
  const LoginPage({super.key, this.initialMode = AuthScreenMode.login});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AuthScreenMode _currentMode;

  // Login controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Register controllers
  final _regFormKey = GlobalKey<FormState>();
  final _regBusinessNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _regObscurePassword = true;
  bool _regSuccess = false;

  // Forgot Password controllers
  final _forgotFormKey = GlobalKey<FormState>();
  final _forgotEmailController = TextEditingController();
  bool _forgotEmailSent = false;

  // General state
  bool _loading = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Signature Ngam Palette
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentBlueGlow = Color(0xFF42A5F5);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color bgDark = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regBusinessNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _forgotEmailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _switchMode(AuthScreenMode mode) {
    setState(() {
      _currentMode = mode;
      _error = null;
    });
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService().signUp(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        businessName: _regBusinessNameController.text.trim(),
      );

      if (mounted) {
        if (AuthService().currentUser == null) {
          setState(() {
            _loading = false;
            _regSuccess = true;
          });
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (!_forgotFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService().resetPassword(_forgotEmailController.text.trim());
      if (mounted) {
        setState(() {
          _loading = false;
          _forgotEmailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().signInWithGoogle();
      if (mounted && AuthService().currentUser != null) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bgDark,
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // ─── 1. Cinematic Background Image ───
              Positioned.fill(
                child: Image.asset(
                  'assets/admin_hero_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF080808),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99000000),
                        Color(0xB3000000),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── 2. Main Portal Fixed Layout ───
              Positioned.fill(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: isDesktop
                        ? _buildDesktopLayout(context)
                        : _buildMobileLayout(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT (Static Left Branding Banner + Dynamic Right Auth Card)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left Branding Section (Permanently Static & Fixed)
        Expanded(
          flex: 12,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Logo Group
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circular Silver Logo Badge
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Ngam',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'NGAM BUSINESS',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8.0,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Satu platform perniagaan pintar untuk pengurusan pesanan,\ninventori, sistem POS dan analitik jualan tanpa had.',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.6,
                            color: textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),

                    // Bottom Branding Footer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '© 2026 Ngam Business System\nSmart Merchant & POS Platform',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.6,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.4),
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

        // Right Auth Section (Switches between Login, Register, Forgot Password)
        Expanded(
          flex: 11,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _buildRightSideCard(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini Logo Badge (Static at top)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Ngam',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'NGAM BUSINESS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Card Switcher
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _buildRightSideCard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ROUTE CARD SELECTOR
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRightSideCard(BuildContext context) {
    switch (_currentMode) {
      case AuthScreenMode.register:
        return _buildRegisterCard(context);
      case AuthScreenMode.forgotPassword:
        return _buildForgotPasswordCard(context);
      case AuthScreenMode.login:
        return _buildLoginCard(context);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. THE LOGIN CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLoginCard(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('login_card'),
      child: _buildCardShell(
        child: Form(
          key: _loginFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MERCHANT LOGIN',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Access your business dashboard and manage store orders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Email Address
              Text(
                'EMAIL ADDRESS',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hintText: 'admin@business.com',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Sila masukkan emel';
                  if (!value.contains('@')) return 'Emel tidak sah';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PASSWORD',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _switchMode(AuthScreenMode.forgotPassword),
                    child: Text(
                      'Forgot?',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentBlueGlow,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                decoration: _inputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  obscure: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Sila masukkan kata laluan' : null,
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF5252),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Sign In Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: accentBlue.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'SIGN IN',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Divider
              _buildDivider(),
              const SizedBox(height: 12),

              // Continue with Google Button (Single full-width button)
              _buildGoogleButton(),
              const SizedBox(height: 18),

              // Footer: Switch to Register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => _switchMode(AuthScreenMode.register),
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. THE REGISTER CARD (3 Clean Fields: Business Name, Email, Password)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRegisterCard(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('register_card'),
      child: _buildCardShell(
        child: _regSuccess
            ? _buildRegisterSuccessView()
            : Form(
                key: _regFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CREATE BUSINESS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join Ngam Business and start managing your store.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Field 1: Business Name
                    Text(
                      'BUSINESS NAME',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regBusinessNameController,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hintText: 'e.g. My Awesome Shop',
                        prefixIcon: Icons.storefront_outlined,
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Sila masukkan nama perniagaan' : null,
                    ),
                    const SizedBox(height: 14),

                    // Field 2: Business Email Address
                    Text(
                      'EMAIL ADDRESS',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regEmailController,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        hintText: 'admin@business.com',
                        prefixIcon: Icons.email_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Sila masukkan emel';
                        if (!val.contains('@')) return 'Emel tidak sah';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field 3: Password
                    Text(
                      'PASSWORD',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regPasswordController,
                      obscureText: _regObscurePassword,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                      decoration: _inputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        obscure: _regObscurePassword,
                        onToggle: () => setState(() => _regObscurePassword = !_regObscurePassword),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Sila masukkan kata laluan';
                        if (val.length < 6) return 'Kata laluan sekurang-kurangnya 6 aksara';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF5252),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Submit Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: accentBlue.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'CREATE ACCOUNT',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildDivider(),
                    const SizedBox(height: 12),

                    // Google Button ONLY (Single full-width button)
                    _buildGoogleButton(),
                    const SizedBox(height: 18),

                    // Footer: Switch to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(AuthScreenMode.login),
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: accentBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRegisterSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF44CF6C).withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Color(0xFF44CF6C),
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Account Created!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your business account has been registered. Please check ${_regEmailController.text.trim()} to verify your email.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              _switchMode(AuthScreenMode.login);
              setState(() => _regSuccess = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'PROCEED TO SIGN IN',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. THE FORGOT PASSWORD CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildForgotPasswordCard(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('forgot_card'),
      child: _buildCardShell(
        child: _forgotEmailSent ? _buildForgotSuccessView() : _buildForgotFormView(),
      ),
    );
  }

  Widget _buildForgotFormView() {
    return Form(
      key: _forgotFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBlue.withValues(alpha: 0.12),
                border: Border.all(color: accentBlue.withValues(alpha: 0.35)),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLockPassword,
                  color: accentBlue,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'RESET PASSWORD',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Masukkan alamat emel untuk menerima pautan penetapan semula kata laluan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Email Input
          Text(
            'EMAIL ADDRESS',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _forgotEmailController,
            style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              hintText: 'admin@business.com',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Sila masukkan emel';
              if (!val.contains('@')) return 'Emel tidak sah';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Error Message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF5252),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Submit Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleForgotPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'SEND RESET LINK',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // Back to Login Link
          Center(
            child: GestureDetector(
              onTap: () => _switchMode(AuthScreenMode.login),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, size: 14, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Back to Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF44CF6C).withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Color(0xFF44CF6C),
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pautan Telah Dihantar!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sila semak peti masuk emel ${_forgotEmailController.text.trim()} untuk arahan penetapan semula kata laluan anda.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              _switchMode(AuthScreenMode.login);
              setState(() => _forgotEmailSent = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'BACK TO SIGN IN',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD SHELL & REUSABLE DECORATIONS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCardShell({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 70,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textSecondary, size: 18)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: textSecondary,
                size: 18,
              ),
              onPressed: onToggle,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentBlue, width: 1.5),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or',
            style: GoogleFonts.inter(
              color: textSecondary.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: _loading ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/google_logo.png',
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
