// fiscal_year_controller.dart
// เก็บ "ปีงบประมาณที่กำลังดูอยู่" (viewing fiscal year) แยกจากปีงบจริงตาม
// ปฏิทินเครื่อง — ให้ผู้ใช้สลับไปดูโครงการของปีงบเก่าได้ (อ่านอย่างเดียว เป็น
// ตัวอย่างอ้างอิง) โดยไม่ลบ/ย้ายข้อมูลปีเก่าออกจากระบบเลย แค่กรอง "มุมมอง" ที่
// เห็นในหน้าจอเท่านั้น ข้อมูลจริงยังอยู่ในฐานข้อมูลตลอด
//
// [ตั้งใจไม่ persist ค่าที่เลือกไว้]: พอปิดแอปแล้วเปิดใหม่ ต้องกลับไปเป็นปีงบ
// จริงปัจจุบันเสมอ (ไม่ค้างที่ปีเก่าที่เคยเลือกดูไว้ครั้งก่อน) — ตรงตามที่ผู้ใช้
// ต้องการ: "พอขึ้นปีงบใหม่จะไม่เป็นโครงการปีงบเก่า นอกจากผู้ใช้จะกดสลับดูเอง"
// ถ้าเก็บค่าไว้ข้ามเซสชัน จะเสี่ยงเปิดแอปมาแล้วเข้าใจผิดว่าเห็นข้อมูลปีปัจจุบัน
// ทั้งที่จริงยังค้างอยู่ปีเก่าจากที่เคยสลับดูไว้เมื่อวาน

import 'package:flutter/foundation.dart';
import '../models/procurement_calendar_task.dart' show fiscalYearOf;

class FiscalYearController extends ChangeNotifier {
  FiscalYearController._() : _viewingYear = fiscalYearOf(DateTime.now()).toString();
  static final FiscalYearController instance = FiscalYearController._();

  /// ปีงบจริงตามปฏิทินเครื่อง ณ ตอนนี้ (ต.ค.-ธ.ค. นับเป็นปีงบถัดไป) — ค่านี้ไม่
  /// เปลี่ยนแปลงตามที่ผู้ใช้สลับดู ใช้เทียบว่ากำลังดู "ปีปัจจุบัน" อยู่หรือดูปีเก่า
  String get currentRealYear => fiscalYearOf(DateTime.now()).toString();

  String _viewingYear;
  String get viewingYear => _viewingYear;
  bool get isViewingCurrentYear => _viewingYear == currentRealYear;

  /// ปีที่ดูอยู่ "น้อยกว่า" ปีปัจจุบันจริง (ย้อนดูของเก่า) — ใช้เลือกคำเตือนให้
  /// ตรงบริบท ต่างจากกรณีดูปีงบถัดไปที่ยังไม่ถึง (วางแผนล่วงหน้า)
  bool get isViewingPastYear {
    final v = int.tryParse(_viewingYear);
    final c = int.tryParse(currentRealYear);
    if (v == null || c == null) return false;
    return v < c;
  }

  /// ปีที่ดูอยู่ "มากกว่า" ปีปัจจุบันจริง — ยังไม่ถึงปีงบนั้นตามปฏิทิน กำลังวาง
  /// แผนล่วงหน้า (เช่น ตั้งแผนงบปีถัดไปไว้ก่อน)
  bool get isViewingFutureYear {
    final v = int.tryParse(_viewingYear);
    final c = int.tryParse(currentRealYear);
    if (v == null || c == null) return false;
    return v > c;
  }

  void setViewingYear(String year) {
    if (year == _viewingYear) return;
    _viewingYear = year;
    notifyListeners();
  }

  /// กลับไปดูปีงบปัจจุบันจริง — ใช้ตอนกด "กลับไปปีปัจจุบัน" ในแบนเนอร์แจ้งเตือน
  void resetToCurrentYear() => setViewingYear(currentRealYear);
}
