// learning_material_record.dart
// ทะเบียนหนังสือเรียน/อุปกรณ์การเรียนทั้งโรงเรียน (เทียบมาจากสมุด "หนังสือเรียน"/
// "อุปกรณ์การเรียน" ของโรงเรียน) — เก็บเป็นยอดสรุปต่อ (สาขา, หมวดหมู่, ชั้น) เดียว
// คือ จำนวนนักเรียน + จำนวนที่สั่งซื้อแล้ว แล้วคำนวณส่วนต่างสดเพื่อเช็คว่าสั่งซื้อ
// ครบตามจำนวนนักเรียนหรือไม่ — ไม่ได้เก็บเป็น log การยืม-คืนแบบสมุดกระดาษเดิม

const learningMaterialCategories = ['หนังสือเรียน', 'อุปกรณ์การเรียน'];

/// ระดับชั้นมาตรฐาน อ.2 - ม.3 — ใช้ร่วมกันทุกสาขา สาขาไหนไม่มีชั้นนั้นจริง
/// (เช่น สาขาที่เปิดสอนถึงแค่ ป.6) ก็แค่เว้นจำนวนนักเรียน/สั่งซื้อไว้เป็น 0
const learningMaterialGradeLevels = [
  'อ.2', 'อ.3', 'ป.1', 'ป.2', 'ป.3', 'ป.4', 'ป.5', 'ป.6', 'ม.1', 'ม.2', 'ม.3',
];

class LearningMaterialRecord {
  final int? id;
  final int branchId;
  final String category; // 'หนังสือเรียน' | 'อุปกรณ์การเรียน'
  final String gradeLevel;
  final int studentCount;
  final int orderedCount;
  // ราคาต่อหัว (บาท/นักเรียน 1 คน) — คูณจำนวนนักเรียนแล้วได้ "งบที่ต้องใช้"
  // ของชั้นนั้น ใช้เทียบกับ actualAmount (เงินที่จัดซื้อจริง) เพื่อเช็คว่า
  // ขาด/เกินงบไปเท่าไหร่ ตามที่โรงเรียนต้องการ
  final double? unitPrice;
  final double? actualAmount;
  final String? asOfDate;
  final String? note;

  const LearningMaterialRecord({
    this.id,
    required this.branchId,
    required this.category,
    required this.gradeLevel,
    this.studentCount = 0,
    this.orderedCount = 0,
    this.unitPrice,
    this.actualAmount,
    this.asOfDate,
    this.note,
  });

  /// ส่วนต่างระหว่างจำนวนที่สั่งซื้อกับจำนวนนักเรียน — ติดลบ = ขาด, บวก = เกิน
  int get diff => orderedCount - studentCount;

  /// งบที่ต้องใช้ทั้งชั้น = ราคาต่อหัว x จำนวนนักเรียน
  double get requiredBudget => (unitPrice ?? 0) * studentCount;

  /// ส่วนต่างงบ (บาท) = เงินที่จัดซื้อจริง - งบที่ต้องใช้ — ติดลบ = งบขาด,
  /// บวก = จัดซื้อเกินงบที่ตั้งไว้
  double get budgetDiff => (actualAmount ?? 0) - requiredBudget;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'branch_id': branchId,
        'category': category,
        'grade_level': gradeLevel,
        'student_count': studentCount,
        'ordered_count': orderedCount,
        'unit_price': unitPrice,
        'actual_amount': actualAmount,
        'as_of_date': asOfDate,
        'note': note,
      };

  factory LearningMaterialRecord.fromMap(Map<String, dynamic> m) => LearningMaterialRecord(
        id: m['id'] as int?,
        branchId: m['branch_id'] as int,
        category: m['category'] as String,
        gradeLevel: m['grade_level'] as String,
        studentCount: m['student_count'] as int? ?? 0,
        orderedCount: m['ordered_count'] as int? ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
        actualAmount: (m['actual_amount'] as num?)?.toDouble(),
        asOfDate: m['as_of_date'] as String?,
        note: m['note'] as String?,
      );

  LearningMaterialRecord copyWith({
    int? studentCount,
    int? orderedCount,
    double? unitPrice,
    double? actualAmount,
    String? asOfDate,
    String? note,
  }) =>
      LearningMaterialRecord(
        id: id,
        branchId: branchId,
        category: category,
        gradeLevel: gradeLevel,
        studentCount: studentCount ?? this.studentCount,
        orderedCount: orderedCount ?? this.orderedCount,
        unitPrice: unitPrice ?? this.unitPrice,
        actualAmount: actualAmount ?? this.actualAmount,
        asOfDate: asOfDate ?? this.asOfDate,
        note: note ?? this.note,
      );
}
