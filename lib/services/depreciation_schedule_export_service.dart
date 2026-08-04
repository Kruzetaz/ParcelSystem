// depreciation_schedule_export_service.dart
// ส่งออก "ตารางค่าเสื่อมราคารายปี" ของครุภัณฑ์ทุกชิ้นที่กรอกอายุการใช้งานไว้ เป็น
// ไฟล์ Excel พิมพ์ได้ — คำนวณแบบเส้นตรง (straight-line) แบบเดียวกับที่หน้า
// ทะเบียนครุภัณฑ์ใช้ (fixed_asset.dart -> calcDepreciation) เป็นค่าประมาณการ
// เท่านั้น ไม่ใช่ตัวเลขบัญชีที่รับรองอย่างเป็นทางการ
//
// ต่างจาก calcDepreciation ตรงที่ตารางนี้เป็น "ตารางคาดการณ์ล่วงหน้าทั้งอายุการ
// ใช้งาน" (ปีที่ 1 ถึงปีสุดท้าย) ไม่ได้อิงวันที่ปัจจุบัน จึงไม่ต้องแปลงวันที่ได้มา
// เป็น DateTime เลย — ใช้แค่แสดงอ้างอิงในตารางเฉยๆ

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/fixed_asset.dart';
import '../utils/app_folder_name.dart';

class DepreciationScheduleExportService {
  static Future<File> export(List<FixedAsset> assets) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('เลขครุภัณฑ์'),
      xls.TextCellValue('ชื่อครุภัณฑ์'),
      xls.TextCellValue('วันที่ได้มา'),
      xls.TextCellValue('ราคาทุน (บาท)'),
      xls.TextCellValue('อายุการใช้งาน (ปี)'),
      xls.TextCellValue('อัตราค่าเสื่อม (%/ปี)'),
      xls.TextCellValue('ปีที่'),
      xls.TextCellValue('ค่าเสื่อมประจำปี (บาท)'),
      xls.TextCellValue('ค่าเสื่อมสะสม (บาท)'),
      xls.TextCellValue('มูลค่าสุทธิปลายปี (บาท)'),
    ]);

    for (final a in assets) {
      final years = a.usefulLifeYears;
      final cost = a.totalValue;
      if (years == null || years <= 0 || cost <= 0) continue;

      final rate = 100 / years;
      final annualDep = cost * rate / 100;
      final maxAccum = cost - 1 > 0 ? cost - 1 : 0.0;

      for (var k = 1; k <= years; k++) {
        final accumulated = (annualDep * k).clamp(0.0, maxAccum);
        final netBookValue = cost - accumulated;
        sheet.appendRow([
          xls.TextCellValue(a.assetNumber ?? '-'),
          xls.TextCellValue(a.name),
          xls.TextCellValue(a.acquiredDate ?? '-'),
          xls.DoubleCellValue(cost),
          xls.IntCellValue(years),
          xls.DoubleCellValue(rate),
          xls.TextCellValue('ปีที่ $k'),
          xls.DoubleCellValue(annualDep),
          xls.DoubleCellValue(accumulated),
          xls.DoubleCellValue(netBookValue),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ตารางค่าเสื่อมราคารายปี'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<FixedAsset> assets) async {
    final file = await export(assets);
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
      // ไม่ throw ต่อ — ไฟล์สร้างสำเร็จแล้ว แค่เปิดอัตโนมัติไม่ได้
    }
  }
}
