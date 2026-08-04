// procurement_document_generator.dart
// สร้างไฟล์ .docx สำหรับเอกสารย่อยที่แยกออกมาจาก master_template.docx (นอกเหนือ
// จาก TOR ที่มี TorDocumentGenerator แยกต่างหากอยู่แล้ว) ใช้ field map ชุดเดียวกับ
// DocumentGenerator (placeholder ที่ไม่ปรากฏในเทมเพลตแต่ละอันจะถูกข้ามเฉยๆ ไม่ error)

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

class ProcurementDocumentGeneratorException implements Exception {
  final String message;
  ProcurementDocumentGeneratorException(this.message);
  @override
  String toString() => 'ProcurementDocumentGeneratorException: $message';
}

enum ProcurementDocumentType {
  contractOrderReport, // รายงานขอซื้อ/ขอจ้าง + คำสั่งแต่งตั้งผู้ตรวจรับพัสดุ
  contractAnnouncement, // รายงานผลการพิจารณา + ประกาศผู้ชนะการเสนอราคา
  quotation, // ใบเสนอราคา
  deliveryNote, // ใบส่งมอบงาน
  disbursementMemo, // บันทึกขออนุมัติเบิกจ่าย
  requisition, // ใบเบิกพัสดุ
  // เอกสารสั่งซื้อ/สั่งจ้างจริงที่ส่งให้ร้านค้า — แยกจาก contractOrderReport
  // ซึ่งเป็นบันทึกขออนุมัติภายในเท่านั้น ใช้ template เดียวกันทั้งซื้อและจ้าง
  // (สลับคำว่า "ซื้อ"/"จ้าง" ด้วย {{order_type}} เหมือน contractOrderReport)
  purchaseOrder, // ใบสั่งซื้อ/ใบสั่งจ้าง (PO/WO)
}

class ProcurementDocumentGenerator {
  static const Map<ProcurementDocumentType, String> _templateAssetPaths = {
    ProcurementDocumentType.contractOrderReport:
        'assets/templates/contract_order_template.docx',
    ProcurementDocumentType.contractAnnouncement:
        'assets/templates/contract_announcement_template.docx',
    ProcurementDocumentType.quotation:
        'assets/templates/quotation_template.docx',
    ProcurementDocumentType.deliveryNote:
        'assets/templates/delivery_note_template.docx',
    ProcurementDocumentType.disbursementMemo:
        'assets/templates/disbursement_memo_template.docx',
    ProcurementDocumentType.requisition:
        'assets/templates/requisition_template.docx',
    ProcurementDocumentType.purchaseOrder:
        'assets/templates/purchase_order_template.docx',
  };

  static const Map<ProcurementDocumentType, String> _outputPrefixes = {
    ProcurementDocumentType.contractOrderReport: 'รายงานขอซื้อขอจ้าง',
    ProcurementDocumentType.contractAnnouncement: 'ประกาศผู้ชนะการเสนอราคา',
    ProcurementDocumentType.quotation: 'ใบเสนอราคา',
    ProcurementDocumentType.deliveryNote: 'ใบส่งมอบงาน',
    ProcurementDocumentType.disbursementMemo: 'บันทึกขออนุมัติเบิกจ่าย',
    ProcurementDocumentType.requisition: 'ใบเบิกพัสดุ',
    ProcurementDocumentType.purchaseOrder: 'ใบสั่งซื้อสั่งจ้าง',
  };

  static Future<File> generate({
    required ProcurementDocumentType type,
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
  }) async {
    final templateAssetPath = _templateAssetPaths[type]!;
    late final ByteData templateData;
    try {
      templateData = await rootBundle.load(templateAssetPath);
    } catch (e) {
      throw ProcurementDocumentGeneratorException(
        'ไม่พบไฟล์เทมเพลตที่ $templateAssetPath\n'
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
      procurementNumber:
          '${_outputPrefixes[type]}_${order.procurementNumber ?? "ไม่ระบุเลขที่"}',
      projectName: order.projectName ?? 'ไม่ระบุชื่อโครงการ',
    );
  }

  static Future<File> generateAndOpen({
    required ProcurementDocumentType type,
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
  }) async {
    final file = await generate(
      type: type,
      order: order,
      school: school,
      items: items,
    );
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
