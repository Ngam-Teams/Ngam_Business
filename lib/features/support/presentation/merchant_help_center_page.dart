import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_update_service.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';
import '../data/merchant_support_service.dart';

class MerchantHelpCenterPage extends StatefulWidget {
  final int initialTab; // 0 = FAQ, 1 = Report Bug/Feedback, 2 = My Tickets

  const MerchantHelpCenterPage({super.key, this.initialTab = 0});

  @override
  State<MerchantHelpCenterPage> createState() => _MerchantHelpCenterPageState();
}

class _MerchantHelpCenterPageState extends State<MerchantHelpCenterPage> {
  final MerchantSupportService _supportService = MerchantSupportService();
  final TextEditingController _searchCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late int _activeTab;
  String _selectedFaqCat = 'all';
  String _searchQuery = '';
  int? _expandedFaqIdx;

  // Report Form State
  String _selectedCategory = 'bug';
  String _selectedPriority = 'normal';
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final List<XFile> _pickedFiles = [];
  final Map<String, Uint8List> _previewBytes = {};
  bool _submitting = false;
  String? _submittedCode;

  static const _faqCategories = ['all', 'pos_kds', 'hardware', 'orders_booking', 'payouts', 'account'];

  static const List<({String id, String key, dynamic icon, Color color})> _ticketCategories = [
    (id: 'bug', key: 'merchant_help.t_cat_bug', icon: HugeIcons.strokeRoundedAlert02, color: Color(0xFFEF4444)),
    (id: 'hardware', key: 'merchant_help.t_cat_hardware', icon: HugeIcons.strokeRoundedPrinter, color: Color(0xFFF59E0B)),
    (id: 'order_issue', key: 'merchant_help.t_cat_order_issue', icon: HugeIcons.strokeRoundedShoppingCart02, color: Color(0xFF42A5F5)),
    (id: 'payment', key: 'merchant_help.t_cat_payment', icon: HugeIcons.strokeRoundedCreditCard, color: Color(0xFF10B981)),
    (id: 'feature', key: 'merchant_help.t_cat_feature', icon: HugeIcons.strokeRoundedIdea01, color: Color(0xFF8B5CF6)),
    (id: 'other', key: 'merchant_help.t_cat_other', icon: HugeIcons.strokeRoundedHelpCircle, color: Color(0xFF94A3B8)),
  ];

  static const List<({String id, String key, Color color})> _priorities = [
    (id: 'low', key: 'merchant_help.prio_low', color: Color(0xFF64748B)),
    (id: 'normal', key: 'merchant_help.prio_normal', color: Color(0xFF42A5F5)),
    (id: 'high', key: 'merchant_help.prio_high', color: Color(0xFFF59E0B)),
    (id: 'urgent', key: 'merchant_help.prio_urgent', color: Color(0xFFEF4444)),
  ];

  List<({String q, String a, String cat, dynamic icon})> get _faqs => [
    (q: 'merchant_help.faq_1_q'.tr(), a: 'merchant_help.faq_1_a'.tr(), cat: 'hardware', icon: HugeIcons.strokeRoundedPrinter),
    (q: 'merchant_help.faq_2_q'.tr(), a: 'merchant_help.faq_2_a'.tr(), cat: 'pos_kds', icon: HugeIcons.strokeRoundedComputerCheck),
    (q: 'merchant_help.faq_3_q'.tr(), a: 'merchant_help.faq_3_a'.tr(), cat: 'pos_kds', icon: HugeIcons.strokeRoundedMoney01),
    (q: 'merchant_help.faq_4_q'.tr(), a: 'merchant_help.faq_4_a'.tr(), cat: 'orders_booking', icon: HugeIcons.strokeRoundedQrCode01),
    (q: 'merchant_help.faq_5_q'.tr(), a: 'merchant_help.faq_5_a'.tr(), cat: 'orders_booking', icon: HugeIcons.strokeRoundedCalendar03),
    (q: 'merchant_help.faq_6_q'.tr(), a: 'merchant_help.faq_6_a'.tr(), cat: 'payouts', icon: HugeIcons.strokeRoundedBank),
    (q: 'merchant_help.faq_7_q'.tr(), a: 'merchant_help.faq_7_a'.tr(), cat: 'account', icon: HugeIcons.strokeRoundedUserGroup),
    (q: 'merchant_help.faq_8_q'.tr(), a: 'merchant_help.faq_8_a'.tr(), cat: 'hardware', icon: HugeIcons.strokeRoundedTv01),
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 2);
    _prefillMerchantContact();
  }

  Future<void> _prefillMerchantContact() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = BusinessService.cachedProfile ??
        await BusinessService().getBusinessProfile(autoCreate: false);
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = (profile?['business_name'] ??
              profile?['name'] ??
              user?.userMetadata?['user_name'] ??
              '')
          .toString()
          .trim();
      _emailCtrl.text = (profile?['email'] ?? user?.email ?? '').toString().trim();
      _phoneCtrl.text = (profile?['phone'] ?? '').toString().trim();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    final text = Uri.encodeComponent('settings.merchant_support_msg'.tr());
    final uri = Uri.parse('https://wa.me/601115892468?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showGlassToast(context, 'orders.cannot_open_whatsapp'.tr(), isError: true);
    }
  }

  Future<void> _pickAttachment() async {
    if (_pickedFiles.length >= 3) {
      showGlassToast(context, 'merchant_help.max_attachments'.tr(), isError: true);
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedFiles.add(picked);
        _previewBytes[picked.path] = bytes;
      });
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'merchant_help.pick_image_error'.tr(), isError: true);
      }
    }
  }

  Future<void> _submitTicket() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final code = await _supportService.submitTicket(
        category: _selectedCategory,
        priority: _selectedPriority,
        subject: _subjectCtrl.text,
        description: _descCtrl.text,
        reporterName: _nameCtrl.text,
        reporterEmail: _emailCtrl.text,
        reporterPhone: _phoneCtrl.text,
        attachments: _pickedFiles,
      );
      if (!mounted) return;
      setState(() {
        _submittedCode = code;
        _subjectCtrl.clear();
        _descCtrl.clear();
        _pickedFiles.clear();
        _previewBytes.clear();
      });
      showGlassToast(context, 'merchant_help.submit_success'.tr(args: [code]));
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'merchant_help.submit_error'.tr(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _openImageViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
              Positioned(
                top: 24,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'merchant_help.title'.tr(),
      subtitle: 'merchant_help.subtitle'.tr(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              const SizedBox(height: 70),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTabSwitcher(),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: switch (_activeTab) {
                  0 => _buildFaqTab(),
                  1 => _buildReportTab(),
                  _ => _buildTicketsTab(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _tabItem(0, 'merchant_help.tab_faq'.tr(), HugeIcons.strokeRoundedHelpCircle),
          _tabItem(1, 'merchant_help.tab_report'.tr(), HugeIcons.strokeRoundedAlert02),
          _tabItem(2, 'merchant_help.tab_tickets'.tr(), HugeIcons.strokeRoundedTicket02),
        ],
      ),
    );
  }

  Widget _tabItem(int idx, String label, dynamic icon) {
    final selected = _activeTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = idx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF42A5F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: 16,
                color: selected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 0: FAQ / PANDUAN PENIAGA
  // ===========================================================================
  Widget _buildFaqTab() {
    final filtered = _faqs.where((f) {
      if (_selectedFaqCat != 'all' && f.cat != _selectedFaqCat) return false;
      if (_searchQuery.isEmpty) return true;
      return f.q.toLowerCase().contains(_searchQuery) ||
          f.a.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 36),
      physics: const BouncingScrollPhysics(),
      children: [
        // Search Input
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF42A5F5), size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _searchQuery = v.trim().toLowerCase();
                    _expandedFaqIdx = null;
                  }),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'merchant_help.search_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                    filled: false,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _expandedFaqIdx = null;
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Category Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _faqCategories.map((cat) {
              final selected = _selectedFaqCat == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedFaqCat = cat;
                    _expandedFaqIdx = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF42A5F5)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFF42A5F5) : Colors.white12,
                      ),
                    ),
                    child: Text(
                      'merchant_help.faq_cat_$cat'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedHelpCircle,
                  color: Color(0xFF42A5F5),
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  'merchant_help.empty_faq_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'merchant_help.empty_faq_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _activeTab = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 17, color: Colors.white),
                  label: Text('merchant_help.open_report_btn'.tr()),
                ),
              ],
            ),
          )
        else
          ...List.generate(filtered.length, (idx) {
            final item = filtered[idx];
            final expanded = _expandedFaqIdx == idx;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: expanded
                    ? const Color(0xFF42A5F5).withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: expanded
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.45)
                      : Colors.white10,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _expandedFaqIdx = expanded ? null : idx),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: expanded
                                  ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: item.icon,
                                size: 16,
                                color: expanded ? const Color(0xFF42A5F5) : Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.q,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: expanded ? const Color(0xFF42A5F5) : Colors.white38,
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Text(
                            item.a,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.8,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: 18),

        // Merchant Support CTA Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCustomerSupport,
                        color: Color(0xFF42A5F5),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'merchant_help.need_more_help'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'merchant_help.need_more_help_desc'.tr(),
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _activeTab = 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.white, size: 17),
                      label: Text(
                        'merchant_help.open_report_btn'.tr(),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchWhatsApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedBubbleChat, color: Color(0xFF25D366), size: 17),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: LAPOR MASALAH & MAKLUM BALAS PENIAGA
  // ===========================================================================
  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 36),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_submittedCode != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'merchant_help.ticket_created_title'.tr(args: [_submittedCode!]),
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'merchant_help.ticket_created_desc'.tr(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _activeTab = 2),
                      child: Text(
                        'merchant_help.view_tickets_btn'.tr(),
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              'merchant_help.category_label'.tr(),
              style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ticketCategories.map((cat) {
                final selected = _selectedCategory == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? cat.color.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? cat.color : Colors.white12,
                        width: selected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(icon: cat.icon, size: 16, color: selected ? cat.color : Colors.white60),
                        const SizedBox(width: 6),
                        Text(
                          cat.key.tr(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text(
              'merchant_help.priority_label'.tr(),
              style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Row(
              children: _priorities.map((p) {
                final selected = _selectedPriority == p.id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: p.id == 'urgent' ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPriority = p.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? p.color.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? p.color : Colors.white12),
                        ),
                        child: Center(
                          child: Text(
                            p.key.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDarkField(
                    controller: _subjectCtrl,
                    label: 'merchant_help.subject_label'.tr(),
                    hint: 'merchant_help.subject_hint'.tr(),
                    validator: (v) => (v == null || v.trim().length < 4)
                        ? 'merchant_help.subject_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _buildDarkField(
                    controller: _descCtrl,
                    label: 'merchant_help.desc_label'.tr(),
                    hint: 'merchant_help.desc_hint'.tr(),
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'merchant_help.desc_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDarkField(
                          controller: _nameCtrl,
                          label: 'merchant_help.name_label'.tr(),
                          hint: 'merchant_help.name_hint'.tr(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'merchant_help.name_required'.tr()
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDarkField(
                          controller: _phoneCtrl,
                          label: 'merchant_help.phone_label'.tr(),
                          hint: '01x-xxxxxxx',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDarkField(
                    controller: _emailCtrl,
                    label: 'merchant_help.email_label'.tr(),
                    hint: 'merchant@kedai.my',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'merchant_help.attachments_label'.tr(),
                        style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${_pickedFiles.length}/3',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ..._pickedFiles.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        final bytes = _previewBytes[file.path];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: bytes != null
                                    ? Image.memory(bytes, fit: BoxFit.cover)
                                    : const Icon(Icons.image_outlined, color: Colors.white54),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _previewBytes.remove(file.path);
                                    _pickedFiles.removeAt(idx);
                                  });
                                },
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      if (_pickedFiles.length < 3)
                        GestureDetector(
                          onTap: _pickAttachment,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.45)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedImage01,
                                  color: Color(0xFF42A5F5),
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'merchant_help.add_photo'.tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF42A5F5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          color: Color(0xFF42A5F5),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'merchant_help.auto_diag_note'.tr(args: [
                              'v${AppUpdateService.currentVersion}',
                              MerchantSupportService.detectedPlatform.toUpperCase(),
                            ]),
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const HugeIcon(icon: HugeIcons.strokeRoundedSent02, color: Colors.white, size: 18),
                      label: Text(
                        _submitting
                            ? 'merchant_help.submitting'.tr()
                            : 'merchant_help.submit_btn'.tr(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: TIKET SAYA (REALTIME)
  // ===========================================================================
  Widget _buildTicketsTab() {
    return StreamBuilder<List<MerchantSupportTicket>>(
      stream: _supportService.watchMyTickets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
        }

        final tickets = snapshot.data ?? const [];
        if (tickets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTicket02,
                        color: Color(0xFF42A5F5),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'merchant_help.no_tickets_title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'merchant_help.no_tickets_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _activeTab = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('merchant_help.open_report_btn'.tr()),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 36),
          physics: const BouncingScrollPhysics(),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final t = tickets[idx];
            final statusColor = switch (t.status) {
              'in_progress' => const Color(0xFFF59E0B),
              'resolved' => const Color(0xFF10B981),
              'closed' => const Color(0xFF64748B),
              _ => const Color(0xFF42A5F5),
            };
            final statusLabel = 'merchant_help.status_${t.status}'.tr();
            final catLabel = 'merchant_help.t_cat_${t.category}'.tr();
            final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(t.createdAt);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: t.adminReply != null && t.adminReply!.trim().isNotEmpty
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : Colors.white12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t.ticketCode,
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          catLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.subject,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                  ),
                  if (t.attachmentUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: t.attachmentUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, imgIdx) {
                          final url = t.attachmentUrls[imgIdx];
                          return GestureDetector(
                            onTap: () => _openImageViewer(url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (t.adminReply != null && t.adminReply!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedCustomerSupport,
                                color: Color(0xFF10B981),
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'merchant_help.admin_reply_label'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            t.adminReply!.trim(),
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDarkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12.5),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.4),
        ),
      ),
    );
  }
}
