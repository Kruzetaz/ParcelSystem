// docx_template_service.dart
//
// Engine หลักสำหรับประมวลผล Master .docx Template
// - แทนที่ {{placeholder}} ทั้งหมดด้วยค่าจริงจาก procurement_forms
// - Clone table row ที่มี {{item_name}} ตามจำนวนแถวใน procurement_items
//   พร้อม increment {{idx}} อัตโนมัติ
// - Export เป็นไฟล์ .docx ใหม่ (ไม่แตะต้อง master template)
//
// วิธีทำงาน: .docx คือไฟล์ zip ที่มี word/document.xml อยู่ข้างใน
// เราแกะ zip ด้วย package:archive, แก้ไข XML ตรงๆ ด้วย regex/string ops
// แล้วบีบอัดกลับเป็น .docx ใหม่
//
// Dependencies (pubspec.yaml):
//   archive: ^3.6.1
//   path: ^1.9.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

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

  /// key ต้องตรงกับ {{key}} ในเทมเพลต (ไม่รวมปีกกา)
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

  /// ประมวลผลไฟล์ template ทั้งก้อน: replace placeholder + clone rows
  ///
  /// [templateBytes] = bytes ของ master .docx (อ่านจากไฟล์)
  /// [fieldValues] = ค่าจาก procurement_forms row เดียว (key ไม่ใส่ {{}})
  /// [items] = รายการ procurement_items ทั้งหมดของ procurement_number นี้
  ///
  /// คืนค่าเป็น Uint8List ของไฟล์ .docx ใหม่ พร้อมเขียนลงดิสก์
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

    // STEP 1: Word มักตัด {{placeholder}} กระจายไป หลาย <w:r> เนื่องจาก
    // spellcheck/autocorrect (เช่น {{ite</w:t></w:r><w:r><w:t>m_name}})
    // ต้อง merge run ที่แตกกันก่อน ไม่งั้น regex หา placeholder ไม่เจอ
    xml = _mergeSplitPlaceholderRuns(xml);

    // STEP 2: Clone table row ตาม items ก่อน (ต้องทำก่อน replace ปกติ
    // เพราะ {{item_name}} เป็น marker บอกตำแหน่งแถว seed)
    xml = _cloneItemRows(xml, items);

    // STEP 3: แทนที่ placeholder ทั่วไปที่เหลือทั้งหมด (field ระดับฟอร์ม)
    xml = _replacePlaceholders(xml, fieldValues);

    // เขียน XML ที่แก้แล้วกลับเข้า archive
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

  /// บันทึกผลลัพธ์ลงดิสก์ ด้วย naming convention: [เลขที่]_[ชื่อโครงการ].docx
  /// จะสร้างชื่อไฟล์ที่ไม่ทับไฟล์เดิม (เติม (1), (2) ถ้าซ้ำ)
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

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  static String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// รวม <w:r>...<w:t>...</w:t>...</w:r> ที่ต่อเนื่องกันภายในย่อหน้าเดียวกัน
  /// ให้กลายเป็น run เดียว เมื่อพบว่าข้อความรวมกันมี {{...}} ที่ถูกตัดขาด
  ///
  /// วิธีนี้ใช้แนวทาง "flatten" ต่อ <w:p>...</w:p> block:
  /// ดึงเฉพาะเนื้อหาใน <w:t> ทั้งหมดออกมาต่อกัน ถ้าเจอ {{ ในย่อหน้านั้น
  /// ให้ merge ทุก run ในย่อหน้าเป็น run เดียว (ใช้ rPr ของ run แรก)
  /// เพื่อความปลอดภัยสูงสุดของการจับ placeholder แม้จะเสียฟอร์แมตย่อยๆ
  /// ของ run กลาง (ปกติ placeholder ไม่ควรมีฟอร์แมตต่างกันอยู่แล้ว)
  static String _mergeSplitPlaceholderRuns(String xml) {
    final paragraphPattern = RegExp(r'<w:p\b[^>]*>.*?</w:p>', dotAll: true);

    return xml.replaceAllMapped(paragraphPattern, (match) {
      final paragraph = match.group(0)!;

      // เฉพาะย่อหน้าที่มี {{ อยู่จริง และมีโอกาสถูกตัดขาด
      if (!paragraph.contains('{{')) return paragraph;

      // ดึงข้อความล้วนจากทุก <w:t> ในย่อหน้า
      final tPattern = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
      final texts = tPattern.allMatches(paragraph).map((m) => m.group(1)!).toList();
      final combinedText = texts.join();

      // ถ้ารวมข้อความแล้วไม่มี {{...}} ที่สมบูรณ์กว่าตอนแยก ไม่ต้องทำอะไร
      final hasCompletePlaceholder = RegExp(r'\{\{[^{}]+\}\}').hasMatch(combinedText);
      if (!hasCompletePlaceholder) return paragraph;

      // ถ้าทุก <w:t> เดิมมี placeholder ครบในตัวเองอยู่แล้ว (ไม่ได้ถูกตัด) ก็ไม่ต้อง merge
      final alreadyIntact = texts.every((t) =>
          !t.contains('{{') && !t.contains('}}') ||
          RegExp(r'\{\{[^{}]*\}\}').hasMatch(t) == RegExp(r'\{\{|\}\}').hasMatch(t));
      if (texts.length <= 1 || alreadyIntact && !_looksSplit(texts)) {
        // เดิมไม่ได้ถูกตัดขาดจริง ปล่อยผ่าน
        if (!_looksSplit(texts)) return paragraph;
      }

      // หา run แรกเพื่อใช้เป็นแม่แบบ rPr (รักษาฟอนต์/ขนาดของ placeholder)
      final firstRunMatch = RegExp(r'<w:r\b[^>]*>.*?</w:r>', dotAll: true).firstMatch(paragraph);
      String rPr = '';
      if (firstRunMatch != null) {
        final rPrMatch = RegExp(r'<w:rPr>.*?</w:rPr>', dotAll: true).firstMatch(firstRunMatch.group(0)!);
        if (rPrMatch != null) rPr = rPrMatch.group(0)!;
      }

      // สร้าง run ใหม่ตัวเดียวที่รวมข้อความทั้งหมด แทนที่ทุก <w:r> เดิม
      final escapedText = combinedText
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      final mergedRun =
          '<w:r>$rPr<w:t xml:space="preserve">$escapedText</w:t></w:r>';

      // แทนที่ทุก <w:r>...</w:r> ในย่อหน้าด้วย run เดียวนี้
      final withoutRuns = paragraph.replaceAll(
        RegExp(r'<w:r\b[^>]*>.*?</w:r>', dotAll: true),
        '',
      );
      // แทรก mergedRun กลับก่อน </w:p>
      return withoutRuns.replaceFirst('</w:p>', '$mergedRun</w:p>');
    });
  }

  /// heuristic: {{ หรือ }} ปรากฏคนละ <w:t> กัน แปลว่าน่าจะถูกตัดขาด
  static bool _looksSplit(List<String> texts) {
    final joined = texts.join('\u0001');
    final hasOpen = joined.contains('{{');
    final hasCloseSeparate = RegExp(r'\{\{[^\u0001]*\u0001').hasMatch(joined) ||
        RegExp(r'\u0001[^\u0001]*\}\}').hasMatch(joined);
    return hasOpen && hasCloseSeparate;
  }

  /// แทนที่ {{key}} ทั่วไปด้วยค่าจาก [values] ทีละ key
  /// key ที่หาไม่เจอใน map จะถูกปล่อยไว้เฉยๆ (ไม่ลบทิ้ง) เพื่อให้เห็น
  /// ง่ายตอน debug ว่ายังมี field ไหนไม่ได้ map
  static String _replacePlaceholders(String xml, Map<String, String> values) {
    var result = xml;
    for (final entry in values.entries) {
      final placeholder = '{{${entry.key}}}';
      final escapedValue = _escapeXmlText(entry.value);
      result = result.replaceAll(placeholder, escapedValue);
    }
    return result;
  }

  static String _escapeXmlText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// หาแถวตาราง (<w:tr>) ที่มี {{item_name}} อยู่ข้างใน ใช้เป็น "seed row"
  /// แล้ว clone แถวนั้นตามจำนวน [items] โดยแทน placeholder เฉพาะแถว
  /// ({{idx}}, {{item_name}}, {{quantity}}, {{unit_price}}, {{total_price}})
  /// ในแต่ละสำเนา จากนั้นลบ seed row ต้นฉบับออก แล้วแทรกแถวที่ clone แล้วแทน
  static String _cloneItemRows(String xml, List<ProcurementItemData> items) {
    final rowPattern = RegExp(r'<w:tr\b[^>]*>.*?</w:tr>', dotAll: true);
    final rows = rowPattern.allMatches(xml).toList();

    String? seedRow;
    for (final m in rows) {
      if (m.group(0)!.contains('{{item_name}}')) {
        seedRow = m.group(0);
        break;
      }
    }

    if (seedRow == null) {
      // ไม่มี seed row ในเอกสารนี้ (เช่นเอกสารที่ไม่มีตารางรายการ) — ข้ามได้
      return xml;
    }

    if (items.isEmpty) {
      // ไม่มีรายการสินค้า — ลบ seed row ทิ้งไปเลย ป้องกันเหลือ {{...}} ค้าง
      return xml.replaceFirst(seedRow, '');
    }

    final buffer = StringBuffer();
    for (final item in items) {
      var rowXml = seedRow;
      final rowValues = item.toPlaceholderMap();
      for (final entry in rowValues.entries) {
        rowXml = rowXml.replaceAll(
          '{{${entry.key}}}',
          _escapeXmlText(entry.value),
        );
      }
      buffer.write(rowXml);
    }

    return xml.replaceFirst(seedRow, buffer.toString());
  }
}