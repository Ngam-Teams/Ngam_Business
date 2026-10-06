import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import '../../../widgets/glass_toast.dart';
import '../data/business_service.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final _client = Supabase.instance.client;
  final _businessService = BusinessService();

  bool _isLoading = true;
  String? _businessId;
  String _businessName = 'Your Business';
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _businessService.getBusinessProfile();
      if (profile != null) {
        _businessId = profile['id'];
        _businessName = profile['business_name'] ?? 'Your Business';

        final res = await _client
            .from('team_members')
            .select()
            .eq('business_id', _businessId!)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _staffList = (res as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addStaff(Map<String, dynamic> staffData) async {
    if (_businessId == null) {
      showGlassToast(context, 'Business profile not loaded.', isError: true);
      return;
    }

    try {
      final email = (staffData['email'] as String).trim();

      // Check if user already exists in auth.users by email to auto-link user_id
      String? matchedUserId;
      try {
        final userCheck = await _client
            .from('users')
            .select('id')
            .ilike('email', email)
            .maybeSingle();
        if (userCheck != null) {
          matchedUserId = userCheck['id'] as String?;
        }
      } catch (_) {}

      final nextNum = _staffList.length + 1;
      final autoCode = 'STF-${nextNum.toString().padLeft(3, '0')}';

      final payload = {
        'business_id': _businessId,
        'user_id': matchedUserId,
        'staff_code': staffData['staff_code']?.toString().isNotEmpty == true
            ? staffData['staff_code']
            : autoCode,
        'name': staffData['name'],
        'email': email,
        'phone': staffData['phone'] ?? '',
        'department': staffData['department'] ?? 'General',
        'designation': staffData['designation'] ?? 'Staff',
        'role': staffData['role'] ?? 'staff',
        'status': matchedUserId != null ? 'active' : 'pending_invite',
      };

      await _client.from('team_members').insert(payload);

      if (mounted) {
        showGlassToast(
          context,
          'Staff member added to $_businessName!',
        );
        _loadStaff();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Failed to add staff: $e', isError: true);
      }
    }
  }

  Future<void> _updateStaff(String staffId, Map<String, dynamic> updates) async {
    try {
      await _client.from('team_members').update(updates).eq('id', staffId);
      if (mounted) {
        showGlassToast(context, 'Staff details updated successfully!');
        _loadStaff();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Failed to update staff: $e', isError: true);
      }
    }
  }

  Future<void> _deleteStaff(String staffId, String staffName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Staff Member', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove "$staffName"? They will lose access to $_businessName on Ngam Teams.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('team_members').delete().eq('id', staffId);
      if (mounted) {
        showGlassToast(context, 'Staff removed successfully.');
        _loadStaff();
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'Failed to remove: $e', isError: true);
    }
  }

  void _showInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InviteStaffSheet(),
    ).then((value) {
      if (value != null && value is Map<String, dynamic>) {
        _addStaff(value);
      }
    });
  }

  void _showEditStaffModal(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditStaffSheet(staff: staff),
    ).then((updates) {
      if (updates != null && updates is Map<String, dynamic>) {
        _updateStaff(staff['id'], updates);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10101A),
        elevation: 0,
        title: Column(
          children: [
            const Text(
              'Staff & Team Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              _businessName,
              style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCoins01, color: Color(0xFF10B981), size: 22),
            tooltip: 'Urus Gaji & Komisen Staf',
            onPressed: () => context.push('/payroll'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteModal,
        backgroundColor: const Color(0xFF42A5F5),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01, color: Colors.white, size: 20),
        label: const Text(
          'Add / Link Staff',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : _staffList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF42A5F5),
                  onRefresh: _loadStaff,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16).copyWith(bottom: 120),
                    itemCount: _staffList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildLinkingGuideBanner();
                      }
                      final staff = _staffList[index - 1];
                      return _buildStaffCard(staff);
                    },
                  ),
                ),
    );
  }

  Widget _buildLinkingGuideBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF42A5F5).withValues(alpha: 0.15),
            const Color(0xFF2DD4BF).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedShield01,
              color: Color(0xFF42A5F5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe & Reliable Staff Linking',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Staff link automatically when they sign in with their email, OR tap the share icon on their card to send them their unique Staff Code to link in Ngam Teams.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: Color(0xFF42A5F5),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Staff Linked Yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your team members here. When they log in to Ngam Teams with their email, they will automatically be linked to your business.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showInviteModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 18),
              label: const Text('Add First Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final bool isLinked = staff['user_id'] != null;
    final String staffCode = staff['staff_code'] ?? 'STF';
    final String role = (staff['role'] as String? ?? 'staff').toUpperCase();
    final String designation = staff['designation'] ?? 'Staff';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLinked
              ? const Color(0xFF42A5F5).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        onTap: () => _showEditStaffModal(staff),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isLinked
              ? const Color(0xFF44CF6C).withValues(alpha: 0.15)
              : const Color(0xFF42A5F5).withValues(alpha: 0.15),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            color: isLinked ? const Color(0xFF44CF6C) : const Color(0xFF42A5F5),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                staff['name'] ?? 'Staff Member',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                staffCode,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${staff['email']} • $designation',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Ngam Teams Link Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLinked
                        ? const Color(0xFF44CF6C).withValues(alpha: 0.15)
                        : const Color(0xFFF9C80E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLinked ? const Color(0xFF44CF6C) : const Color(0xFFF9C80E),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLinked ? 'Ngam Teams Linked' : 'Pending First Login',
                        style: TextStyle(
                          color: isLinked ? const Color(0xFF44CF6C) : const Color(0xFFF9C80E),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Color(0xFFF9C80E), size: 19),
              tooltip: 'QR Code & Fast Link',
              onPressed: () => _showStaffQrModal(staff),
            ),
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare01, color: Color(0xFF2DD4BF), size: 18),
              tooltip: 'Share Invite & Staff Code',
              onPressed: () => _copyStaffInvite(staff),
            ),
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit02, color: Color(0xFF42A5F5), size: 18),
              tooltip: 'Edit Info',
              onPressed: () => _showEditStaffModal(staff),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
              tooltip: 'Remove',
              onPressed: () => _deleteStaff(staff['id'], staff['name'] ?? 'Staff'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffQrModal(Map<String, dynamic> staff) {
    final name = staff['name'] ?? 'Staff';
    final code = (staff['staff_code'] ?? 'STF-001').toString().toUpperCase();
    final role = (staff['role'] ?? 'staff').toString().toUpperCase();
    final qrData = 'NGAM_STAFF:$code';

    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: const Color(0xFF141420),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedQrCode,
                              color: Color(0xFF42A5F5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Pautan Pantas Staf • $role',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      gapless: true,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'KOD PANTAS STAF',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showGlassToast(context, 'Kod $code disalin!');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              color: Color(0xFF42A5F5),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.copy_rounded, color: Color(0xFF42A5F5), size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Buka Ngam Teams > Profil > Imbas QR atau masukkan kod di atas untuk pautkan akaun serta-merta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _copyStaffInvite(staff);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare01, color: Colors.white, size: 16),
                      label: const Text('Kongsi Jemputan WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _copyStaffInvite(Map<String, dynamic> staff) {
    final name = staff['name'] ?? 'Staff';
    final code = staff['staff_code'] ?? 'STF-001';
    final email = staff['email'] ?? '';
    final biz = _businessName;

    final msg = '''
Halo $name! Anda telah ditambah sebagai staf untuk "$biz" di aplikasi Ngam Teams.

🔑 Kod Staf Anda: $code
📧 Emel: $email

Cara Menyambung Mudah & Pantas:
1. Buka aplikasi Ngam Teams.
2. Log masuk menggunakan emel ($email), ATAU buka menu Profil dan tekan "Enter Staff Code to Connect" lalu masukkan kod: $code.
Selamat bertugas!
'''.trim();

    Clipboard.setData(ClipboardData(text: msg));
    showGlassToast(
      context,
      'Jemputan & Kod Staf ($code) disalin! Boleh tampal terus di WhatsApp.',
      customIcon: Icons.share_rounded,
      customColor: const Color(0xFF2DD4BF),
    );
  }
}

class _InviteStaffSheet extends StatefulWidget {
  const _InviteStaffSheet();

  @override
  State<_InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends State<_InviteStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  final _staffCodeController = TextEditingController();

  String _selectedRole = 'staff';
  String _selectedDepartment = 'General';

  static const _departments = ['General', 'F&B', 'Kitchen', 'Counter', 'Service', 'Barber', 'Sales'];
  static const _roles = [
    {'id': 'staff', 'label': 'Staff'},
    {'id': 'cashier', 'label': 'Cashier'},
    {'id': 'manager', 'label': 'Manager'},
    {'id': 'tenant_admin', 'label': 'Admin'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _staffCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'designation': _designationController.text.trim().isNotEmpty
          ? _designationController.text.trim()
          : 'Staff',
      'staff_code': _staffCodeController.text.trim(),
      'department': _selectedDepartment,
      'role': _selectedRole,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161622).withValues(alpha: 0.95),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add / Link Staff Member',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Text(
                      'When this staff member logs in to Ngam Teams with this email, they will automatically be linked to your business.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _buildField(
                      label: 'Full Name *',
                      controller: _nameController,
                      hint: 'e.g. Siti Nurhaliza',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    _buildField(
                      label: 'Email (Used to log in on Ngam Teams) *',
                      controller: _emailController,
                      hint: 'e.g. siti@example.com or siti@ngam.my',
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email required';
                        if (!val.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phone & Staff Code
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Phone (Optional)',
                            controller: _phoneController,
                            hint: '+6012...',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'Staff Code (Optional)',
                            controller: _staffCodeController,
                            hint: 'e.g. STF-001',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Designation & Department
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Job Title / Designation',
                            controller: _designationController,
                            hint: 'e.g. Cashier / Barista',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text('Department', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ),
                              DropdownButtonFormField<String>(
                                value: _selectedDepartment,
                                dropdownColor: const Color(0xFF1E1E2C),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedDepartment = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Role
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Role & Permissions', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                    Row(
                      children: _roles.map((r) {
                        final isSelected = _selectedRole == r['id'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = r['id']!),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  r['label']!,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF42A5F5) : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Save & Link Staff',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditStaffSheet extends StatefulWidget {
  final Map<String, dynamic> staff;
  const _EditStaffSheet({required this.staff});

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _designationController;
  late final TextEditingController _staffCodeController;

  late String _selectedRole;
  late String _selectedDepartment;

  static const _departments = ['General', 'F&B', 'Kitchen', 'Counter', 'Service', 'Barber', 'Sales'];
  static const _roles = [
    {'id': 'staff', 'label': 'Staff'},
    {'id': 'cashier', 'label': 'Cashier'},
    {'id': 'manager', 'label': 'Manager'},
    {'id': 'tenant_admin', 'label': 'Admin'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff['name'] ?? '');
    _phoneController = TextEditingController(text: widget.staff['phone'] ?? '');
    _designationController = TextEditingController(text: widget.staff['designation'] ?? 'Staff');
    _staffCodeController = TextEditingController(text: widget.staff['staff_code'] ?? 'STF');

    _selectedRole = widget.staff['role'] ?? 'staff';
    _selectedDepartment = _departments.contains(widget.staff['department'])
        ? widget.staff['department']
        : 'General';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _staffCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'designation': _designationController.text.trim(),
      'staff_code': _staffCodeController.text.trim(),
      'department': _selectedDepartment,
      'role': _selectedRole,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161622).withValues(alpha: 0.95),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Staff Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      'Editing details for ${widget.staff['email']}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _buildField(
                      label: 'Full Name *',
                      controller: _nameController,
                      hint: 'Staff name',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Phone & Staff Code
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Phone',
                            controller: _phoneController,
                            hint: '+6012...',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'Staff Code',
                            controller: _staffCodeController,
                            hint: 'STF-001',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Designation & Department
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Job Title / Designation',
                            controller: _designationController,
                            hint: 'Cashier / Barista',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text('Department', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ),
                              DropdownButtonFormField<String>(
                                value: _selectedDepartment,
                                dropdownColor: const Color(0xFF1E1E2C),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedDepartment = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Role
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Role & Permissions', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                    Row(
                      children: _roles.map((r) {
                        final isSelected = _selectedRole == r['id'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = r['id']!),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF42A5F5).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF42A5F5) : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  r['label']!,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF42A5F5) : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Update Staff Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
        ),
      ],
    );
  }
}
