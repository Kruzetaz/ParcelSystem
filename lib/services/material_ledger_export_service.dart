// material_ledger_export_service.dart
// ส่งออก "บัญชีวัสดุ" เป็นไฟล์ Excel พิมพ์ได้ — หนึ่งชีตต่อวัสดุหนึ่งชนิด
// (แบบบัตรคุมสต๊อกของราชการ): ชื่อหน่วยงาน ตามด้วยหัวข้อ ประเภท/ชื่อ/รหัส/
// ขนาด/จำนวนอย่างสูง-ต่ำ/หน่วยนับ/ที่เก็บ แล้วตามด้วยตารางประวัติรับ-จ่าย
// ทีละรายการพร้อมยอดคงเหลือสะสม — แยกคนละชีตต่อวัสดุ 1 ชนิดเสมอ เพื่อให้
// พิมพ์ออกมาแล้วบัตรแต่ละใบไม่ถูกตัดคาบเกี่ยวข้ามหน้ากระดาษ (excel package
// ที่ใช้ไม่รองรับการตั้ง page break ภายในชีตเดียวโดยตรง)

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
    String? schoolName,
  }) async {
    final excel = xls.Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final usedSheetNames = <String>{};

    for (var i = 0; i < materials.length; i++) {
      final m = materials[i];
      final sheetName = i == 0 ? defaultSheetName : _sheetNameFor(m, i, usedSheetNames);
      usedSheetNames.add(sheetName);
      if (i == 0) excel.rename(defaultSheetName, sheetName);
      final sheet = excel[sheetName];

      sheet.appendRow([xls.TextCellValue('บัญชีวัสดุ')]);
      if (schoolName != null && schoolName.trim().isNotEmpty) {
        sheet.appendRow([xls.TextCellValue(schoolName)]);
      }
      sheet.appendRow([]);
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
    }

    if (materials.isEmpty) {
      excel[defaultSheetName].appendRow([xls.TextCellValue('(ยังไม่มีวัสดุ)')]);
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
    String? schoolName,
  }) async {
    final file = await export(
      materials: materials,
      transactionsByMaterialId: transactionsByMaterialId,
      schoolName: schoolName,
    );
    await _openFile(file.path);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// ชื่อชีตต้องไม่ซ้ำ ไม่เกิน 31 ตัวอักษร และห้ามมีอักขระ \ / ? * [ ] ตามข้อจำกัดของ Excel
  static String _sheetNameFor(MaterialItem m, int index, Set<String> used) {
    final raw = m.name.trim().isEmpty ? 'วัสดุ ${index + 1}' : m.name.trim();
    final sanitized = raw.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
    final prefix = '${index + 1}. ';
    final maxNameLen = 31 - prefix.length;
    var name = prefix + (sanitized.length > maxNameLen ? sanitized.substring(0, maxNameLen) : sanitized);
    var suffix = 1;
    while (used.contains(name)) {
      suffix++;
      final tag = ' ($suffix)';
      final base = prefix + sanitized;
      final trimLen = 31 - tag.length;
      name = (base.length > trimLen ? base.substring(0, trimLen) : base) + tag;
    }
    return name;
  }

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
