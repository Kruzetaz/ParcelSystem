// vendor.dart
// จดจำข้อมูลร้านค้า/คู่ค้าที่เคยกรอกและบันทึกไว้ (จากแท็บ "ร้านค้า/เงื่อนไข" ของ
// order_wizard_screen.dart หรือจากหน้าจัดการร้านค้าในตั้งค่า) ให้เลือกใช้ซ้ำได้
// ครบทุกช่องในครั้งถัดไป — key คือชื่อร้าน

const vendorTypeIndividual = 'บุคคลธรรมดา';
const vendorTypeJuristic = 'นิติบุคคล';
const vendorTypes = [vendorTypeIndividual, vendorTypeJuristic];

class Vendor {
  final int? id;
  final String name;
  final String? owner;
  final String? addressNo;
  final String? mooNumber;
  final String? subdistrict;
  final String? district;
  final String? province;
  final String? postalCode;
  final String? phone;
  final String? taxId;
  final String vendorType;
  final bool active;

  const Vendor({
    this.id,
    required this.name,
    this.owner,
    this.addressNo,
    this.mooNumber,
    this.subdistrict,
    this.district,
    this.province,
    this.postalCode,
    this.phone,
    this.taxId,
    this.vendorType = vendorTypeIndividual,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'owner': owner,
        'address_no': addressNo,
        'moo_number': mooNumber,
        'subdistrict': subdistrict,
        'district': district,
        'province': province,
        'postal_code': postalCode,
        'phone': phone,
        'tax_id': taxId,
        'vendor_type': vendorType,
        'active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory Vendor.fromMap(Map<String, dynamic> m) => Vendor(
        id: m['id'] as int?,
        name: m['name'] as String,
        owner: m['owner'] as String?,
        addressNo: m['address_no'] as String?,
        mooNumber: m['moo_number'] as String?,
        subdistrict: m['subdistrict'] as String?,
        district: m['district'] as String?,
        province: m['province'] as String?,
        postalCode: m['postal_code'] as String?,
        phone: m['phone'] as String?,
        taxId: m['tax_id'] as String?,
        vendorType: (m['vendor_type'] as String?) ?? vendorTypeIndividual,
        active: (m['active'] as int? ?? 1) == 1,
      );

  Vendor copyWith({
    int? id,
    String? name,
    String? owner,
    String? addressNo,
    String? mooNumber,
    String? subdistrict,
    String? district,
    String? province,
    String? postalCode,
    String? phone,
    String? taxId,
    String? vendorType,
    bool? active,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      owner: owner ?? this.owner,
      addressNo: addressNo ?? this.addressNo,
      mooNumber: mooNumber ?? this.mooNumber,
      subdistrict: subdistrict ?? this.subdistrict,
      district: district ?? this.district,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      phone: phone ?? this.phone,
      taxId: taxId ?? this.taxId,
      vendorType: vendorType ?? this.vendorType,
      active: active ?? this.active,
    );
  }
}
