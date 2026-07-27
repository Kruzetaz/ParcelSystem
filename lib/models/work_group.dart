// work_group.dart
// กลุ่มงาน/ฝ่ายของโรงเรียน เป็นตารางจัดการได้จริง (แทนที่ budgetDepartmentGroups
// ที่เคยล็อกเป็น 5 ค่าคงที่ในโค้ด) — แต่ละกลุ่มงานกำหนด "หัวหน้ากลุ่มงาน" ได้
// (พิมพ์ชื่อจากทำเนียบบุคลากร)

class WorkGroup {
  final int? id;
  final String name;
  final String? headName;
  final bool active;

  const WorkGroup({
    this.id,
    required this.name,
    this.headName,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'head_name': headName,
        'active': active ? 1 : 0,
      };

  factory WorkGroup.fromMap(Map<String, dynamic> m) => WorkGroup(
        id: m['id'] as int?,
        name: m['name'] as String,
        headName: m['head_name'] as String?,
        active: (m['active'] as int? ?? 1) == 1,
      );

  WorkGroup copyWith({int? id, String? name, String? headName, bool? active}) {
    return WorkGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      headName: headName ?? this.headName,
      active: active ?? this.active,
    );
  }
}
