import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// SubscriptionPlansPage — Plan Details, Comparison & Upgrading
// ============================================================

enum SubscriptionTier {
  starter,
  pro,
  enterprise,
}

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  SubscriptionTier _currentTier = SubscriptionTier.starter;
  bool _isAnnual = false;

  void _confirmPlanChange(SubscriptionTier newTier) {
    if (newTier == _currentTier) {
      showGlassToast(context, 'This is already your active plan.');
      return;
    }

    final isUpgrade = newTier.index > _currentTier.index;
    final planName = _getPlanName(newTier);
    final price = _isAnnual ? _getAnnualMonthlyPrice(newTier) : _getMonthlyPrice(newTier);
    final totalBilled = _isAnnual ? (newTier == SubscriptionTier.pro ? 'RM 468.00 / year' : 'RM 1,236.00 / year') : '$price / month';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String paymentMethod = 'fpx';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const HugeIcon(icon: HugeIcons.strokeRoundedDiamond, color: Color(0xFF42A5F5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUpgrade ? 'Upgrade to $planName' : 'Switch to $planName',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _isAnnual ? 'Billed annually ($totalBilled)' : 'Billed monthly ($totalBilled)',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Payment Method selector
                    const Text('Select Payment Method', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildPaymentOption(
                      id: 'fpx',
                      title: 'FPX Online Banking',
                      subtitle: 'Maybank2u, CIMB Clicks, Bank Islam, RHB, etc.',
                      icon: HugeIcons.strokeRoundedBuilding03,
                      selected: paymentMethod == 'fpx',
                      onTap: () => setModalState(() => paymentMethod = 'fpx'),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      id: 'duitnow',
                      title: 'DuitNow QR / E-Wallets',
                      subtitle: 'Touch n Go, GrabPay, ShopeePay, MAE',
                      icon: HugeIcons.strokeRoundedQrCode,
                      selected: paymentMethod == 'duitnow',
                      onTap: () => setModalState(() => paymentMethod = 'duitnow'),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      id: 'card',
                      title: 'Credit / Debit Card',
                      subtitle: 'Visa & MasterCard auto-debit',
                      icon: HugeIcons.strokeRoundedCreditCard,
                      selected: paymentMethod == 'card',
                      onTap: () => setModalState(() => paymentMethod = 'card'),
                    ),
                    const SizedBox(height: 24),

                    // Confirm Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentTier = newTier;
                          });
                          Navigator.pop(ctx);
                          showGlassToast(
                            context,
                            isUpgrade
                                ? 'Congratulations! You are now subscribed to $planName!'
                                : 'Switched to $planName successfully.',
                            customColor: const Color(0xFF44CF6C),
                          );
                        },
                        child: Text(
                          isUpgrade ? 'Confirm & Upgrade Now' : 'Confirm Plan Switch',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Cancel or change your subscription anytime with zero penalty.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required List<List<dynamic>> icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF42A5F5).withValues(alpha: 0.12) : const Color(0xFF0F0F1B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF42A5F5) : Colors.white12),
        ),
        child: Row(
          children: [
            HugeIcon(icon: icon, color: selected ? const Color(0xFF42A5F5) : Colors.white54, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF42A5F5) : Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  String _getPlanName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.starter:
        return 'Ngam Starter (Free)';
      case SubscriptionTier.pro:
        return 'Ngam Pro';
      case SubscriptionTier.enterprise:
        return 'Ngam Enterprise';
    }
  }

  String _getMonthlyPrice(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.starter:
        return 'RM 0';
      case SubscriptionTier.pro:
        return 'RM 49';
      case SubscriptionTier.enterprise:
        return 'RM 129';
    }
  }

  String _getAnnualMonthlyPrice(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.starter:
        return 'RM 0';
      case SubscriptionTier.pro:
        return 'RM 39'; // Save 20%
      case SubscriptionTier.enterprise:
        return 'RM 103'; // Save 20%
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription & Plans',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Manage your tier & unlock business capabilities',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Overview Hero Card
            _buildCurrentPlanHero(),
            const SizedBox(height: 28),

            // Billing Cycle Toggle (Monthly vs Annual)
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF141424),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isAnnual = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isAnnual ? const Color(0xFF42A5F5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Monthly Billing',
                          style: TextStyle(
                            color: !_isAnnual ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isAnnual = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isAnnual ? const Color(0xFF42A5F5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Annual Billing',
                              style: TextStyle(
                                color: _isAnnual ? Colors.white : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF44CF6C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SAVE 20%',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3 Subscription Cards
            _buildPlanCard(
              tier: SubscriptionTier.starter,
              badge: 'FREE FOREVER',
              badgeColor: Colors.white54,
              price: 'RM 0',
              billingNote: 'Free starter tier',
              tagline: 'Ideal for small stalls, kiosks & solo hawkers',
              features: [
                '1 POS Terminal & Register',
                'Up to 50 Menu Items',
                'Standard DuitNow QR Generator',
                'Basic Sales Overview',
                '2 Staff Login Accounts',
                'Standard Thermal Receipt Printing',
              ],
              lockedFeatures: [
                'Kitchen Display System (KDS)',
                'Automated Z-Report & Cash Drawer Shift Logs',
                'Custom QR Standee Colors & PDF',
                'Multi-Outlet & Branch Aggregator',
              ],
            ),
            const SizedBox(height: 18),

            _buildPlanCard(
              tier: SubscriptionTier.pro,
              badge: 'MOST POPULAR • RECOMMENDED',
              badgeColor: const Color(0xFF42A5F5),
              price: _isAnnual ? 'RM 39' : 'RM 49',
              billingNote: _isAnnual ? '/ month (Billed RM 468 / year)' : '/ month',
              tagline: 'For fast-growing cafes, restaurants & retail shops',
              isHighlighted: true,
              features: [
                'Unlimited Menu Items & Categories',
                'Kitchen Display System (KDS) Integration',
                'Full Cash Drawer Audits & Shift Z-Reports',
                'Custom QR Standee Branding & Color Picker',
                'Thermal Printer Bluetooth/LAN Integration',
                'Hourly Sales Analytics & Peak Heatmap',
                'Unlimited Staff Accounts with Role PINs',
                'Priority Cloud Data Sync',
              ],
              lockedFeatures: [
                'Multi-Outlet & Branch Aggregator',
                'Automated WhatsApp Marketing Blasts',
              ],
            ),
            const SizedBox(height: 18),

            _buildPlanCard(
              tier: SubscriptionTier.enterprise,
              badge: 'MULTI-OUTLET & CHAIN',
              badgeColor: const Color(0xFFAB47BC),
              price: _isAnnual ? 'RM 103' : 'RM 129',
              billingNote: _isAnnual ? '/ month (Billed RM 1,236 / year)' : '/ month',
              tagline: 'For franchises, multi-branch outlets & food courts',
              features: [
                'Everything in Ngam Pro included',
                'Multi-Branch Consolidated Dashboard',
                'Centralized Warehouse & Stock Transfers',
                'Automated Customer WhatsApp/SMS Marketing',
                '0% Platform Fee on Customer App Orders',
                'Dedicated 24/7 Account Manager & WhatsApp VIP',
                'Custom Data Export API (Excel/Accounting)',
              ],
              lockedFeatures: [],
            ),
            const SizedBox(height: 32),

            // FAQ Accordion Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFaqTile(
              question: 'Can I cancel or switch my plan anytime?',
              answer: 'Yes! There are no lock-in contracts. You can upgrade, downgrade, or cancel your subscription at any moment directly from this page.',
            ),
            const SizedBox(height: 8),
            _buildFaqTile(
              question: 'What happens to my transaction data if I change plans?',
              answer: 'All your past orders, customer records, and financial receipts are permanently stored and safe. You will never lose historical data.',
            ),
            const SizedBox(height: 8),
            _buildFaqTile(
              question: 'What payment methods are supported for subscriptions?',
              answer: 'We support FPX online banking (all Malaysian banks), DuitNow QR, e-wallets, and Visa / MasterCard debit and credit cards.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF42A5F5).withValues(alpha: 0.18),
            const Color(0xFF141424),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(icon: HugeIcons.strokeRoundedDiamond, color: Color(0xFF42A5F5), size: 22),
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
                            _getPlanName(_currentTier),
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF44CF6C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('ACTIVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentTier == SubscriptionTier.starter ? 'Free Plan • Zero monthly charges' : 'Active billing • Renews automatically',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: Colors.white12),

          // Quota & Resource Usage
          const Text('Plan Quota & Resource Usage:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildUsageBar('Menu Items', 15, _currentTier == SubscriptionTier.starter ? 50 : 999, '15 / 50 items'),
          const SizedBox(height: 8),
          _buildUsageBar('Staff Logins', 2, _currentTier == SubscriptionTier.starter ? 2 : 999, '2 / 2 accounts'),
          const SizedBox(height: 8),
          _buildUsageBar('Monthly Orders', 480, _currentTier == SubscriptionTier.starter ? 1000 : 9999, '480 / 1,000 orders'),
        ],
      ),
    );
  }

  Widget _buildUsageBar(String label, int used, int limit, String display) {
    final double fraction = limit >= 999 ? 0.2 : (used / limit).clamp(0.0, 1.0);
    final isFull = fraction >= 1.0 && limit < 999;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              limit >= 999 ? '$used (Unlimited)' : display,
              style: TextStyle(color: isFull ? const Color(0xFFEF4444) : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(isFull ? const Color(0xFFEF4444) : const Color(0xFF42A5F5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required SubscriptionTier tier,
    required String badge,
    required Color badgeColor,
    required String price,
    required String billingNote,
    required String tagline,
    required List<String> features,
    required List<String> lockedFeatures,
    bool isHighlighted = false,
  }) {
    final isCurrent = _currentTier == tier;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF42A5F5)
              : (isCurrent ? const Color(0xFF44CF6C).withValues(alpha: 0.6) : Colors.white12),
          width: isHighlighted ? 1.8 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [BoxShadow(color: const Color(0xFF42A5F5).withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2)]
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF44CF6C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: Colors.black),
                      SizedBox(width: 4),
                      Text('CURRENT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Price row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              Text(
                billingNote,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tagline,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const Divider(height: 28, color: Colors.white12),

          // Included features
          ...features.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF44CF6C), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(feat, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              )),

          // Locked features
          ...lockedFeatures.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.remove_circle_outline_rounded, color: Colors.white.withValues(alpha: 0.25), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feat,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13, decoration: TextDecoration.lineThrough),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent
                    ? Colors.white.withValues(alpha: 0.08)
                    : (isHighlighted ? const Color(0xFF42A5F5) : const Color(0xFF1B1B2C)),
                foregroundColor: isCurrent ? Colors.white54 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isCurrent ? BorderSide.none : BorderSide(color: isHighlighted ? Colors.transparent : Colors.white24),
                ),
              ),
              onPressed: isCurrent ? null : () => _confirmPlanChange(tier),
              child: Text(
                isCurrent
                    ? 'Current Active Plan'
                    : (tier.index > _currentTier.index ? 'Upgrade to ${_getPlanName(tier)}' : 'Switch to ${_getPlanName(tier)}'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        iconColor: const Color(0xFF42A5F5),
        collapsedIconColor: Colors.white54,
        title: Text(
          question,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
