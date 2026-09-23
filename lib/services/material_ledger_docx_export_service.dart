// material_ledger_docx_export_service.dart
// ส่งออก "บัญชีวัสดุ" เป็นไฟล์ Word (.docx) ตามแบบฟอร์มราชการจริง (บัตรคุมสต๊อก
// รายชิ้น — วัสดุ 1 ชนิดต่อ 1 หน้า) แทนที่ material_ledger_export_service.dart
// เดิมที่ส่งออกเป็น Excel — ใช้เทมเพลต assets/templates/material_ledger_template.docx
// ร่วมกับ DocxTemplateService.processGenericTemplate (engine เดียวกับเอกสาร
// จัดซื้อจัดจ้างอื่นๆ) clone แถวประวัติรับ-จ่ายตามจำนวนธุรกรรมจริง แล้วรวม
// วัสดุทุกชิ้นเป็นไฟล์เดียวด้วย mergeDocxBodies (คั่นแต่ละชิ้นด้วยขึ้นหน้าใหม่
// เหมือนที่ใช้กับเอกสารสัญญาต่อเนื่องอยู่แล้ว)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/material_item.dart';
import '../models/material_transaction.dart';
import '../utils/app_folder_name.dart';
import '../utils/money_format.dart';
import 'docx_template_service.dart';
import 'feature_access_service.dart';

class MaterialLedgerDocxExportService {
  static const String _templateAssetPath = 'assets/templates/material_ledger_template.docx';

  static Future<File> export({
    required List<MaterialItem> materials,
    required Map<int, List<MaterialTransaction>> transactionsByMaterialId,
    String? schoolName,
    String? educationServiceArea,
  }) async {
    final templateData = await rootBundle.load(_templateAssetPath);
    final templateBytes = templateData.buffer.asUint8List(templateData.offsetInBytes, templateData.lengthInBytes);

    final parts = <Uint8List>[];
    for (var i = 0; i < materials.length; i++) {
      final m = materials[i];
      final transactions = transactionsByMaterialId[m.id] ?? [];
      var runningBalance = 0.0;
      var qtyInTotal = 0.0;
      var qtyOutTotal = 0.0;
      var valueTotal = 0.0;
      final rows = <Map<String, String>>[];
      for (final t in transactions) {
        final isIn = t.transactionType == 'รับเข้า';
        runningBalance += isIn ? t.quantity : -t.quantity;
        if (isIn) {
          qtyInTotal += t.quantity;
          if (t.unitPrice != null) valueTotal += t.unitPrice! * t.quantity;
        } else {
          qtyOutTotal += t.quantity;
        }
        final counterpartyLabel = '${isIn ? "รับจาก" : "จ่ายให้"} ${t.counterparty ?? "-"}';
        rows.add({
          'tx_date': t.transactionDate ?? '-',
          'tx_counterparty': counterpartyLabel,
          'tx_ref': _cleanRefDocument(t.refDocument),
          'tx_unit_price': t.unitPrice != null ? formatBaht(t.unitPrice) : '-',
          'tx_qty_in': isIn ? t.quantity.toStringAsFixed(0) : '-',
          'tx_qty_out': !isIn ? t.quantity.toStringAsFixed(0) : '-',
          'tx_qty_balance': runningBalance.toStringAsFixed(0),
          'tx_note': t.note ?? '',
        });
      }

      final fieldValues = {
        'school_name': schoolName ?? '',
        'department_name': (educationServiceArea?.trim().isNotEmpty ?? false) ? educationServiceArea! : (schoolName ?? ''),
        'sheet_no': '${i + 1}',
        'category': m.category ?? '-',
        'material_name': m.name,
        'material_code': m.materialCode ?? '-',
        'size_spec': m.sizeSpec ?? '-',
        'unit': m.unit ?? '-',
        'storage_location': m.storageLocation ?? '-',
        'max_stock': m.maxStock?.toStringAsFixed(0) ?? '-',
        'min_stock': m.minStock?.toStringAsFixed(0) ?? '-',
        'tx_qty_in_total': qtyInTotal.toStringAsFixed(0),
        'tx_qty_out_total': qtyOutTotal.toStringAsFixed(0),
        'tx_qty_balance_total': runningBalance.toStringAsFixed(0),
        'tx_value_total': formatBaht(valueTotal),
      };

      final docBytes = DocxTemplateService.processGenericTemplate(
        templateBytes: templateBytes,
        fieldValues: fieldValues,
        rowsSeedKey: 'tx_date',
        rows: rows,
      );
      parts.add(docBytes);
    }

    if (parts.isEmpty) {
      throw Exception('ยังไม่มีวัสดุให้ส่งออก');
    }

    final mergedBytes = DocxTemplateService.mergeDocxBodies(parts);

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'บัญชีวัสดุ_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.docx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(mergedBytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required List<MaterialItem> materials,
    required Map<int, List<MaterialTransaction>> transactionsByMaterialId,
    String? schoolName,
    String? educationServiceArea,
  }) async {
    FeatureAccessService.instance.requireModule(FeatureModules.assetManagement, 'วัสดุ/คลังพัสดุ');
    final file = await export(
      materials: materials,
      transactionsByMaterialId: transactionsByMaterialId,
      schoolName: schoolName,
      educationServiceArea: educationServiceArea,
    );
    await _openFile(file.path);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// ช่อง "ที่เอกสาร" ควรโชว์แค่เลขเอกสารอ้างอิงเปล่าๆ (เช่น "ซ77/2569")
  /// แต่ ref_document ของรายการที่มาจากฟีเจอร์ "ดึงจากโครงการ" จะขึ้นต้นด้วย
  /// "ดึงจากโครงการ " เสมอ (ตั้งใจเก็บไว้แบบนั้นในฐานข้อมูล เพราะใช้จับคู่แบบ
  /// exact-match กันดึงซ้ำใน getOrdersNotYetPulledToMaterials — แก้ตรงนั้น
  /// ไม่ได้) เลยตัด prefix ออกแค่ตอนพิมพ์แสดงผลที่นี่แทน
  static const _refPrefixesToStrip = ['ดึงจากโครงการ '];

  static String _cleanRefDocument(String? ref) {
    if (ref == null || ref.trim().isEmpty) return '-';
    var cleaned = ref.trim();
    for (final prefix in _refPrefixesToStrip) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    return cleaned;
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
      // เปิดไฟล์อัตโนมัติไม่สำเร็จ — ไฟล์ยังถูกสร้างไว้แล้ว ผู้ใช้เปิดเองได้
    }
  }
}
