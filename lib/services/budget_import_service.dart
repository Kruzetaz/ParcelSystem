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

const _budgetImportPrompt = '''
คุณเป็นผู้ช่วยแกะข้อมูลแผนงบประมาณจากเอกสารราชการไทย จงอ่านเนื้อหาที่แนบมาแล้วดึงรายการ
แผนงบประมาณทั้งหมดออกมา ตอบกลับเป็น JSON array เท่านั้น ห้ามมีข้อความอื่นใดนอกเหนือ JSON
และห้ามใช้ ``` แต่ละรายการมี field ดังนี้:
- fiscal_year: ปีงบประมาณ พ.ศ. (string เช่น "2568")
- project_name: ชื่อโครงการ/รายการ (string)
- activity_name: กิจกรรมย่อย (string, ถ้าไม่มีให้เว้นว่าง)
- allocated_amount: วงเงินงบประมาณ (ตัวเลขล้วน ไม่มีคอมมา ไม่มีหน่วย)

ตัวอย่าง: [{"fiscal_year":"2568","project_name":"จัดซื้อวัสดุสำนักงาน","activity_name":"งานธุรการ","allocated_amount":50000}]
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

  static const _headerKeywords = {
    'fiscalYear': ['ปีงบ', 'ปีงบประมาณ', 'ปี'],
    'projectName': ['โครงการ', 'รายการ'],
    'activityName': ['กิจกรรม'],
    'allocatedAmount': ['วงเงิน', 'งบประมาณ', 'จำนวนเงิน'],
  };

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

    // แถวแรก = header — หาว่าคอลัมน์ไหนตรงกับ field ไหนโดยเทียบคำสำคัญ
    final headerRow = sheet.rows.first;
    final columnIndex = <String, int>{};
    for (var col = 0; col < headerRow.length; col++) {
      final headerText = headerRow[col]?.value?.toString().trim() ?? '';
      if (headerText.isEmpty) continue;
      for (final entry in _headerKeywords.entries) {
        if (columnIndex.containsKey(entry.key)) continue;
        if (entry.value.any((kw) => headerText.contains(kw))) {
          columnIndex[entry.key] = col;
        }
      }
    }

    final missing = _headerKeywords.keys.where((k) => !columnIndex.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      throw BudgetImportException(
        'หาคอลัมน์ไม่ครบในไฟล์ Excel — ต้องมีหัวตาราง (แถวแรก) ที่มีคำว่า '
        '"ปีงบประมาณ", "โครงการ", "กิจกรรม" และ "วงเงิน" อย่างละ 1 คอลัมน์',
      );
    }

    final budgets = <Budget>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      String cellText(int col) =>
          col < row.length ? (row[col]?.value?.toString().trim() ?? '') : '';
      final fiscalYear = cellText(columnIndex['fiscalYear']!);
      final projectName = cellText(columnIndex['projectName']!);
      if (fiscalYear.isEmpty && projectName.isEmpty) continue; // แถวว่าง
      final amountText = cellText(columnIndex['allocatedAmount']!).replaceAll(',', '');
      budgets.add(Budget(
        fiscalYear: fiscalYear,
        projectName: projectName.isEmpty ? null : projectName,
        activityName: cellText(columnIndex['activityName']!).let((s) => s.isEmpty ? null : s),
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
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
