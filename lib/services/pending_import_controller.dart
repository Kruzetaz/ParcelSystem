// pending_import_controller.dart
// เก็บผลการนำเข้าโครงการเก่า (ImportAttempt) ที่อ่านไฟล์เสร็จแล้ว แต่ยังไม่ได้
// เปิดหน้าตรวจสอบ/ยืนยัน เพราะผู้ใช้สลับออกจากหน้าทะเบียนคุมไปแล้วระหว่างรอ AI
// อ่านไฟล์ (ใช้เวลานานหลายนาทีถ้าไฟล์เยอะ) — ถ้าทิ้งผลไปเฉยๆ ตาม `!mounted`
// เหมือนจุดอื่นในแอป ผู้ใช้จะเสียงานที่รอมาทั้งหมดโดยไม่รู้ตัว เก็บไว้ที่นี่แทน
// แล้วให้หน้าทะเบียนคุมเช็คตอนเปิดขึ้นมาใหม่ว่ามีผลค้างอยู่ไหม ถ้ามีให้เปิดหน้า
// ตรวจสอบ/ยืนยันต่อทันที

import 'package:flutter/material.dart';
import '../widgets/procurement_import_dialog.dart';

class PendingImportController extends ChangeNotifier {
  PendingImportController._();
  static final PendingImportController instance = PendingImportController._();

  List<ImportAttempt>? _pending;

  bool get hasPending => _pending != null && _pending!.isNotEmpty;

  void store(List<ImportAttempt> attempts) {
    _pending = attempts;
    notifyListeners();
  }

  /// ดึงผลที่ค้างไว้มาใช้ครั้งเดียวแล้วล้างทิ้ง (กันเปิดซ้ำสองรอบถ้าหน้าถูกสร้างใหม่หลายครั้ง)
  List<ImportAttempt>? consume() {
    final p = _pending;
    _pending = null;
    if (p != null) notifyListeners();
    return p;
  }
}
