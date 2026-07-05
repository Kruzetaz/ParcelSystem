// docx_template_service.dart
//
// Engine หลักสำหรับประมวลผล Master .docx Template
// - แทนที่ {{placeholder}} ทั้งหมดด้วยค่าจริงจาก procurement_forms
// - Clone table row ที่มี {{item_name}} ตามจำนวนแถวใน procurement_items
//   พร้อม increment {{idx}} อัตโนมัติ
// - Export เป็นไฟล์ .docx ใหม่ (ไม่แตะต้อง master template)
//
// หมายเหตุ: master_template.docx ถูก pre-process ด้วย merge_runs.py แล้ว
// ทำให้ {{placeholder}} ทุกตัวอยู่ใน <w:t> เดียว ไม่ถูกตัดขาด
// จึงไม่จำเป็นต้องใช้ _mergeSplitPlaceholderRuns อีกต่อไป

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import '../models/procurement_item.dart';

/// แทน 1 แถวสินค้าที่จะ clone ลงตาราง
class ProcurementItemData {
  final int idx;
  final String itemName;
  final String quantity;
  final double unitPrice;
  final double totalPrice;

  ProcurementItemData({
    required this.idx,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory ProcurementItemData.fromItem(ProcurementItem item, int idx) {
    return ProcurementItemData(
      idx: idx,
      itemName: item.itemName,
      quantity: item.quantityDisplay,
      unitPrice: item.unitPrice,
      totalPrice: item.totalPrice ?? item.computedTotal,
    );
  }

  static List<ProcurementItemData> fromItems(List<ProcurementItem> items) {
    return [
      for (var i = 0; i < items.length; i++)
        ProcurementItemData.fromItem(items[i], i + 1),
    ];
  }

  Map<String, String> toPlaceholderMap({String Function(double)? money}) {
    final fmt = money ?? (double v) => v.toStringAsFixed(2);
    return {
      'idx': idx.toString(),
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': fmt(unitPrice),
      'total_price': fmt(totalPrice),
    };
  }
}

class DocxTemplateException implements Exception {
  final String message;
  DocxTemplateException(this.message);
  @override
  String toString() => 'DocxTemplateException: $message';
}

class DocxTemplateService {
  static const String _documentXmlPath = 'word/document.xml';

  static Uint8List processTemplate({
    required Uint8List templateBytes,
    required Map<String, String> fieldValues,
    required List<ProcurementItemData> items,
  }) {
    final archive = ZipDecoder().decodeBytes(templateBytes);

    final docFile = archive.files.firstWhere(
      (f) => f.name == _documentXmlPath,
      orElse: () => throw DocxTemplateException(
        'ไม่พบ $_documentXmlPath ในไฟล์ template — อาจไม่ใช่ .docx ที่ถูกต้อง',
      ),
    );

    String xml = utf8.decode(docFile.content as List<int>);

    // STEP 1: Strip MERGEFIELD blocks (เผื่อ template เก่ายังมีหลงเหลือ)
    xml = _stripMergeFields(xml);

    // STEP 2: Clone table rows ตาม items
    xml = _cloneItemRows(xml, items);

    // STEP 3: Replace placeholders ทั้งหมด
    xml = _replacePlaceholders(xml, fieldValues);

    final newDocBytes = utf8.encode(xml);
    final newArchive = Archive();
    for (final file in archive.files) {
      if (file.name == _documentXmlPath) {
        newArchive.addFile(
          ArchiveFile(file.name, newDocBytes.length, newDocBytes),
        );
      } else if (file.isFile) {
        newArchive.addFile(
          ArchiveFile(file.name, file.content.length, file.content),
        );
      }
    }

    final output = ZipEncoder().encode(newArchive);
    if (output == null) {
      throw DocxTemplateException('บีบอัดไฟล์ .docx ใหม่ไม่สำเร็จ');
    }
    return Uint8List.fromList(output);
  }

  static Future<File> saveOutput({
    required Uint8List docxBytes,
    required String outputDir,
    required String procurementNumber,
    required String projectName,
  }) async {
    final safeNumber = _sanitizeFilename(procurementNumber);
    final safeName = _sanitizeFilename(projectName);
    var baseName = '${safeNumber}_$safeName';

    var candidate = File('$outputDir/$baseName.docx');
    var counter = 1;
    while (await candidate.exists()) {
      candidate = File('$outputDir/$baseName ($counter).docx');
      counter++;
    }

    await Directory(outputDir).create(recursive: true);
    return candidate.writeAsBytes(docxBytes, flush: true);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────────

  static String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  static String _stripMergeFields(String xml) {
    xml = xml.replaceAll(
      RegExp(
        r'<w:r\b[^>]*>(?:<w:rPr>.*?</w:rPr>)?<w:instrText[^>]*>.*?</w:instrText>(?:<w:fldChar[^/]*/?>)?</w:r>',
        dotAll: true,
      ),
      '',
    );
    xml = xml.replaceAll(
      RegExp(
        r'<w:r\b[^>]*>(?:<w:rPr>.*?</w:rPr>)?<w:fldChar\b[^/]*/?>(?:<w:ffData>.*?</w:ffData>)?</w:r>',
        dotAll: true,
      ),
      '',
    );
    xml = xml.replaceAll(RegExp(r'<w:fldChar\b[^/]*/>'), '');
    xml = xml.replaceAll(
      RegExp(r'<w:instrText[^>]*>.*?</w:instrText>', dotAll: true),
      '',
    );
    return xml;
  }

  static String _replacePlaceholders(String xml, Map<String, String> values) {
    var result = xml;
    for (final entry in values.entries) {
      result = result.replaceAll(
        '{{${entry.key}}}',
        _escapeXmlText(entry.value),
      );
    }
    return result;
  }

  static String _escapeXmlText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _cloneItemRows(String xml, List<ProcurementItemData> items) {
    final rowPattern = RegExp(r'<w:tr\b[^>]*>.*?</w:tr>', dotAll: true);

    final buffer = StringBuffer();
    var lastEnd = 0;
    var foundAnySeed = false;

    for (final m in rowPattern.allMatches(xml)) {
      final rowXml = m.group(0)!;
      if (!rowXml.contains('{{item_name}}')) continue;

      foundAnySeed = true;
      buffer.write(xml.substring(lastEnd, m.start));

      if (items.isNotEmpty) {
        for (var i = 0; i < items.length; i++) {
          var clonedRow = rowXml;
          final rowValues = items[i].toPlaceholderMap();
          for (final entry in rowValues.entries) {
            clonedRow = clonedRow.replaceAll(
              '{{${entry.key}}}',
              _escapeXmlText(entry.value),
            );
          }
          // แถวที่ 2+ ให้ลบ form-level placeholder ออกจาก cell
          // เพื่อไม่ให้ข้อมูลอย่าง procurement_number และ purpose_reason
          // ซ้ำในทุกแถว (แสดงแค่แถวแรก แถวถัดไปว่าง)
          if (i > 0) {
            clonedRow = clonedRow
                .replaceAll('{{procurement_number}}', '')
                .replaceAll('{{purpose_reason}}', '')
                .replaceAll('{{order_number}}', '');
          }
          buffer.write(clonedRow);
        }
      }
      // items.isEmpty → ลบ seed row ทิ้ง (ไม่ write อะไร)

      lastEnd = m.end;
    }

    if (!foundAnySeed) return xml;

    buffer.write(xml.substring(lastEnd));
    return buffer.toString();
  }
}