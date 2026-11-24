import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/services/audit_service.dart';
import '../../../core/utils/file_saver/file_saver.dart';
import '../../../core/utils/ngam_ref.dart';
import '../../../widgets/glass_toast.dart';
import '../../../widgets/glass_nav_button.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSeverity = 'all'; // 'all', 'critical', 'warning', 'info'

  bool _loading = true;
  bool _isMissingTable = false;
  List<Map<String, dynamic>> _logs = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchLogs(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final results = await AuditService.getAuditLogs(
      severity: _selectedSeverity,
      searchQuery: _searchController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _logs = results;
        _isMissingTable = AuditService.isMissingTableError;
        _loading = false;
      });
    }
  }

  Future<void> _recordTestLog() async {
    final ok = await AuditService.log(
      action: 'SECURITY_AUDIT_INIT',
      severity: 'info',
      targetType: 'system',
      description: 'audit_logs.test_log_description'.tr(),
    );
    if (mounted) {
      showGlassToast(
        context,
        ok ? 'audit_logs.test_log_success'.tr() : 'audit_logs.test_log_failed'.tr(),
        isError: !ok,
      );
    }
    _fetchLogs();
  }

  Future<void> _exportCsv() async {
    if (_logs.isEmpty) {
      showGlassToast(context, 'audit_logs.export_csv_empty'.tr(), isError: true);
      return;
    }
    final csv = AuditService.buildCsv(_logs);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await saveAndDownloadCsv(
      csvContent: csv,
      fileName: 'Ngam_Audit_Logs_$stamp.csv',
    );
    if (mounted) {
      showGlassToast(context, 'audit_logs.export_csv_success'.tr());
    }
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

  String _formatTargetBadge(
    String targetType,
    String targetId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  ) {
    final explicit = (metadata?['target_label'] ??
            metadata?['order_ref'] ??
            metadata?['pos_ref'] ??
            metadata?['booking_ref'] ??
            metadata?['code'] ??
            metadata?['product_name'])
        ?.toString()
        .trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (targetId.isEmpty) return '';
    final typeLower = targetType.toLowerCase();
    if (typeLower == 'order') return NgamRef.order(targetId, createdAt: createdAt);
    if (typeLower == 'pos') return NgamRef.pos(targetId, createdAt);
    if (typeLower == 'booking') return NgamRef.booking(targetId, createdAt);
    if (targetId.length == 36 && targetId.contains('-')) {
      return targetId.substring(0, 8).toUpperCase();
    }
    return targetId.length > 22 ? '${targetId.substring(0, 20)}...' : targetId;
  }

  /// Extracts clean, human-readable key-value detail entries.
  /// When [explicitOnly] is true, only renders an explicit `metadata['details']` map
  /// so supplemental context (like void/cancellation reason) appears cleanly beneath a diff box.
  List<MapEntry<String, String>> _extractCleanDetails(
    Map<String, dynamic>? metadata, {
    bool explicitOnly = false,
  }) {
    if (metadata == null || metadata.isEmpty) return const [];
    const hiddenKeys = {
      'changes',
      'fields',
      'details',
      'target_label',
      'order_ref',
      'pos_ref',
      'booking_ref',
    };
    final out = <MapEntry<String, String>>[];

    final detailsMap = metadata['details'];
    if (detailsMap is Map) {
      for (final e in detailsMap.entries) {
        final k = e.key.toString();
        final v = e.value;
        if (v == null || v.toString().trim().isEmpty) continue;
        final formatted = AuditService.formatFieldValue(k, v);
        if (formatted == 'Kosong') continue;
        out.add(MapEntry(AuditService.labelForField(k), formatted));
      }
      return out;
    }

    if (explicitOnly) return const [];

    for (final e in metadata.entries) {
      final k = e.key.toString();
      if (hiddenKeys.contains(k)) continue;
      final v = e.value;
      if (v == null) continue;
      if (v is List && v.isEmpty) continue;
      if (v is Map && v.isEmpty) continue;
      final formatted = AuditService.formatFieldValue(k, v);
      if (formatted == 'Kosong') continue;
      out.add(MapEntry(AuditService.labelForField(k), formatted));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'audit_logs.title'.tr(),
      subtitle: 'audit_logs.subtitle'.tr(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 68),
              ),
              // Search, Filter & Export Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
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
                            const Icon(Icons.search_rounded, color: Colors.white54, size: 19),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => _fetchLogs(),
                                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: 'audit_logs.search_hint'.tr(),
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
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
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchLogs();
                                },
                              ),
                            IconButton(
                              tooltip: 'audit_logs.refresh_tooltip'.tr(),
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 19),
                              onPressed: () => _fetchLogs(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter Chips + Export CSV
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('audit_logs.filter_all'.tr(), 'all', Colors.white70),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('audit_logs.filter_critical'.tr(), 'critical', const Color(0xFFEF4444)),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('audit_logs.filter_warning'.tr(), 'warning', const Color(0xFFF59E0B)),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('audit_logs.filter_info'.tr(), 'info', const Color(0xFF42A5F5)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _exportCsv,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              'audit_logs.export_csv'.tr(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),

                      if (_isMissingTable) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'audit_logs.missing_table_title'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFFFBBF24),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'audit_logs.missing_table_desc'.tr(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 8),
              ),

              // Logs List
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5))),
                )
              else if (_logs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i.isOdd) return const SizedBox(height: 10);
                        final itemIdx = i ~/ 2;
                        return _buildLogCard(_logs[itemIdx]);
                      },
                      childCount: _logs.isEmpty ? 0 : (_logs.length * 2 - 1),
                    ),
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

  Widget _buildDiffComparisonBox(List<Map<String, String>> changes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, color: Color(0xFF38BDF8), size: 14),
              const SizedBox(width: 6),
              Text(
                'audit_logs.changes_header'.tr(args: [changes.length.toString()]),
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...changes.asMap().entries.map((entry) {
            final idx = entry.key;
            final c = entry.value;
            final label = c['label'] ?? '';
            final from = c['from'] ?? '';
            final to = c['to'] ?? '';

            return Padding(
              padding: EdgeInsets.only(bottom: idx == changes.length - 1 ? 0 : 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // BEFORE pill (soft red)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          from,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Colors.white54,
                      ),
                      // AFTER pill (soft emerald)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.34),
                          ),
                        ),
                        child: Text(
                          to,
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailsChipsBox(List<MapEntry<String, String>> details) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: details.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(7),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${e.key}: ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: e.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final severity = log['severity'] as String? ?? 'info';
    final severityColor = _getSeverityColor(severity);
    final icon = _getSeverityIcon(severity);
    final actorName = (log['actor_name'] ?? 'System').toString();
    final actorRole = (log['actor_role'] ?? 'staff').toString();
    final action = (log['action'] ?? 'ACTION').toString().toUpperCase();
    final description = (log['description'] ?? '').toString();
    final targetType = (log['target_type'] ?? '').toString();
    final targetId = (log['target_id'] ?? '').toString().trim();
    final createdAtStr = log['created_at'] as String?;
    final metadata = log['metadata'] is Map ? Map<String, dynamic>.from(log['metadata'] as Map) : null;

    DateTime? parsedCreatedAt;
    String formattedDate = '';
    if (createdAtStr != null) {
      try {
        parsedCreatedAt = DateTime.parse(createdAtStr).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsedCreatedAt);
      } catch (_) {
        formattedDate = createdAtStr;
      }
    }

    final changes = AuditService.extractChanges(metadata);
    final cleanDetails = _extractCleanDetails(metadata, explicitOnly: changes.isNotEmpty);
    final targetBadge = _formatTargetBadge(targetType, targetId, metadata, parsedCreatedAt);

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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    action,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline_rounded, color: Colors.white.withValues(alpha: 0.45), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    actorName,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
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
              if (targetBadge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'audit_logs.reference_badge'.tr(args: [targetBadge]),
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildDiffComparisonBox(changes),
          ],
          if (cleanDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailsChipsBox(cleanDetails),
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
            Text(
              'audit_logs.no_logs'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'audit_logs.no_logs_desc'.tr(),
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
              label: Text('audit_logs.generate_test_log'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
