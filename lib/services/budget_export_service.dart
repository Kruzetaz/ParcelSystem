// budget_export_service.dart
// ส่งออก "แผนงบประมาณ" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/budget.dart';
import '../utils/app_folder_name.dart';

class BudgetExportService {
  /// [actualRemainingById] คือยอด "คงเหลือจริง" ที่คำนวณสดจากออร์เดอร์ที่เสร็จ
  /// สมบูรณ์แล้ว (คิดโดยหน้าจอ ไม่ใช่คอลัมน์ remaining_amount ในฐานข้อมูลซึ่งไม่
  /// เคยถูกหักลดตามการใช้จ่ายจริงเลย) — ให้ไฟล์ export ตรงกับตัวเลขที่เห็นบนจอ
  static Future<File> export(List<Budget> budgets, Map<int, double> actualRemainingById) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('ปีงบประมาณ'),
      xls.TextCellValue('ฝ่าย/แผนงาน'),
      xls.TextCellValue('โครงการ'),
      xls.TextCellValue('กิจกรรม/รายการย่อย'),
      xls.TextCellValue('เลข e-GP'),
      xls.TextCellValue('ผู้รับผิดชอบ'),
      xls.TextCellValue('วงเงินที่ได้รับจัดสรร (บาท)'),
      xls.TextCellValue('คงเหลือ (บาท)'),
      xls.TextCellValue('แหล่งงบประมาณ'),
    ]);

    for (var i = 0; i < budgets.length; i++) {
      final b = budgets[i];
      final remaining = b.id != null ? (actualRemainingById[b.id] ?? b.allocatedAmount ?? 0) : (b.allocatedAmount ?? 0);
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(b.fiscalYear),
        xls.TextCellValue(b.groupName ?? '-'),
        xls.TextCellValue(b.projectName ?? '-'),
        xls.TextCellValue(b.activityName ?? '-'),
        xls.TextCellValue(b.egpNumber ?? '-'),
        xls.TextCellValue(b.responsiblePerson ?? '-'),
        b.allocatedAmount != null ? xls.DoubleCellValue(b.allocatedAmount!) : xls.TextCellValue('-'),
        xls.DoubleCellValue(remaining),
        xls.TextCellValue(b.budgetSource),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'แผนงบประมาณ'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<Budget> budgets, Map<int, double> actualRemainingById) async {
    final file = await export(budgets, actualRemainingById);
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
