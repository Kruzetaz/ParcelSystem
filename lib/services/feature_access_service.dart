// feature_access_service.dart
// รวมศูนย์เช็คว่าเครื่องนี้มีสิทธิ์ใช้ "โมดูล" ไหนบ้าง ตาม license token ล่าสุด
// ที่ผ่านการตรวจลายเซ็นแล้ว (LicenseService เป็นคนอัปเดตค่านี้ให้ทุกครั้งที่
// เช็ค license ผ่าน) — เรียกใช้ได้ทั้งระดับ UI (ล็อกเมนู/แสดง upsell dialog)
// และระดับ service (กันก่อนบันทึก/สร้างเอกสารจริง กันกรณีมีคนพยายามเลี่ยง
// การเช็คที่ UI ไปเรียก service ตรงๆ)

import 'license_token.dart';

/// ชื่อโมดูลที่ระบบรู้จัก — ต้องตรงกับค่าที่ server ใส่ไว้ใน token.modules
class FeatureModules {
  FeatureModules._();

  /// งานจัดซื้อจัดจ้างพื้นฐาน (หน้าหลัก/ปฏิทิน/สร้างเอกสาร/แผนงบ/TOR/ทะเบียน
  /// เลขที่) — โมดูลหลักของระบบ ให้สิทธิ์ดู/แก้ไข/ส่งออกเอกสารของโครงการที่มี
  /// อยู่แล้วเท่านั้น แพ็กเกจ Free ก็มีสิทธิ์นี้ (ดูของเดิมได้ แต่สร้างใหม่ไม่ได้
  /// — ต้องมี [procurementCreate] เพิ่มด้วยถึงจะสร้างโครงการใหม่ได้)
  static const procurement = 'PROCUREMENT';

  /// สร้างโครงการจัดซื้อจัดจ้างใหม่ (รวมถึงทำซ้ำ/คัดลอกโครงการเดิมเป็นโครงการ
  /// ใหม่) — แยกจาก [procurement] เพื่อให้ Free tier เข้าเมนูจัดซื้อได้ปกติ
  /// (ดู/แก้ไข/ส่งออกโครงการเดิม) แต่กดสร้างโครงการใหม่ไม่ได้จนกว่าจะอัปเกรด
  static const procurementCreate = 'PROCUREMENT_CREATE';

  /// บริหารสัญญา/หลักประกัน/ตรวจรับ/สัญญาต่อเนื่องหลายงวด — โมดูลเสริมระดับ
  /// กลาง (มีคู่สัญญาแล้ว เข้าสู่ขั้นตอนดำเนินการจัดซื้อจัดจ้างจริง)
  static const contractManagement = 'CONTRACT_MANAGEMENT';

  /// ทรัพย์สินและพัสดุ (ครุภัณฑ์/ประวัติซ่อม/วัสดุ/หนังสือเรียน/ตรวจนับ
  /// ประจำปี/จำหน่ายพัสดุ) — โมดูลเสริม
  static const assetManagement = 'ASSET_MANAGEMENT';

  /// รายงาน/สตง. — โมดูลเสริม
  static const reports = 'REPORTS';

  /// เบิกจ่ายเดินทางไปราชการ (แบบ ๘๗๐๘) — โมดูลเสริม แยกขายต่างหาก
  static const travelExpense = 'TRAVEL_EXPENSE';

  /// ตั้งค่า AI (ผู้ช่วยกรอกฟอร์ม/ร่างเอกสารด้วย AI) — โมดูลเสริม
  static const aiFeatures = 'AI_FEATURES';
}

/// ขึ้น error นี้เมื่อพยายามบันทึก/สร้างเอกสารของโมดูลที่แพ็กเกจปัจจุบันยัง
/// ไม่ปลดล็อก — ใช้ร่วมกันได้ทุก service (ไม่ต้องสร้าง exception class แยก
/// ของตัวเองซ้ำในทุกไฟล์)
class FeatureLockedException implements Exception {
  final String message;
  FeatureLockedException(this.message);
  @override
  String toString() => message;
}

class FeatureAccessService {
  FeatureAccessService._();
  static final FeatureAccessService instance = FeatureAccessService._();

  LicenseToken? _token;

  /// LicenseService เรียกทุกครั้งหลังเช็ค/verify token สำเร็จ (ทั้งตอน
  /// activate, checkOnStartup, หรือกู้จาก cache ที่เก็บไว้)
  void updateToken(LicenseToken? token) => _token = token;

  LicenseToken? get currentToken => _token;

  /// ยังไม่เคย activate เลย (ไม่มี token ที่ผ่านการตรวจ) → ถือว่าไม่มีสิทธิ์
  /// อะไรทั้งนั้น ไม่ใช่แค่ปลดล็อกทุกอย่างเป็นค่าเริ่มต้น
  bool hasModule(String moduleKey) => _token?.hasModule(moduleKey) ?? false;

  /// เช็คสิทธิ์โมดูลก่อนบันทึก/สร้างเอกสารจริง — throw
  /// [FeatureLockedException] ถ้าแพ็กเกจปัจจุบันไม่มีโมดูลนี้ กันซ้ำที่ชั้น
  /// service ด้วย ไม่ใช่เชื่อแค่ว่า UI ล็อกเมนู/routing กันไว้แล้วเท่านั้น
  void requireModule(String moduleKey, String moduleLabel) {
    if (!hasModule(moduleKey)) {
      throw FeatureLockedException('โมดูล$moduleLabelยังไม่ได้ปลดล็อกในแพ็กเกจนี้');
    }
  }
}
