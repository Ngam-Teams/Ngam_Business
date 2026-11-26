import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../widgets/glass_toast.dart';
import '../../../../widgets/liquid_glass_compat.dart';
import '../../../integrations/data/easyparcel_service.dart';
import '../../../settings/data/business_service.dart';
import '../../data/orders_service.dart';

/// Glassmorphic modal for booking & tracking an EasyParcel shipment from an order.
class EasyParcelShipModal extends StatefulWidget {
  final OrderModel order;
  final OrderShipmentModel? existingShipment;
  final VoidCallback? onShipmentCreated;

  const EasyParcelShipModal({
    super.key,
    required this.order,
    this.existingShipment,
    this.onShipmentCreated,
  });

  static Future<OrderShipmentModel?> show(
    BuildContext context, {
    required OrderModel order,
    OrderShipmentModel? existingShipment,
    VoidCallback? onShipmentCreated,
  }) {
    return showDialog<OrderShipmentModel>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => EasyParcelShipModal(
        order: order,
        existingShipment: existingShipment,
        onShipmentCreated: onShipmentCreated,
      ),
    );
  }

  @override
  State<EasyParcelShipModal> createState() => _EasyParcelShipModalState();
}

class _EasyParcelShipModalState extends State<EasyParcelShipModal> {
  static const Color _epPink = Color(0xFFEC008C);

  final EasyParcelService _service = EasyParcelService();

  bool _loadingConfig = true;
  bool _checkingRates = false;
  bool _booking = false;
  bool _tracking = false;

  EasyParcelConfig _config = const EasyParcelConfig();
  OrderShipmentModel? _shipment;

  // Form controllers
  late final TextEditingController _pickNameCtrl;
  late final TextEditingController _pickPhoneCtrl;
  late final TextEditingController _pickAddrCtrl;
  late final TextEditingController _pickCityCtrl;
  late final TextEditingController _pickPostcodeCtrl;
  String _pickState = 'sgr';

  late final TextEditingController _sendNameCtrl;
  late final TextEditingController _sendPhoneCtrl;
  late final TextEditingController _sendAddrCtrl;
  late final TextEditingController _sendCityCtrl;
  late final TextEditingController _sendPostcodeCtrl;
  String _sendState = 'sgr';

  late final TextEditingController _weightCtrl;
  late final TextEditingController _contentCtrl;
  bool _autoPay = true;

  List<EasyParcelRate> _rates = [];
  EasyParcelRate? _selectedRate;
  String? _rateError;

  @override
  void initState() {
    super.initState();
    _shipment = widget.existingShipment;

    _pickNameCtrl = TextEditingController();
    _pickPhoneCtrl = TextEditingController();
    _pickAddrCtrl = TextEditingController();
    _pickCityCtrl = TextEditingController();
    _pickPostcodeCtrl = TextEditingController();

    _sendNameCtrl = TextEditingController(text: widget.order.customerName ?? '');
    _sendPhoneCtrl = TextEditingController(text: widget.order.customerPhone ?? '');
    _sendAddrCtrl = TextEditingController();
    _sendCityCtrl = TextEditingController();
    _sendPostcodeCtrl = TextEditingController();

    _weightCtrl = TextEditingController(text: '1.0');
    _contentCtrl = TextEditingController(text: 'Order ${widget.order.refCode}');

    _initData();
  }

  Future<void> _initData() async {
    final cfg = await _service.getConfig();
    final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
    final existing = _shipment ?? await _service.getOrderShipment(widget.order.id);

    if (!mounted) return;

    final bizName = profile?['name']?.toString() ?? '';
    final bizPhone = profile?['business_phone']?.toString() ?? '';
    final bizAddr = profile?['address']?.toString() ?? '';

    _pickNameCtrl.text = cfg.senderName.isNotEmpty ? cfg.senderName : bizName;
    _pickPhoneCtrl.text = cfg.senderPhone.isNotEmpty ? cfg.senderPhone : bizPhone;
    _pickAddrCtrl.text = cfg.senderAddr1.isNotEmpty ? cfg.senderAddr1 : bizAddr;
    _pickPostcodeCtrl.text = cfg.senderPostcode.isNotEmpty
        ? cfg.senderPostcode
        : EasyParcelService.extractPostcode(bizAddr);
    _pickCityCtrl.text = cfg.senderCity.isNotEmpty
        ? cfg.senderCity
        : EasyParcelService.extractCity(_pickAddrCtrl.text);
    _pickState = cfg.senderState.isNotEmpty
        ? cfg.senderState
        : EasyParcelService.guessStateCode(bizAddr);

    // 1. Auto-extract customer delivery address from order notes `(Alamat: ...)`
    String receiverAddr = EasyParcelService.extractDeliveryAddress(widget.order.notes);
    if (receiverAddr.isEmpty && widget.order.notes != null) {
      final rawNotes = widget.order.notes!.trim();
      if (EasyParcelService.extractPostcode(rawNotes).isNotEmpty) {
        receiverAddr = rawNotes;
      }
    }

    // 2. Fallback to customer's saved `user_address` / `user_phone` in `public.users`
    if (receiverAddr.isEmpty || _sendPhoneCtrl.text.trim().isEmpty) {
      final custInfo = await _service.fetchCustomerAddress(
        widget.order.customerId ?? widget.order.ownerUserId,
      );
      if (receiverAddr.isEmpty && (custInfo['address'] ?? '').isNotEmpty) {
        receiverAddr = custInfo['address']!;
      }
      if (_sendPhoneCtrl.text.trim().isEmpty && (custInfo['phone'] ?? '').isNotEmpty) {
        _sendPhoneCtrl.text = custInfo['phone']!;
      }
      if (_sendNameCtrl.text.trim().isEmpty && (custInfo['name'] ?? '').isNotEmpty) {
        _sendNameCtrl.text = custInfo['name']!;
      }
    }

    if (receiverAddr.isNotEmpty) {
      _sendAddrCtrl.text = receiverAddr;
      _sendPostcodeCtrl.text = EasyParcelService.extractPostcode(receiverAddr);
      _sendCityCtrl.text = EasyParcelService.extractCity(receiverAddr);
      _sendState = EasyParcelService.guessStateCode(receiverAddr);
    }

    final estimatedWeight = await _service.estimateOrderWeightKg(widget.order.id);
    _weightCtrl.text = estimatedWeight.toStringAsFixed(estimatedWeight % 1 == 0 ? 1 : 2);

    if (!mounted) return;
    setState(() {
      _config = cfg;
      _shipment = existing;
      _loadingConfig = false;
    });

    // 3. Auto-check courier rates immediately if both sender & receiver postcodes are ready!
    if (existing == null &&
        _pickPostcodeCtrl.text.trim().length >= 5 &&
        _sendPostcodeCtrl.text.trim().length >= 5) {
      _checkRates();
    }
  }

  @override
  void dispose() {
    _pickNameCtrl.dispose();
    _pickPhoneCtrl.dispose();
    _pickAddrCtrl.dispose();
    _pickCityCtrl.dispose();
    _pickPostcodeCtrl.dispose();
    _sendNameCtrl.dispose();
    _sendPhoneCtrl.dispose();
    _sendAddrCtrl.dispose();
    _sendCityCtrl.dispose();
    _sendPostcodeCtrl.dispose();
    _weightCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRates() async {
    final pickCode = _pickPostcodeCtrl.text.trim();
    final sendCode = _sendPostcodeCtrl.text.trim();
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;

    if (pickCode.length < 5 || sendCode.length < 5) {
      showGlassToast(context, 'easyparcel.err_postcode_required'.tr(), isError: true);
      return;
    }
    if (weight <= 0) {
      showGlassToast(context, 'easyparcel.err_weight_invalid'.tr(), isError: true);
      return;
    }

    setState(() {
      _checkingRates = true;
      _rateError = null;
      _rates = [];
      _selectedRate = null;
    });

    final result = await _service.checkRates(
      pickCode: pickCode,
      pickState: _pickState,
      sendCode: sendCode,
      sendState: _sendState,
      weight: weight,
    );

    if (!mounted) return;
    final customerChoice = _extractCustomerChosenCourier();
    setState(() {
      _checkingRates = false;
      _rates = result.rates;
      _rateError = result.error;
      if (_rates.isNotEmpty) {
        if (customerChoice.serviceId != null) {
          final exact = _rates.where((r) => r.serviceId == customerChoice.serviceId).toList();
          if (exact.isNotEmpty) {
            _selectedRate = exact.first;
          } else if (customerChoice.courierName != null) {
            final byName = _rates.where(
              (r) => r.courierName.toLowerCase().contains(customerChoice.courierName!.toLowerCase()),
            ).toList();
            _selectedRate = byName.isNotEmpty ? byName.first : _rates.first;
          } else {
            _selectedRate = _rates.first;
          }
        } else {
          _selectedRate = _rates.first;
        }
      }
    });
  }

  ({String? courierName, String? serviceId, String? paidPrice}) _extractCustomerChosenCourier() {
    final notes = widget.order.notes ?? '';
    final m = RegExp(
      r'\[Kurier:\s*([^|\]]+)(?:\|\s*Service:\s*([^|\]]+))?(?:\|\s*Pos:\s*RM([0-9.]+))?\]',
      caseSensitive: false,
    ).firstMatch(notes);
    return (
      courierName: m?.group(1)?.trim() ?? widget.order.courierName?.trim(),
      serviceId: m?.group(2)?.trim(),
      paidPrice: m?.group(3)?.trim(),
    );
  }

  Future<void> _bookShipment() async {
    final rate = _selectedRate;
    if (rate == null) {
      showGlassToast(context, 'easyparcel.err_select_courier'.tr(), isError: true);
      return;
    }
    if (_pickNameCtrl.text.trim().isEmpty ||
        _pickPhoneCtrl.text.trim().isEmpty ||
        _pickAddrCtrl.text.trim().isEmpty ||
        _sendNameCtrl.text.trim().isEmpty ||
        _sendPhoneCtrl.text.trim().isEmpty ||
        _sendAddrCtrl.text.trim().isEmpty) {
      showGlassToast(context, 'easyparcel.err_fill_addresses'.tr(), isError: true);
      return;
    }

    setState(() => _booking = true);

    try {
      final weight = double.tryParse(_weightCtrl.text.trim()) ?? 1.0;
      final res = await _service.bookAndPay(
        orderId: widget.order.id,
        rate: rate,
        weight: weight,
        content: _contentCtrl.text.trim().isEmpty ? 'Parcel' : _contentCtrl.text.trim(),
        value: widget.order.total > 0 ? widget.order.total : 10.0,
        reference: widget.order.refCode,
        autoPay: _autoPay,
        sender: {
          'name': _pickNameCtrl.text.trim(),
          'company': _pickNameCtrl.text.trim(),
          'phone': _pickPhoneCtrl.text.trim(),
          'addr1': _pickAddrCtrl.text.trim(),
          'addr2': '',
          'city': _pickCityCtrl.text.trim().isEmpty ? _pickPostcodeCtrl.text.trim() : _pickCityCtrl.text.trim(),
          'state': _pickState,
          'postcode': _pickPostcodeCtrl.text.trim(),
        },
        receiver: {
          'name': _sendNameCtrl.text.trim(),
          'phone': _sendPhoneCtrl.text.trim(),
          'addr1': _sendAddrCtrl.text.trim(),
          'addr2': '',
          'city': _sendCityCtrl.text.trim().isEmpty ? _sendPostcodeCtrl.text.trim() : _sendCityCtrl.text.trim(),
          'state': _sendState,
          'postcode': _sendPostcodeCtrl.text.trim(),
        },
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final shipmentMap = res['shipment'] is Map
            ? Map<String, dynamic>.from(res['shipment'] as Map)
            : <String, dynamic>{};
        final created = OrderShipmentModel.fromJson({
          ...shipmentMap,
          'order_id': widget.order.id,
        });

        setState(() {
          _booking = false;
          _shipment = created;
        });

        widget.onShipmentCreated?.call();

        if (res['insufficient_credit'] == true) {
          showGlassToast(context, 'easyparcel.warn_insufficient_credit'.tr(), isError: true);
        } else {
          showGlassToast(context, 'easyparcel.book_success'.tr());
        }
      } else {
        setState(() => _booking = false);
        showGlassToast(
          context,
          res['error']?.toString() ?? 'easyparcel.book_failed'.tr(),
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      showGlassToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _refreshTracking() async {
    final awb = _shipment?.awbNumber;
    if (awb == null || awb.isEmpty) return;

    setState(() => _tracking = true);
    try {
      final res = await _service.trackParcel(
        awbNumber: awb,
        shipmentId: _shipment?.id,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final refreshed = await _service.getOrderShipment(widget.order.id);
        if (mounted) {
          setState(() {
            _tracking = false;
            if (refreshed != null) _shipment = refreshed;
          });
          showGlassToast(context, 'easyparcel.tracking_updated'.tr());
        }
      } else {
        setState(() => _tracking = false);
        showGlassToast(context, res['error']?.toString() ?? 'easyparcel.tracking_failed'.tr(), isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _tracking = false);
      showGlassToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareTrackingWhatsApp() async {
    final s = _shipment;
    if (s == null) return;
    final rawPhone = (widget.order.customerPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (rawPhone.isEmpty) {
      showGlassToast(context, 'easyparcel.err_no_customer_phone'.tr(), isError: true);
      return;
    }
    final intlPhone = rawPhone.startsWith('0') ? '6$rawPhone' : rawPhone;
    final msg = 'easyparcel.whatsapp_tracking_msg'.tr(args: [
      widget.order.refCode,
      s.courierName ?? 'EasyParcel',
      s.awbNumber ?? s.epOrderNo ?? '-',
      s.trackingUrl ?? '',
    ]);
    final uri = Uri.parse('https://wa.me/$intlPhone?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12.5),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.28),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _epPink, width: 1.3),
      ),
    );
  }

  Widget _buildStateDropdown(String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: kMalaysiaStates.any((s) => s['code'] == value) ? value : 'sgr',
          isExpanded: true,
          dropdownColor: const Color(0xFF141827),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
          items: kMalaysiaStates.map((s) {
            return DropdownMenuItem<String>(
              value: s['code'],
              child: Text(s['name']!, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _epPink),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildShipmentSummaryView(OrderShipmentModel s) {
    final hasAwb = s.awbNumber != null && s.awbNumber!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _epPink.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _epPink.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      s.status.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (s.environment == 'demo')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'easyparcel.env_demo'.tr(),
                        style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.courierName ?? s.serviceName ?? 'EasyParcel',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              if (s.serviceName != null && s.serviceName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  s.serviceName!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'easyparcel.awb_label'.tr(),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasAwb ? s.awbNumber! : (s.epOrderNo ?? '-'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'common.copy'.tr(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: hasAwb ? s.awbNumber! : (s.epOrderNo ?? '')));
                      showGlassToast(context, 'easyparcel.awb_copied'.tr());
                    },
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                  ),
                ],
              ),
              if (s.latestTrackingStatus != null && s.latestTrackingStatus!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${'easyparcel.latest_status'.tr()}: ${s.latestTrackingStatus}',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (s.awbPdfUrl != null && s.awbPdfUrl!.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _epPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openUrl(s.awbPdfUrl),
                icon: const Icon(Icons.print_rounded, size: 17),
                label: Text('easyparcel.print_awb'.tr()),
              ),
            if (hasAwb)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _tracking ? null : _refreshTracking,
                icon: _tracking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, size: 17),
                label: Text('easyparcel.refresh_tracking'.tr()),
              ),
            if (s.trackingUrl != null && s.trackingUrl!.isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openUrl(s.trackingUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('easyparcel.open_tracking'.tr()),
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _shareTrackingWhatsApp,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text('easyparcel.share_whatsapp'.tr()),
            ),
          ],
        ),
        if (s.trackingEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('easyparcel.tracking_timeline'.tr(), Icons.local_shipping_rounded),
          const SizedBox(height: 8),
          ...s.trackingEvents.map((ev) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 8, color: _epPink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev['status']?.toString() ?? '-',
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ev['event_date'] ?? ''} ${ev['event_time'] ?? ''} • ${ev['location'] ?? ''}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildBookingForm() {
    final customerChoice = _extractCustomerChosenCourier();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customerChoice.courierName != null && customerChoice.courierName!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _epPink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _epPink.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: _epPink, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerChoice.paidPrice != null
                        ? 'easyparcel.customer_selected_courier'.tr(
                            args: [customerChoice.courierName!, customerChoice.paidPrice!],
                          )
                        : 'easyparcel.customer_selected_courier_only'.tr(
                            args: [customerChoice.courierName!],
                          ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_config.isPlatformMode) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFF34D399), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'easyparcel.platform_banner_title'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Sender Details
        _buildSectionTitle('easyparcel.sender_section'.tr(), Icons.storefront_rounded),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pickNameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration('easyparcel.sender_name_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pickPhoneCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration('easyparcel.phone_hint'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pickAddrCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _fieldDecoration('easyparcel.address_hint'.tr()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _pickPostcodeCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('easyparcel.postcode_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _pickCityCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration('easyparcel.city_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _buildStateDropdown(_pickState, (v) => setState(() => _pickState = v)),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Receiver Details
        _buildSectionTitle('easyparcel.receiver_section'.tr(), Icons.person_pin_circle_rounded),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sendNameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration('easyparcel.receiver_name_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _sendPhoneCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration('easyparcel.phone_hint'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sendAddrCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _fieldDecoration('easyparcel.receiver_address_hint'.tr()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _sendPostcodeCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('easyparcel.postcode_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _sendCityCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration('easyparcel.city_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _buildStateDropdown(_sendState, (v) => setState(() => _sendState = v)),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Parcel details
        _buildSectionTitle('easyparcel.parcel_section'.tr(), Icons.inventory_2_rounded),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _weightCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDecoration('easyparcel.weight_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _contentCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration('easyparcel.content_hint'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _epPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _checkingRates ? null : _checkRates,
            icon: _checkingRates
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search_rounded, size: 18),
            label: Text(
              _checkingRates ? 'easyparcel.checking_rates'.tr() : 'easyparcel.check_rates_btn'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),

        if (_rateError != null) ...[
          const SizedBox(height: 10),
          Text(
            _rateError!,
            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5),
          ),
        ],

        if (_rates.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle(
            'easyparcel.select_courier'.tr(args: [_rates.length.toString()]),
            Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 8),
          ..._rates.take(12).map((rate) {
            final isSelected = _selectedRate?.rateId == rate.rateId &&
                _selectedRate?.serviceId == rate.serviceId;
            return GestureDetector(
              onTap: () => setState(() => _selectedRate = rate),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _epPink.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _epPink : Colors.white.withValues(alpha: 0.12),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    if (rate.courierLogo.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          rate.courierLogo,
                          width: 42,
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 42,
                            height: 42,
                            color: Colors.white10,
                            child: const Icon(Icons.local_shipping_rounded, color: Colors.white70, size: 20),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rate.courierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${rate.serviceDetail.toUpperCase()} • ${rate.delivery}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RM ${rate.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _epPink,
            title: Text(
              _config.isPlatformMode
                  ? 'easyparcel.auto_pay_platform_label'.tr()
                  : 'easyparcel.auto_pay_label'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
            value: _autoPay,
            onChanged: (v) => setState(() => _autoPay = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _booking ? null : _bookShipment,
              icon: _booking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                _booking
                    ? 'easyparcel.booking_in_progress'.tr()
                    : 'easyparcel.book_and_pay_btn'.tr(args: [
                        (_selectedRate?.price ?? 0).toStringAsFixed(2),
                      ]),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: LiquidGlassSettings(
            thickness: 0.1,
            blur: 24,
            glassColor: const Color(0xFF0E1220).withValues(alpha: 0.92),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _epPink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _epPink.withValues(alpha: 0.45)),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: _epPink, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'easyparcel.ship_modal_title'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.order.refCode,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, _shipment),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                Flexible(
                  child: _loadingConfig
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(color: _epPink)),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _shipment != null
                              ? _buildShipmentSummaryView(_shipment!)
                              : _buildBookingForm(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
