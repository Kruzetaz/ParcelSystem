// material_list_docx_export_service.dart
// ส่งออก "รายการวัสดุคงเหลือ" เป็นไฟล์ Word (.docx) — ตารางสรุปวัสดุทุกชิ้นใน
// หน้าเดียว (คนละอันกับ "บัญชีวัสดุ"/material_ledger_docx_export_service.dart
// ที่เป็นบัตรคุมสต๊อกแยกหน้าต่อชิ้นพร้อมประวัติรับ-จ่าย) ใช้ตอนต้องการรายการ
// วัสดุคงเหลือแบบสรุปสั้นๆ เช่น แนบประกอบการตรวจนับประจำปี/ส่งมอบงาน

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/material_item.dart';
import '../utils/app_folder_name.dart';
import '../utils/money_format.dart';
import 'docx_template_service.dart';
import 'feature_access_service.dart';

class MaterialListDocxExportService {
  static const String _templateAssetPath =
      'assets/templates/material_list_template.docx';

  static Future<File> export({
    required List<MaterialItem> materials,
    String? schoolName,
    String? educationServiceArea,
    String? preparerName,
    String? directorName,
  }) async {
    if (materials.isEmpty) {
      throw Exception('ยังไม่มีวัสดุให้ส่งออก');
    }
    final templateData = await rootBundle.load(_templateAssetPath);
    final templateBytes = templateData.buffer
        .asUint8List(templateData.offsetInBytes, templateData.lengthInBytes);

    final rows = <Map<String, String>>[];
    var grandTotal = 0.0;
    for (var i = 0; i < materials.length; i++) {
      final m = materials[i];
      grandTotal += m.totalValue;
      rows.add({
        'row_idx': '${i + 1}',
        'row_code': m.materialCode ?? '-',
        'row_name': m.name,
        'row_category': m.category ?? '-',
        'row_unit': m.unit ?? '-',
        'row_remaining': m.remaining.toStringAsFixed(0),
        'row_unit_price': m.unitPrice != null ? formatBaht(m.unitPrice) : '-',
        'row_total_value': formatBaht(m.totalValue),
        'row_location': m.storageLocation ?? '-',
      });
    }

    final now = DateTime.now();
    final fieldValues = {
      'school_name': schoolName ?? '',
      'department_name': (educationServiceArea?.trim().isNotEmpty ?? false)
          ? educationServiceArea!
          : (schoolName ?? ''),
      'print_date': '${now.day} ${_thaiMonths[now.month]} ${now.year + 543}',
      'grand_total_value': formatBaht(grandTotal),
      'preparer_name': preparerName ?? '',
      'director_name': directorName ?? '',
    };

    final docBytes = DocxTemplateService.processGenericTemplate(
      templateBytes: templateBytes,
      fieldValues: fieldValues,
      rowsSeedKey: 'row_idx',
      rows: rows,
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final fileName =
        'รายการวัสดุคงเหลือ_${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}.docx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(docBytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required List<MaterialItem> materials,
    String? schoolName,
    String? educationServiceArea,
    String? preparerName,
    String? directorName,
  }) async {
    FeatureAccessService.instance
        .requireModule(FeatureModules.assetManagement, 'วัสดุ/คลังพัสดุ');
    final file = await export(
      materials: materials,
      schoolName: schoolName,
      educationServiceArea: educationServiceArea,
      preparerName: preparerName,
      directorName: directorName,
    );
    await _openFile(file.path);
  }

  static const _thaiMonths = [
    '',
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

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
