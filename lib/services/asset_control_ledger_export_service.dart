// asset_control_ledger_export_service.dart
// ส่งออก "ทะเบียนคุมทรัพย์สิน" เป็นไฟล์ Excel พิมพ์ได้ — คอลัมน์อ้างอิงจากแบบฟอร์ม
// ทะเบียนคุมทรัพย์สินจริงที่โรงเรียนใช้ (ประเภทเงิน/วิธีการได้มา/ราคาต่อหน่วย/
// อายุการใช้งาน/ค่าเสื่อมราคา/มูลค่าสุทธิ) — ข้อมูลทั้งหมดดึงจากทะเบียนครุภัณฑ์ที่
// มีอยู่แล้วในระบบ ไม่ต้องกรอกซ้ำ

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/fixed_asset.dart';
import '../utils/app_folder_name.dart';

class AssetControlLedgerExportService {
  static Future<File> export(List<FixedAsset> assets, {required DateTime? Function(String?) parseDate}) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([xls.TextCellValue('ทะเบียนคุมทรัพย์สิน')]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('เลขครุภัณฑ์'),
      xls.TextCellValue('รายการ'),
      xls.TextCellValue('สถานที่ตั้ง/หน่วยงานที่รับผิดชอบ'),
      xls.TextCellValue('ชื่อผู้ขาย/ผู้รับจ้าง/ผู้บริจาค'),
      xls.TextCellValue('ประเภทเงิน'),
      xls.TextCellValue('วิธีการได้มา'),
      xls.TextCellValue('วัน/เดือน/ปี ที่ได้มา'),
      xls.TextCellValue('จำนวน'),
      xls.TextCellValue('หน่วย'),
      xls.TextCellValue('ราคาต่อหน่วย (บาท)'),
      xls.TextCellValue('มูลค่ารวม (บาท)'),
      xls.TextCellValue('อายุการใช้งาน (ปี)'),
      xls.TextCellValue('อัตราค่าเสื่อมราคา (%/ปี)'),
      xls.TextCellValue('ค่าเสื่อมราคาสะสม (บาท)'),
      xls.TextCellValue('มูลค่าสุทธิ (บาท)'),
      xls.TextCellValue('สถานะปัจจุบัน'),
    ]);

    for (final a in assets) {
      final dep = calcDepreciation(a, parseDate(a.acquiredDate));
      sheet.appendRow([
        xls.TextCellValue(a.assetNumber ?? '-'),
        xls.TextCellValue(a.name),
        xls.TextCellValue(a.location ?? '-'),
        xls.TextCellValue(a.vendorName ?? '-'),
        xls.TextCellValue(a.fundType ?? '-'),
        xls.TextCellValue(a.procurementMethod ?? '-'),
        xls.TextCellValue(a.acquiredDate ?? '-'),
        xls.DoubleCellValue(a.quantity),
        xls.TextCellValue('-'),
        xls.DoubleCellValue(a.unitPrice ?? 0),
        xls.DoubleCellValue(a.totalValue),
        xls.TextCellValue(a.usefulLifeYears?.toString() ?? '-'),
        xls.TextCellValue(dep != null ? dep.ratePercentPerYear.toStringAsFixed(2) : '-'),
        xls.TextCellValue(dep != null ? dep.accumulatedDepreciation.toStringAsFixed(2) : '-'),
        xls.TextCellValue(dep != null ? dep.netBookValue.toStringAsFixed(2) : a.totalValue.toStringAsFixed(2)),
        xls.TextCellValue(a.status),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ทะเบียนคุมทรัพย์สิน'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<FixedAsset> assets, {required DateTime? Function(String?) parseDate}) async {
    final file = await export(assets, parseDate: parseDate);
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
