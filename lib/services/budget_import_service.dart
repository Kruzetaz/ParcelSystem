// budget_import_service.dart
// นำเข้าแผนงบประมาณจากไฟล์ — ทำงานแบบ Hybrid ตามที่ตกลงกันไว้:
// .xlsx → แกะข้อมูลตรงๆ ด้วยแพ็คเกจ excel (แม่นยำ 100% ไม่เปลืองโควตา AI)
// .docx/.pdf → ส่งให้ Gemini อ่านแล้วแปลงกลับมาเป็น Budget

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import '../models/budget.dart';
import 'gemini_service.dart';

// เอกสารแต่ละโรงเรียนอาจสะกด/จัดหน้าไม่เหมือนกัน (เช่น บางที่เขียน "ฝ่ายวิชาการ" สั้นๆ,
// บางที่เขียน "งบกลุ่มบริหารงานวิชาการ" เต็ม) จึงให้ Gemini จับคู่ความหมายเอาเอง
// แทนที่จะ hardcode คำค้นตายตัว — รายชื่อกลุ่มมาตรฐานอยู่ที่ budgetDepartmentGroups
// ใน models/budget.dart ใช้ร่วมกันทั้งฟอร์ม/ตัวกรอง/ตัว import

final _budgetImportPrompt = '''
คุณเป็นผู้ช่วยแกะข้อมูลแผนงบประมาณจากเอกสารราชการไทย จงอ่านเนื้อหาที่แนบมาแล้วดึงรายการ
แผนงบประมาณทั้งหมดออกมา ตอบกลับเป็น JSON array เท่านั้น ห้ามมีข้อความอื่นใดนอกเหนือ JSON
และห้ามใช้ ``` แต่ละรายการมี field ดังนี้:
- fiscal_year: ปีงบประมาณ พ.ศ. (string เช่น "2568")
- group_name: ฝ่าย/กลุ่มงานที่รายการนี้สังกัดอยู่ — เอกสารมักจัดเป็นหัวข้อใหญ่คลุมหลาย
  โครงการ (เช่น หัวตารางสีเข้ม/แถบหัวข้อที่ไม่มีเลขที่ ก่อนรายการโครงการย่อยลงมา)
  ให้จับคู่ความหมายกับ 5 กลุ่มมาตรฐานนี้เท่านั้น (ตอบกลับเป็นข้อความในลิสต์นี้เป๊ะๆ
  ห้ามแต่งคำใหม่ ถ้าเดาไม่ได้จริงๆ ให้เว้นว่าง):
  ${budgetDepartmentGroups.map((g) => '  * "$g"').join('\n')}
  ตัวอย่างการจับคู่ความหมาย (เอกสารจริงอาจสะกด/ย่อไม่เหมือนตัวอย่าง): "ฝ่ายวิชาการ",
  "งานวิชาการ" → "งบกลุ่มบริหารงานวิชาการ" | "ฝ่ายงบประมาณ", "งานการเงิน" →
  "งบกลุ่มบริหารงานงบประมาณ" | "ฝ่ายบุคคล", "งานบุคลากร" → "งบกลุ่มบริหารงานบุคคล" |
  "ฝ่ายบริหารทั่วไป", "งานทั่วไป" → "งบกลุ่มบริหารงานบริหารทั่วไป" | "กิจกรรมพัฒนาผู้เรียน",
  "งบพัฒนาผู้เรียน" → "งบกิจกรรมพัฒนาผู้เรียน"
- project_name: ชื่อโครงการ/รายการ (string)
- activity_name: กิจกรรมย่อย (string, ถ้าไม่มีให้เว้นว่าง)
- allocated_amount: วงเงินงบประมาณ (ตัวเลขล้วน ไม่มีคอมมา ไม่มีหน่วย)

ห้ามดึงแถว "รวมงบกลุ่ม..." หรือแถวสรุปยอดรวมท้ายตารางออกมาเป็นรายการ — ดึงเฉพาะรายการ
โครงการ/กิจกรรมจริงเท่านั้น

ตัวอย่าง: [{"fiscal_year":"2568","group_name":"งบกลุ่มบริหารงานบริหารทั่วไป","project_name":"จัดซื้อวัสดุสำนักงาน","activity_name":"งานธุรการ","allocated_amount":50000}]
''';

class BudgetImportException implements Exception {
  final String message;
  BudgetImportException(this.message);
  @override
  String toString() => message;
}

class BudgetImportService {
  BudgetImportService._();
  static final BudgetImportService instance = BudgetImportService._();

  Future<List<Budget>> importFromFile(String path) async {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'xlsx':
        return _parseExcel(path);
      case 'pdf':
        return _parseViaGemini(
          bytes: await File(path).readAsBytes(),
          mimeType: 'application/pdf',
        );
      case 'docx':
        final text = _extractDocxText(await File(path).readAsBytes());
        return _parseViaGeminiText(text);
      default:
        throw BudgetImportException('ไม่รองรับไฟล์ประเภทนี้ (.$ext)');
    }
  }

  // ─────────────────────────────────────────
  // .xlsx — แกะตรงๆ ด้วย excel package
  // ─────────────────────────────────────────

  // fiscalYear ไม่บังคับต้องมีคอลัมน์แยก — ไฟล์โรงเรียนจริงส่วนใหญ่ใส่ปีงบประมาณไว้
  // แค่ในหัวเรื่องเอกสาร (เช่น "แผนการใช้จ่ายงบประมาณ...ปีงบประมาณ 2569") ไม่ได้ทำเป็น
  // คอลัมน์ต่อแถว จึงลองเดาจากข้อความในไฟล์แทนถ้าหาคอลัมน์ไม่เจอ
  static const _headerKeywords = {
    'fiscalYear': ['ปีงบ', 'ปีงบประมาณ'],
    'groupName': ['ฝ่าย', 'กลุ่มงาน', 'กลุ่ม'],
    'projectName': ['โครงการ', 'รายการ'],
    'activityName': ['กิจกรรม'],
    'allocatedAmount': ['วงเงิน', 'งบประมาณ', 'จำนวนเงิน', 'งบ'],
  };
  static const _requiredKeys = ['projectName', 'allocatedAmount'];

  Future<List<Budget>> _parseExcel(String path) async {
    final bytes = await File(path).readAsBytes();
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw BudgetImportException('ไฟล์ Excel นี้ไม่มีข้อมูล');
    }
    final sheet = workbook.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw BudgetImportException('ไฟล์ Excel นี้ไม่มีข้อมูล');
    }

    // หาแถว header — ไล่หาแถวแรกที่จับคู่คำสำคัญได้อย่างน้อย projectName+allocatedAmount
    // (บางไฟล์มีแถวหัวเรื่อง/ว่างอยู่ก่อนแถวหัวตารางจริง)
    var headerRowIndex = -1;
    var columnIndex = <String, int>{};
    for (var r = 0; r < sheet.rows.length && r < 10; r++) {
      final candidate = <String, int>{};
      final row = sheet.rows[r];
      for (var col = 0; col < row.length; col++) {
        final headerText = row[col]?.value?.toString().trim() ?? '';
        if (headerText.isEmpty) continue;
        for (final entry in _headerKeywords.entries) {
          if (candidate.containsKey(entry.key)) continue;
          if (entry.value.any((kw) => headerText.contains(kw))) {
            candidate[entry.key] = col;
          }
        }
      }
      if (_requiredKeys.every(candidate.containsKey)) {
        headerRowIndex = r;
        columnIndex = candidate;
        break;
      }
    }
    if (headerRowIndex == -1) {
      throw BudgetImportException(
        'หาหัวตารางไม่เจอในไฟล์ Excel — ต้องมีคอลัมน์ที่มีคำว่า "โครงการ" หรือ "รายการ" '
        'และคอลัมน์ "วงเงิน"/"งบประมาณ"/"งบ" อย่างละ 1 คอลัมน์',
      );
    }

    // ปีงบประมาณ: ถ้าไม่มีคอลัมน์แยก ลองเดาจากข้อความ 4 หลัก 25xx ในแถวก่อนหน้าหัวตาราง
    String? fallbackFiscalYear;
    if (!columnIndex.containsKey('fiscalYear')) {
      final yearPattern = RegExp(r'25\d{2}');
      for (var r = 0; r <= headerRowIndex; r++) {
        for (final cell in sheet.rows[r]) {
          final text = cell?.value?.toString() ?? '';
          final match = yearPattern.firstMatch(text);
          if (match != null) {
            fallbackFiscalYear = match.group(0);
            break;
          }
        }
        if (fallbackFiscalYear != null) break;
      }
    }

    final budgets = <Budget>[];
    String? currentGroup;
    for (var r = headerRowIndex + 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      String cellText(int? col) =>
          col != null && col < row.length ? (row[col]?.value?.toString().trim() ?? '') : '';
      final fiscalYear = columnIndex.containsKey('fiscalYear')
          ? cellText(columnIndex['fiscalYear'])
          : (fallbackFiscalYear ?? '');
      final projectName = cellText(columnIndex['projectName']);
      final amountText = cellText(columnIndex['allocatedAmount']).replaceAll(',', '');

      // แถวหัวข้อกลุ่มงาน (เช่น "งบกลุ่มบริหารงานวิชาการ") มักไม่มีกิจกรรมย่อยในแถว
      // เดียวกัน แค่ชื่อกลุ่ม + ยอดรวม — เก็บไว้เป็น "กลุ่มปัจจุบัน" ให้แถวถัดๆ ไป
      final matchedGroup = budgetDepartmentGroups.where((g) => projectName.contains(g) || g.contains(projectName)).firstOrNull;
      if (matchedGroup != null && projectName.isNotEmpty) {
        currentGroup = matchedGroup;
        if (cellText(columnIndex['activityName']).isEmpty) continue; // แถวหัวข้อล้วนๆ ไม่ใช่รายการ
      }
      // ข้ามแถว "รวมงบกลุ่ม..." ท้ายแต่ละหมวด
      if (projectName.startsWith('รวม')) continue;

      if (fiscalYear.isEmpty && projectName.isEmpty) continue; // แถวว่าง
      budgets.add(Budget(
        fiscalYear: fiscalYear,
        groupName: columnIndex.containsKey('groupName')
            ? cellText(columnIndex['groupName']).let((s) => s.isEmpty ? currentGroup : s)
            : currentGroup,
        projectName: projectName.isEmpty ? null : projectName,
        activityName: cellText(columnIndex['activityName']).let((s) => s.isEmpty ? null : s),
        allocatedAmount: double.tryParse(amountText),
      ));
    }
    return budgets;
  }

  // ─────────────────────────────────────────
  // .pdf — ส่งไฟล์ตรงๆ ให้ Gemini อ่าน (รองรับ PDF โดยตรง)
  // ─────────────────────────────────────────

  Future<List<Budget>> _parseViaGemini({
    required List<int> bytes,
    required String mimeType,
  }) async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      throw BudgetImportException('กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน');
    }
    final responseText = await GeminiService.instance.generateFromFile(
      prompt: _budgetImportPrompt,
      fileBytes: bytes,
      mimeType: mimeType,
    );
    return _parseGeminiJson(responseText);
  }

  // ─────────────────────────────────────────
  // .docx — Gemini ไม่รองรับไฟล์ .docx โดยตรง (คืน error บ่อย) จึงแกะข้อความ
  // ออกมาเองก่อน (docx คือไฟล์ zip ที่มี word/document.xml อยู่ข้างใน) แล้ว
  // ส่งเป็นข้อความล้วนให้ Gemini อ่านแทน
  // ─────────────────────────────────────────

  Future<List<Budget>> _parseViaGeminiText(String text) async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      throw BudgetImportException('กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน');
    }
    final responseText = await GeminiService.instance.generateText('$_budgetImportPrompt\n\nเนื้อหาเอกสาร:\n$text');
    return _parseGeminiJson(responseText);
  }

  String _extractDocxText(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXml = archive.files.where((f) => f.name == 'word/document.xml').firstOrNull;
    if (docXml == null) {
      throw BudgetImportException('ไฟล์ Word นี้เสียหายหรือไม่ใช่ไฟล์ .docx ที่ถูกต้อง');
    }
    final xmlStr = utf8.decode(docXml.content as List<int>);
    final buffer = StringBuffer();
    final pattern = RegExp(r'<w:t[^>]*>(.*?)</w:t>|</w:p>', dotAll: true);
    for (final match in pattern.allMatches(xmlStr)) {
      final text = match.group(1);
      buffer.write(text != null ? _unescapeXml(text) : '\n');
    }
    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw BudgetImportException('ไม่พบข้อความในไฟล์ Word นี้');
    }
    return result;
  }

  String _unescapeXml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  List<Budget> _parseGeminiJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'```\s*$'), '');
    }
    final decoded = jsonDecode(text.trim());
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().map((json) {
      final amount = json['allocated_amount'];
      return Budget(
        fiscalYear: (json['fiscal_year'] ?? '').toString(),
        groupName: _normalizeGroupName(json['group_name'] as String?),
        projectName: (json['project_name'] as String?)?.trim().isEmpty == true
            ? null
            : json['project_name'] as String?,
        activityName: (json['activity_name'] as String?)?.trim().isEmpty == true
            ? null
            : json['activity_name'] as String?,
        allocatedAmount: amount is num ? amount.toDouble() : double.tryParse('$amount'),
      );
    }).where((b) => b.fiscalYear.isNotEmpty || b.projectName != null).toList();
  }

  /// กัน Gemini ตอบกลับมาไม่ตรงเป๊ะกับ 5 กลุ่มมาตรฐาน (เช่น เว้นวรรคเกิน/เติมคำ)
  /// — ถ้าตรงกับกลุ่มมาตรฐานตัวใดตัวหนึ่งแบบ contains ให้ normalize เป็นคำมาตรฐาน
  /// ถ้าไม่เจอเลยให้ตัดทิ้ง (คืน null) ดีกว่าใส่ค่าที่ผู้ใช้เลือกใน dropdown ไม่ได้
  String? _normalizeGroupName(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    for (final g in budgetDepartmentGroups) {
      if (text == g || text.contains(g) || g.contains(text)) return g;
    }
    return null;
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
