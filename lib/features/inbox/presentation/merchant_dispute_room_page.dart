import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../data/merchant_dispute_service.dart';

// =============================================================================
// Ngam Business — Dispute List & 3-Way Mediation Room Screen
// Merchant can inspect customer claim/photos, submit rebuttal & R2 evidence,
// agree to instant refund, or escalate ("Panggil Admin Ngam") to Mediator.
// =============================================================================

class MerchantDisputesListPage extends StatelessWidget {
  final String businessId;
  final String businessName;

  const MerchantDisputesListPage({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final currFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D18),
      body: Stack(
        children: [
          StreamBuilder<List<MerchantDisputeCase>>(
            stream: MerchantDisputeService.watchBusinessDisputes(businessId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                );
              }
              final disputes = snap.data ?? const <MerchantDisputeCase>[];
              if (disputes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedShield01,
                            color: Color(0xFFF59E0B),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'dispute.empty_title'.tr(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'dispute.empty_subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(16, topPad + 72, 16, 28),
                itemCount: disputes.length,
                itemBuilder: (ctx, i) {
                  final d = disputes[i];
                  final col = _disputeStatusColor(d.status);
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MerchantDisputeRoomPage(
                          initialDispute: d,
                          businessName: businessName,
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141827),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: col.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _disputeStatusLabel(d.status),
                                  style: TextStyle(
                                    color: col,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  d.targetType == 'booking'
                                      ? 'dispute.booking_type'.tr()
                                      : 'dispute.order_type'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                currFmt.format(
                                  d.approvedRefundAmount ?? d.requestedRefundAmount,
                                ),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '#${d.caseNumber} • ${d.customerName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.reasonText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(d.createdAt),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'dispute.open_room_btn'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: Color(0xFF38BDF8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FloatingTopBar(
            isDark: true,
            top: topPad + 10,
            onBack: () => Navigator.pop(context),
            title: 'dispute.center_title'.tr(),
            subtitle: businessName,
          ),
        ],
      ),
    );
  }
}

class MerchantDisputeRoomPage extends StatefulWidget {
  final MerchantDisputeCase initialDispute;
  final String businessName;

  const MerchantDisputeRoomPage({
    super.key,
    required this.initialDispute,
    required this.businessName,
  });

  @override
  State<MerchantDisputeRoomPage> createState() =>
      _MerchantDisputeRoomPageState();
}

class _MerchantDisputeRoomPageState extends State<MerchantDisputeRoomPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;
  bool _isSubmittingAction = false;
  bool _showDetailsCard = true;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int _stepIndex(MerchantDisputeCase d) {
    if (d.isResolved) return 3;
    if (d.isEscalated) return 2;
    if (d.status == 'business_responded') return 1;
    return 0;
  }

  Future<void> _sendText(MerchantDisputeCase dispute) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    try {
      await MerchantDisputeService.sendMessage(
        disputeId: dispute.id,
        message: text,
        senderName: widget.businessName,
      );
    } catch (e) {
      if (mounted) {
        showGlassToast(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendChatPhoto(MerchantDisputeCase dispute) async {
    if (_isSending) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 82,
      );
      if (picked == null) return;
      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final url =
          await MerchantDisputeService.uploadEvidenceImage(bytes, picked.name);
      await MerchantDisputeService.sendMessage(
        disputeId: dispute.id,
        message: 'dispute.store_evidence'.tr(),
        senderName: widget.businessName,
        attachments: [url],
      );
    } catch (_) {
      if (mounted) {
        showGlassToast(
          context,
          'dispute.attach_photo_failed'.tr(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openRespondSheet(MerchantDisputeCase dispute) async {
    final ctrl = TextEditingController(text: dispute.businessResponseText ?? '');
    final List<String> urls = List<String>.from(dispute.businessEvidenceUrls);
    bool isUploading = false;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF141827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(
                top: BorderSide(color: Color(0xFF38BDF8), width: 1.2),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'dispute.respond_modal_title'.tr(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'dispute.respond_hint'.tr(),
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'dispute.store_evidence'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...urls.asMap().entries.map(
                            (e) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    e.value,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setModalState(() => urls.removeAt(e.key)),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (urls.length < 4)
                        GestureDetector(
                          onTap: isUploading
                              ? null
                              : () async {
                                  final picked = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1400,
                                    maxHeight: 1400,
                                    imageQuality: 82,
                                  );
                                  if (picked == null) return;
                                  setModalState(() => isUploading = true);
                                  try {
                                    final b = await picked.readAsBytes();
                                    final url = await MerchantDisputeService
                                        .uploadEvidenceImage(b, picked.name);
                                    setModalState(() => urls.add(url));
                                  } catch (_) {
                                    if (mounted) {
                                      showGlassToast(
                                        context,
                                        'dispute.attach_photo_failed'.tr(),
                                        isError: true,
                                      );
                                    }
                                  } finally {
                                    setModalState(() => isUploading = false);
                                  }
                                },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                              ),
                            ),
                            child: isUploading
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const HugeIcon(
                                        icon: HugeIcons.strokeRoundedCamera01,
                                        color: Color(0xFF38BDF8),
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'dispute.add_photo'.tr(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final txt = ctrl.text.trim();
                              if (txt.isEmpty) {
                                showGlassToast(
                                  context,
                                  'dispute.respond_required'.tr(),
                                  type: GlassToastType.warning,
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              try {
                                await MerchantDisputeService.respondDispute(
                                  disputeId: dispute.id,
                                  decision: 'counter_evidence',
                                  responseText: txt,
                                  evidenceUrls: urls,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  showGlassToast(
                                    context,
                                    'dispute.respond_success'.tr(),
                                    type: GlassToastType.success,
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (mounted) {
                                  showGlassToast(
                                    context,
                                    e.toString(),
                                    isError: true,
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'dispute.respond_btn'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAgreeRefund(MerchantDisputeCase dispute) async {
    final amtStr = dispute.requestedRefundAmount.toStringAsFixed(2);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'dispute.agree_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'dispute.agree_body'.tr(args: [amtStr]),
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'dispute.agree_confirm'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isSubmittingAction = true);
    try {
      await MerchantDisputeService.respondDispute(
        disputeId: dispute.id,
        decision: 'agree_refund',
        responseText: 'Kedai bersetuju memulangkan bayaran penuh kepada pelanggan.',
      );
      if (mounted) {
        showGlassToast(
          context,
          'dispute.agree_success'.tr(),
          type: GlassToastType.success,
        );
      }
    } catch (e) {
      if (mounted) showGlassToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingAction = false);
    }
  }

  Future<void> _confirmEscalate(MerchantDisputeCase dispute) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCrown02,
              color: Color(0xFFA855F7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'dispute.escalate_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'dispute.escalate_body'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'dispute.escalate_hint'.tr(),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'dispute.escalate_confirm'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isSubmittingAction = true);
    try {
      await MerchantDisputeService.escalateToAdmin(
        dispute.id,
        note: noteCtrl.text.trim(),
      );
      if (mounted) {
        showGlassToast(
          context,
          'dispute.escalate_success'.tr(),
          type: GlassToastType.info,
        );
      }
    } catch (e) {
      if (mounted) showGlassToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingAction = false);
    }
  }

  void _openLightbox(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final currFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D18),
      body: StreamBuilder<MerchantDisputeCase>(
        stream: MerchantDisputeService.watchDispute(widget.initialDispute.id),
        initialData: widget.initialDispute,
        builder: (context, dispSnap) {
          final dispute = dispSnap.data ?? widget.initialDispute;
          final sColor = _disputeStatusColor(dispute.status);
          final step = _stepIndex(dispute);

          return Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: topPad + 66),

                  // ── Collapsible Escrow & Evidence Summary Card ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sColor.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () =>
                                setState(() => _showDetailsCard = !_showDetailsCard),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _disputeStatusLabel(dispute.status),
                                    style: TextStyle(
                                      color: sColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  currFmt.format(
                                    dispute.approvedRefundAmount ??
                                        dispute.requestedRefundAmount,
                                  ),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _showDetailsCard
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white54,
                                ),
                              ],
                            ),
                          ),
                          if (_showDetailsCard) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _stepDot('dispute.step_opened'.tr(), step >= 0, sColor),
                                _stepLine(step >= 1, sColor),
                                _stepDot('dispute.step_responded'.tr(), step >= 1, sColor),
                                _stepLine(step >= 2, sColor),
                                _stepDot('dispute.step_escalated'.tr(), step >= 2, sColor),
                                _stepLine(step >= 3, sColor),
                                _stepDot('dispute.step_resolved'.tr(), step >= 3, sColor),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${'dispute.customer_claim'.tr()} (${dispute.customerName})',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    dispute.reasonText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (dispute.customerEvidenceUrls.isNotEmpty ||
                                dispute.businessEvidenceUrls.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 48,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    ...dispute.customerEvidenceUrls.map(
                                      (u) => _thumb(u, Colors.amber),
                                    ),
                                    ...dispute.businessEvidenceUrls.map(
                                      (u) => _thumb(u, const Color(0xFF38BDF8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (dispute.moderatorNote != null &&
                                dispute.moderatorNote!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'dispute.verdict_title'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      dispute.moderatorNote!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (dispute.isEscalated) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA855F7).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCrown02,
                                      color: Color(0xFFC084FC),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'dispute.awaiting_verdict'.tr(),
                                        style: const TextStyle(
                                          color: Color(0xFFE9D5FF),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],

                          // ── Merchant Decision Row ──
                          if (!dispute.isResolved) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  onPressed: _isSubmittingAction
                                      ? null
                                      : () => _openRespondSheet(dispute),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCamera01,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  label: Text(
                                    'dispute.respond_btn'.tr(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF10B981),
                                    side: const BorderSide(color: Color(0xFF10B981)),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  onPressed: _isSubmittingAction
                                      ? null
                                      : () => _confirmAgreeRefund(dispute),
                                  child: Text(
                                    'dispute.agree_refund_btn'.tr(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!dispute.isEscalated)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFC084FC),
                                      side: const BorderSide(color: Color(0xFFA855F7)),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                    ),
                                    onPressed: _isSubmittingAction
                                        ? null
                                        : () => _confirmEscalate(dispute),
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCrown02,
                                      color: Color(0xFFC084FC),
                                      size: 15,
                                    ),
                                    label: Text(
                                      'dispute.escalate_btn'.tr(),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── 3-Way Mediation Chat Stream ──
                  Expanded(
                    child: StreamBuilder<List<MerchantDisputeMessage>>(
                      stream: MerchantDisputeService.watchMessages(dispute.id),
                      builder: (context, msgSnap) {
                        final msgs =
                            msgSnap.data ?? const <MerchantDisputeMessage>[];
                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) => _buildBubble(msgs[i]),
                        );
                      },
                    ),
                  ),

                  // ── Composer ──
                  if (!dispute.isResolved)
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            MediaQuery.of(context).padding.bottom > 0
                                ? MediaQuery.of(context).padding.bottom + 4
                                : 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121624).withValues(alpha: 0.92),
                            border: const Border(
                              top: BorderSide(color: Colors.white12),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _isSending
                                    ? null
                                    : () => _sendChatPhoto(dispute),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedImage01,
                                  color: Color(0xFF38BDF8),
                                  size: 22,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _msgCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'dispute.message_hint'.tr(),
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.06),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendText(dispute),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _isSending
                                      ? null
                                      : () => _sendText(dispute),
                                  child: const SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: Center(
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedSent02,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              FloatingTopBar(
                isDark: true,
                top: topPad + 10,
                onBack: () => Navigator.pop(context),
                title: 'dispute.case_prefix'.tr(args: [dispute.caseNumber]),
                subtitle: '${'dispute.customer_label'.tr()}: ${dispute.customerName}',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thumb(String url, Color borderCol) {
    return GestureDetector(
      onTap: () => _openLightbox(url),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol.withValues(alpha: 0.75), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, width: 44, height: 44, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _stepDot(String label, bool active, Color activeCol) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeCol : Colors.white12,
          ),
          child: active
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? activeCol : Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool active, Color activeCol) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
        color: active ? activeCol : Colors.white12,
      ),
    );
  }

  Widget _buildBubble(MerchantDisputeMessage m) {
    if (m.senderRole == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          m.message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      );
    }

    final bool isMe = m.senderRole == 'business';
    final bool isMediator = m.senderRole == 'moderator';
    final timeStr = DateFormat('hh:mm a').format(m.createdAt);

    Color bubbleBg;
    Color borderCol;
    if (isMediator) {
      bubbleBg = const Color(0xFF7C3AED).withValues(alpha: 0.22);
      borderCol = const Color(0xFFA855F7).withValues(alpha: 0.55);
    } else if (isMe) {
      bubbleBg = const Color(0xFF0284C7).withValues(alpha: 0.22);
      borderCol = const Color(0xFF38BDF8).withValues(alpha: 0.45);
    } else {
      bubbleBg = Colors.white.withValues(alpha: 0.07);
      borderCol = Colors.white12;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMediator) ...[
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCrown02,
                    color: Color(0xFFC084FC),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  isMediator
                      ? 'dispute.mediator_badge'.tr()
                      : (isMe
                          ? '${m.senderName} (${'dispute.business_badge'.tr()})'
                          : '${m.senderName} (${'dispute.customer_badge'.tr()})'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isMediator
                        ? const Color(0xFFC084FC)
                        : (isMe ? const Color(0xFF38BDF8) : Colors.amberAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            if (m.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.attachments
                    .map(
                      (u) => GestureDetector(
                        onTap: () => _openLightbox(u),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            u,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 9.5, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

String _disputeStatusLabel(String status) {
  return switch (status) {
    'open' => 'dispute.status_open'.tr(),
    'business_responded' => 'dispute.status_business_responded'.tr(),
    'escalated' => 'dispute.status_escalated'.tr(),
    'under_review' => 'dispute.status_under_review'.tr(),
    'resolved_refund_full' => 'dispute.status_resolved_refund_full'.tr(),
    'resolved_refund_partial' => 'dispute.status_resolved_refund_partial'.tr(),
    'resolved_release_business' => 'dispute.status_resolved_release_business'.tr(),
    'withdrawn' => 'dispute.status_withdrawn'.tr(),
    _ => status,
  };
}

Color _disputeStatusColor(String status) {
  return switch (status) {
    'open' => const Color(0xFFF59E0B),
    'business_responded' => const Color(0xFF38BDF8),
    'escalated' || 'under_review' => const Color(0xFFA855F7),
    'resolved_refund_full' || 'resolved_refund_partial' => const Color(0xFF10B981),
    'resolved_release_business' => const Color(0xFF3B82F6),
    'withdrawn' => const Color(0xFF94A3B8),
    _ => const Color(0xFFF59E0B),
  };
}
