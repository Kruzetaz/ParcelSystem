// material_ledger_export_service.dart
// ส่งออก "บัญชีวัสดุ" เป็นไฟล์ Excel พิมพ์ได้ — หนึ่งบล็อกต่อวัสดุหนึ่งชนิด
// (แบบบัตรคุมสต๊อกของราชการ): หัวข้อ ประเภท/ชื่อ/รหัส/ขนาด/จำนวนอย่างสูง-ต่ำ/
// หน่วยนับ/ที่เก็บ ตามด้วยตารางประวัติรับ-จ่ายทีละรายการพร้อมยอดคงเหลือสะสม

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/material_item.dart';
import '../models/material_transaction.dart';
import '../utils/app_folder_name.dart';

class MaterialLedgerExportService {
  static Future<File> export({
    required List<MaterialItem> materials,
    required Map<int, List<MaterialTransaction>> transactionsByMaterialId,
  }) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    for (final m in materials) {
      sheet.appendRow([xls.TextCellValue('บัญชีวัสดุ')]);
      sheet.appendRow([
        xls.TextCellValue('ประเภท: ${m.category ?? "-"}'),
        xls.TextCellValue('ชื่อหรือชนิดวัสดุ: ${m.name}'),
        xls.TextCellValue('รหัส: ${m.materialCode ?? "-"}'),
      ]);
      sheet.appendRow([
        xls.TextCellValue('ขนาดหรือลักษณะ: ${m.sizeSpec ?? "-"}'),
        xls.TextCellValue('หน่วยนับ: ${m.unit ?? "-"}'),
        xls.TextCellValue('ที่เก็บ: ${m.storageLocation ?? "-"}'),
      ]);
      sheet.appendRow([
        xls.TextCellValue('จำนวนอย่างสูง: ${m.maxStock?.toStringAsFixed(0) ?? "-"}'),
        xls.TextCellValue('จำนวนอย่างต่ำ: ${m.minStock?.toStringAsFixed(0) ?? "-"}'),
      ]);
      sheet.appendRow([
        xls.TextCellValue('วันเดือนปี'),
        xls.TextCellValue('รับจาก/จ่ายให้'),
        xls.TextCellValue('เลขที่เอกสาร'),
        xls.TextCellValue('ราคา/หน่วย (บาท)'),
        xls.TextCellValue('รับ'),
        xls.TextCellValue('จ่าย'),
        xls.TextCellValue('คงเหลือ'),
        xls.TextCellValue('หมายเหตุ'),
      ]);

      final transactions = transactionsByMaterialId[m.id] ?? [];
      var runningBalance = 0.0;
      for (final t in transactions) {
        final isIn = t.transactionType == 'รับเข้า';
        runningBalance += isIn ? t.quantity : -t.quantity;
        sheet.appendRow([
          xls.TextCellValue(t.transactionDate ?? '-'),
          xls.TextCellValue(t.counterparty ?? '-'),
          xls.TextCellValue(t.refDocument ?? '-'),
          t.unitPrice != null ? xls.DoubleCellValue(t.unitPrice!) : xls.TextCellValue('-'),
          xls.TextCellValue(isIn ? t.quantity.toStringAsFixed(0) : ''),
          xls.TextCellValue(!isIn ? t.quantity.toStringAsFixed(0) : ''),
          xls.TextCellValue(runningBalance.toStringAsFixed(0)),
          xls.TextCellValue(t.note ?? ''),
        ]);
      }
      if (transactions.isEmpty) {
        sheet.appendRow([xls.TextCellValue('(ยังไม่มีประวัติรับ-จ่าย)')]);
      }
      sheet.appendRow([]);
      sheet.appendRow([]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'บัญชีวัสดุ'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required List<MaterialItem> materials,
    required Map<int, List<MaterialTransaction>> transactionsByMaterialId,
  }) async {
    final file = await export(materials: materials, transactionsByMaterialId: transactionsByMaterialId);
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
