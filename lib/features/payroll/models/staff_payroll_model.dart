// =============================================================================
// StaffPayrollModel — Payroll compensation, commission formulas & monthly runs
// =============================================================================

class StaffPayrollSetting {
  final String staffId;
  final String staffName;
  final String staffCode;
  final String designation;
  final double baseSalary;
  final double serviceCommissionRate; // e.g. 35.0 = 35%
  final double productCommissionRate; // e.g. 10.0 = 10%
  final bool epfEnabled;
  final bool socsoEnabled;
  final bool eisEnabled;
  final String? bankName;
  final String? bankAccountNumber;

  const StaffPayrollSetting({
    required this.staffId,
    required this.staffName,
    required this.staffCode,
    required this.designation,
    this.baseSalary = 1800.0,
    this.serviceCommissionRate = 35.0,
    this.productCommissionRate = 10.0,
    this.epfEnabled = true,
    this.socsoEnabled = true,
    this.eisEnabled = true,
    this.bankName,
    this.bankAccountNumber,
  });

  factory StaffPayrollSetting.fromJson(Map<String, dynamic> json) {
    return StaffPayrollSetting(
      staffId: json['staff_id'] as String,
      staffName: json['staff_name'] as String? ?? 'Staff',
      staffCode: json['staff_code'] as String? ?? 'STF-001',
      designation: json['designation'] as String? ?? 'Staff',
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 1800.0,
      serviceCommissionRate: (json['service_commission_rate'] as num?)?.toDouble() ?? 35.0,
      productCommissionRate: (json['product_commission_rate'] as num?)?.toDouble() ?? 10.0,
      epfEnabled: json['epf_enabled'] as bool? ?? true,
      socsoEnabled: json['socso_enabled'] as bool? ?? true,
      eisEnabled: json['eis_enabled'] as bool? ?? true,
      bankName: json['bank_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'staff_id': staffId,
    'staff_name': staffName,
    'staff_code': staffCode,
    'designation': designation,
    'base_salary': baseSalary,
    'service_commission_rate': serviceCommissionRate,
    'product_commission_rate': productCommissionRate,
    'epf_enabled': epfEnabled,
    'socso_enabled': socsoEnabled,
    'eis_enabled': eisEnabled,
    'bank_name': bankName,
    'bank_account_number': bankAccountNumber,
  };

  StaffPayrollSetting copyWith({
    double? baseSalary,
    double? serviceCommissionRate,
    double? productCommissionRate,
    bool? epfEnabled,
    bool? socsoEnabled,
    bool? eisEnabled,
    String? bankName,
    String? bankAccountNumber,
  }) {
    return StaffPayrollSetting(
      staffId: staffId,
      staffName: staffName,
      staffCode: staffCode,
      designation: designation,
      baseSalary: baseSalary ?? this.baseSalary,
      serviceCommissionRate: serviceCommissionRate ?? this.serviceCommissionRate,
      productCommissionRate: productCommissionRate ?? this.productCommissionRate,
      epfEnabled: epfEnabled ?? this.epfEnabled,
      socsoEnabled: socsoEnabled ?? this.socsoEnabled,
      eisEnabled: eisEnabled ?? this.eisEnabled,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }
}

class MonthlyPayrollItem {
  final String staffId;
  final String staffName;
  final String staffCode;
  final String designation;
  final double baseSalary;
  final double serviceCommission;
  final double productCommission;
  final double overtimePay;
  final double tipsShare;
  final double bonusOrAllowance;
  final double penaltyOrDeduction;

  final bool epfEnabled;
  final bool socsoEnabled;
  final bool eisEnabled;
  final String status; // 'draft' | 'approved' | 'paid'
  final String? bankName;
  final String? bankAccountNumber;

  const MonthlyPayrollItem({
    required this.staffId,
    required this.staffName,
    required this.staffCode,
    required this.designation,
    required this.baseSalary,
    this.serviceCommission = 0.0,
    this.productCommission = 0.0,
    this.overtimePay = 0.0,
    this.tipsShare = 0.0,
    this.bonusOrAllowance = 0.0,
    this.penaltyOrDeduction = 0.0,
    this.epfEnabled = true,
    this.socsoEnabled = true,
    this.eisEnabled = true,
    this.status = 'draft',
    this.bankName,
    this.bankAccountNumber,
  });

  double get grossPay =>
      baseSalary +
      serviceCommission +
      productCommission +
      overtimePay +
      tipsShare +
      bonusOrAllowance;

  // Malaysian Statutory Calculations (EPF 11%, SOCSO ~0.5%, EIS ~0.2%)
  double get epfEmployee => epfEnabled ? (baseSalary * 0.11) : 0.0;
  double get epfEmployer => epfEnabled ? (baseSalary * 0.13) : 0.0;

  double get socsoEmployee => socsoEnabled ? 9.25 : 0.0;
  double get socsoEmployer => socsoEnabled ? 32.35 : 0.0;

  double get eisEmployee => eisEnabled ? 3.70 : 0.0;
  double get eisEmployer => eisEnabled ? 3.70 : 0.0;

  double get totalEmployeeDeductions =>
      epfEmployee + socsoEmployee + eisEmployee + penaltyOrDeduction;

  double get netPay => (grossPay - totalEmployeeDeductions).clamp(0.0, double.infinity);

  MonthlyPayrollItem copyWith({
    double? bonusOrAllowance,
    double? penaltyOrDeduction,
    double? overtimePay,
    String? status,
  }) {
    return MonthlyPayrollItem(
      staffId: staffId,
      staffName: staffName,
      staffCode: staffCode,
      designation: designation,
      baseSalary: baseSalary,
      serviceCommission: serviceCommission,
      productCommission: productCommission,
      overtimePay: overtimePay ?? this.overtimePay,
      tipsShare: tipsShare,
      bonusOrAllowance: bonusOrAllowance ?? this.bonusOrAllowance,
      penaltyOrDeduction: penaltyOrDeduction ?? this.penaltyOrDeduction,
      epfEnabled: epfEnabled,
      socsoEnabled: socsoEnabled,
      eisEnabled: eisEnabled,
      status: status ?? this.status,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
    );
  }
}
