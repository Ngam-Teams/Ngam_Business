import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/file_saver/file_saver.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';

// ============================================================
// CustomerInsightsPage — Loyal Customers & VIP Tiers
// ============================================================

class CustomerInsightsPage extends StatefulWidget {
  const CustomerInsightsPage({super.key});

  @override
  State<CustomerInsightsPage> createState() => _CustomerInsightsPageState();
}

class _CustomerInsightsPageState extends State<CustomerInsightsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  bool _isSendingVoucher = false;
  String? _businessId;
  String _businessName = 'Ngam Business';

  @override
  void initState() {
    super.initState();
    _loadLiveCustomers();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-]'), '').trim();
  }

  DateTime? _parseLatestDate(DateTime? current, dynamic rawIso) {
    if (rawIso == null) return current;
    final parsed = DateTime.tryParse(rawIso.toString())?.toLocal();
    if (parsed == null) return current;
    if (current == null || parsed.isAfter(current)) return parsed;
    return current;
  }

  String _computeTierKey(double totalSpent, int visits) {
    if (totalSpent >= 500 || visits >= 15) return 'gold';
    if (totalSpent >= 200 || visits >= 5) return 'silver';
    return 'regular';
  }

  String _tierLabel(String tierKey) {
    switch (tierKey) {
      case 'gold':
        return 'customers.tier_gold'.tr();
      case 'silver':
        return 'customers.tier_silver'.tr();
      default:
        return 'customers.tier_regular'.tr();
    }
  }

  Color _tierColor(String tierKey) {
    switch (tierKey) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return const Color(0xFF42A5F5);
      default:
        return Colors.white54;
    }
  }

  String _formatLastVisit(Map<String, dynamic> cust) {
    final dt = cust['lastVisitAt'] as DateTime?;
    if (dt != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(dt.year, dt.month, dt.day);
      final diffDays = today.difference(target).inDays;
      if (diffDays <= 0) return 'customers.today_label'.tr();
      if (diffDays == 1) return 'customers.yesterday_label'.tr();
      return 'customers.days_ago'.tr(args: ['$diffDays']);
    }
    if (cust['hasLoyaltyCard'] == true) {
      return 'customers.loyalty_member_label'.tr();
    }
    return 'customers.recent_label'.tr();
  }

  Future<void> _loadLiveCustomers() async {
    try {
      final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
      final businessId = profile?['id']?.toString();
      if (businessId == null || businessId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _businessId = businessId;
      _businessName = (profile?['business_name'] ?? 'Ngam Business').toString();

      final results = await Future.wait([
        Supabase.instance.client
            .from('customer_loyalty_cards')
            .select('id, customer_name, customer_phone, current_stamps, last_stamped_at, created_at')
            .eq('business_id', businessId),
        Supabase.instance.client
            .from('orders')
            .select('id, owner_user_id, customer_id, customer_name, source, total, status, created_at')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(200),
        Supabase.instance.client
            .from('bookings')
            .select('id, customer_id, customer_name, total_price, status, booking_metadata, created_at')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(200),
      ]);

      final cards = (results[0] as List?) ?? [];
      final orders = (results[1] as List?) ?? [];
      final bookings = (results[2] as List?) ?? [];

      // Collect customer UUIDs for user contact lookup
      final Set<String> customerIds = {};
      for (final o in orders) {
        final cid = o['customer_id']?.toString().trim() ?? '';
        final oid = o['owner_user_id']?.toString().trim() ?? '';
        final src = (o['source'] ?? '').toString().toLowerCase();
        final effectiveUid = cid.isNotEmpty ? cid : (src != 'pos' ? oid : '');
        if (effectiveUid.isNotEmpty) customerIds.add(effectiveUid);
      }
      for (final b in bookings) {
        final cid = b['customer_id']?.toString().trim() ?? '';
        if (cid.isNotEmpty) customerIds.add(cid);
      }

      final Map<String, Map<String, dynamic>> usersMap = {};
      if (customerIds.isNotEmpty) {
        try {
          final usersRes = await Supabase.instance.client
              .from('users')
              .select('id, user_name, user_phone')
              .inFilter('id', customerIds.toList());
          for (final u in (usersRes as List? ?? [])) {
            final uid = u['id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              usersMap[uid] = Map<String, dynamic>.from(u as Map);
            }
          }
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> agg = {};

      String resolveKey(String phone, String customerId, String name) {
        final normPhone = _normalizePhone(phone);
        if (normPhone.isNotEmpty) return 'ph:$normPhone';
        if (customerId.isNotEmpty) return 'uid:$customerId';
        return 'name:${name.toLowerCase()}';
      }

      for (final c in cards) {
        final rawPhone = (c['customer_phone'] ?? '').toString().trim();
        final name = (c['customer_name'] ?? '').toString().trim();
        if (rawPhone.isEmpty && name.isEmpty) continue;
        final key = resolveKey(rawPhone, '', name);
        final stamps = (c['current_stamps'] as num?)?.toInt() ?? 0;
        final lastDt = _parseLatestDate(null, c['last_stamped_at'] ?? c['created_at']);

        agg[key] = {
          'id': c['id']?.toString() ?? 'CUST-${agg.length + 1}',
          'customerId': '',
          'name': name.isNotEmpty ? name : rawPhone,
          'phone': rawPhone.isNotEmpty ? rawPhone : '-',
          'visits': stamps > 0 ? stamps : 1,
          'stamps': stamps,
          'totalSpent': 0.0,
          'lastVisitAt': lastDt,
          'hasLoyaltyCard': true,
          'tierKey': _computeTierKey(0.0, stamps > 0 ? stamps : 1),
        };
      }

      void mergeVisit({
        required String customerId,
        required String rawName,
        required String rawPhone,
        required double amount,
        required dynamic createdAt,
      }) {
        if (rawName.isEmpty && rawPhone.isEmpty && customerId.isEmpty) return;

        // Try matching an existing entry by phone, customerId, or lowercase name
        String? matchedKey;
        final normPhone = _normalizePhone(rawPhone);
        if (normPhone.isNotEmpty && agg.containsKey('ph:$normPhone')) {
          matchedKey = 'ph:$normPhone';
        } else if (customerId.isNotEmpty && agg.containsKey('uid:$customerId')) {
          matchedKey = 'uid:$customerId';
        } else if (rawName.isNotEmpty && agg.containsKey('name:${rawName.toLowerCase()}')) {
          matchedKey = 'name:${rawName.toLowerCase()}';
        } else if (normPhone.isNotEmpty || rawName.isNotEmpty) {
          for (final entry in agg.entries) {
            final existingPhone = _normalizePhone((entry.value['phone'] ?? '').toString());
            final existingName = (entry.value['name'] ?? '').toString().trim().toLowerCase();
            if (normPhone.isNotEmpty && existingPhone == normPhone) {
              matchedKey = entry.key;
              break;
            }
            if (rawName.isNotEmpty && existingName == rawName.toLowerCase()) {
              matchedKey = entry.key;
              break;
            }
          }
        }

        final key = matchedKey ?? resolveKey(rawPhone, customerId, rawName);
        final entry = agg.putIfAbsent(
          key,
          () => {
            'id': 'CUST-${agg.length + 1}',
            'customerId': customerId,
            'name': rawName.isNotEmpty
                ? rawName
                : (rawPhone.isNotEmpty ? rawPhone : 'customers.fallback_customer'.tr()),
            'phone': rawPhone.isNotEmpty ? rawPhone : '-',
            'visits': 0,
            'stamps': 0,
            'totalSpent': 0.0,
            'lastVisitAt': null,
            'hasLoyaltyCard': false,
            'tierKey': 'regular',
          },
        );

        if ((entry['customerId'] ?? '').toString().isEmpty && customerId.isNotEmpty) {
          entry['customerId'] = customerId;
        }
        if ((entry['phone'] == '-' || (entry['phone'] ?? '').toString().isEmpty) && rawPhone.isNotEmpty) {
          entry['phone'] = rawPhone;
        }
        if ((entry['name'] == 'customers.fallback_customer'.tr()) && rawName.isNotEmpty) {
          entry['name'] = rawName;
        }

        final nextVisits = (entry['visits'] as int) + 1;
        final nextSpent = (entry['totalSpent'] as double) + amount;
        entry['visits'] = nextVisits;
        entry['totalSpent'] = nextSpent;
        entry['lastVisitAt'] = _parseLatestDate(entry['lastVisitAt'] as DateTime?, createdAt);
        entry['tierKey'] = _computeTierKey(nextSpent, nextVisits);
      }

      for (final o in orders) {
        final st = (o['status'] ?? '').toString().toLowerCase();
        if (st == 'cancelled' || st == 'refunded') continue;
        final cid = o['customer_id']?.toString().trim() ?? '';
        final oid = o['owner_user_id']?.toString().trim() ?? '';
        final src = (o['source'] ?? '').toString().toLowerCase();
        final effectiveUid = cid.isNotEmpty ? cid : (src != 'pos' ? oid : '');
        final user = effectiveUid.isNotEmpty ? usersMap[effectiveUid] : null;
        final name = (o['customer_name'] ?? user?['user_name'] ?? '').toString().trim();
        final phone = (user?['user_phone'] ?? '').toString().trim();
        final amt = (o['total'] as num?)?.toDouble() ?? 0.0;
        mergeVisit(
          customerId: effectiveUid,
          rawName: name,
          rawPhone: phone,
          amount: amt,
          createdAt: o['created_at'],
        );
      }

      for (final b in bookings) {
        final st = (b['status'] ?? '').toString().toLowerCase();
        if (st == 'cancelled' || st == 'holding' || st == 'rejected') continue;
        final cid = b['customer_id']?.toString().trim() ?? '';
        final user = cid.isNotEmpty ? usersMap[cid] : null;
        final meta = b['booking_metadata'] is Map
            ? Map<String, dynamic>.from(b['booking_metadata'] as Map)
            : <String, dynamic>{};
        final name = (b['customer_name'] ?? meta['customer_name'] ?? user?['user_name'] ?? '').toString().trim();
        final phone = (meta['phone'] ?? meta['customer_phone'] ?? user?['user_phone'] ?? '').toString().trim();
        final amt = (b['total_price'] as num?)?.toDouble() ?? 0.0;
        mergeVisit(
          customerId: cid,
          rawName: name,
          rawPhone: phone,
          amount: amt,
          createdAt: b['created_at'],
        );
      }

      final list = agg.values.toList()
        ..sort((a, b) {
          final cmpSpend = (b['totalSpent'] as double).compareTo(a['totalSpent'] as double);
          if (cmpSpend != 0) return cmpSpend;
          return (b['visits'] as int).compareTo(a['visits'] as int);
        });

      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      final name = c['name'].toString().toLowerCase();
      final phone = c['phone'].toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _sendPerk(Map<String, dynamic> customer) async {
    if (_isSendingVoucher) return;
    final bizId = _businessId;
    if (bizId == null || bizId.isEmpty) {
      showGlassToast(context, 'customers.voucher_create_failed'.tr(), isError: true);
      return;
    }

    setState(() => _isSendingVoucher = true);
    try {
      final custName = (customer['name'] ?? 'customers.fallback_customer'.tr()).toString();
      final randSuffix = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final code = 'VIP10$randSuffix';

      await Supabase.instance.client.from('vouchers').insert({
        'business_id': bizId,
        'code': code,
        'title': 'customers.voucher_title'.tr(args: [custName]),
        'description': 'customers.voucher_desc'.tr(args: [_businessName]),
        'discount_type': 'fixed_amount',
        'discount_value': 10.0,
        'min_spend': 20.0,
        'total_usage_limit': 1,
        'usage_limit_per_user': 1,
        'start_date': DateTime.now().toUtc().toIso8601String(),
        'end_date': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
        'applicable_scope': 'all',
        'customer_eligibility': 'all',
        'is_active': true,
      });

      final customerId = (customer['customerId'] ?? '').toString().trim();
      if (customerId.isNotEmpty) {
        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': customerId,
            'business_id': bizId,
            'title': 'customers.notif_voucher_title'.tr(args: [_businessName]),
            'message': 'customers.notif_voucher_msg'.tr(args: [code]),
            'type': 'sistem',
            'reference_id': code,
            'is_read': false,
          });
        } catch (_) {}
      }

      if (mounted) {
        showGlassToast(context, 'customers.voucher_sent_toast'.tr(args: [code, custName]));
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'customers.voucher_create_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSendingVoucher = false);
    }
  }

  Future<void> _exportCustomerCsv() async {
    showGlassToast(context, 'export.preparing'.tr());
    try {
      final bizService = BusinessService();
      final profile = await bizService.getBusinessProfile();
      final bizName = profile?['business_name']?.toString() ?? 'Perniagaan Ngam';

      final fmt = DateFormat('yyyy-MM-dd_HHmm');
      final nowStr = fmt.format(DateTime.now());

      final buffer = StringBuffer();
      buffer.writeln('SENARAI PELANGGAN & STATUS KEAHLIAN - $bizName');
      buffer.writeln('Tarikh Dijana: ${DateTime.now().toLocal()}');
      buffer.writeln('Jumlah Pelanggan: ${_customers.length}');
      buffer.writeln('');
      buffer.writeln('ID_Pelanggan,Nama_Pelanggan,Nombor_Telefon,Kategori_Status,Jumlah_Pesanan,Jumlah_Belanja_RM,Mata_Ganjaran_Cop,Kunjungan_Terakhir');

      for (final c in _customers) {
        final id = (c['id'] ?? '-').toString().replaceAll(',', ' ');
        final name = (c['name'] ?? 'Pelanggan').toString().replaceAll(',', ' ');
        final phone = (c['phone'] ?? '-').toString().replaceAll(',', ' ');
        final tier = _tierLabel((c['tierKey'] ?? 'regular').toString()).replaceAll(',', ' ');
        final visits = c['visits'] ?? 0;
        final spent = ((c['totalSpent'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
        final stamps = c['stamps'] ?? 0;
        final last = _formatLastVisit(c).replaceAll(',', ' ');

        buffer.writeln('$id,$name,$phone,$tier,$visits,$spent,$stamps,$last');
      }

      await saveAndDownloadCsv(
        csvContent: buffer.toString(),
        fileName: 'Senarai_Pelanggan_VIP_$nowStr.csv',
      );

      if (mounted) {
        showGlassToast(context, 'export.csv_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'export.export_failed'.tr(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _customers.length;
    final repeatCount = _customers.where((c) => (c['visits'] as int? ?? 0) >= 2).length;
    final repeatRate = totalCount > 0 ? ((repeatCount / totalCount) * 100).round() : 0;
    final totalRevenue = _customers.fold<double>(
      0.0,
      (sum, c) => sum + ((c['totalSpent'] as num?)?.toDouble() ?? 0.0),
    );
    final avgSpend = totalCount > 0 ? totalRevenue / totalCount : 0.0;

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'customers.title'.tr(),
      subtitle: 'customers.subtitle'.tr(),
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedDownload01,
          tooltip: 'export.customers_title'.tr(),
          onTap: _exportCustomerCsv,
        ),
      ],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 68),
          ),
          // Top Stat Summary Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'customers.total_customers'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCount',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'customers.returning_rate'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$repeatRate%',
                            style: const TextStyle(color: Color(0xFF44CF6C), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'customers.avg_spend'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${avgSpend.toStringAsFixed(totalCount > 0 && avgSpend < 100 ? 2 : 0)}',
                            style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'customers.search_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

          // Customer List
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              ),
            )
          else if (_filteredCustomers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 14),
                      Text(
                        'customers.no_customers'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'customers.no_customers_desc'.tr(),
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cust = _filteredCustomers[index];
                    final tierKey = (cust['tierKey'] ?? 'regular').toString();
                    final tierCol = _tierColor(tierKey);
                    final tierLabel = _tierLabel(tierKey);
                    final visits = (cust['visits'] as num?)?.toInt() ?? 0;
                    final spentStr = ((cust['totalSpent'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                    final lastVisitText = _formatLastVisit(cust);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: tierCol.withValues(alpha: 0.15),
                                child: Icon(Icons.person, color: tierCol, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            (cust['name'] ?? 'customers.fallback_customer'.tr()).toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: tierCol.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tierLabel,
                                            style: TextStyle(color: tierCol, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (cust['phone'] ?? '-').toString(),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF42A5F5), size: 22),
                                tooltip: 'customers.send_vip_voucher'.tr(),
                                onPressed: _isSendingVoucher ? null : () => _sendPerk(cust),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'customers.visits_and_spent'.tr(args: ['$visits', spentStr]),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                'customers.last_label'.tr(args: [lastVisitText]),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: _filteredCustomers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
