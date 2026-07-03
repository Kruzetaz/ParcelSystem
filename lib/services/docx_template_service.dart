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
import '../models/procurement_item.dart';

enum _TokenType { text, tab, lineBreak, pageBreak }

/// หน่วยย่อยของเนื้อหาในย่อหน้า docx (ข้อความ / tab / ตัดบรรทัด / ตัดหน้า)
/// ใช้ตอนรื้อ-ประกอบ <w:r> กลับ เพื่อไม่ให้ tab/br/page-break หายไปตอน merge
class _RunToken {
  final _TokenType type;
  final String? text;

  _RunToken.text(this.text) : type = _TokenType.text;
  _RunToken.tab()
      : type = _TokenType.tab,
        text = null;
  _RunToken.lineBreak()
      : type = _TokenType.lineBreak,
        text = null;
  _RunToken.pageBreak()
      : type = _TokenType.pageBreak,
        text = null;
}

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

  /// สร้างจาก ProcurementItem model โดยตรง (schema v2: quantity เป็น double
  /// แยกจาก unit) — [idx] คือลำดับแถวที่คำนวณจากตำแหน่งในลิสต์ตอน render
  /// เอกสาร ไม่ได้เก็บ idx ไว้ใน DB
  factory ProcurementItemData.fromItem(ProcurementItem item, int idx) {
    return ProcurementItemData(
      idx: idx,
      itemName: item.itemName,
      quantity: item.quantityDisplay,
      unitPrice: item.unitPrice,
      totalPrice: item.totalPrice ?? item.computedTotal,
    );
  }

  /// สร้างลิสต์ทั้งชุดจาก List<ProcurementItem> พร้อมคำนวณ idx ให้อัตโนมัติ
  /// (idx = ตำแหน่งในลิสต์ + 1) — ใช้ตัวนี้แทนการวนลูปเองใน UI/service เรียกใช้
  static List<ProcurementItemData> fromItems(List<ProcurementItem> items) {
    return [
      for (var i = 0; i < items.length; i++)
        ProcurementItemData.fromItem(items[i], i + 1),
    ];
  }

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

    // STEP 1a: Strip Word MERGEFIELD blocks ออกก่อน
    // (template ที่สร้างจาก Mail Merge จะมี <w:fldChar>/<w:instrText> ครอบ
    // {{placeholder}} ไว้ — ถ้าไม่ strip Word จะแสดง field เก่าทับค่าที่ replace)
    xml = _stripMergeFields(xml);

    // STEP 1b: Word มักตัด {{placeholder}} กระจายไป หลาย <w:r> เนื่องจาก
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
  /// เดินไล่เนื้อหาของย่อหน้าตามลำดับจริง แทนที่จะดึงเฉพาะ <w:t> แล้วทิ้ง
  /// <w:r> เดิมทั้งหมด — เพราะ <w:tab/>, <w:br/> (ตัดบรรทัด) และ
  /// <w:br w:type="page"/> (ตัดหน้า) ก็อยู่ใน <w:r> เหมือนกัน ถ้าทิ้งแบบเดิม
  /// พวกนี้จะหายไปเงียบๆ ทำให้เอกสารที่ควรขึ้นหน้าใหม่ไหลไปต่อท้ายเอกสาร
  /// ก่อนหน้าแทน (ดูเหมือนการจัดหน้าเพี้ยนทั้งที่ margin จริงไม่ได้เปลี่ยน)
  /// Strip Word MERGEFIELD blocks ออกจาก XML
  /// โครงสร้างที่ต้องแก้:
  /// <w:r>...<w:instrText>MERGEFIELD ...</w:instrText></w:r>
  /// <w:r>...<w:fldChar w:fldCharType="separate"/></w:r>
  /// <w:r>...<w:t>{{placeholder}}</w:t></w:r>   ← เก็บตัวนี้ไว้
  /// <w:r>...<w:fldChar w:fldCharType="end"/></w:r>
  /// → เหลือแค่ <w:r>...<w:t>{{placeholder}}</w:t></w:r>
  static String _stripMergeFields(String xml) {
    // ลบ run ที่มี instrText (MERGEFIELD declaration)
    xml = xml.replaceAll(
      RegExp(r'<w:r\b[^>]*>(?:<w:rPr>.*?</w:rPr>)?<w:instrText[^>]*>.*?</w:instrText>(?:<w:fldChar[^/]*/?>)?</w:r>', dotAll: true),
      '',
    );

    // ลบ run ที่มี fldChar begin/separate/end เท่านั้น (ไม่มี w:t)
    xml = xml.replaceAll(
      RegExp(r'<w:r\b[^>]*>(?:<w:rPr>.*?</w:rPr>)?<w:fldChar\b[^/]*/?>(?:<w:ffData>.*?</w:ffData>)?</w:r>', dotAll: true),
      '',
    );

    // ลบ fldChar ที่หลุดอยู่โดดๆ ใน run ที่มี w:t ด้วย (กรณี Word ซ้อน)
    xml = xml.replaceAll(
      RegExp(r'<w:fldChar\b[^/]*/>'),
      '',
    );
    xml = xml.replaceAll(
      RegExp(r'<w:instrText[^>]*>.*?</w:instrText>', dotAll: true),
      '',
    );

    return xml;
  }

  static String _mergeSplitPlaceholderRuns(String xml) {
    final paragraphPattern = RegExp(r'<w:p\b[^>]*>.*?</w:p>', dotAll: true);

    return xml.replaceAllMapped(paragraphPattern, (match) {
      final paragraph = match.group(0)!;

      if (!paragraph.contains('{{')) return paragraph;

      final runPattern = RegExp(r'<w:r\b[^>]*>.*?</w:r>', dotAll: true);
      final runMatches = runPattern.allMatches(paragraph).toList();
      if (runMatches.isEmpty) return paragraph;

      // แตกเนื้อหาทุก run ในย่อหน้าออกเป็น token ตามลำดับจริง
      final tokens = <_RunToken>[];
      for (final rm in runMatches) {
        tokens.addAll(_tokenizeRun(rm.group(0)!));
      }

      // เซฟตี้เน็ต: ถ้า parse เจอ tag แปลกที่ไม่รู้จักหลุดมาเป็นข้อความดิบ
      // ให้ยกเลิกการ merge ย่อหน้านี้ ปล่อยของเดิมไว้ดีกว่าเสี่ยงเอกสารเพี้ยน
      for (final t in tokens) {
        if (t.type == _TokenType.text &&
            (t.text!.contains('<w:') || t.text!.contains('</w:'))) {
          return paragraph;
        }
      }

      // texts = เฉพาะ token ข้อความ ตามลำดับ ใช้เช็คว่า placeholder ถูกตัดขาดไหม
      final texts =
          tokens.where((t) => t.type == _TokenType.text).map((t) => t.text!).toList();
      final combinedText = texts.join();

      final hasCompletePlaceholder =
          RegExp(r'\{\{[^{}]+\}\}').hasMatch(combinedText);
      if (!hasCompletePlaceholder) return paragraph;

      // ไม่ได้ถูกตัดขาดจริง ไม่ต้อง merge — ปล่อย <w:r> เดิมไว้เฉยๆ
      if (!_looksSplit(texts)) return paragraph;

      // สร้าง map จาก run index → rPr เพื่อให้แต่ละ token ใช้ rPr ของ run ตัวเองได้
      // (ไม่ใช้ rPr ของ run แรกทาสีทุกตัว ซึ่งทำให้ format เพี้ยน)
      final runRprs = <int, String>{};
      for (var ri = 0; ri < runMatches.length; ri++) {
        final rPrMatch = RegExp(r'<w:rPr>.*?</w:rPr>', dotAll: true)
            .firstMatch(runMatches[ri].group(0)!);
        runRprs[ri] = rPrMatch?.group(0) ?? '';
      }

      // สร้าง token พร้อม index ของ run ต้นทาง เพื่อ track rPr
      final indexedTokens = <({_RunToken token, int runIdx})>[];
      for (var ri = 0; ri < runMatches.length; ri++) {
        for (final t in _tokenizeRun(runMatches[ri].group(0)!)) {
          indexedTokens.add((token: t, runIdx: ri));
        }
      }

      // หา run ที่มี placeholder อยู่ — ใช้ rPr ของ run นั้นสำหรับ token ที่ merge
      int placeholderRunIdx = 0;
      final combinedForSearch = texts.join();
      var charCount = 0;
      outer:
      for (var ri = 0; ri < runMatches.length; ri++) {
        final runTexts = _tokenizeRun(runMatches[ri].group(0)!)
            .where((t) => t.type == _TokenType.text)
            .map((t) => t.text ?? '')
            .join();
        for (var ci = 0; ci < runTexts.length; ci++) {
          if (combinedForSearch.substring(charCount).contains('{{')) {
            placeholderRunIdx = ri;
            break outer;
          }
        }
        charCount += runTexts.length;
      }
      final placeholderRpr = runRprs[placeholderRunIdx] ?? '';

      final buffer = StringBuffer();
      final textBuffer = StringBuffer();
      int currentRunIdx = 0;

      void flushText() {
        if (textBuffer.isEmpty) return;
        final text = textBuffer.toString();
        // ถ้า text นี้มี placeholder ใช้ rPr ของ placeholder run
        // ถ้าไม่มี ใช้ rPr ของ run ปัจจุบัน
        final rPr = text.contains('{{') || text.contains('}}')
            ? placeholderRpr
            : (runRprs[currentRunIdx] ?? '');
        final escaped = text
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        buffer.write('<w:r>$rPr<w:t xml:space="preserve">$escaped</w:t></w:r>');
        textBuffer.clear();
      }

      for (final it in indexedTokens) {
        currentRunIdx = it.runIdx;
        switch (it.token.type) {
          case _TokenType.text:
            textBuffer.write(it.token.text);
            break;
          case _TokenType.tab:
            flushText();
            buffer.write('<w:r>${runRprs[it.runIdx] ?? ''}<w:tab/></w:r>');
            break;
          case _TokenType.lineBreak:
            flushText();
            buffer.write('<w:r>${runRprs[it.runIdx] ?? ''}<w:br/></w:r>');
            break;
          case _TokenType.pageBreak:
            flushText();
            buffer.write('<w:r>${runRprs[it.runIdx] ?? ''}<w:br w:type="page"/></w:r>');
            break;
        }
      }
      flushText();

      final withoutRuns = paragraph.replaceAll(runPattern, '');
      return withoutRuns.replaceFirst('</w:p>', '${buffer.toString()}</w:p>');
    });
  }

  /// แตก <w:r>...</w:r> หนึ่งตัว ออกเป็นลำดับ token (ข้อความ / tab /
  /// ตัดบรรทัด / ตัดหน้า) ตามลำดับจริงที่ปรากฏใน XML ของ run นั้น
  static List<_RunToken> _tokenizeRun(String runXml) {
    final childPattern = RegExp(
      r'<w:t\b[^>]*?(?:/>|>(.*?)</w:t>)'
      r'|<w:tab\b[^>]*/>'
      r'|<w:br\b[^>]*/>'
      r'|<w:cr\b[^>]*/>',
      dotAll: true,
    );

    final tokens = <_RunToken>[];
    for (final m in childPattern.allMatches(runXml)) {
      final raw = m.group(0)!;
      if (raw.startsWith('<w:t')) {
        tokens.add(_RunToken.text(m.group(1) ?? ''));
      } else if (raw.startsWith('<w:tab')) {
        tokens.add(_RunToken.tab());
      } else if (raw.startsWith('<w:br')) {
        final isPageBreak = raw.contains('w:type="page"');
        tokens.add(isPageBreak ? _RunToken.pageBreak() : _RunToken.lineBreak());
      } else if (raw.startsWith('<w:cr')) {
        tokens.add(_RunToken.lineBreak());
      }
    }
    return tokens;
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
  ///
  /// เอกสารจริงมักมีตารางรายการซ้ำหลายจุดในไฟล์เดียว (เช่น ภาคผนวก,
  /// ใบเสนอราคา, ใบขอซื้อ) — ต้องวนทำ "ทุก" seed row ที่พบ ไม่ใช่แค่ตัวแรก
  /// มิฉะนั้นตารางที่เหลือจะยังมี {{...}} ค้างอยู่
  static String _cloneItemRows(String xml, List<ProcurementItemData> items) {
    final rowPattern = RegExp(r'<w:tr\b[^>]*>.*?</w:tr>', dotAll: true);

    final buffer = StringBuffer();
    var lastEnd = 0;
    var foundAnySeed = false;

    for (final m in rowPattern.allMatches(xml)) {
      final rowXml = m.group(0)!;
      if (!rowXml.contains('{{item_name}}')) continue;

      foundAnySeed = true;
      // เก็บส่วนของ xml ก่อนหน้าแถวนี้ไว้ก่อน
      buffer.write(xml.substring(lastEnd, m.start));

      if (items.isEmpty) {
        // ไม่มีรายการสินค้า — ลบ seed row ทิ้งไปเลย ป้องกันเหลือ {{...}} ค้าง
      } else {
        for (final item in items) {
          var clonedRow = rowXml;
          final rowValues = item.toPlaceholderMap();
          for (final entry in rowValues.entries) {
            clonedRow = clonedRow.replaceAll(
              '{{${entry.key}}}',
              _escapeXmlText(entry.value),
            );
          }
          buffer.write(clonedRow);
        }
      }

      lastEnd = m.end;
    }

    if (!foundAnySeed) {
      // ไม่มี seed row เลยในเอกสารนี้ — ข้ามได้
      return xml;
    }

    buffer.write(xml.substring(lastEnd));
    return buffer.toString();
  }

}