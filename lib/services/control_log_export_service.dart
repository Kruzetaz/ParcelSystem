// control_log_export_service.dart
// ส่งออก "ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/control_log_entry.dart';
import '../utils/app_folder_name.dart';

class ControlLogExportService {
  static Future<File> export(List<ControlLogEntry> entries) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('เลขที่บันทึก/คำสั่ง'),
      xls.TextCellValue('ประเภทงาน'),
      xls.TextCellValue('วันที่บันทึก'),
      xls.TextCellValue('ชื่อรายการ/บันทึกข้อความ'),
      xls.TextCellValue('วงเงินงบประมาณ'),
      xls.TextCellValue('หน่วยงาน/กลุ่มงาน'),
      xls.TextCellValue('ผู้รับผิดชอบหลัก'),
    ]);

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(e.controlNumber),
        xls.TextCellValue(e.docType),
        xls.TextCellValue(e.dateText ?? ''),
        xls.TextCellValue(e.description),
        e.amount != null ? xls.DoubleCellValue(e.amount!) : xls.TextCellValue(''),
        xls.TextCellValue(e.department ?? ''),
        xls.TextCellValue(e.responsiblePerson ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ทะเบียนคุมเลขที่บันทึกข้อความ_คำสั่ง_TOR'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<ControlLogEntry> entries) async {
    final file = await export(entries);
    await _openFile(file.path);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Future<void> _openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // เปิดไฟล์อัตโนมัติไม่สำเร็จ — ไฟล์ยังถูกสร้างไว้แล้ว ผู้ใช้เปิดเองได้
    }
  }
}
