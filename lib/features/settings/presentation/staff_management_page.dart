import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/services/ngam_teams_service.dart';
import '../../../widgets/glass_toast.dart';
import '../data/business_service.dart';
import '../../../widgets/glass_nav_button.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  final _businessService = BusinessService();

  late final TabController _tabController;

  bool _isLoading = true;
  String? _businessId;
  String _businessName = 'Your Business';
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _leaveList = [];
  List<Map<String, dynamic>> _attendanceList = [];
  List<Map<String, dynamic>> _announcementList = [];
  bool _isLoadingLeave = false;
  bool _isLoadingAttendance = false;
  bool _isLoadingAnnouncements = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadStaff();
    if (_businessId != null) {
      await Future.wait([
        _loadLeaves(),
        _loadAttendance(),
        _loadAnnouncements(),
      ]);
    }
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

  Future<void> _loadLeaves() async {
    if (_businessId == null) return;
    setState(() => _isLoadingLeave = true);
    try {
      final res = await _client
          .from('staff_leaves')
          .select()
          .eq('business_id', _businessId!)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _leaveList = (res as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
          _isLoadingLeave = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaves: $e');
      if (mounted) setState(() => _isLoadingLeave = false);
    }
  }

  Future<void> _loadAttendance() async {
    if (_businessId == null) return;
    setState(() => _isLoadingAttendance = true);
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await _client
          .from('staff_attendance')
          .select()
          .eq('business_id', _businessId!)
          .eq('date', todayStr)
          .order('check_in_time', ascending: false);
      if (mounted) {
        setState(() {
          _attendanceList = (res as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
          _isLoadingAttendance = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  Future<void> _loadAnnouncements() async {
    if (_businessId == null) return;
    setState(() => _isLoadingAnnouncements = true);
    try {
      final res = await _client
          .from('business_announcements')
          .select()
          .eq('business_id', _businessId!)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _announcementList = (res as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  Future<void> _addStaff(Map<String, dynamic> staffData) async {
    if (_businessId == null) {
      showGlassToast(context, 'common.error'.tr(), isError: true);
      return;
    }

    try {
      final email = (staffData['email'] as String).trim();

      // Guard duplicate email in team_members
      final existingMember = await _client
          .from('team_members')
          .select('id')
          .eq('business_id', _businessId!)
          .ilike('email', email)
          .maybeSingle();

      if (existingMember != null) {
        if (mounted) {
          showGlassToast(context, 'Anggota krew dengan e-mel ini sudah wujud.', isError: true);
        }
        return;
      }

      // Check if user already exists in auth.users by user_email to auto-link user_id
      String? matchedUserId;
      try {
        final userCheck = await _client
            .from('users')
            .select('id')
            .ilike('user_email', email)
            .maybeSingle();
        if (userCheck != null) {
          matchedUserId = userCheck['id'] as String?;
        }
      } catch (_) {}

      // Calculate max + 1 STF-XXX
      int maxNum = 0;
      final stfRegex = RegExp(r'STF-(\d+)', caseSensitive: false);
      for (final s in _staffList) {
        final code = s['staff_code']?.toString() ?? '';
        final match = stfRegex.firstMatch(code);
        if (match != null) {
          final n = int.tryParse(match.group(1) ?? '') ?? 0;
          if (n > maxNum) maxNum = n;
        }
      }
      final nextNum = maxNum > 0 ? maxNum + 1 : _staffList.length + 1;
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

      AuditService.log(
        action: 'STAFF_ADDED',
        severity: 'warning',
        targetType: 'staff',
        description: 'Staf baharu ditambah: ${staffData['name']} (${staffData['role']})',
        metadata: {'email': email, 'role': staffData['role'], 'department': staffData['department']},
      );

      if (mounted) {
        showGlassToast(
          context,
          'staff.staff_saved'.tr(),
        );
        _loadStaff();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal menambah staf: $e', isError: true);
      }
    }
  }

  Future<void> _updateStaff(String staffId, Map<String, dynamic> updates) async {
    try {
      await _client.from('team_members').update(updates).eq('id', staffId);

      AuditService.log(
        action: 'STAFF_UPDATED',
        severity: 'warning',
        targetType: 'staff',
        targetId: staffId,
        description: 'Maklumat staf ID $staffId telah dikemas kini',
        metadata: updates,
      );

      if (mounted) {
        showGlassToast(context, 'staff.staff_saved'.tr());
        _loadStaff();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal mengemas kini staf: $e', isError: true);
      }
    }
  }

  Future<void> _deleteStaff(String staffId, String staffName, [String? staffUserId, String? staffRole]) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (staffUserId != null && staffUserId == currentUserId) {
      showGlassToast(context, 'staff.cannot_remove_self'.tr(), isError: true);
      return;
    }
    if (staffRole == 'owner' || staffRole == 'tenant_admin') {
      final biz = await _businessService.getBusinessProfile();
      if (biz != null && biz['owner_user_id'] == staffUserId) {
        showGlassToast(context, 'staff.cannot_remove_owner'.tr(), isError: true);
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('staff.remove_staff'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'staff.remove_confirm'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('team_members').delete().eq('id', staffId);

      AuditService.log(
        action: 'STAFF_REMOVED',
        severity: 'critical',
        targetType: 'staff',
        targetId: staffId,
        description: 'Staf "$staffName" telah dikeluarkan daripada perniagaan',
      );

      if (mounted) {
        showGlassToast(context, 'staff.staff_removed'.tr());
        _loadStaff();
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'Gagal mengeluarkan staf: $e', isError: true);
    }
  }

  Future<void> _updateLeaveStatus(String leaveId, String status) async {
    try {
      final normalizedStatus = status.toLowerCase() == 'approved'
          ? 'Approved'
          : (status.toLowerCase() == 'rejected' ? 'Rejected' : 'Pending');
      await _client
          .from('staff_leaves')
          .update({
            'status': normalizedStatus,
            'approved_by': _client.auth.currentUser?.id,
          })
          .eq('id', leaveId);
      if (mounted) {
        showGlassToast(context, 'staff.leave_status_updated'.tr());
        _loadLeaves();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'staff.leave_status_failed'.tr(), isError: true);
      }
    }
  }

  Future<void> _addAnnouncement(String title, String content, String priority, bool isPinned) async {
    if (_businessId == null) return;
    try {
      String dbPriority = priority;
      if (!const ['Important', 'Info', 'Reminder', 'Notice'].contains(dbPriority)) {
        if (priority == 'high') {
          dbPriority = 'Important';
        } else if (priority == 'low') {
          dbPriority = 'Notice';
        } else {
          dbPriority = 'Info';
        }
      }

      await _client.from('business_announcements').insert({
        'business_id': _businessId!,
        'author_id': _client.auth.currentUser?.id,
        'author_name': 'Pengurusan',
        'title': title,
        'body': content,
        'priority': dbPriority,
        'is_pinned': isPinned,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send notification to linked staff with valid type: 'sistem'
      final linkedStaff = _staffList.where((s) => s['user_id'] != null).toList();
      for (final staff in linkedStaff) {
        final uid = staff['user_id'] as String?;
        if (uid != null) {
          try {
            await _client.from('notifications').insert({
              'user_id': uid,
              'business_id': _businessId,
              'title': title,
              'message': content,
              'type': 'sistem',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
        }
      }

      if (mounted) {
        showGlassToast(context, 'staff.announcement_posted'.tr());
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal menyiarkan pengumuman: $e', isError: true);
      }
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('common.confirm'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'staff.announcement_delete_confirm'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('business_announcements').delete().eq('id', id);
      if (mounted) {
        showGlassToast(context, 'Pengumuman berjaya dipadam.');
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memadam pengumuman: $e', isError: true);
      }
    }
  }

  String _getStaffName(String? userId) {
    if (userId == null) return 'Staf';
    final match = _staffList.firstWhere(
      (s) => s['user_id'] == userId,
      orElse: () => {'name': 'Staf'},
    );
    return match['name'] ?? 'Staf';
  }

  void _showAddAnnouncementModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAnnouncementSheet(
        onAdd: (title, content, priority, isPinned) {
          _addAnnouncement(title, content, priority, isPinned);
        },
      ),
    );
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
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height ||
        MediaQuery.of(context).size.width > 700;

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'staff.title'.tr(),
      subtitle: _businessName.isNotEmpty ? _businessName : 'staff.subtitle'.tr(),
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedSmartPhone01,
          tooltip: 'Hab Krew Ngam Teams',
          onTap: () => NgamTeamsService.showTeamsHubModal(context, businessName: _businessName),
        ),
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedTask01,
          tooltip: 'Audit Logs & Rekod Staf',
          onTap: () => context.push('/audit-logs'),
        ),
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedCoins01,
          tooltip: 'Urus Gaji & Komisen Staf',
          onTap: () => context.push('/payroll'),
        ),
      ],
      bottomTabBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF42A5F5),
          indicatorWeight: 2.5,
          labelColor: const Color(0xFF42A5F5),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: [
            Tab(text: 'staff.tab_crew'.tr()),
            Tab(text: 'staff.tab_leave'.tr()),
            Tab(text: 'staff.tab_attendance'.tr()),
            Tab(text: 'staff.tab_announcements'.tr()),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showInviteModal,
              backgroundColor: const Color(0xFF42A5F5),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01, color: Colors.white, size: 20),
              label: Text(
                'staff.add_staff'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : (_tabController.index == 3
              ? FloatingActionButton.extended(
                  onPressed: _showAddAnnouncementModal,
                  backgroundColor: const Color(0xFF42A5F5),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedNotification03, color: Colors.white, size: 20),
                  label: Text(
                    'staff.add_announcement'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              : null),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCrewTab(isLandscape),
                _buildLeaveTab(isLandscape),
                _buildAttendanceTab(isLandscape),
                _buildAnnouncementsTab(isLandscape),
              ],
            ),
    );
  }

  Widget _buildCrewTab(bool isLandscape) {
    return RefreshIndicator(
      color: const Color(0xFF42A5F5),
      onRefresh: _loadStaff,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 110, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNgamTeamsBanner(),
                  _buildLinkingGuideBanner(),
                ],
              ),
            ),
          ),
          if (_staffList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else if (isLandscape)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildStaffCard(_staffList[index]),
                  childCount: _staffList.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildStaffCard(_staffList[index]),
                  childCount: _staffList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveTab(bool isLandscape) {
    if (_isLoadingLeave) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
    }
    return RefreshIndicator(
      color: const Color(0xFF42A5F5),
      onRefresh: _loadLeaves,
      child: _leaveList.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.beach_access_outlined, color: Colors.white.withValues(alpha: 0.3), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'staff.no_leave_requests'.tr(),
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 110, 16, 120),
              itemCount: _leaveList.length,
              itemBuilder: (context, index) {
                final leave = _leaveList[index];
                final status = (leave['status'] as String? ?? 'pending').toLowerCase();
                final staffName = _getStaffName(leave['user_id']);
                final leaveType = leave['leave_type'] ?? 'Tahunan';
                final reason = leave['reason'] ?? '-';
                final dates = '${leave['start_date'] ?? ''} - ${leave['end_date'] ?? ''}';

                Color statusColor = const Color(0xFFF9C80E);
                String statusLabel = 'staff.leave_pending'.tr();
                if (status == 'approved') {
                  statusColor = const Color(0xFF44CF6C);
                  statusLabel = 'staff.leave_approved'.tr();
                } else if (status == 'rejected') {
                  statusColor = const Color(0xFFFF5252);
                  statusLabel = 'staff.leave_rejected'.tr();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              staffName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${'staff.leave_type'.tr()}: $leaveType  •  $dates',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${'staff.leave_reason'.tr()}: $reason',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF44CF6C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: Text('staff.leave_approve'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _updateLeaveStatus(leave['id'], 'approved'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF5252),
                                  side: const BorderSide(color: Color(0xFFFF5252)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: Text('staff.leave_reject'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _updateLeaveStatus(leave['id'], 'rejected'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAttendanceTab(bool isLandscape) {
    if (_isLoadingAttendance) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
    }
    return RefreshIndicator(
      color: const Color(0xFF42A5F5),
      onRefresh: _loadAttendance,
      child: _attendanceList.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'staff.no_attendance_records'.tr(),
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 110, 16, 120),
              itemCount: _attendanceList.length,
              itemBuilder: (context, index) {
                final record = _attendanceList[index];
                final staffName = _getStaffName(record['user_id']);
                final checkInRaw = record['check_in_time'] as String?;
                final checkOutRaw = record['check_out_time'] as String?;

                String checkInFormatted = '-';
                if (checkInRaw != null) {
                  try {
                    checkInFormatted = DateFormat('hh:mm a').format(DateTime.parse(checkInRaw).toLocal());
                  } catch (_) {
                    checkInFormatted = checkInRaw;
                  }
                }

                String checkOutFormatted = 'staff.attendance_not_out'.tr();
                if (checkOutRaw != null) {
                  try {
                    checkOutFormatted = DateFormat('hh:mm a').format(DateTime.parse(checkOutRaw).toLocal());
                  } catch (_) {
                    checkOutFormatted = checkOutRaw;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                        child: const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFF42A5F5), size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staffName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${'staff.attendance_in'.tr()}: $checkInFormatted  •  ${'staff.attendance_out'.tr()}: $checkOutFormatted',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (record['status'] as String? ?? 'Hadir').toUpperCase(),
                          style: const TextStyle(color: Color(0xFF44CF6C), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAnnouncementsTab(bool isLandscape) {
    if (_isLoadingAnnouncements) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
    }
    return RefreshIndicator(
      color: const Color(0xFF42A5F5),
      onRefresh: _loadAnnouncements,
      child: _announcementList.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined, color: Colors.white.withValues(alpha: 0.3), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'staff.no_announcements'.tr(),
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 110, 16, 120),
              itemCount: _announcementList.length,
              itemBuilder: (context, index) {
                final ann = _announcementList[index];
                final isPinned = ann['is_pinned'] == true;
                final priority = ann['priority'] as String? ?? 'Info';
                final createdRaw = ann['created_at'] as String?;
                String dateStr = '';
                if (createdRaw != null) {
                  try {
                    dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(createdRaw).toLocal());
                  } catch (_) {
                    dateStr = createdRaw;
                  }
                }

                Color pColor = const Color(0xFF42A5F5);
                if (priority == 'Important' || priority == 'high') pColor = const Color(0xFFFF5252);
                if (priority == 'Reminder') pColor = const Color(0xFFF9C80E);
                if (priority == 'Notice' || priority == 'low') pColor = Colors.white54;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPinned
                          ? const Color(0xFF42A5F5).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPinned) ...[
                            const Icon(Icons.push_pin, color: Color(0xFF42A5F5), size: 16),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              ann['title'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: pColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(color: pColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteAnnouncement(ann['id']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ann['body'] ?? ann['content'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNgamTeamsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.22),
            const Color(0xFF3B82F6).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  color: Color(0xFFA78BFA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aplikasi Operasi Krew Ngam Teams',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kakitangan anda menggunakan aplikasi Ngam Teams untuk tugasan harian, kehadiran & panggil giliran.',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3 Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    elevation: 0,
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSmartPhone01,
                    color: Colors.white,
                    size: 15,
                  ),
                  label: const Text(
                    'Buka App',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => NgamTeamsService.launchTeamsApp(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDownload04,
                    color: Colors.white70,
                    size: 15,
                  ),
                  label: const Text(
                    'Muat Turun',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => NgamTeamsService.openDownloadReleases(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedShare01,
                    color: Color(0xFF25D366),
                    size: 15,
                  ),
                  label: const Text(
                    'Jemput',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => NgamTeamsService.copyStaffInvite(context, businessName: _businessName),
                ),
              ),
            ],
          ),
        ],
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
                  'Pautan Krew Selamat & Tepat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Staf dipautkan secara automatik apabila log masuk menggunakan e-mel yang didaftarkan, ATAU kongsikan Kod Staf unik untuk dimasukkan dalam aplikasi Ngam Teams.',
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
              'Tiada Anggota Krew Lagi',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambah anggota pasukan anda di sini. Apabila mereka log masuk ke aplikasi Ngam Teams menggunakan e-mel, akaun mereka akan dipautkan secara automatik ke perniagaan anda.',
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
              label: Text('staff.add_staff'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final bool isLinked = staff['user_id'] != null;
    final String staffCode = staff['staff_code'] ?? 'STF';
    final String rawRole = (staff['role'] as String? ?? 'staff').toLowerCase();
    String displayRole = 'Staf';
    if (rawRole == 'cashier') {
      displayRole = 'staff.role_cashier'.tr();
    } else if (rawRole == 'manager') {
      displayRole = 'staff.role_manager'.tr();
    } else if (rawRole == 'owner') {
      displayRole = 'staff.role_owner'.tr();
    } else if (rawRole == 'tenant_admin') {
      displayRole = 'Pentadbir';
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Info Area (Tappable to Edit)
          InkWell(
            onTap: () => _showEditStaffModal(staff),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isLinked
                        ? const Color(0xFF44CF6C).withValues(alpha: 0.15)
                        : const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: isLinked ? const Color(0xFF44CF6C) : const Color(0xFF42A5F5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Staff Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Code
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                staff['name'] ?? 'Anggota Staf',
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        const SizedBox(height: 3),
                        Text(
                          '${staff['email'] ?? '-'} • $designation',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Badges Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Role Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                displayRole,
                                style: const TextStyle(
                                  color: Color(0xFF42A5F5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

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
                                    isLinked ? 'Ngam Teams Dipautkan' : 'Menunggu Log Masuk Pertama',
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
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),

          // 4 Action Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // 1. QR Code
                _buildStaffActionBtn(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedQrCode, color: Color(0xFFF9C80E), size: 15),
                  label: 'QR',
                  color: const Color(0xFFF9C80E),
                  tooltip: 'Kod QR & Pautan Pantas',
                  onTap: () => _showStaffQrModal(staff),
                ),
                const SizedBox(width: 6),

                // 2. Share Invite
                _buildStaffActionBtn(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare01, color: Color(0xFF2DD4BF), size: 15),
                  label: 'Jemput',
                  color: const Color(0xFF2DD4BF),
                  tooltip: 'Kongsi Jemputan & Kod Staf',
                  onTap: () => _copyStaffInvite(staff),
                ),
                const SizedBox(width: 6),

                // 3. Edit Info
                _buildStaffActionBtn(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit02, color: Color(0xFF42A5F5), size: 15),
                  label: 'Sunting',
                  color: const Color(0xFF42A5F5),
                  tooltip: 'Sunting Maklumat',
                  onTap: () => _showEditStaffModal(staff),
                ),
                const SizedBox(width: 6),

                // 4. Remove / Delete
                _buildStaffActionBtn(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 16),
                  label: 'Padam',
                  color: const Color(0xFFFF5252),
                  tooltip: 'Padam Staf',
                  onTap: () => _deleteStaff(staff['id'], staff['name'] ?? 'Staff', staff['user_id'], staff['role']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffActionBtn({
    required Widget icon,
    required String label,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
Halo $name! Anda telah ditambah sebagai krew/staf untuk "$biz" di aplikasi Ngam Teams.

📲 Muat Turun Aplikasi (Android APK):
${NgamTeamsService.apkDownloadUrl}

🔑 Kod Staf Anda: $code
📧 E-mel Berdaftar: $email

Cara Menyambung Mudah & Pantas:
1. Pasang aplikasi Ngam Teams menggunakan pautan di atas.
2. Log masuk menggunakan e-mel ($email), ATAU buka menu Profil dan tekan "Enter Staff Code to Connect" lalu masukkan kod: $code.
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
    {'id': 'staff', 'label': 'Staf'},
    {'id': 'cashier', 'label': 'Juruwang'},
    {'id': 'manager', 'label': 'Pengurus'},
    {'id': 'tenant_admin', 'label': 'Pentadbir'},
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
                        Text(
                          'staff.add_staff'.tr(),
                          style: const TextStyle(
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
                      'Apabila anggota staf log masuk ke aplikasi Ngam Teams menggunakan e-mel ini, akaun akan dipautkan secara automatik ke perniagaan anda.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _buildField(
                      label: '${'staff.staff_name'.tr()} *',
                      controller: _nameController,
                      hint: 'cth: Nur Aisyah',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    _buildField(
                      label: '${'staff.staff_email'.tr()} *',
                      controller: _emailController,
                      hint: 'cth: staf@ngam.dev',
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'E-mel wajib diisi';
                        if (!val.contains('@')) return 'Sila masukkan alamat e-mel yang sah';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phone & Staff Code
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'staff.staff_phone'.tr(),
                            controller: _phoneController,
                            hint: '+6012...',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'staff.staff_code'.tr(),
                            controller: _staffCodeController,
                            hint: 'cth: STF-001',
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
                            label: 'Jawatan / Peranan Khusus',
                            controller: _designationController,
                            hint: 'cth: Juruwang / Barista',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text('Jabatan', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('staff.role'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                        child: Text(
                          'common.save'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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
    {'id': 'staff', 'label': 'Staf'},
    {'id': 'cashier', 'label': 'Juruwang'},
    {'id': 'manager', 'label': 'Pengurus'},
    {'id': 'tenant_admin', 'label': 'Pentadbir'},
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
                        Text(
                          'staff.edit_staff'.tr(),
                          style: const TextStyle(
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
                      'Menyunting maklumat untuk ${widget.staff['email']}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _buildField(
                      label: '${'staff.staff_name'.tr()} *',
                      controller: _nameController,
                      hint: 'Nama staf',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    // Phone & Staff Code
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'staff.staff_phone'.tr(),
                            controller: _phoneController,
                            hint: '+6012...',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'staff.staff_code'.tr(),
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
                            label: 'Jawatan / Peranan Khusus',
                            controller: _designationController,
                            hint: 'Juruwang / Barista',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text('Jabatan', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('staff.role'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                        child: Text(
                          'common.save'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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

class _AddAnnouncementSheet extends StatefulWidget {
  final void Function(String title, String content, String priority, bool isPinned) onAdd;
  const _AddAnnouncementSheet({required this.onAdd});

  @override
  State<_AddAnnouncementSheet> createState() => _AddAnnouncementSheetState();
}

class _AddAnnouncementSheetState extends State<_AddAnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String _priority = 'Info';
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAdd(
      _titleController.text.trim(),
      _contentController.text.trim(),
      _priority,
      _isPinned,
    );
    Navigator.pop(context);
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
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
                        Text(
                          'staff.add_announcement'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'staff.announcement_title'.tr(),
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'staff.announcement_content'.tr(),
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            dropdownColor: const Color(0xFF1E1E2C),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'staff.announcement_priority'.tr(),
                              labelStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Info', child: Text('Maklumat (Info)')),
                              DropdownMenuItem(value: 'Important', child: Text('Penting / Mustahak')),
                              DropdownMenuItem(value: 'Reminder', child: Text('Peringatan')),
                              DropdownMenuItem(value: 'Notice', child: Text('Notis')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _priority = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Row(
                          children: [
                            const Text('Sematkan', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Switch(
                              value: _isPinned,
                              activeColor: const Color(0xFF42A5F5),
                              onChanged: (val) => setState(() => _isPinned = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text('common.submit'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
}

