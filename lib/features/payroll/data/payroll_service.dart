import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/data/business_service.dart';
import '../models/staff_payroll_model.dart';

class PayrollService {
  final SupabaseClient _client;
  final BusinessService _businessService;

  // Local fallback storage for demo & offline
  static final Map<String, StaffPayrollSetting> _localSettings = {};
  static final List<MonthlyPayrollItem> _localCurrentPayroll = [];

  /// Reset in-memory cached payroll data (e.g. on sign out)
  static void reset() {
    _localSettings.clear();
    _localCurrentPayroll.clear();
  }

  PayrollService({SupabaseClient? client, BusinessService? businessService})
      : _client = client ?? Supabase.instance.client,
        _businessService = businessService ?? BusinessService(client: client ?? Supabase.instance.client);

  Future<String?> _getShopId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id'];
  }

  /// Fetches compensation settings for all active staff in the business
  Future<List<StaffPayrollSetting>> fetchStaffPayrollSettings() async {
    final businessId = await _getShopId();
    if (businessId == null) return _localSettings.values.toList();

    try {
      // 1. Fetch team members
      final membersRes = await _client
          .from('team_members')
          .select()
          .eq('business_id', businessId)
          .eq('status', 'active');

      final members = (membersRes as List).cast<Map<String, dynamic>>();

      // 2. Fetch saved compensation settings from DB
      final dbSettingsRes = await _client
          .from('staff_payroll_settings')
          .select()
          .eq('business_id', businessId);
      final Map<String, Map<String, dynamic>> dbMap = {};
      for (final row in (dbSettingsRes as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map['staff_id'] != null) {
          dbMap[map['staff_id'] as String] = map;
        }
      }

      final List<StaffPayrollSetting> results = [];
      for (final m in members) {
        final id = m['id'] as String;
        if (_localSettings.containsKey(id)) {
          results.add(_localSettings[id]!);
        } else if (dbMap.containsKey(id)) {
          final merged = {
            ...dbMap[id]!,
            'staff_name': m['name'] ?? dbMap[id]!['staff_name'] ?? 'Staff',
            'staff_code': m['staff_code'] ?? dbMap[id]!['staff_code'] ?? 'STF-001',
            'designation': m['designation'] ?? dbMap[id]!['designation'] ?? 'Staff',
          };
          final setting = StaffPayrollSetting.fromJson(merged);
          _localSettings[id] = setting;
          results.add(setting);
        } else {
          final setting = StaffPayrollSetting(
            staffId: id,
            staffName: m['name'] as String? ?? 'Staff',
            staffCode: m['staff_code'] as String? ?? 'STF-001',
            designation: m['designation'] as String? ?? 'Krew',
            baseSalary: 0.0,
            serviceCommissionRate: 0.0,
            productCommissionRate: 0.0,
            epfEnabled: false,
            socsoEnabled: false,
            eisEnabled: false,
            bankName: null,
            bankAccountNumber: null,
          );
          _localSettings[id] = setting;
          results.add(setting);
        }
      }
      return results;
    } catch (_) {
      return _localSettings.values.toList();
    }
  }

  /// Updates compensation settings for a staff member
  Future<void> updateStaffPayrollSetting(StaffPayrollSetting setting) async {
    _localSettings[setting.staffId] = setting;

    try {
      final businessId = await _getShopId();
      if (businessId == null) return;

      await _client.from('staff_payroll_settings').upsert(
        {
          'business_id': businessId,
          ...setting.toDbJson(),
        },
        onConflict: 'business_id,staff_id',
      );
    } catch (_) {
      // Silently fall back to in-memory
    }
  }

  /// Generates the live monthly payroll run with calculated commissions from real sales
  Future<List<MonthlyPayrollItem>> generateMonthlyPayroll() async {
    if (_localCurrentPayroll.isNotEmpty) {
      return List.from(_localCurrentPayroll);
    }

    final businessId = await _getShopId();
    final settings = await fetchStaffPayrollSettings();
    final List<MonthlyPayrollItem> list = [];

    // Query real completed bookings and orders this month to compute exact commissions
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final Map<String, double> staffServiceSales = {};
    final Map<String, double> staffProductSales = {};

    if (businessId != null) {
      try {
        final bookingsRes = await _client
            .from('bookings')
            .select('staff_id, total_price, status, created_at')
            .eq('business_id', businessId)
            .eq('status', 'completed')
            .gte('created_at', startOfMonth);
        for (final b in (bookingsRes as List)) {
          final sid = b['staff_id'] as String?;
          final amt = (b['total_price'] as num?)?.toDouble() ?? 0.0;
          if (sid != null) {
            staffServiceSales[sid] = (staffServiceSales[sid] ?? 0.0) + amt;
          }
        }
      } catch (_) {}

      try {
        final membersRes = await _client
            .from('team_members')
            .select('id, user_id')
            .eq('business_id', businessId)
            .eq('status', 'active');
        final Map<String, String> userIdToStaffId = {};
        for (final m in (membersRes as List)) {
          final uid = m['user_id'] as String?;
          final sid = m['id'] as String?;
          if (uid != null && sid != null) {
            userIdToStaffId[uid] = sid;
          }
        }

        final ordersRes = await _client
            .from('orders')
            .select('owner_user_id, total, status, created_at')
            .eq('business_id', businessId)
            .eq('status', 'completed')
            .gte('created_at', startOfMonth);
        for (final o in (ordersRes as List)) {
          final uid = o['owner_user_id'] as String?;
          final sid = uid != null ? userIdToStaffId[uid] : null;
          final amt = (o['total'] as num?)?.toDouble() ?? 0.0;
          if (sid != null) {
            staffProductSales[sid] = (staffProductSales[sid] ?? 0.0) + amt;
          }
        }
      } catch (_) {}
    }

    for (final s in settings) {
      final totalServiceSales = staffServiceSales[s.staffId] ?? 0.0;
      final totalProductSales = staffProductSales[s.staffId] ?? 0.0;
      final serviceComm = totalServiceSales * (s.serviceCommissionRate / 100.0);
      final productComm = totalProductSales * (s.productCommissionRate / 100.0);

      list.add(
        MonthlyPayrollItem(
          staffId: s.staffId,
          staffName: s.staffName,
          staffCode: s.staffCode,
          designation: s.designation,
          baseSalary: s.baseSalary,
          serviceCommission: serviceComm,
          productCommission: productComm,
          overtimePay: 0.0,
          tipsShare: 0.0,
          bonusOrAllowance: 0.0,
          penaltyOrDeduction: 0.0,
          epfEnabled: s.epfEnabled,
          socsoEnabled: s.socsoEnabled,
          eisEnabled: s.eisEnabled,
          bankName: s.bankName,
          bankAccountNumber: s.bankAccountNumber,
          status: 'draft',
        ),
      );
    }

    _localCurrentPayroll.clear();
    _localCurrentPayroll.addAll(list);
    return list;
  }

  /// Updates adjustments for a monthly payroll item (bonus, deduction, OT)
  void updatePayrollItem(MonthlyPayrollItem item) {
    final idx = _localCurrentPayroll.indexWhere((p) => p.staffId == item.staffId);
    if (idx != -1) {
      _localCurrentPayroll[idx] = item;
    }
  }

  /// Approves the monthly payroll and issues digital payslips
  Future<void> approveMonthlyPayroll() async {
    for (int i = 0; i < _localCurrentPayroll.length; i++) {
      _localCurrentPayroll[i] = _localCurrentPayroll[i].copyWith(status: 'approved');
    }

    try {
      final businessId = await _getShopId();
      if (businessId != null) {
        final now = DateTime.now();
        final existing = await _client
            .from('monthly_payrolls')
            .select('id')
            .eq('business_id', businessId)
            .eq('month', now.month)
            .eq('year', now.year)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (existing != null) {
          await _client.from('monthly_payrolls').update({
            'total_amount': _localCurrentPayroll.fold(0.0, (s, i) => s + i.netPay),
            'status': 'approved',
          }).eq('id', existing['id']);
        } else {
          await _client.from('monthly_payrolls').insert({
            'business_id': businessId,
            'month': now.month,
            'year': now.year,
            'total_amount': _localCurrentPayroll.fold(0.0, (s, i) => s + i.netPay),
            'status': 'approved',
            'created_at': now.toIso8601String(),
          });
        }
      }
    } catch (_) {}
  }
}
