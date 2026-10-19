import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/services/audit_service.dart';
import '../../../widgets/glass_toast.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSeverity = 'all'; // 'all', 'critical', 'warning', 'info'

  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    final results = await AuditService.getAuditLogs(
      severity: _selectedSeverity,
      searchQuery: _searchController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _logs = results;
        _loading = false;
      });
    }
  }

  Future<void> _recordTestLog() async {
    await AuditService.log(
      action: 'SECURITY_AUDIT_INIT',
      severity: 'info',
      description: 'Sistem audit keselamatan telah disahkan dan diaktifkan.',
    );
    if (mounted) {
      showGlassToast(context, 'Log audit permulaan berjaya direkodkan.');
    }
    _fetchLogs();
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'info':
      default:
        return const Color(0xFF42A5F5);
    }
  }

  IconData _getSeverityIcon(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Icons.gpp_bad_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
      default:
        return Icons.verified_user_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Audit Trails & Security Logs',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Muat Semula Log',
            onPressed: _fetchLogs,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _fetchLogs(),
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Cari staf, tindakan (cth: VOID, MFA, PRICE)...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchLogs();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Semua', 'all', Colors.white70),
                          const SizedBox(width: 8),
                          _buildFilterChip('Kritikal', 'critical', const Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          _buildFilterChip('Amaran', 'warning', const Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          _buildFilterChip('Informasi', 'info', const Color(0xFF42A5F5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Logs List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
                    : _logs.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _buildLogCard(_logs[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final selected = _selectedSeverity == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      side: BorderSide(color: selected ? color : Colors.white.withValues(alpha: 0.1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (bool isSelected) {
        if (isSelected) {
          setState(() => _selectedSeverity = value);
          _fetchLogs();
        }
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final severity = log['severity'] as String? ?? 'info';
    final severityColor = _getSeverityColor(severity);
    final icon = _getSeverityIcon(severity);
    final actorName = log['actor_name'] ?? 'System';
    final actorRole = log['actor_role'] ?? 'staff';
    final action = log['action'] ?? 'ACTION';
    final description = log['description'] ?? '';
    final createdAtStr = log['created_at'] as String?;
    final metadata = log['metadata'] as Map<String, dynamic>?;

    String formattedDate = '';
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = createdAtStr;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.25),
          width: 1.1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: severityColor, size: 16),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: Colors.white.withValues(alpha: 0.45), size: 14),
              const SizedBox(width: 4),
              Text(
                actorName,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  actorRole.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (metadata != null && metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Data: ${metadata.toString()}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedShield01,
                color: Color(0xFF42A5F5),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tiada Log Keselamatan Dijumpai',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Sebarang pengaktifan 2FA, pembatalan pesanan, perubahan harga atau pindaan staf akan direkodkan secara kekal di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _recordTestLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: const Text('Jana Log Percubaan (Test Log)'),
            ),
          ],
        ),
      ),
    );
  }
}
