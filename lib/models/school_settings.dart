// school_settings.dart
// ข้อมูลโรงเรียน — มีแถวเดียวเสมอในตาราง (id คงที่ = 1)
// กรอกครั้งเดียวในหน้า Settings แล้วใช้ซ้ำได้ในทุกเอกสารที่สร้าง

class SchoolSettings {
  final String? schoolName;
  // "ส่วนราชการ" ต้นสังกัด เช่น "สำนักงานเขตพื้นที่การศึกษาประถมศึกษาลำพูน
  // เขต 1" — เป็นประโยคฟิกที่ต้องใช้ซ้ำในหลายเอกสารราชการ (เช่น บัญชีวัสดุ)
  // แยกจาก schoolName เพราะ "ส่วนราชการ" ในระเบียบมักหมายถึงหน่วยงานต้นสังกัด
  // ไม่ใช่ชื่อโรงเรียนเอง
  final String? educationServiceArea;
  final String? schoolAddressNo;
  final String? schoolSubdistrict;
  final String? schoolAmphoe;
  final String? schoolChangwat;
  final String? schoolPhone;
  final String? directorName;
  final String? procurementOfficer;
  final String? procurementHead;
  final String? financeOfficer;

  const SchoolSettings({
    this.schoolName,
    this.educationServiceArea,
    this.schoolAddressNo,
    this.schoolSubdistrict,
    this.schoolAmphoe,
    this.schoolChangwat,
    this.schoolPhone,
    this.directorName,
    this.procurementOfficer,
    this.procurementHead,
    this.financeOfficer,
  });

  Map<String, dynamic> toMap() => {
        'id': 1, // แถวเดียวเสมอ
        'school_name': schoolName,
        'education_service_area': educationServiceArea,
        'school_address_no': schoolAddressNo,
        'school_subdistrict': schoolSubdistrict,
        'school_amphoe': schoolAmphoe,
        'school_changwat': schoolChangwat,
        'school_phone': schoolPhone,
        'director_name': directorName,
        'procurement_officer': procurementOfficer,
        'procurement_head': procurementHead,
        'finance_officer': financeOfficer,
      };

  factory SchoolSettings.fromMap(Map<String, dynamic> m) => SchoolSettings(
        schoolName: m['school_name'] as String?,
        educationServiceArea: m['education_service_area'] as String?,
        schoolAddressNo: m['school_address_no'] as String?,
        schoolSubdistrict: m['school_subdistrict'] as String?,
        schoolAmphoe: m['school_amphoe'] as String?,
        schoolChangwat: m['school_changwat'] as String?,
        schoolPhone: m['school_phone'] as String?,
        directorName: m['director_name'] as String?,
        procurementOfficer: m['procurement_officer'] as String?,
        procurementHead: m['procurement_head'] as String?,
        financeOfficer: m['finance_officer'] as String?,
      );

  SchoolSettings copyWith({
    String? schoolName,
    String? educationServiceArea,
    String? schoolAddressNo,
    String? schoolSubdistrict,
    String? schoolAmphoe,
    String? schoolChangwat,
    String? schoolPhone,
    String? directorName,
    String? procurementOfficer,
    String? procurementHead,
    String? financeOfficer,
  }) {
    return SchoolSettings(
      schoolName: schoolName ?? this.schoolName,
      educationServiceArea: educationServiceArea ?? this.educationServiceArea,
      schoolAddressNo: schoolAddressNo ?? this.schoolAddressNo,
      schoolSubdistrict: schoolSubdistrict ?? this.schoolSubdistrict,
      schoolAmphoe: schoolAmphoe ?? this.schoolAmphoe,
      schoolChangwat: schoolChangwat ?? this.schoolChangwat,
      schoolPhone: schoolPhone ?? this.schoolPhone,
      directorName: directorName ?? this.directorName,
      procurementOfficer: procurementOfficer ?? this.procurementOfficer,
      procurementHead: procurementHead ?? this.procurementHead,
      financeOfficer: financeOfficer ?? this.financeOfficer,
    );
  }
}
