// annual_count.dart
// ตรวจนับพัสดุประจำปี (blueprint หน้าที่ 10) — บันทึกประวัติการตรวจสอบ
// สินทรัพย์ตามกฎหมาย (ครุภัณฑ์+วัสดุ) ประจำปีงบประมาณ

class AnnualCount {
  final int? id;
  final String fiscalYear;
  final String? startDate;
  final String? responsiblePersons;
  final int? totalItems;
  final int? foundItems;
  final int? damagedLostItems;
  final String status; // 'กำลังดำเนินการ' | 'เสร็จสิ้น'
  final String? summaryNotes;

  const AnnualCount({
    this.id,
    required this.fiscalYear,
    this.startDate,
    this.responsiblePersons,
    this.totalItems,
    this.foundItems,
    this.damagedLostItems,
    this.status = 'กำลังดำเนินการ',
    this.summaryNotes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'fiscal_year': fiscalYear,
        'start_date': startDate,
        'responsible_persons': responsiblePersons,
        'total_items': totalItems,
        'found_items': foundItems,
        'damaged_lost_items': damagedLostItems,
        'status': status,
        'summary_notes': summaryNotes,
      };

  factory AnnualCount.fromMap(Map<String, dynamic> m) => AnnualCount(
        id: m['id'] as int?,
        fiscalYear: m['fiscal_year'] as String,
        startDate: m['start_date'] as String?,
        responsiblePersons: m['responsible_persons'] as String?,
        totalItems: m['total_items'] as int?,
        foundItems: m['found_items'] as int?,
        damagedLostItems: m['damaged_lost_items'] as int?,
        status: m['status'] as String? ?? 'กำลังดำเนินการ',
        summaryNotes: m['summary_notes'] as String?,
      );
}
