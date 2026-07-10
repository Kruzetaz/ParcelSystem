// audit_service.dart
// บันทึก Audit Trail — เฉพาะ สร้าง/แก้ไข/ลบ ไม่บันทึกการเปิดดู ตามที่ตกลงกันไว้
// เรียกจาก ProcurementRepository ทุกครั้งที่มีการเขียนข้อมูล

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'current_user_service.dart';

const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  Future<void> log(Database db, {required String action, required String tableLabel, required String description}) async {
    final now = DateTime.now();
    final timestamp = '${now.day} ${_thaiMonths[now.month]} ${now.year + 543} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final userName = await CurrentUserService.instance.getName();
    await db.insert('audit_log', {
      'timestamp': timestamp,
      'action': action,
      'table_label': tableLabel,
      'description': description,
      'user_name': userName,
    });
  }
}
