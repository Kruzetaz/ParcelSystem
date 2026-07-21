// order_register_export_service.dart
// ส่งออก "ทะเบียนคุมเลขที่จัดซื้อจัดจ้าง" เป็นไฟล์ Excel (.xlsx) — จัดคอลัมน์ให้
// ใกล้เคียงกับไฟล์ทะเบียนคุมที่โรงเรียนใช้งานจริง แยกชีตจัดซื้อ/จัดจ้าง

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/budget.dart';
import '../models/procurement_order.dart';
import '../utils/app_folder_name.dart';

class OrderRegisterExportService {
  static Future<File> export({
    required List<ProcurementOrder> purchases,
    required List<ProcurementOrder> hires,
    required Map<int, Budget> budgetsById,
    String? fiscalYearLabel,
  }) async {
    final excel = xls.Excel.createExcel();
    final starterSheetName = excel.getDefaultSheet();

    _writeSheet(excel, 'จัดซื้อ', purchases, budgetsById);
    _writeSheet(excel, 'จัดจ้าง', hires, budgetsById);

    if (starterSheetName != null && starterSheetName != 'จัดซื้อ' && starterSheetName != 'จัดจ้าง') {
      excel.delete(starterSheetName);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final yearPart = fiscalYearLabel != null ? '_ปี$fiscalYearLabel' : '';
    final fileName = 'ทะเบียนคุมเลขที่จัดซื้อจัดจ้าง$yearPart'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required List<ProcurementOrder> purchases,
    required List<ProcurementOrder> hires,
    required Map<int, Budget> budgetsById,
    String? fiscalYearLabel,
  }) async {
    final file = await export(
      purchases: purchases,
      hires: hires,
      budgetsById: budgetsById,
      fiscalYearLabel: fiscalYearLabel,
    );
    await _openFile(file.path);
  }

  static void _writeSheet(
    xls.Excel excel,
    String sheetName,
    List<ProcurementOrder> orders,
    Map<int, Budget> budgetsById,
  ) {
    final sheet = excel[sheetName];
    sheet.appendRow([
      xls.TextCellValue('ที่'),
      xls.TextCellValue('เลขที่เอกสาร'),
      xls.TextCellValue('วันที่'),
      xls.TextCellValue('รายการ/โครงการ'),
      xls.TextCellValue('จำนวนเงิน'),
      xls.TextCellValue('ประเภทของเงิน'),
      xls.TextCellValue('ผู้ขาย/ผู้รับจ้าง'),
      xls.TextCellValue('แผนงาน/โครงการ'),
      xls.TextCellValue('เลขที่โครงการ'),
      xls.TextCellValue('ครบกำหนดส่งมอบ'),
      xls.TextCellValue('วันตรวจรับ'),
      xls.TextCellValue('วันส่งเบิกเงิน'),
    ]);

    for (var i = 0; i < orders.length; i++) {
      final o = orders[i];
      final budget = o.budgetId != null ? budgetsById[o.budgetId] : null;
      final projectLabel = budget?.projectName ?? o.projectName ?? o.procurementSubject ?? '';
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(o.orderNumber ?? o.procurementNumber ?? ''),
        xls.TextCellValue(o.dateOrderCreated ?? ''),
        xls.TextCellValue(projectLabel),
        o.currentOrderPrice != null ? xls.DoubleCellValue(o.currentOrderPrice!) : xls.TextCellValue(''),
        xls.TextCellValue(o.fundType ?? ''),
        xls.TextCellValue(o.vendorName ?? ''),
        xls.TextCellValue(budget?.groupName ?? ''),
        xls.TextCellValue(o.projectNumber ?? ''),
        xls.TextCellValue(o.dateDeadline ?? ''),
        xls.TextCellValue(o.dateInspection ?? ''),
        xls.TextCellValue(o.dateDisbursement ?? ''),
      ]);
    }
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
