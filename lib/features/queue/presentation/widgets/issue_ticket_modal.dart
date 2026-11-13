import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../widgets/glass_toast.dart';
import '../../../settings/data/business_service.dart';
import '../../data/queue_service.dart';
import '../../models/queue_ticket_model.dart';

class IssueTicketModal extends StatefulWidget {
  final QueueService queueService;

  const IssueTicketModal({super.key, required this.queueService});

  static Future<QueueTicketModel?> show({
    required BuildContext context,
    required QueueService queueService,
  }) {
    return showModalBottomSheet<QueueTicketModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IssueTicketModal(queueService: queueService),
    );
  }

  @override
  State<IssueTicketModal> createState() => _IssueTicketModalState();
}

class _IssueTicketModalState extends State<IssueTicketModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController(text: 'Haircut & Styling');
  final _chairCtrl = TextEditingController(text: 'Kerusi 1');
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  List<Map<String, dynamic>> _staffMembers = [];
  String? _selectedStaffId;
  String? _selectedStaffName;

  List<String> _popularServices = [
    'Haircut & Styling',
    'Beard Trim & Shave',
    'Hair Wash & Massage',
    'Full Grooming Package',
    'Kids Haircut',
  ];

  List<String> _stationOptions = [
    'Kerusi 1',
    'Kerusi 2',
    'Kerusi 3',
    'Kerusi 4',
    'Kaunter Utama',
  ];

  @override
  void initState() {
    super.initState();
    _loadStoreServicesAndChairs();
  }

  Future<void> _loadStoreServicesAndChairs() async {
    try {
      final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
      if (profile == null) return;
      final shopId = profile['id']?.toString();

      // 1. Dynamic chairs based on total_chairs in settings
      if (profile['settings'] is Map) {
        final settings = profile['settings'] as Map;
        final totalChairs = (settings['total_chairs'] as num?)?.toInt() ?? 0;
        if (totalChairs > 0) {
          final chairs = List.generate(
            totalChairs.clamp(1, 12),
            (i) => 'queue.chair_prefix'.tr(args: [(i + 1).toString()]),
          );
          chairs.add('Kaunter Utama');
          if (mounted) {
            setState(() {
              _stationOptions = chairs;
              _chairCtrl.text = chairs.first;
            });
          }
        }
      }

      // 2. Dynamic services from business_products
      if (shopId != null && shopId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('business_products')
            .select('name, is_active')
            .eq('shop_id', shopId)
            .order('created_at', ascending: true);
        final names = (rows as List)
            .where((r) => r['is_active'] != false && (r['name']?.toString().trim().isNotEmpty ?? false))
            .map((r) => r['name'].toString().trim())
            .toSet()
            .toList();
        if (names.isNotEmpty && mounted) {
          setState(() {
            _popularServices = names;
            _serviceCtrl.text = names.first;
          });
        }

        // 3. Dynamic staff members from team_members
        final staffRows = await Supabase.instance.client
            .from('team_members')
            .select('id, user_id, role, name, user_email, is_active')
            .eq('business_id', shopId)
            .eq('is_active', true);
        if (mounted) {
          setState(() {
            _staffMembers = (staffRows as List).cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _serviceCtrl.dispose();
    _chairCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final ticket = await widget.queueService.issueTicket(
        customerName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        serviceName: _serviceCtrl.text.trim(),
        stationOrChair: _chairCtrl.text.trim(),
        assignedStaffId: _selectedStaffId,
        assignedStaffName: _selectedStaffName,
        notes: _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      showGlassToast(
        context,
        'queue.ticket_issued_toast'.tr(args: [ticket.ticketNumber]),
        customColor: const Color(0xFF44CF6C),
      );
      Navigator.pop(context, ticket);
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Ralat: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 580 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.95 : 0.9),
        ),
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: const Color(0xFF10101E),
          borderRadius: isLandscape
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'queue.register_walkin_title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'queue.register_walkin_sub'.tr(),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Colors.white12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Name
                      _buildField(
                        controller: _nameCtrl,
                        label: 'queue.customer_name_req'.tr(),
                        hint: 'queue.name_placeholder'.tr(),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'queue.name_validation'.tr() : null,
                      ),
                      const SizedBox(height: 12),

                      // Phone Number
                      _buildField(
                        controller: _phoneCtrl,
                        label: 'queue.phone_wa_label'.tr(),
                        hint: 'queue.phone_placeholder'.tr(),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Staff Assignment
                      if (_staffMembers.isNotEmpty) ...[
                        Text(
                          'queue.assigned_staff'.tr(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Mana-mana Krew', style: TextStyle(fontSize: 12)),
                              selected: _selectedStaffId == null,
                              selectedColor: const Color(0xFF42A5F5),
                              backgroundColor: const Color(0xFF1A1A2E),
                              side: BorderSide(color: _selectedStaffId == null ? const Color(0xFF42A5F5) : Colors.white12),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedStaffId = null;
                                    _selectedStaffName = null;
                                  });
                                }
                              },
                            ),
                            ..._staffMembers.map((sm) {
                              final staffId = sm['id']?.toString() ?? '';
                              final staffName = sm['name']?.toString() ?? 'Krew';
                              final isSel = _selectedStaffId == staffId;
                              return ChoiceChip(
                                label: Text(staffName, style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12)),
                                selected: isSel,
                                selectedColor: const Color(0xFF42A5F5),
                                backgroundColor: const Color(0xFF1A1A2E),
                                side: BorderSide(color: isSel ? const Color(0xFF42A5F5) : Colors.white12),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _selectedStaffId = staffId;
                                      _selectedStaffName = staffName;
                                    });
                                  }
                                },
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Service selector
                      Text(
                        'queue.service_requested'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _popularServices.map((srv) {
                          final isSel = _serviceCtrl.text == srv;
                          return ChoiceChip(
                            label: Text(srv, style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12)),
                            selected: isSel,
                            selectedColor: const Color(0xFF42A5F5),
                            backgroundColor: const Color(0xFF1A1A2E),
                            side: BorderSide(color: isSel ? const Color(0xFF42A5F5) : Colors.white12),
                            onSelected: (val) {
                              if (val) setState(() => _serviceCtrl.text = srv);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _serviceCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'queue.custom_service_hint'.tr(),
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1A1A2E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Target station / chair
                      Text(
                        'queue.station_chair_choice'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _stationOptions.map((st) {
                          final isSel = _chairCtrl.text == st;
                          return ChoiceChip(
                            label: Text(st, style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12)),
                            selected: isSel,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: const Color(0xFF1A1A2E),
                            side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.white12),
                            onSelected: (val) {
                              if (val) setState(() => _chairCtrl.text = st);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      _buildField(
                        controller: _notesCtrl,
                        label: 'queue.optional_notes'.tr(),
                        hint: 'queue.notes_placeholder'.tr(),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Submit button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D1A),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.confirmation_number_outlined, size: 20),
                    label: Text(
                      _submitting ? 'queue.processing'.tr() : 'queue.issue_ticket_btn'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
