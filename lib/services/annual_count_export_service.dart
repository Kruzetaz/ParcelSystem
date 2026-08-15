// annual_count_export_service.dart
// ส่งออก "ผลตรวจนับพัสดุประจำปี" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/annual_count.dart';
import '../utils/app_folder_name.dart';

class AnnualCountExportService {
  static Future<File> export(List<AnnualCount> counts) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('ปีงบประมาณ'),
      xls.TextCellValue('วันที่เริ่มตรวจ'),
      xls.TextCellValue('ผู้รับผิดชอบ'),
      xls.TextCellValue('จำนวนทั้งหมด'),
      xls.TextCellValue('จำนวนที่พบจริง'),
      xls.TextCellValue('จำนวนที่ชำรุด/สูญหาย'),
      xls.TextCellValue('สถานะ'),
      xls.TextCellValue('สรุปผลรายงานการตรวจสอบ'),
    ]);

    for (var i = 0; i < counts.length; i++) {
      final a = counts[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(a.fiscalYear),
        xls.TextCellValue(a.startDate ?? '-'),
        xls.TextCellValue(a.responsiblePersons ?? '-'),
        a.totalItems != null ? xls.IntCellValue(a.totalItems!) : xls.TextCellValue('-'),
        a.foundItems != null ? xls.IntCellValue(a.foundItems!) : xls.TextCellValue('-'),
        xls.IntCellValue(a.damagedLostItems ?? 0),
        xls.TextCellValue(a.status),
        xls.TextCellValue(a.summaryNotes ?? '-'),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ผลตรวจนับพัสดุประจำปี'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<AnnualCount> counts) async {
    final file = await export(counts);
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
