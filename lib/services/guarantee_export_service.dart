// guarantee_export_service.dart
// ส่งออก "ทะเบียนหลักประกัน" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/guarantee.dart';
import '../utils/app_folder_name.dart';

class GuaranteeExportService {
  static Future<File> export(List<Guarantee> guarantees) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('ประเภทหลักประกัน'),
      xls.TextCellValue('คู่สัญญา'),
      xls.TextCellValue('วงเงินค้ำประกัน (บาท)'),
      xls.TextCellValue('วันที่เริ่มค้ำประกัน'),
      xls.TextCellValue('วันหมดอายุ'),
      xls.TextCellValue('สถานะ'),
      xls.TextCellValue('วันที่คืน'),
    ]);

    for (var i = 0; i < guarantees.length; i++) {
      final g = guarantees[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(g.guaranteeType ?? '-'),
        xls.TextCellValue(g.counterpartyName ?? '-'),
        g.amount != null ? xls.DoubleCellValue(g.amount!) : xls.TextCellValue('-'),
        xls.TextCellValue(g.startDate ?? '-'),
        xls.TextCellValue(g.expiryDate ?? '-'),
        xls.TextCellValue(g.status),
        xls.TextCellValue(g.returnedDate ?? '-'),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ทะเบียนหลักประกัน'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<Guarantee> guarantees) async {
    final file = await export(guarantees);
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
