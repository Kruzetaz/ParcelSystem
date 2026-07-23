// vendor.dart
// จดจำข้อมูลร้านค้า/คู่ค้าที่เคยกรอกและบันทึกไว้ (จากแท็บ "ร้านค้า/เงื่อนไข" ของ
// order_wizard_screen.dart) ให้เลือกใช้ซ้ำได้ครบทุกช่องในครั้งถัดไป — key คือชื่อร้าน

class Vendor {
  final int? id;
  final String name;
  final String? owner;
  final String? addressNo;
  final String? subdistrict;
  final String? district;
  final String? province;
  final String? phone;
  final String? taxId;

  const Vendor({
    this.id,
    required this.name,
    this.owner,
    this.addressNo,
    this.subdistrict,
    this.district,
    this.province,
    this.phone,
    this.taxId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'owner': owner,
        'address_no': addressNo,
        'subdistrict': subdistrict,
        'district': district,
        'province': province,
        'phone': phone,
        'tax_id': taxId,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory Vendor.fromMap(Map<String, dynamic> m) => Vendor(
        id: m['id'] as int?,
        name: m['name'] as String,
        owner: m['owner'] as String?,
        addressNo: m['address_no'] as String?,
        subdistrict: m['subdistrict'] as String?,
        district: m['district'] as String?,
        province: m['province'] as String?,
        phone: m['phone'] as String?,
        taxId: m['tax_id'] as String?,
      );
}
