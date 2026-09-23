// staff_appointment_order.dart
// คำสั่งแต่งตั้งหัวหน้าเจ้าหน้าที่พัสดุ/เจ้าหน้าที่พัสดุ ประจำปีงบประมาณ —
// แยกออกมาเป็นฟีเจอร์ของตัวเอง ไม่ผูกกับตรวจนับพัสดุประจำปี เพราะเป็นคำสั่ง
// แต่งตั้งบุคคล ไม่ใช่คำสั่งเกี่ยวกับการตรวจนับ

import 'dart:convert';

const staffAppointmentRoles = ['หัวหน้าเจ้าหน้าที่พัสดุ', 'เจ้าหน้าที่พัสดุ'];

class StaffAppointmentMember {
  final String name;
  final String position; // ตำแหน่งราชการ เช่น "ครูผู้ช่วย", "ธุรการโรงเรียน"
  final String role; // 'หัวหน้าเจ้าหน้าที่พัสดุ' | 'เจ้าหน้าที่พัสดุ'

  const StaffAppointmentMember({
    required this.name,
    this.position = '',
    this.role = 'เจ้าหน้าที่พัสดุ',
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'position': position, 'role': role};

  factory StaffAppointmentMember.fromJson(Map<String, dynamic> j) =>
      StaffAppointmentMember(
        name: j['name'] as String? ?? '',
        position: j['position'] as String? ?? '',
        role: j['role'] as String? ?? 'เจ้าหน้าที่พัสดุ',
      );
}

class StaffAppointmentOrder {
  final int? id;
  final String fiscalYear;
  final String? orderNumber;
  final String? orderDate;
  final String? effectiveDate;
  final List<StaffAppointmentMember> staff;

  const StaffAppointmentOrder({
    this.id,
    required this.fiscalYear,
    this.orderNumber,
    this.orderDate,
    this.effectiveDate,
    this.staff = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'fiscal_year': fiscalYear,
        'order_number': orderNumber,
        'order_date': orderDate,
        'effective_date': effectiveDate,
        'staff_json': jsonEncode(staff.map((s) => s.toJson()).toList()),
      };

  factory StaffAppointmentOrder.fromMap(Map<String, dynamic> m) =>
      StaffAppointmentOrder(
        id: m['id'] as int?,
        fiscalYear: m['fiscal_year'] as String,
        orderNumber: m['order_number'] as String?,
        orderDate: m['order_date'] as String?,
        effectiveDate: m['effective_date'] as String?,
        staff: _decodeStaff(m['staff_json'] as String?),
      );

  static List<StaffAppointmentMember> _decodeStaff(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map(
              (e) => StaffAppointmentMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  StaffAppointmentOrder copyWith({
    int? id,
    String? fiscalYear,
    String? orderNumber,
    String? orderDate,
    String? effectiveDate,
    List<StaffAppointmentMember>? staff,
  }) {
    return StaffAppointmentOrder(
      id: id ?? this.id,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      staff: staff ?? this.staff,
    );
  }
}
