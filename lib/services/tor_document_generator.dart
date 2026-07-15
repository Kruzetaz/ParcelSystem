// tor_document_generator.dart
// สร้างไฟล์ .docx เฉพาะส่วน TOR/ขอบเขตของงาน — แยกออกมาจาก master_template.docx
// (คำสั่งแต่งตั้งผู้จัดทำ TOR + เอกสารขอบเขตของงาน/คุณลักษณะเฉพาะ พร้อมตาราง
// รายการพัสดุและลายเซ็นผู้กำหนดสเปก) ใช้ field map ชุดเดียวกับ DocumentGenerator
// (placeholder ที่ไม่ปรากฏในเทมเพลตนี้จะถูกข้ามเฉยๆ ไม่ error)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/school_settings.dart';
import '../utils/app_folder_name.dart';
import 'docx_template_service.dart';
import 'document_generator.dart';

class TorDocumentGeneratorException implements Exception {
  final String message;
  TorDocumentGeneratorException(this.message);
  @override
  String toString() => 'TorDocumentGeneratorException: $message';
}

class TorDocumentGenerator {
  static const String _templateAssetPath = 'assets/templates/tor_template.docx';

  static Future<File> generate({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
  }) async {
    late final ByteData templateData;
    try {
      templateData = await rootBundle.load(_templateAssetPath);
    } catch (e) {
      throw TorDocumentGeneratorException(
        'ไม่พบไฟล์เทมเพลต TOR ที่ $_templateAssetPath\n'
        'รายละเอียด: $e',
      );
    }
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );

    final itemDataList = ProcurementItemData.fromItems(items);
    final fieldValues = DocumentGenerator.buildFieldMap(order, school);

    final resultBytes = DocxTemplateService.processTemplate(
      templateBytes: templateBytes,
      fieldValues: fieldValues,
      items: itemDataList,
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = '${docsDir.path}/$folderName';

    return DocxTemplateService.saveOutput(
      docxBytes: resultBytes,
      outputDir: outputDir,
      procurementNumber: 'TOR_${order.procurementNumber ?? "ไม่ระบุเลขที่"}',
      projectName: order.projectName ?? 'ไม่ระบุชื่อโครงการ',
    );
  }

  static Future<File> generateAndOpen({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
  }) async {
    final file = await generate(order: order, school: school, items: items);
    await _openFile(file.path);
    return file;
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
