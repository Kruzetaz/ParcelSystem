// school_branch.dart
// สาขาของโรงเรียน (เช่น โรงเรียนหลัก + สาขาย่อยที่แยกพื้นที่จัดการเรียนการสอน)
// จัดการเพิ่ม/แก้ไข/ลบเองได้จากหน้า "ทะเบียนหนังสือเรียน/อุปกรณ์การเรียน"
// ใช้เป็น FK ของ LearningMaterialRecord เพื่อแยกยอดนักเรียน/อุปกรณ์ต่อสาขา

class SchoolBranch {
  final int? id;
  final String name;
  final int sortOrder;

  const SchoolBranch({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort_order': sortOrder,
      };

  factory SchoolBranch.fromMap(Map<String, dynamic> m) => SchoolBranch(
        id: m['id'] as int?,
        name: m['name'] as String,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  SchoolBranch copyWith({String? name, int? sortOrder}) => SchoolBranch(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
