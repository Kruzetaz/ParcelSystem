// procurement_import_service.dart
// นำเข้าโครงการจัดซื้อจัดจ้างเก่า/นอกระบบ (ไฟล์ .docx/.pdf ที่เคยทำด้วยมือ) เข้า
// ระบบ — ใช้แพทเทิร์นเดียวกับ BudgetImportService (Hybrid): .xlsx แกะตรงด้วย
// package excel, .docx/.pdf ส่งให้ Gemini อ่านแล้วแปลงกลับเป็น ProcurementOrder
// + ProcurementItem — วิเคราะห์จากไฟล์จริงของโรงเรียนแล้วพบว่าทุกไฟล์ (ทั้งซื้อ
// และจ้าง หลายปี) มีโครงสร้างเดียวกัน: บันทึกข้อความรายงานขอซื้อ/จ้าง ->
// รายละเอียดแนบท้าย(ตารางรายการ) -> คำสั่งแต่งตั้งผู้ตรวจรับพัสดุ -> ใบเสนอราคา
// -> รายงานผลการพิจารณา -> ประกาศผู้ชนะ — ให้ดึงข้อมูลได้แม่นยำสูง
//
// สำคัญ: ฟังก์ชันนี้คืนค่าเป็น (order, items) เฉยๆ ไม่ได้บันทึกลง DB ทันที —
// ต้องผ่านหน้าจอตรวจสอบ/แก้ไขก่อนเสมอ (ตามที่ผู้ใช้ยืนยันไว้) เพราะ AI อ่านผิด
// พลาดได้ โดยเฉพาะเลขที่เอกสาร/ราคา ที่ต้องแม่นเป๊ะ

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import 'gemini_service.dart';

class ProcurementImportException implements Exception {
  final String message;
  ProcurementImportException(this.message);
  @override
  String toString() => message;
}

typedef ImportedProject = ({
  ProcurementOrder order,
  List<ProcurementItem> items
});

final _procurementImportPrompt = '''
คุณเป็นผู้ช่วยแกะข้อมูลเอกสารจัดซื้อจัดจ้างของโรงเรียนไทย เอกสารที่แนบมาเป็นชุดเอกสาร
ต่อกันของโครงการจัดซื้อ/จัดจ้าง 1 โครงการ (บันทึกข้อความรายงานขอซื้อ/ขอจ้าง ->
รายละเอียดแนบท้าย(ตารางรายการพัสดุ) -> คำสั่งแต่งตั้งผู้ตรวจรับพัสดุ -> ใบเสนอราคา ->
รายงานผลการพิจารณา -> ประกาศผู้ชนะการเสนอราคา) จงอ่านทั้งหมดแล้วดึงข้อมูลออกมาเป็น
JSON object เดียว (ไม่ใช่ array) เท่านั้น ห้ามมีข้อความอื่นใดนอกเหนือ JSON และห้ามใช้ ```

โครงสร้าง JSON ที่ต้องการ:
{
  "order_number": เลขที่เอกสาร เช่น "ซ06/2569" หรือ "จ02/2569" (string, ดึงจากบรรทัด "ที่ ...")
  "order_type": "ซื้อ" หรือ "จ้าง" เท่านั้น (ดูจากอักษรนำหน้าเลขที่เอกสาร ซ=ซื้อ จ=จ้าง
    หรือจากคำว่า "จัดซื้อ"/"จัดจ้าง"/"จ้างเหมา" ในเรื่อง)
  "procurement_subject": หัวเรื่องเต็มจากบรรทัด "เรื่อง ..." ของบันทึกฉบับแรก (string)
  "date_order_created": วันที่ของบันทึกฉบับแรก แปลงเป็นรูปแบบ "D เดือนไทยเต็ม พ.ศ. 4 หลัก"
    เช่น "17 พฤศจิกายน 2568" (string)
  "fiscal_year": ปีงบประมาณ พ.ศ. 4 หลัก เช่น "2569" — ถ้าเอกสารไม่ได้ระบุตรงๆ ให้คำนวณจาก
    date_order_created ตามปีงบประมาณราชการไทย (ต.ค.-ก.ย.) คือถ้าเดือนเป็น ต.ค./พ.ย./ธ.ค.
    ให้ใช้ปี พ.ศ. ของวันที่ + 1 เดือนอื่นใช้ปี พ.ศ. ของวันที่ตรงๆ (string)
  "procurement_method": ดูวิธีจัดซื้อจัดจ้างจากเอกสาร ปกติจะเป็น "เฉพาะเจาะจง" ถ้าไม่แน่ใจ
    ให้ตอบ "เฉพาะเจาะจง" ไว้ก่อน (string)
  "vendor_name": ชื่อร้าน/บริษัทผู้ขายหรือผู้รับจ้าง (จากประกาศผู้ชนะ หรือใบเสนอราคา) (string)
  "vendor_owner": ชื่อเจ้าของร้าน/ผู้ยื่นข้อเสนอ จากใบเสนอราคา "ข้าพเจ้า ... เป็นผู้ขาย" (string, ถ้าไม่มีเว้นว่าง)
  "vendor_address_no": เลขที่/หมู่บ้าน ของที่อยู่ผู้ขาย (string, ถ้าไม่มีเว้นว่าง)
  "vendor_subdistrict": ตำบล/แขวง ของผู้ขาย ไม่ต้องมีคำว่า "ตำบล" นำหน้า (string)
  "vendor_district": อำเภอ/เขต ของผู้ขาย ไม่ต้องมีคำว่า "อำเภอ" นำหน้า (string)
  "vendor_province": จังหวัดของผู้ขาย ไม่ต้องมีคำว่า "จังหวัด" นำหน้า (string)
  "vendor_postal_code": รหัสไปรษณีย์ผู้ขาย (string)
  "vendor_phone": เบอร์โทรผู้ขาย (string)
  "vendor_tax_id": เลขประจำตัวผู้เสียภาษีผู้ขาย (string)
  "inspector1": ชื่อผู้ตรวจรับพัสดุคนแรก (ประธาน) จากคำสั่งแต่งตั้งผู้ตรวจรับพัสดุ (string, ถ้าไม่มีเว้นว่าง)
  "inspector1_pos": ตำแหน่งของผู้ตรวจรับพัสดุคนแรก เช่น "ครู" (string, ถ้าไม่มีเว้นว่าง)
  "inspector2": ชื่อผู้ตรวจรับพัสดุคนที่สอง จากคำสั่งแต่งตั้งผู้ตรวจรับพัสดุ ถ้ามีแค่คนเดียวเว้นว่าง (string)
  "inspector2_pos": ตำแหน่งของผู้ตรวจรับพัสดุคนที่สอง (string, ถ้าไม่มีเว้นว่าง)
  "inspector3": ชื่อผู้ตรวจรับพัสดุคนที่สาม จากคำสั่งแต่งตั้งผู้ตรวจรับพัสดุ ถ้ามีไม่ถึง 3 คนเว้นว่าง (string)
  "inspector3_pos": ตำแหน่งของผู้ตรวจรับพัสดุคนที่สาม (string, ถ้าไม่มีเว้นว่าง)
  "date_announcement": วันที่ประกาศผู้ชนะการเสนอราคา แปลงเป็นรูปแบบ "D เดือนไทยเต็ม พ.ศ. 4 หลัก"
    (string, ถ้าไม่มีเว้นว่าง)
  "date_quotation": วันที่ในใบเสนอราคาของผู้ขาย/ผู้รับจ้าง (string, ถ้าไม่มีเว้นว่าง)
  "date_contract_signed": วันที่ลงนามสัญญา/ใบสั่งซื้อ-สั่งจ้าง (string, ถ้าไม่มีเว้นว่าง)
  "date_deadline": วันครบกำหนดส่งมอบพัสดุตามสัญญา/ใบสั่ง (string, ถ้าไม่มีเว้นว่าง)
  "date_shipping": วันที่ผู้ขาย/ผู้รับจ้างส่งมอบพัสดุจริง จากใบส่งของหรือใบส่งมอบงาน
    (string, ถ้าไม่มีเว้นว่าง)
  "date_inspection": วันที่คณะกรรมการ/ผู้ตรวจรับพัสดุตรวจรับ จากใบตรวจรับพัสดุ
    (string, ถ้าไม่มีเว้นว่าง)
  "date_disbursement": วันที่บันทึกขออนุมัติเบิกจ่ายเงิน (string, ถ้าไม่มีเว้นว่าง)
  "contract_control_number": เลขคุมสัญญา/เลขคุมใบสั่งซื้อสั่งจ้าง ถ้ามีระบุไว้ในเอกสาร
    (string, ถ้าไม่มีเว้นว่าง)
  "egp_project_id": เลขที่โครงการในระบบ e-GP (ขึ้นต้นด้วยตัวเลขปี เช่น "69017123456")
    ถ้ามีระบุไว้ในเอกสาร (string, ถ้าไม่มีเว้นว่าง)
  "items": array ของรายการพัสดุจากตาราง "รายละเอียดแนบท้าย" แต่ละรายการมี
    {"item_name": ชื่อรายการ, "quantity": จำนวนตัวเลขล้วน, "unit": หน่วยนับ เช่น "ริม"/"ด้าม" (ถ้าไม่มีเว้นว่าง),
     "unit_price": ราคาต่อหน่วยตัวเลขล้วนไม่มีคอมมา}
    ห้ามดึงแถว "รวมเป็นเงินทั้งสิ้น" มาเป็นรายการ
}

ถ้าข้อมูลไหนหาในเอกสารไม่เจอจริงๆ ให้ใส่ค่าว่าง "" (สำหรับ string) หรือ [] (สำหรับ items ถ้าไม่มีตารางเลย)
ห้ามเดามั่วถ้าไม่มีในเอกสาร
''';

class ProcurementImportService {
  ProcurementImportService._();
  static final ProcurementImportService instance = ProcurementImportService._();

  Future<List<ImportedProject>> importFromFile(String path) async {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'docx':
        final text = _extractDocxText(await File(path).readAsBytes());
        return [await _parseViaGeminiText(text)];
      case 'pdf':
        return [
          await _parseViaGemini(
            bytes: await File(path).readAsBytes(),
            mimeType: 'application/pdf',
          ),
        ];
      case 'xlsx':
        return _parseExcel(path);
      default:
        throw ProcurementImportException('ไม่รองรับไฟล์ประเภทนี้ (.$ext)');
    }
  }

  // ─────────────────────────────────────────
  // .xlsx — ทะเบียนคุมแบบหลายแถว/หลายโครงการในไฟล์เดียว แกะตรงๆ ด้วย excel
  // package (คอลัมน์จับคู่ตามคำหลัก คล้าย BudgetImportService) — แต่ละแถว
  // = 1 โครงการ ไม่มีรายการพัสดุย่อย (ต้องมาเติมทีหลังในหน้าตรวจสอบ)
  // ─────────────────────────────────────────
  static const _headerKeywords = {
    'orderNumber': ['เลขที่'],
    'procurementSubject': ['รายการ', 'เรื่อง', 'ชื่อโครงการ'],
    'vendorName': ['ผู้ขาย', 'ร้านค้า', 'คู่สัญญา'],
    'totalPrice': ['จำนวนเงิน', 'ราคา', 'วงเงิน'],
    'dateOrderCreated': ['วันที่'],
  };
  static const _requiredKeys = ['procurementSubject'];

  Future<List<ImportedProject>> _parseExcel(String path) async {
    final bytes = await File(path).readAsBytes();
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw ProcurementImportException('ไฟล์ Excel นี้ไม่มีข้อมูล');
    }
    final sheet = workbook.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw ProcurementImportException('ไฟล์ Excel นี้ไม่มีข้อมูล');
    }

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
      throw ProcurementImportException(
        'หาหัวตารางไม่เจอในไฟล์ Excel — ต้องมีคอลัมน์ที่มีคำว่า "รายการ" หรือ "เรื่อง" หรือ "ชื่อโครงการ" อย่างน้อย 1 คอลัมน์',
      );
    }

    final results = <ImportedProject>[];
    for (var r = headerRowIndex + 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      String cellText(int? col) => col != null && col < row.length
          ? (row[col]?.value?.toString().trim() ?? '')
          : '';
      final subject = cellText(columnIndex['procurementSubject']);
      if (subject.isEmpty) continue;
      final orderNumber = cellText(columnIndex['orderNumber']);
      final totalPriceText =
          cellText(columnIndex['totalPrice']).replaceAll(',', '');
      final totalPrice = double.tryParse(totalPriceText);
      final order = ProcurementOrder(
        orderNumber: orderNumber.isEmpty ? null : orderNumber,
        procurementNumber: orderNumber.isEmpty ? null : orderNumber,
        orderType: (orderNumber.startsWith('จ')) ? 'จ้าง' : 'ซื้อ',
        procurementSubject: subject,
        procurementMethod: 'เฉพาะเจาะจง',
        dateOrderCreated: cellText(columnIndex['dateOrderCreated']).isEmpty
            ? null
            : cellText(columnIndex['dateOrderCreated']),
        vendorName: cellText(columnIndex['vendorName']).isEmpty
            ? null
            : cellText(columnIndex['vendorName']),
      );
      final items = totalPrice == null
          ? <ProcurementItem>[]
          : [
              ProcurementItem(
                  itemName: subject, quantity: 1, unitPrice: totalPrice)
            ];
      results.add((order: order, items: items));
    }
    if (results.isEmpty) {
      throw ProcurementImportException('ไม่พบแถวข้อมูลในไฟล์ Excel นี้');
    }
    return results;
  }

  // ─────────────────────────────────────────
  // .pdf — ส่งไฟล์ตรงๆ ให้ Gemini อ่าน
  // ─────────────────────────────────────────
  Future<ImportedProject> _parseViaGemini({
    required List<int> bytes,
    required String mimeType,
  }) async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      throw ProcurementImportException(
          'กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน');
    }
    final responseText = await GeminiService.instance.generateFromFile(
      prompt: _procurementImportPrompt,
      fileBytes: bytes,
      mimeType: mimeType,
    );
    return _parseGeminiJson(responseText);
  }

  // ─────────────────────────────────────────
  // .docx — แกะข้อความออกมาเองก่อน (docx คือ zip ที่มี word/document.xml) แล้ว
  // ส่งเป็นข้อความล้วนให้ Gemini อ่าน (Gemini ไม่รองรับ .docx โดยตรง)
  // ─────────────────────────────────────────
  Future<ImportedProject> _parseViaGeminiText(String text) async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      throw ProcurementImportException(
          'กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน');
    }
    final responseText = await GeminiService.instance
        .generateText('$_procurementImportPrompt\n\nเนื้อหาเอกสาร:\n$text');
    return _parseGeminiJson(responseText);
  }

  String _extractDocxText(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXml =
        archive.files.where((f) => f.name == 'word/document.xml').firstOrNull;
    if (docXml == null) {
      throw ProcurementImportException(
          'ไฟล์ Word นี้เสียหายหรือไม่ใช่ไฟล์ .docx ที่ถูกต้อง');
    }
    final xmlStr = utf8.decode(docXml.content as List<int>);
    final buffer = StringBuffer();
    // สำคัญ: ต้องใช้ '\b' หลัง 'w:t' ไม่ใช่ 'w:t[^>]*' เฉยๆ — ไม่งั้นจะไปแมตช์
    // <w:tab/>, <w:tabs>, <w:tbl...> ผิดๆ ด้วย (ขึ้นต้นด้วย "w:t" เหมือนกัน) ทำให้
    // regex ไล่หา </w:t> ที่แท้จริงข้ามเนื้อหาไปไกลมาก แล้วกวาดเอา XML ดิบ (เช่น
    // รูปภาพ/drawing ที่แทรกอยู่) มาเป็น "ข้อความ" ทั้งก้อนโดยไม่ตั้งใจ — เจอบั๊กนี้
    // จากไฟล์จริงที่มีโลโก้โรงเรียนแทรกอยู่ (ข้อความที่แกะออกมาพองจาก ~14K ตัวอักษร
    // เป็น ~225K ตัวอักษร เพราะโดน XML ดิบปนมาด้วย)
    final pattern = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>|</w:p>', dotAll: true);
    for (final match in pattern.allMatches(xmlStr)) {
      final text = match.group(1);
      buffer.write(text != null ? _unescapeXml(text) : '\n');
    }
    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw ProcurementImportException('ไม่พบข้อความในไฟล์ Word นี้');
    }
    return result;
  }

  String _unescapeXml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  ImportedProject _parseGeminiJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'```\s*$'), '');
    }
    final decoded = jsonDecode(text.trim());
    if (decoded is! Map<String, dynamic>) {
      throw ProcurementImportException(
          'AI ตอบกลับมาไม่ถูกต้อง ลองใหม่อีกครั้ง');
    }
    String? str(String key) {
      final v = decoded[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final orderType = str('order_type') == 'จ้าง' ? 'จ้าง' : 'ซื้อ';
    final order = ProcurementOrder(
      orderNumber: str('order_number'),
      procurementNumber: str('order_number'),
      orderType: orderType,
      procurementSubject: str('procurement_subject'),
      dateOrderCreated: str('date_order_created'),
      fiscalYear: str('fiscal_year'),
      procurementMethod: str('procurement_method') ?? 'เฉพาะเจาะจง',
      vendorName: str('vendor_name'),
      vendorOwner: str('vendor_owner'),
      vendorAddressNo: str('vendor_address_no'),
      vendorSubdistrict: str('vendor_subdistrict'),
      vendorDistrict: str('vendor_district'),
      vendorProvince: str('vendor_province'),
      vendorPostalCode: str('vendor_postal_code'),
      vendorPhone: str('vendor_phone'),
      vendorTaxId: str('vendor_tax_id'),
      inspector1: str('inspector1'),
      inspector1Pos: str('inspector1_pos'),
      inspector2: str('inspector2'),
      inspector2Pos: str('inspector2_pos'),
      inspector3: str('inspector3'),
      inspector3Pos: str('inspector3_pos'),
      dateAnnouncement: str('date_announcement'),
      dateQuotation: str('date_quotation'),
      dateContractSigned: str('date_contract_signed'),
      dateDeadline: str('date_deadline'),
      dateShipping: str('date_shipping'),
      dateInspection: str('date_inspection'),
      dateDisbursement: str('date_disbursement'),
      contractControlNumber: str('contract_control_number'),
      egpProjectId: str('egp_project_id'),
    );

    final itemsRaw = decoded['items'];
    final items = <ProcurementItem>[];
    if (itemsRaw is List) {
      for (final entry in itemsRaw.whereType<Map<String, dynamic>>()) {
        final name = (entry['item_name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final qty = entry['quantity'];
        final price = entry['unit_price'];
        items.add(ProcurementItem(
          itemName: name,
          quantity: qty is num ? qty.toDouble() : double.tryParse('$qty') ?? 1,
          unit: (entry['unit'] ?? '').toString().trim().isEmpty
              ? null
              : (entry['unit']).toString().trim(),
          unitPrice:
              price is num ? price.toDouble() : double.tryParse('$price') ?? 0,
        ));
      }
    }

    if ((order.procurementSubject?.trim().isEmpty ?? true) && items.isEmpty) {
      throw ProcurementImportException(
          'AI ดึงข้อมูลจากไฟล์นี้ไม่ได้เลย — ไฟล์อาจไม่ใช่เอกสารจัดซื้อจัดจ้าง หรือเนื้อหาไม่ครบ');
    }
    return (order: order, items: items);
  }
}
