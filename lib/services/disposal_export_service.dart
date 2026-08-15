// disposal_export_service.dart
// ส่งออก "ทะเบียนจำหน่ายพัสดุ" เป็นไฟล์ Excel (.xlsx)

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/disposal.dart';
import '../models/fixed_asset.dart';
import '../utils/app_folder_name.dart';

class DisposalExportService {
  /// [assetsById] ใช้แปลง assetId ที่ผูกไว้ (ถ้ามี) เป็นเลขครุภัณฑ์/ชื่อรายการ
  /// จริง — ตรงกับที่หน้าจำหน่ายพัสดุแสดงผล (ผูกกับทะเบียนครุภัณฑ์แบบไม่บังคับ
  /// ถ้าไม่ได้ผูกจะใช้ itemName ที่กรอกเองแทน)
  static Future<File> export(List<Disposal> disposals, Map<int, FixedAsset> assetsById) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('เลขครุภัณฑ์'),
      xls.TextCellValue('ชื่อรายการ'),
      xls.TextCellValue('วิธีการจำหน่าย'),
      xls.TextCellValue('วันที่อนุมัติจำหน่าย'),
      xls.TextCellValue('ผู้ลงนามอนุมัติ'),
      xls.TextCellValue('สถานะ'),
    ]);

    for (var i = 0; i < disposals.length; i++) {
      final d = disposals[i];
      final asset = d.assetId != null ? assetsById[d.assetId] : null;
      final itemLabel = asset?.name ?? d.itemName ?? '-';
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(asset?.assetNumber ?? '-'),
        xls.TextCellValue(itemLabel),
        xls.TextCellValue(d.disposalMethod ?? '-'),
        xls.TextCellValue(d.approvedDate ?? '-'),
        xls.TextCellValue(d.approverName ?? '-'),
        xls.TextCellValue(d.status),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'ทะเบียนจำหน่ายพัสดุ'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen(List<Disposal> disposals, Map<int, FixedAsset> assetsById) async {
    final file = await export(disposals, assetsById);
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
