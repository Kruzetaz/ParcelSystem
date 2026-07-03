// budget.dart
// แผนงบประมาณปฏิบัติการประจำปี — 1 budget ผูกได้กับหลาย procurement_orders
// ใช้สำหรับ Auto-Population: เลือกโครงการย่อยแล้วดึงงบคงเหลือ/egp/ผู้รับผิดชอบ
// มากรอกในฟอร์ม procurement_orders อัตโนมัติ

class Budget {
  final int? id;
  final String fiscalYear;
  final String? groupName;
  final String? projectName;
  final String? activityName;
  final String? egpNumber;
  final double? allocatedAmount;
  final double? remainingAmount;
  final String? responsiblePerson;

  const Budget({
    this.id,
    required this.fiscalYear,
    this.groupName,
    this.projectName,
    this.activityName,
    this.egpNumber,
    this.allocatedAmount,
    this.remainingAmount,
    this.responsiblePerson,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'fiscal_year': fiscalYear,
        'group_name': groupName,
        'project_name': projectName,
        'activity_name': activityName,
        'egp_number': egpNumber,
        'allocated_amount': allocatedAmount,
        'remaining_amount': remainingAmount,
        'responsible_person': responsiblePerson,
      };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as int?,
        fiscalYear: m['fiscal_year'] as String,
        groupName: m['group_name'] as String?,
        projectName: m['project_name'] as String?,
        activityName: m['activity_name'] as String?,
        egpNumber: m['egp_number'] as String?,
        allocatedAmount: (m['allocated_amount'] as num?)?.toDouble(),
        remainingAmount: (m['remaining_amount'] as num?)?.toDouble(),
        responsiblePerson: m['responsible_person'] as String?,
      );

  Budget copyWith({
    int? id,
    String? fiscalYear,
    String? groupName,
    String? projectName,
    String? activityName,
    String? egpNumber,
    double? allocatedAmount,
    double? remainingAmount,
    String? responsiblePerson,
  }) {
    return Budget(
      id: id ?? this.id,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      groupName: groupName ?? this.groupName,
      projectName: projectName ?? this.projectName,
      activityName: activityName ?? this.activityName,
      egpNumber: egpNumber ?? this.egpNumber,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
    );
  }
}
