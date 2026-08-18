// learning_material_grade.dart
// รายชื่อชั้นเรียนที่ใช้ในทะเบียนหนังสือเรียน/อุปกรณ์การเรียน — จัดการเพิ่ม/
// แก้ไข/ลบเองได้จากหน้า "จัดการชั้นเรียน" (เดิม fix ตายตัว อ.2-ม.3 ในโค้ด)

class LearningMaterialGrade {
  final int? id;
  final String name;
  final int sortOrder;

  const LearningMaterialGrade({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort_order': sortOrder,
      };

  factory LearningMaterialGrade.fromMap(Map<String, dynamic> m) => LearningMaterialGrade(
        id: m['id'] as int?,
        name: m['name'] as String,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  LearningMaterialGrade copyWith({String? name, int? sortOrder}) => LearningMaterialGrade(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
