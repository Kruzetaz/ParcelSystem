// expenditure_register_export_service.dart
// ส่งออก "ทะเบียนคุมรายจ่ายโครงการ" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/budget_spending.dart';
import '../utils/app_folder_name.dart';

class ExpenditureRegisterExportService {
  static Future<File> export(List<BudgetSpending> rows) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('ปีงบ'),
      xls.TextCellValue('หน่วยงาน/กลุ่มงาน'),
      xls.TextCellValue('โครงการ'),
      xls.TextCellValue('กิจกรรม'),
      xls.TextCellValue('ผู้รับผิดชอบ'),
      xls.TextCellValue('วงเงินที่ได้รับจัดสรร'),
      xls.TextCellValue('จ่ายไปแล้ว'),
      xls.TextCellValue('คงเหลือ'),
      xls.TextCellValue('จำนวนรายการที่เบิกจ่าย'),
    ]);

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final b = r.budget;
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(b.fiscalYear),
        xls.TextCellValue(b.groupName ?? ''),
        xls.TextCellValue(b.projectName ?? ''),
        xls.TextCellValue(b.activityName ?? ''),
        xls.TextCellValue(b.responsiblePerson ?? ''),
        b.allocatedAmount != null
            ? xls.DoubleCellValue(b.allocatedAmount!)
            : xls.TextCellValue(''),
        xls.DoubleCellValue(r.spentAmount),
        xls.DoubleCellValue(r.remainingAmount),
        xls.IntCellValue(r.orderCount),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ทะเบียนคุมรายจ่ายโครงการ'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<BudgetSpending> rows) async {
    final file = await export(rows);
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
