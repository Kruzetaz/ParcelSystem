// backup_service.dart
// Backup: zip procurement.db → ~/Documents/BanPaLao_Documents/backup_YYYYMMDD_HHmm.zip
// Restore: เลือกไฟล์ .zip → แตกไฟล์ → ทับ DB เดิม → ปิด connection (เปิดใหม่อัตโนมัติตอน query ครั้งถัดไป)

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../data/database.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  // ─────────────────────────────────────────
  // BACKUP
  // ─────────────────────────────────────────

  /// สำรองข้อมูลเป็นไฟล์ .zip
  /// คืน path ของไฟล์ที่สร้างเสร็จ หรือ throw Exception ถ้าเกิดข้อผิดพลาด
  Future<String> backup() async {
    // 1. หา path ของ DB จริง
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'procurement.db'));
    if (!dbFile.existsSync()) {
      throw Exception('ไม่พบไฟล์ฐานข้อมูล กรุณาเปิดแอปและกรอกข้อมูลก่อน');
    }

    // 2. ปิด connection ชั่วคราวเพื่อให้ไฟล์ไม่ถูก lock ตอน copy
    await (await AppDatabase.instance.database).close();

    try {
      // 3. เตรียมโฟลเดอร์ปลายทาง
      final docsDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(p.join(docsDir.path, 'BanPaLao_Documents'));
      if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

      // 4. ตั้งชื่อไฟล์ตาม timestamp
      final now = DateTime.now();
      final stamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
      final zipPath = p.join(outputDir.path, 'backup_$stamp.zip');

      // 5. สร้าง zip
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addFile(dbFile, 'procurement.db');
      encoder.close();

      return zipPath;
    } finally {
      // 6. เปิด connection กลับอัตโนมัติ (database getter จะ init ใหม่ครั้งถัดไปที่ query)
      await AppDatabase.instance.database;
    }
  }

  // ─────────────────────────────────────────
  // RESTORE
  // ─────────────────────────────────────────

  /// คืนข้อมูลจากไฟล์ .zip ที่เลือก
  /// zipFilePath คือ path เต็มของไฟล์ .zip ที่ user เลือกผ่าน file_picker
  Future<void> restore(String zipFilePath) async {
    final zipFile = File(zipFilePath);
    if (!zipFile.existsSync()) {
      throw Exception('ไม่พบไฟล์ที่เลือก');
    }

    // 1. แตกไฟล์ zip ในหน่วยความจำก่อน ตรวจสอบว่ามี procurement.db อยู่ข้างใน
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dbEntry = archive.findFile('procurement.db');
    if (dbEntry == null) {
      throw Exception('ไฟล์ .zip นี้ไม่ใช่ไฟล์ backup ของระบบ (ไม่พบ procurement.db)');
    }

    // 2. ปิด connection ก่อนเขียนทับ
    await (await AppDatabase.instance.database).close();

    try {
      // 3. เขียน DB ใหม่ทับของเดิม
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'procurement.db'));
      dbFile.writeAsBytesSync(dbEntry.content as List<int>);
    } finally {
      // 4. เปิด connection กลับ
      await AppDatabase.instance.database;
    }
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  String _pad(int n) => n.toString().padLeft(2, '0');
}