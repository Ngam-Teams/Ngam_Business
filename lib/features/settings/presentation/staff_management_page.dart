import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  // Mock data for MVP
  final List<Map<String, dynamic>> _staffList = [
    {
      'name': 'Ahmad Faizal',
      'role': 'Admin',
      'email': 'ahmad@example.com',
      'status': 'Active',
    },
    {
      'name': 'Siti Nurhaliza',
      'role': 'Cashier',
      'email': 'siti@example.com',
      'status': 'Active',
    },
    {
      'name': 'Muthu Kumar',
      'role': 'Cashier',
      'email': 'muthu@example.com',
      'status': 'Pending Invite',
    },
  ];

  void _showInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InviteStaffSheet(),
    ).then((value) {
      if (value != null && value is Map<String, dynamic>) {
        setState(() {
          _staffList.add({
            'name': 'Pending User',
            'role': value['role'],
            'email': value['email'],
            'status': 'Pending Invite',
          });
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${value['email']}'),
            backgroundColor: const Color(0xFF42A5F5),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Staff Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteModal,
        backgroundColor: const Color(0xFF42A5F5),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedMailSend01, color: Colors.white, size: 20),
        label: const Text('Invite Staff', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16).copyWith(bottom: 100),
        itemCount: _staffList.length,
        itemBuilder: (context, index) {
          final staff = _staffList[index];
          return _buildStaffCard(staff);
        },
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final bool isPending = staff['status'] == 'Pending Invite';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            color: const Color(0xFF42A5F5),
            size: 20,
          ),
        ),
        title: Text(
          staff['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              staff['email'],
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    staff['role'],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending 
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    staff['status'],
                    style: TextStyle(
                      color: isPending ? Colors.orangeAccent : Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
        trailing: IconButton(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVerticalCircle01, color: Colors.white54),
          onPressed: () {
            // Placeholder for edit/delete
          },
        ),
      ),
    );
  }
}

class _InviteStaffSheet extends StatefulWidget {
  const _InviteStaffSheet();

  @override
  State<_InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends State<_InviteStaffSheet> {
  final _emailController = TextEditingController();
  String _selectedRole = 'Cashier';

  void _sendInvite() {
    if (_emailController.text.isEmpty) return;
    Navigator.pop(context, {
      'email': _emailController.text.trim(),
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
              color: const Color(0xFF1A1A24).withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite Staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: HugeIcon(icon: HugeIcons.strokeRoundedMail01, color: Colors.white54, size: 20),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF42A5F5))),
                  ),
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      dropdownColor: const Color(0xFF1A1A24),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: Colors.white54, size: 18),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: ['Admin', 'Cashier', 'Manager'].map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedRole = v);
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _sendInvite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Send Invitation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
