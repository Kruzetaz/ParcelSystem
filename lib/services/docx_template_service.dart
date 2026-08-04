// docx_template_service.dart
//
// Engine หลักสำหรับประมวลผล Master .docx Template
// - Merge run ที่ถูก Word ตัดขาดกลาง {{placeholder}} แบบ "เฉพาะกลุ่มที่จำเป็น"
//   (ไม่ merge ทั้งย่อหน้า) เพื่อไม่ให้ฟอร์แมต/ช่องว่างเดิมของ run อื่นเสียหาย
// - แทนที่ {{placeholder}} ทั้งหมดด้วยค่าจริงจาก procurement_forms
// - Clone table row ที่มี {{item_name}} ตามจำนวนแถวใน procurement_items
//   พร้อม increment {{idx}} อัตโนมัติ
// - Export เป็นไฟล์ .docx ใหม่ (ไม่แตะต้อง master template)
//
// หมายเหตุ: ไม่ต้องพึ่ง merge_runs.py pre-process อีกต่อไป — merge run
// ทำที่นี่แบบ runtime ทุกครั้งที่ generate เอกสาร และปลอดภัยกว่าเดิม
// (เดิม merge ทั้งย่อหน้าทำให้ format/ช่องว่างของ run ที่ไม่เกี่ยวกับ
// placeholder เสียหายไปด้วย — บั๊กนี้แก้แล้วโดยการ merge เฉพาะกลุ่ม run
// ที่ประกอบกันเป็น {{...}} ที่ถูกตัดขาดจริงเท่านั้น)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import '../models/procurement_item.dart';
import '../utils/money_format.dart';

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
    final fmt = money ?? (double v) => formatBaht(v);
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

    // STEP 0: Merge run ที่ถูก Word ตัดขาดกลาง {{placeholder}} — เฉพาะ
    // กลุ่ม run ที่จำเป็นจริงๆ เท่านั้น ไม่แตะ run อื่นในย่อหน้าเลย
    xml = _mergeSplitPlaceholderRuns(xml);

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

  /// รวมเฉพาะกลุ่ม <w:r> ที่ประกอบกันเป็น {{placeholder}} ที่ถูก Word ตัดขาด
  /// (มักเกิดจาก autocorrect/spellcheck แทรก <w:proofErr> คั่นกลาง)
  ///
  /// ต่างจาก implementation เดิมที่ merge "ทั้งย่อหน้า" — ตัวนี้ merge เฉพาะ
  /// run ที่ char-range ของมันซ้อนกับช่วง {{...}} ที่ตรวจพบว่าขาดตอนจริง
  /// เท่านั้น run อื่นในย่อหน้าเดียวกันที่ไม่เกี่ยวข้องจะถูกคัดลอกผ่านแบบ
  /// raw XML เดิมทุกตัวอักษร ไม่แตะ format หรือช่องว่างใดๆ ของมันเลย
  static String _mergeSplitPlaceholderRuns(String xml) {
    final paraPattern = RegExp(r'<w:p\b[^>]*>.*?</w:p>', dotAll: true);

    return xml.replaceAllMapped(paraPattern, (m) {
      final para = m.group(0)!;
      if (!para.contains('{{')) return para;

      final runPattern = RegExp(r'<w:r\b[^>]*>.*?</w:r>', dotAll: true);
      final runs = runPattern.allMatches(para).map((r) => r.group(0)!).toList();
      if (runs.length < 2) return para;

      final tPattern = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>', dotAll: true);

      // ข้อความของแต่ละ run (รองรับ run ที่ไม่มี <w:t> เลย เช่น <w:tab/>, <w:br/> -> '')
      final runTexts = runs.map((r) {
        final tm = tPattern.firstMatch(r);
        return tm != null ? tm.group(1)! : '';
      }).toList();

      // ตำแหน่งเริ่ม/จบของแต่ละ run ใน combined text (หน่วย: unescaped char)
      final starts = <int>[];
      final ends = <int>[];
      var pos = 0;
      final combinedBuffer = StringBuffer();
      for (final t in runTexts) {
        final unescaped = _unescapeXmlText(t);
        starts.add(pos);
        combinedBuffer.write(unescaped);
        pos += unescaped.length;
        ends.add(pos);
      }
      final combined = combinedBuffer.toString();

      if (!RegExp(r'\{\{[^{}]+\}\}').hasMatch(combined)) return para;

      // หาช่วง run-index ที่ต้อง merge จริง (เฉพาะ match ที่คาบเกี่ยวมากกว่า 1 run)
      final mergeRanges = <List<int>>[]; // [firstRunIdx, lastRunIdx]
      for (final tagMatch in RegExp(r'\{\{[^{}]+\}\}').allMatches(combined)) {
        int? firstIdx, lastIdx;
        for (var i = 0; i < starts.length; i++) {
          if (starts[i] < tagMatch.end && ends[i] > tagMatch.start) {
            firstIdx ??= i;
            lastIdx = i;
          }
        }
        if (firstIdx != null && lastIdx != null && lastIdx > firstIdx) {
          mergeRanges.add([firstIdx, lastIdx]);
        }
      }
      if (mergeRanges.isEmpty) return para; // ไม่มี placeholder ไหนถูกตัดขาดจริง

      // รวม range ที่ทับซ้อน/ติดกันเข้าด้วยกัน (เผื่อ 2 placeholder แชร์ run กลาง)
      mergeRanges.sort((a, b) => a[0].compareTo(b[0]));
      final merged = <List<int>>[];
      for (final r in mergeRanges) {
        if (merged.isNotEmpty && r[0] <= merged.last[1]) {
          merged.last[1] = r[1] > merged.last[1] ? r[1] : merged.last[1];
        } else {
          merged.add([r[0], r[1]]);
        }
      }

      // ถ้ากลุ่มไหนมี run ที่ไม่มี <w:t> เลย (opaque เช่น tab/br/drawing) อยู่ตรงกลาง
      // ให้ข้ามกลุ่มนั้นไปอย่างปลอดภัย (ไม่ merge) ป้องกันโครงสร้าง XML พัง
      final safeMerged = merged.where((range) {
        for (var i = range[0]; i <= range[1]; i++) {
          if (!runs[i].contains('<w:t')) return false;
        }
        return true;
      }).toList();
      if (safeMerged.isEmpty) return para;

      // สร้างย่อหน้าใหม่: run ที่ไม่อยู่ในกลุ่มไหนเลย -> คัดลอกผ่านตรงๆ
      // run ที่อยู่ในกลุ่ม -> แทนด้วย run เดียวที่รวมข้อความ + ใช้ rPr ของ run แรกในกลุ่ม
      final rprPattern = RegExp(r'<w:rPr>.*?</w:rPr>', dotAll: true);
      final buffer = StringBuffer();
      var i = 0;
      var rangeIdx = 0;
      while (i < runs.length) {
        if (rangeIdx < safeMerged.length && i == safeMerged[rangeIdx][0]) {
          final range = safeMerged[rangeIdx];
          final groupText = StringBuffer();
          for (var j = range[0]; j <= range[1]; j++) {
            groupText.write(runTexts[j]); // เก็บ raw-escaped text ตรงๆ พอ (จะ escape รวมทีเดียวด้านล่าง)
          }
          final firstRun = runs[range[0]];
          final rprMatch = rprPattern.firstMatch(firstRun);
          final rpr = rprMatch?.group(0) ?? '';
          final escaped = _escapeXmlText(_unescapeXmlText(groupText.toString()));
          buffer.write('<w:r>$rpr<w:t xml:space="preserve">$escaped</w:t></w:r>');
          i = range[1] + 1;
          rangeIdx++;
        } else {
          buffer.write(runs[i]);
          i++;
        }
      }

      // แทนที่ run ทั้งหมดในย่อหน้าด้วยเวอร์ชันใหม่ (ตำแหน่งเดิม, นอก <w:r> คงเดิม)
      var result = para;
      final allRunsPattern = RegExp(r'<w:r\b[^>]*>.*?</w:r>', dotAll: true);
      // ลบ run เดิมทั้งหมด (รวม proofErr ที่คั่นกลางกลุ่มที่ merge ไปด้วย) แล้วแทรกผลลัพธ์ใหม่
      // หา index ของ run แรกสุดในย่อหน้าเพื่อรู้ตำแหน่งแทรก
      final firstRunMatch = allRunsPattern.firstMatch(result);
      if (firstRunMatch == null) return para;

      // แทนที่ตั้งแต่ run แรกถึง run สุดท้ายในย่อหน้า (รวม <w:proofErr/> ที่
      // Word แทรกคั่นกลางไปด้วย — proofErr เป็นแค่ตัวช่วยตรวจสะกด ไม่มีผลต่อ
      // เนื้อหา/layout จริง ตัดออกได้ปลอดภัย) ด้วยลำดับ run ใหม่ที่สร้างไว้
      final lastRunEnd = runPattern.allMatches(result).last.end;
      return result.replaceRange(
        firstRunMatch.start,
        lastRunEnd,
        buffer.toString(),
      );
    });
  }

  static String _unescapeXmlText(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
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
    // ตัดเครื่องหมายขึ้นบรรทัดใหม่ที่หลุดติดมาในค่าที่กรอก (เช่น พิมพ์เผลอกด
    // Enter, หรือวางข้อความที่ก็อปมาจากที่อื่นแล้วมีบรรทัดใหม่ติดมา) ให้เหลือ
    // แค่ช่องว่างแทน — ถ้าไม่ตัด อักขระ \n/\r ดิบจะหลุดเข้าไปอยู่ใน <w:t> ตรงๆ
    // ซึ่ง Word จะตีความเป็นการขึ้นบรรทัดใหม่กลางประโยค ทำให้ข้อความที่ควรต่อกัน
    // (เช่น "{{school_name}} จะดำเนินการจัด{{procurement_subject}}") ถูกตัดขึ้น
    // บรรทัดใหม่แบบเลือกไม่ได้ ลบไม่ออกในไฟล์ที่สร้างออกมา (ต้นเหตุคือค่าข้อมูล
    // ไม่ใช่ตัว template — ตัว template เองไม่มี <w:br/> หรือย่อหน้าแยกตรงจุดนั้น)
    final normalized = value
        .replaceAll('\r\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return normalized
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