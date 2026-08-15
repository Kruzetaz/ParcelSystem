// asset_repair_export_service.dart
// ส่งออก "ประวัติซ่อมครุภัณฑ์" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/asset_repair_entry.dart';
import '../utils/app_folder_name.dart';

class AssetRepairExportService {
  static Future<File> export(List<AssetRepairEntry> entries) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('ชื่อครุภัณฑ์'),
      xls.TextCellValue('เลขครุภัณฑ์'),
      xls.TextCellValue('วันที่ซ่อม'),
      xls.TextCellValue('รายละเอียด'),
      xls.TextCellValue('สถานที่'),
    ]);

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(e.assetName),
        xls.TextCellValue(e.assetNumber ?? ''),
        xls.TextCellValue(e.eventDate ?? ''),
        xls.TextCellValue(e.description ?? ''),
        xls.TextCellValue(e.assetLocation ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ประวัติซ่อมครุภัณฑ์'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<AssetRepairEntry> entries) async {
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
