import 'package:flutter/material.dart';
import '../../../../widgets/glass_toast.dart';
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

  final List<String> _popularServices = [
    'Haircut & Styling',
    'Beard Trim & Shave',
    'Hair Wash & Massage',
    'Full Grooming Package',
    'Kids Haircut',
  ];

  final List<String> _stationOptions = [
    'Kerusi 1',
    'Kerusi 2',
    'Kerusi 3',
    'Kerusi 4',
    'Kaunter Utama',
  ];

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
        notes: _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      showGlassToast(
        context,
        'Nombor Giliran Dikeluarkan: ${ticket.ticketNumber}',
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF10101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Giliran Walk-In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Keluarkan tiket giliran untuk pelanggan kaunter',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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
                      label: 'Nama Pelanggan *',
                      hint: 'Contoh: Ahmad Danial',
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Sila masukkan nama pelanggan' : null,
                    ),
                    const SizedBox(height: 12),

                    // Phone Number
                    _buildField(
                      controller: _phoneCtrl,
                      label: 'Nombor Telefon (WhatsApp)',
                      hint: 'Contoh: 012-3456789',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Service selector
                    const Text(
                      'Servis Diminta',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 16),

                    // Target station / chair
                    const Text(
                      'Pilihan Kerusi / Kaunter',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
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
                      label: 'Nota Tambahan (Pilihan)',
                      hint: 'Contoh: Potong nipis tepi, cuci rambut',
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
                    _submitting ? 'Sedang Diproses...' : 'Keluarkan Nombor Tiket',
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
