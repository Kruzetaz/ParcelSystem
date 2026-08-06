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
    Map<String, bool> conditionalFlags = const {},
  }) {
    final archive = ZipDecoder().decodeBytes(templateBytes);

    final docFile = archive.files.firstWhere(
      (f) => f.name == _documentXmlPath,
      orElse: () => throw DocxTemplateException(
        'ไม่พบ $_documentXmlPath ในไฟล์ template — อาจไม่ใช่ .docx ที่ถูกต้อง',
      ),
    );

    String xml = utf8.decode(docFile.content as List<int>);

    // STEP -1: แยก run ที่มีหลาย {{...}} ติดกันออกเป็นคนละ run — ป้องกันบั๊ก
    // ที่เจอจริง: เปิด template ใน Word แล้วแก้ไข/บันทึกจุดอื่นที่ไม่เกี่ยวกันเลย
    // Word จะ "ทำความสะอาด" เอกสารทุกครั้งที่ save โดยรวม run ที่ format
    // เหมือนกันทุกอย่างเข้าด้วยกัน (เช่น marker เงื่อนไข 2 ตัวติดกันที่ font/ขนาด/
    // ซ่อนไว้เหมือนกันทุกอย่าง) ทำให้ {{if:x}}{{endif:x}} ไปติดอยู่ใน <w:t>
    // เดียวกัน แล้วตอนตัด marker ตัวหนึ่งออกจะพาอีกตัวที่แอบอยู่ใน run เดียวกัน
    // หายไปด้วย — ขั้นตอนนี้แยกกลับให้เป็นคนละ run เสมอ ก่อนประมวลผลอะไรทั้งสิ้น
    // ทำให้ไม่ต้องพึ่งว่า template ต้องคงสภาพเดิมเป๊ะๆ ตลอดไป
    xml = _splitMergedMarkerRuns(xml);

    // STEP 0: Merge run ที่ถูก Word ตัดขาดกลาง {{placeholder}} — เฉพาะ
    // กลุ่ม run ที่จำเป็นจริงๆ เท่านั้น ไม่แตะ run อื่นในย่อหน้าเลย
    xml = _mergeSplitPlaceholderRuns(xml);

    // STEP 1: Strip MERGEFIELD blocks (เผื่อ template เก่ายังมีหลงเหลือ)
    xml = _stripMergeFields(xml);

    // STEP 2: Clone table rows ตาม items
    xml = _cloneItemRows(xml, items);

    // STEP 2.5: ตัด/เก็บข้อความบางช่วงตามเงื่อนไข (เช่น ย่อหน้าที่ใช้ได้แค่
    // กรณีผู้ตรวจรับคนเดียว ไม่ใช่คณะกรรมการ) — ต้องทำก่อน replace placeholder
    // ทั่วไป เพราะ marker เองก็อยู่ในรูป {{if:...}}/{{endif:...}}
    xml = _applyConditionals(xml, conditionalFlags);

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

  /// รวมไฟล์ .docx หลายไฟล์ (bytes ของแต่ละไฟล์ที่ประมวลผลแล้ว) เข้าเป็น
  /// ไฟล์เดียว ต่อกันตามลำดับที่ส่งเข้ามา คั่นแต่ละส่วนด้วยการขึ้นหน้าใหม่
  /// — ใช้สำหรับสัญญาต่อเนื่อง (เช่น อาหารกลางวัน) ที่ต้องการเอกสารจัดจ้าง
  /// ตอนแรก + ชุดเอกสารรายงวดทั้งหมด รวมอยู่ในไฟล์ .docx เดียวกัน เหมือนที่
  /// โรงเรียนทำเก็บไว้จริง (ไม่ใช่แยกไฟล์คนละใบ)
  ///
  /// ใช้ package (styles.xml, ตั้งค่าหน้ากระดาษ ฯลฯ) ของไฟล์ "แรก" เป็นฐาน
  /// แล้วดึงแค่เนื้อหาใน <w:body> (ไม่รวม <w:sectPr> ท้ายสุด) ของไฟล์ถัดๆ ไป
  /// มาต่อท้ายก่อน sectPr ของฐาน — ปลอดภัยเพราะทุกเทมเพลตในระบบนี้จัดฟอร์แมต
  /// แบบ direct-formatting (TH SarabunIT๙ ฝังในแต่ละ run) ไม่ได้พึ่ง named
  /// style ข้ามไฟล์ และไม่มีรูปภาพ/ไฮเปอร์ลิงก์ที่ต้องจับคู่ relationship ID
  static Uint8List mergeDocxBodies(List<Uint8List> parts) {
    if (parts.isEmpty) {
      throw DocxTemplateException('ไม่มีเอกสารให้รวม');
    }
    if (parts.length == 1) return parts.first;

    final baseArchive = ZipDecoder().decodeBytes(parts.first);
    final baseDocFile = baseArchive.files.firstWhere(
      (f) => f.name == _documentXmlPath,
      orElse: () => throw DocxTemplateException('ไฟล์แรกไม่ใช่ .docx ที่ถูกต้อง'),
    );
    var baseXml = utf8.decode(baseDocFile.content as List<int>);

    const pageBreak = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
    final buffer = StringBuffer();
    for (var i = 1; i < parts.length; i++) {
      final archive = ZipDecoder().decodeBytes(parts[i]);
      final docFile = archive.files.firstWhere(
        (f) => f.name == _documentXmlPath,
        orElse: () => throw DocxTemplateException('เอกสารลำดับที่ ${i + 1} ไม่ใช่ .docx ที่ถูกต้อง'),
      );
      final xml = utf8.decode(docFile.content as List<int>);
      // จับเนื้อหาทั้งหมดใน <w:body> ก่อนถึง <w:sectPr> ตัวสุดท้าย (greedy
      // .* จะกินไปจนถึง sectPr ตัวท้ายสุดพอดี เผื่อกรณีมี sectPr กลางเอกสาร)
      final match = RegExp(r'<w:body>(.*)<w:sectPr\b[^>]*>.*?</w:sectPr>\s*</w:body>', dotAll: true)
          .firstMatch(xml);
      if (match == null) {
        throw DocxTemplateException('ไม่พบโครงสร้าง <w:body> ในเอกสารลำดับที่ ${i + 1}');
      }
      buffer.write(pageBreak);
      buffer.write(match.group(1));
    }

    // แทรกเนื้อหาที่รวมมาทั้งหมด ก่อน <w:sectPr> ของไฟล์ฐาน (ต้องอยู่ท้ายสุด
    // ของ body เสมอตามสเปก OOXML)
    final baseSectPrIndex = baseXml.lastIndexOf('<w:sectPr');
    if (baseSectPrIndex == -1) {
      throw DocxTemplateException('ไม่พบ <w:sectPr> ในไฟล์ฐาน');
    }
    baseXml = baseXml.substring(0, baseSectPrIndex) + buffer.toString() + baseXml.substring(baseSectPrIndex);

    final newDocBytes = utf8.encode(baseXml);
    final newArchive = Archive();
    for (final file in baseArchive.files) {
      if (file.name == _documentXmlPath) {
        newArchive.addFile(ArchiveFile(file.name, newDocBytes.length, newDocBytes));
      } else if (file.isFile) {
        newArchive.addFile(ArchiveFile(file.name, file.content.length, file.content));
      }
    }
    final output = ZipEncoder().encode(newArchive);
    if (output == null) {
      throw DocxTemplateException('บีบอัดไฟล์ .docx ที่รวมแล้วไม่สำเร็จ');
    }
    return Uint8List.fromList(output);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────────

  static String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// แยก run เดียวที่มีหลาย {{...}} ต่อกันแบบไม่มีข้อความอื่นคั่น (เช่น
  /// "{{endif:a}}{{if:b}}") ออกเป็นคนละ run ต่อ marker หนึ่งตัว — คงค่า rPr
  /// (font/ขนาด/ซ่อน) เดิมไว้ทุกตัว กันบั๊ก Word รวม run ที่ format เหมือนกัน
  /// เข้าด้วยกันตอน save ทำให้ตัด marker ตัวเดียวแล้วพา marker ข้างเคียงหายไปด้วย
  static String _splitMergedMarkerRuns(String xml) {
    final runPattern = RegExp(r'<w:r\b[^>]*>.*?</w:r>', dotAll: true);
    return xml.replaceAllMapped(runPattern, (m) {
      final run = m.group(0)!;
      final tMatch = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true).firstMatch(run);
      if (tMatch == null) return run;
      final text = tMatch.group(1)!;
      final tokens = RegExp(r'\{\{[^{}]+\}\}').allMatches(text).map((t) => t.group(0)!).toList();
      // ต้องมีมากกว่า 1 marker และเนื้อหาทั้งหมดใน run นี้ประกอบด้วย marker
      // ล้วนๆ ต่อกัน (ไม่มีข้อความอื่นแทรกอยู่) ถึงจะปลอดภัยที่จะแยก — ถ้ามี
      // ข้อความอื่นปนอยู่ด้วย (เช่น "ก่อน {{a}}") ให้ข้ามไป ไม่ยุ่งกับมัน
      if (tokens.length < 2 || tokens.join() != text) return run;

      final rprMatch = RegExp(r'<w:rPr>.*?</w:rPr>', dotAll: true).firstMatch(run);
      final rpr = rprMatch?.group(0) ?? '';
      final buffer = StringBuffer();
      for (final token in tokens) {
        buffer.write('<w:r>$rpr<w:t>$token</w:t></w:r>');
      }
      return buffer.toString();
    });
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

  /// ตัด/เก็บข้อความบางช่วงในเอกสารตามเงื่อนไข — ใช้เครื่องหมายคู่
  /// {{if:FLAG}}...{{endif:FLAG}} ที่แทรกไว้เป็น run แยกต่างหากใน template
  /// (เห็นได้เฉพาะตอนเปิดดู template ดิบ เพราะซ่อนไว้ด้วย w:vanish อยู่แล้ว):
  /// - FLAG เป็น true  -> เก็บเนื้อหาไว้ ตัดแค่ตัว marker ทั้งสองฝั่งออก
  /// - FLAG เป็น false -> ตัดทั้งช่วงตั้งแต่ marker เริ่มถึง marker จบทิ้งทั้งหมด
  ///   (รวมเนื้อหาระหว่างนั้น เช่น ประโยค/บรรทัดที่ใช้ไม่ได้ในกรณีนี้)
  /// ถ้า template ไม่มี marker คู่นี้อยู่เลย ก็แค่ข้ามไปเฉยๆ ไม่ error
  static String _applyConditionals(String xml, Map<String, bool> flags) {
    var result = xml;
    for (final entry in flags.entries) {
      final startMarker = '{{if:${entry.key}}}';
      final endMarker = '{{endif:${entry.key}}}';
      final startRunPattern = RegExp(
        '<w:r\\b[^>]*>(?:(?!</w:r>).)*?${RegExp.escape(startMarker)}(?:(?!</w:r>).)*?</w:r>',
        dotAll: true,
      );
      final endRunPattern = RegExp(
        '<w:r\\b[^>]*>(?:(?!</w:r>).)*?${RegExp.escape(endMarker)}(?:(?!</w:r>).)*?</w:r>',
        dotAll: true,
      );
      final startMatch = startRunPattern.firstMatch(result);
      final endMatch = endRunPattern.firstMatch(result);
      if (startMatch == null || endMatch == null) continue;

      if (entry.value) {
        // ลบจากท้ายไปหน้า (endMatch ก่อน) กัน offset ของ startMatch เพี้ยน
        result = result.replaceRange(endMatch.start, endMatch.end, '');
        result = result.replaceRange(startMatch.start, startMatch.end, '');
      } else {
        result = result.replaceRange(startMatch.start, endMatch.end, '');
      }
    }
    return result;
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
      final prefix = xml.substring(lastEnd, m.start);
      // ทำให้แถวหัวตาราง (แถวสุดท้ายก่อนแถว seed) เป็น header row ที่ซ้ำ
      // ขึ้นทุกหน้าอัตโนมัติเวลาตารางยาวเกิน 1 หน้า — ทำที่นี่แทนการพึ่ง
      // ให้ผู้ใช้ไปกด "Repeat Header Rows" เองใน Word ทุกครั้งที่ generate ใหม่
      buffer.write(_markLastRowAsHeader(prefix));

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

  /// หา <w:tr>...</w:tr> ตัวสุดท้ายใน [segment] (ควรเป็นแถวหัวตารางที่อยู่
  /// ติดกับแถว seed ของรายการพัสดุ) แล้วใส่ <w:tblHeader/> ไว้ใน <w:trPr>
  /// ของแถวนั้น เพื่อให้ Word ซ้ำแถวนี้เป็นหัวตารางอัตโนมัติทุกหน้า
  static String _markLastRowAsHeader(String segment) {
    final rowPattern = RegExp(r'<w:tr\b[^>]*>.*?</w:tr>', dotAll: true);
    final matches = rowPattern.allMatches(segment).toList();
    if (matches.isEmpty) return segment;

    final lastMatch = matches.last;
    var row = lastMatch.group(0)!;

    if (row.contains('<w:tblHeader')) {
      return segment; // ตั้งไว้แล้ว ไม่ต้องทำซ้ำ
    }

    if (row.contains('<w:trPr>')) {
      row = row.replaceFirst('<w:trPr>', '<w:trPr><w:tblHeader/>');
    } else if (row.contains('<w:trPr/>')) {
      row = row.replaceFirst('<w:trPr/>', '<w:trPr><w:tblHeader/></w:trPr>');
    } else {
      // ไม่มี <w:trPr> เลย ให้แทรกไว้ทันทีหลังแท็กเปิด <w:tr ...>
      final openTagMatch = RegExp(r'^<w:tr\b[^>]*>').firstMatch(row)!;
      row = row.replaceRange(
        openTagMatch.end,
        openTagMatch.end,
        '<w:trPr><w:tblHeader/></w:trPr>',
      );
    }

    return segment.substring(0, lastMatch.start) +
        row +
        segment.substring(lastMatch.end);
  }
}