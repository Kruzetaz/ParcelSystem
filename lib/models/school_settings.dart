// school_settings.dart
// ข้อมูลโรงเรียน — มีแถวเดียวเสมอในตาราง (id คงที่ = 1)
// กรอกครั้งเดียวในหน้า Settings แล้วใช้ซ้ำได้ในทุกเอกสารที่สร้าง

class SchoolSettings {
  final String? schoolName;
  final String? schoolAddressNo;
  final String? schoolSubdistrict;
  final String? schoolAmphoe;
  final String? schoolChangwat;
  final String? schoolPhone;

  const SchoolSettings({
    this.schoolName,
    this.schoolAddressNo,
    this.schoolSubdistrict,
    this.schoolAmphoe,
    this.schoolChangwat,
    this.schoolPhone,
  });

  Map<String, dynamic> toMap() => {
        'id': 1, // แถวเดียวเสมอ
        'school_name': schoolName,
        'school_address_no': schoolAddressNo,
        'school_subdistrict': schoolSubdistrict,
        'school_amphoe': schoolAmphoe,
        'school_changwat': schoolChangwat,
        'school_phone': schoolPhone,
      };

  factory SchoolSettings.fromMap(Map<String, dynamic> m) => SchoolSettings(
        schoolName: m['school_name'] as String?,
        schoolAddressNo: m['school_address_no'] as String?,
        schoolSubdistrict: m['school_subdistrict'] as String?,
        schoolAmphoe: m['school_amphoe'] as String?,
        schoolChangwat: m['school_changwat'] as String?,
        schoolPhone: m['school_phone'] as String?,
      );

  SchoolSettings copyWith({
    String? schoolName,
    String? schoolAddressNo,
    String? schoolSubdistrict,
    String? schoolAmphoe,
    String? schoolChangwat,
    String? schoolPhone,
  }) {
    return SchoolSettings(
      schoolName: schoolName ?? this.schoolName,
      schoolAddressNo: schoolAddressNo ?? this.schoolAddressNo,
      schoolSubdistrict: schoolSubdistrict ?? this.schoolSubdistrict,
      schoolAmphoe: schoolAmphoe ?? this.schoolAmphoe,
      schoolChangwat: schoolChangwat ?? this.schoolChangwat,
      schoolPhone: schoolPhone ?? this.schoolPhone,
    );
  }
}