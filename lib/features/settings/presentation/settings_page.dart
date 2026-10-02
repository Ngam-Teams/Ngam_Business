import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/glass_toast.dart';
import '../data/business_service.dart';
import '../../../core/services/app_update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _client = Supabase.instance.client;
  final _businessService = BusinessService();
  bool _signingOut = false;
  bool _loadingBusiness = true;
  Map<String, dynamic>? _businessProfile;

  String get _userEmail =>
      _client.auth.currentUser?.email ?? 'Unknown';

  String get _userId =>
      _client.auth.currentUser?.id.substring(0, 8) ?? '—';

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    setState(() => _loadingBusiness = true);
    final profile = await _businessService.getBusinessProfile();
    if (mounted) {
      setState(() {
        _businessProfile = profile;
        _loadingBusiness = false;
      });
    }
  }

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

  String _formatIndustry(String? industry) {
    switch (industry?.toLowerCase()) {
      case 'fnb':
        return 'Food & Beverage';
      case 'barber':
        return 'Barber & Salon';
      case 'retail':
        return 'Retail & Shopping';
      case 'services':
      default:
        return 'Services & Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = _businessProfile?['business_name'] ?? 'Add Your Business Details';
    final industry = _formatIndustry(_businessProfile?['business_industry']);
    final city = _businessProfile?['business_city'] ?? '';
    final state = _businessProfile?['state'] ?? '';
    final logoUrl = _businessProfile?['business_logo_url'] as String?;
    final coverUrl = _businessProfile?['business_cover_url'] as String?;
    final hasLocation = _businessProfile?['latitude'] != null && _businessProfile?['longitude'] != null;

    final locationText = [city, state].where((s) => s.isNotEmpty).join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Profile Highlight Card (Twitter banner style with centered logo & Ngam design)
            _buildProfileHeroCard(
              businessName: businessName,
              industry: industry,
              locationText: locationText,
              hasLocation: hasLocation,
              logoUrl: logoUrl,
              coverUrl: coverUrl,
            ),

            const SizedBox(height: 24),

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
              title: 'Business Management',
              icon: HugeIcons.strokeRoundedBuilding03,
              child: Column(
                children: [
                  _buildNavRow(
                    label: 'Business Profile & Details',
                    icon: HugeIcons.strokeRoundedNote01,
                    onTap: () async {
                      await context.push('/business-profile');
                      _loadBusiness();
                    },
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
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Operating Hours & Rush Mode',
                    icon: HugeIcons.strokeRoundedTime02,
                    onTap: () => context.push('/operating-hours'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Inventory & Stock Alerts',
                    icon: HugeIcons.strokeRoundedPackageDelivered,
                    onTap: () => context.push('/inventory'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Promotions & Vouchers',
                    icon: HugeIcons.strokeRoundedDiscountTag02,
                    onTap: () => context.push('/promotions'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Customer Reviews',
                    icon: HugeIcons.strokeRoundedStar,
                    onTap: () => context.push('/customer-reviews'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Customer Insights & VIPs',
                    icon: HugeIcons.strokeRoundedUserGroup,
                    onTap: () => context.push('/customers'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Payouts & Bank Settlement',
                    icon: HugeIcons.strokeRoundedMoneySend02,
                    onTap: () => context.push('/payouts'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Kitchen Display System (KDS)',
                    icon: HugeIcons.strokeRoundedRestaurant01,
                    onTap: () => context.push('/kds'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Customer Messaging Inbox',
                    icon: HugeIcons.strokeRoundedChatting01,
                    onTap: () => context.push('/merchant-inbox'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'QR & Standee Generator',
                    icon: HugeIcons.strokeRoundedQrCode,
                    onTap: () => context.push('/qr-generator'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Cash Drawer & Z-Report',
                    icon: HugeIcons.strokeRoundedMoney01,
                    onTap: () => context.push('/cash-drawer'),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildNavRow(
                    label: 'Receipts & Thermal Printer',
                    icon: HugeIcons.strokeRoundedPrinter,
                    onTap: () => context.push('/receipt-settings'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Subscription Tier & Plan Card (Perkemas & premium modern card)
            _buildSubscriptionCard(),

            const SizedBox(height: 24),

            // App info
            _buildPanel(
              title: 'App',
              icon: HugeIcons.strokeRoundedInformationCircle,
              child: Column(
                children: [
                  InkWell(
                    onTap: () => AppUpdateService.checkManually(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              label: 'Version',
                              value: 'v${AppUpdateService.currentVersion}',
                              icon: HugeIcons.strokeRoundedCode,
                              valueColor: const Color(0xFF44CF6C),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Semak Kemas Kini',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF44CF6C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24, color: Color(0x1AFFFFFF)),
                  _buildInfoRow(
                    label: 'Build',
                    value: 'Oct 1 (Clean Rebuild)',
                    icon: HugeIcons.strokeRoundedCalendar03,
                    valueColor: const Color(0xFF42A5F5),
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

  Widget _buildProfileHeroCard({
    required String businessName,
    required String industry,
    required String locationText,
    required bool hasLocation,
    required String? logoUrl,
    required String? coverUrl,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await context.push('/business-profile');
          _loadBusiness();
        },
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.transparent,
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131422),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                // Banner & Centered Avatar Stack (Twitter cover style with centered logo)
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Top Banner / Cover Image
                    Container(
                      height: 120,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 42),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1E2640),
                            Color(0xFF0F1424),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        image: (coverUrl != null && coverUrl.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(coverUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Contrast overlay gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.65),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Top Right Edit Profile badge
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedEdit02,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Centered Circular Avatar (cutout border overlapping banner, middle aligned)
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131422),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF131422),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A28),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF42A5F5).withValues(alpha: 0.7),
                              width: 1.8,
                            ),
                            image: (logoUrl != null && logoUrl.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(logoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (logoUrl == null || logoUrl.isEmpty)
                              ? const Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedStore01,
                                    color: Color(0xFF42A5F5),
                                    size: 34,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),

                // Business Details below centered avatar (Ngam profile style)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    children: [
                      // Store Name
                      Text(
                        _loadingBusiness ? 'Loading...' : businessName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Industry Category Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          industry.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Location & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedLocation01,
                            color: hasLocation || locationText.isNotEmpty
                                ? Colors.white60
                                : const Color(0xFFF9C80E),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              locationText.isNotEmpty
                                  ? locationText
                                  : (hasLocation ? 'Location Pinned' : 'Location Not Set — Tap to setup'),
                              style: TextStyle(
                                color: hasLocation || locationText.isNotEmpty
                                    ? Colors.white70
                                    : const Color(0xFFF9C80E),
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final tierRaw = (_businessProfile?['business_subscription_tier'] as String?)?.toLowerCase() ?? 'free';
    final isPro = tierRaw == 'pro';
    final isEnterprise = tierRaw == 'enterprise';

    final planTitle = isEnterprise
        ? 'Enterprise Multi-Outlet'
        : (isPro ? 'Ngam Pro' : 'Free Starter');
    final planPrice = isEnterprise
        ? 'RM 129 / mo'
        : (isPro ? 'RM 49 / mo' : 'RM 0.00 / month');
    final planStatus = isEnterprise || isPro ? 'ACTIVE' : 'FREE TIER';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/subscription-plans'),
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.transparent,
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1A1A32),
                  Color(0xFF101020),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFF42A5F5)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedDiamond,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        planTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF44CF6C).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF44CF6C).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        planStatus,
                                        style: const TextStyle(
                                          color: Color(0xFF44CF6C),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  planPrice,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF6C5CE7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Upgrade',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFeaturePill('1 POS Register'),
                          _buildFeaturePill('50 Menu Items'),
                          _buildFeaturePill('2 Staff Logins'),
                          _buildFeaturePill('DuitNow QR Pay'),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    border: const Border(
                      top: BorderSide(color: Color(0x18FFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View all plans, KDS, & feature comparison',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFF42A5F5), size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required String label,
    required dynamic icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: Colors.white60,
                size: 20,
                strokeWidth: 2.1,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Colors.white.withValues(alpha: 0.4),
                size: 18,
                strokeWidth: 2.1,
              ),
            ],
          ),
        ),
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
