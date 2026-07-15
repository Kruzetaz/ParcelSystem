// app_folder_name.dart
// ชื่อโฟลเดอร์เก็บเอกสาร Word / รูปครุภัณฑ์ / ไฟล์ backup ของระบบ
// ใช้ชื่อโรงเรียนที่ตั้งค่าไว้ในหน้า "ตั้งค่าโรงเรียน" แทนชื่อ BanPaLao_Documents
// เดิม เพื่อให้แต่ละโรงเรียนที่ติดตั้งแอปนี้แยกโฟลเดอร์ของตัวเองได้ชัดเจน
// ถ้ายังไม่ได้กรอกชื่อโรงเรียน จะ fallback กลับไปใช้ชื่อเดิมไปก่อน

import '../data/procurement_repository.dart';

const String defaultDocumentsFolderName = 'BanPaLao_Documents';

Future<String> getSchoolDocumentsFolderName() async {
  final settings = await ProcurementRepository().getSchoolSettings();
  final raw = settings?.schoolName?.trim() ?? '';
  if (raw.isEmpty) return defaultDocumentsFolderName;
  // ตัดอักขระที่ห้ามใช้เป็นชื่อโฟลเดอร์บน Windows/macOS ออก
  final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return cleaned.isEmpty ? defaultDocumentsFolderName : '${cleaned}_Documents';
}
