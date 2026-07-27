// personnel.dart
// ทำเนียบบุคลากรกลางของโรงเรียน (ครู/เจ้าหน้าที่) — ให้ทุกช่องกรอกชื่อ-ตำแหน่ง
// ทั่วทั้งแอป (wizard, กลุ่มงาน ฯลฯ) เลือกใช้ซ้ำได้แทนพิมพ์เองทุกครั้ง
// แก้ที่นี่ที่เดียว ทุกจุดที่อ้างอิงชื่อนี้จะเห็นตำแหน่ง/เบอร์ล่าสุดตรงกัน

class Personnel {
  final int? id;
  final String name;
  final String? position;
  final String? phone;
  final String? email;
  final bool active;

  const Personnel({
    this.id,
    required this.name,
    this.position,
    this.phone,
    this.email,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'position': position,
        'phone': phone,
        'email': email,
        'active': active ? 1 : 0,
      };

  factory Personnel.fromMap(Map<String, dynamic> m) => Personnel(
        id: m['id'] as int?,
        name: m['name'] as String,
        position: m['position'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        active: (m['active'] as int? ?? 1) == 1,
      );

  Personnel copyWith({
    int? id,
    String? name,
    String? position,
    String? phone,
    String? email,
    bool? active,
  }) {
    return Personnel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      active: active ?? this.active,
    );
  }
}
