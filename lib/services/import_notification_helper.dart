// import_notification_helper.dart
// แจ้งเตือนไฟล์ที่นำเข้าโครงการเก่าแล้วอ่านไม่สำเร็จ (เช่น AI โดน rate limit
// ชั่วคราว) แยกเป็นรายการของตัวเองในกระดิ่งแจ้งเตือน — เดิมถ้านำเข้าหลายไฟล์
// พร้อมกันแล้วมีบางไฟล์พัง ข้อความสรุปจะบอกแค่ "อ่านไฟล์เสร็จแล้ว" เฉยๆ (นับ
// เฉพาะไฟล์ที่สำเร็จ) ทำให้ไฟล์ที่พังหลุดรอดไม่มีใครสังเกต ต้องแยกแจ้งต่างหาก
// ให้เห็นชัดว่ามีไฟล์ไหนพังบ้างและเพราะอะไร

import 'package:flutter/material.dart';
import 'notification_history_controller.dart';
import '../widgets/procurement_import_dialog.dart' show ImportAttempt;

void notifyImportFailuresIfAny(List<ImportAttempt> attempts,
    {String? navigateMode}) {
  final failed = attempts.where((a) => !a.ok).toList();
  if (failed.isEmpty) return;
  NotificationHistoryController.instance.add(
    title: 'อ่านไฟล์ไม่สำเร็จ ${failed.length} ไฟล์',
    message: failed.map((a) => '${a.fileName}: ${a.errorMessage}').join('\n'),
    icon: Icons.error_outline,
    color: const Color(0xFFDC2626),
    navigateMode: navigateMode,
  );
}
