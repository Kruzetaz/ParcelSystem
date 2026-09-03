// procurement_document_generator.dart
// สร้างไฟล์ .docx สำหรับเอกสารย่อยที่แยกออกมาจาก master_template.docx (นอกเหนือ
// จาก TOR ที่มี TorDocumentGenerator แยกต่างหากอยู่แล้ว) ใช้ field map ชุดเดียวกับ
// DocumentGenerator (placeholder ที่ไม่ปรากฏในเทมเพลตแต่ละอันจะถูกข้ามเฉยๆ ไม่ error)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/procurement_installment.dart';
import '../models/school_settings.dart';
import '../utils/app_folder_name.dart';
import '../utils/money_format.dart';
import 'docx_template_service.dart';
import 'document_generator.dart';

class ProcurementDocumentGeneratorException implements Exception {
  final String message;
  ProcurementDocumentGeneratorException(this.message);
  @override
  String toString() => 'ProcurementDocumentGeneratorException: $message';
}

enum ProcurementDocumentType {
  contractOrderReport, // รายงานขอซื้อ/ขอจ้าง + คำสั่งแต่งตั้งผู้ตรวจรับพัสดุ
  contractAnnouncement, // รายงานผลการพิจารณา + ประกาศผู้ชนะการเสนอราคา
  quotation, // ใบเสนอราคา
  deliveryNote, // ใบส่งมอบงาน
  disbursementMemo, // บันทึกขออนุมัติเบิกจ่าย
  requisition, // ใบเบิกพัสดุ
  // เอกสารสั่งซื้อ/สั่งจ้างจริงที่ส่งให้ร้านค้า — แยกจาก contractOrderReport
  // ซึ่งเป็นบันทึกขออนุมัติภายในเท่านั้น ใช้ template เดียวกันทั้งซื้อและจ้าง
  // (สลับคำว่า "ซื้อ"/"จ้าง" ด้วย {{order_type}} เหมือน contractOrderReport)
  purchaseOrder, // ใบสั่งซื้อ/ใบสั่งจ้าง (PO/WO)
  inspectionReceipt, // ใบตรวจรับการจัดซื้อ/จัดจ้าง — ใช้กับงวดของสัญญาต่อเนื่อง
  paymentReceipt, // ใบสำคัญรับเงิน
  // เอกสารรายงวดของ "สัญญาต่อเนื่องหลายเดือน" (เช่น อาหารกลางวัน) — แยก
  // เทมเพลตจาก deliveryNote/disbursementMemo ปกติ เพราะถ้อยคำ/โครงสร้างจริง
  // ที่โรงเรียนใช้ไม่เหมือนกัน (ไม่มีรายละเอียด VAT, มี "งวดที่ N" กำกับ)
  installmentDeliveryNote, // ใบส่งมอบงาน (รายงวด)
  installmentDisbursementMemo, // บันทึกข้อความส่งเบิกเงิน (รายงวด)
}

class ProcurementDocumentGenerator {
  static const Map<ProcurementDocumentType, String> _templateAssetPaths = {
    ProcurementDocumentType.contractOrderReport:
        'assets/templates/contract_order_template.docx',
    ProcurementDocumentType.contractAnnouncement:
        'assets/templates/contract_announcement_template.docx',
    ProcurementDocumentType.quotation:
        'assets/templates/quotation_template.docx',
    ProcurementDocumentType.deliveryNote:
        'assets/templates/delivery_note_template.docx',
    ProcurementDocumentType.disbursementMemo:
        'assets/templates/disbursement_memo_template.docx',
    ProcurementDocumentType.requisition:
        'assets/templates/requisition_template.docx',
    ProcurementDocumentType.purchaseOrder:
        'assets/templates/purchase_order_template.docx',
    ProcurementDocumentType.inspectionReceipt:
        'assets/templates/inspection_receipt_template.docx',
    ProcurementDocumentType.paymentReceipt:
        'assets/templates/payment_receipt_template.docx',
    ProcurementDocumentType.installmentDeliveryNote:
        'assets/templates/installment_delivery_note_template.docx',
    ProcurementDocumentType.installmentDisbursementMemo:
        'assets/templates/installment_disbursement_memo_template.docx',
  };

  static const Map<ProcurementDocumentType, String> _outputPrefixes = {
    ProcurementDocumentType.contractOrderReport: 'รายงานขอซื้อขอจ้าง',
    ProcurementDocumentType.contractAnnouncement: 'ประกาศผู้ชนะการเสนอราคา',
    ProcurementDocumentType.quotation: 'ใบเสนอราคา',
    ProcurementDocumentType.deliveryNote: 'ใบส่งมอบงาน',
    ProcurementDocumentType.disbursementMemo: 'บันทึกขออนุมัติเบิกจ่าย',
    ProcurementDocumentType.requisition: 'ใบเบิกพัสดุ',
    ProcurementDocumentType.purchaseOrder: 'ใบสั่งซื้อสั่งจ้าง',
    ProcurementDocumentType.inspectionReceipt: 'ใบตรวจรับการจัดซื้อจัดจ้าง',
    ProcurementDocumentType.paymentReceipt: 'ใบสำคัญรับเงิน',
    ProcurementDocumentType.installmentDeliveryNote: 'ใบส่งมอบงาน',
    ProcurementDocumentType.installmentDisbursementMemo: 'บันทึกข้อความส่งเบิกเงิน',
  };

  /// ประมวลผลเทมเพลตของเอกสารย่อยเป็น bytes ล้วนๆ (ไม่เขียนไฟล์) — แยกออกมา
  /// เพื่อให้เอาไปต่อกับเอกสารอื่นได้โดยไม่ต้องเขียน/อ่านไฟล์ชั่วคราว เช่น
  /// รวมชุดเอกสารรายงวดของสัญญาต่อเนื่องกับเอกสารจัดจ้างตอนแรกเป็นไฟล์เดียว
  static Future<Uint8List> generateBytes({
    required ProcurementDocumentType type,
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    Map<String, String> overrideFields = const {},
    // ทับ/เพิ่ม flag เงื่อนไขนอกเหนือจาก DocumentGenerator.buildConditionalFlags
    // ปกติ (เช่น เปิด is_installment_period ตอนสร้างเอกสารรายงวด)
    Map<String, bool> extraConditionalFlags = const {},
  }) async {
    final templateAssetPath = _templateAssetPaths[type]!;
    late final ByteData templateData;
    try {
      templateData = await rootBundle.load(templateAssetPath);
    } catch (e) {
      throw ProcurementDocumentGeneratorException(
        'ไม่พบไฟล์เทมเพลตที่ $templateAssetPath\n'
        'รายละเอียด: $e',
      );
    }
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );

    final itemDataList = ProcurementItemData.fromItems(items);
    final fieldValues = {
      ...DocumentGenerator.buildFieldMap(order, school),
      ...overrideFields,
    };

    return DocxTemplateService.processTemplate(
      templateBytes: templateBytes,
      fieldValues: fieldValues,
      items: itemDataList,
      conditionalFlags: {
        ...DocumentGenerator.buildConditionalFlags(order),
        ...extraConditionalFlags,
      },
    );
  }

  static Future<File> generate({
    required ProcurementDocumentType type,
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    // ค่าที่ต้องการทับ field map ปกติของ order (เช่น จำนวนเงิน/วันที่ของ
    // งวดใดงวดหนึ่ง สำหรับสัญญาแบบต่อเนื่องหลายเดือน) — ไม่ใส่ก็ได้ตามปกติ
    Map<String, String> overrideFields = const {},
    Map<String, bool> extraConditionalFlags = const {},
    // ต่อท้ายชื่อไฟล์ผลลัพธ์ (เช่น "_งวด1") กันชื่อไฟล์ซ้ำกันเวลา generate
    // เอกสารประเภทเดียวกันหลายงวดจาก order เดียวกัน
    String outputSuffix = '',
  }) async {
    final resultBytes = await generateBytes(
      type: type,
      order: order,
      school: school,
      items: items,
      overrideFields: overrideFields,
      extraConditionalFlags: extraConditionalFlags,
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = '${docsDir.path}/$folderName';

    // ชื่อไฟล์ = "{ประเภทเอกสาร}_{เลขที่จัดซื้อ}{ต่อท้ายงวดถ้ามี}_{หัวเรื่อง}"
    return DocxTemplateService.saveOutput(
      docxBytes: resultBytes,
      outputDir: outputDir,
      procurementNumber:
          '${_outputPrefixes[type]}_${order.procurementNumber ?? "ไม่ระบุเลขที่"}$outputSuffix',
      projectName: order.procurementSubject ?? 'ไม่ระบุหัวเรื่อง',
    );
  }

  static Future<File> generateAndOpen({
    required ProcurementDocumentType type,
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    Map<String, String> overrideFields = const {},
    Map<String, bool> extraConditionalFlags = const {},
    String outputSuffix = '',
  }) async {
    final file = await generate(
      type: type,
      order: order,
      school: school,
      items: items,
      overrideFields: overrideFields,
      extraConditionalFlags: extraConditionalFlags,
      outputSuffix: outputSuffix,
    );
    await _openFile(file.path);
    return file;
  }

  // [ประวัติ] เคยลองใส่ ☑/☐ (U+2611/U+2610) เป็นข้อความ {{placeholder}} ธรรมดา
  // มาก่อน — ใช้ไม่ได้จริง เพราะฟอนต์ "TH SarabunIT๙" ที่ใช้ทั้งเอกสารไม่มีกลีบ
  // ตัวอักษรนี้ พอ Word หาไม่เจอก็ไป substitute ฟอนต์อื่นแทนเองอัตโนมัติ ผลลัพธ์
  // ไม่แน่นอนแล้วแต่เครื่อง (เช่น กลายเป็นไอคอนตราครุฑแทนกล่องติ๊กบนบางเครื่อง)
  //
  // แก้ใหม่ให้ตรงกับเทคนิคที่ master_template.docx ใช้อยู่แล้วสำหรับเครื่องหมาย
  // ✓ ในเอกสารส่วนอื่น — ใช้ element <w:sym w:font="Wingdings"/> ของ OOXML
  // โดยตรง (ไม่ใช่ตัวอักษรใน <w:t>) ระบุฟอนต์+รหัสตัวอักษรตรงๆ ไม่ต้องพึ่ง
  // font fallback เลย — แต่ <w:sym> ใส่ข้อความแทนที่แบบ {{placeholder}} ไม่ได้
  // (ไม่มี <w:t> ให้แทนที่) เทมเพลตจึงฝัง "กล่องติ๊กแล้ว" กับ "กล่องว่าง" ไว้
  // ทั้งคู่ล่วงหน้า แล้วใช้ conditional flag {{if:X}}...{{endif:X}} ของ
  // DocxTemplateService ตัดฝั่งที่ไม่ตรงตามค่าจริงทิ้งแทน (ดู
  // buildInstallmentConditionalFlags ด้านล่าง) — เหลือให้เห็นแค่ฝั่งเดียวจริง

  /// ธงเงื่อนไขคู่กล่องติ๊กของใบตรวจรับการจัดซื้อ/จัดจ้างรายงวด — แต่ละกล่องมี
  /// 2 ธง (…_on / …_off) เพราะเทมเพลตฝัง <w:sym> ของทั้งสองสถานะไว้คู่กัน
  /// ต้องส่งมาครบคู่เสมอ (ไม่งั้นเทมเพลตเก่าที่ยังไม่มี marker คู่นี้จะเงียบ
  /// ไม่ตัดอะไรออกเลย — ปลอดภัยแต่ไม่มีผล)
  static Map<String, bool> buildInstallmentConditionalFlags(ProcurementInstallment i) {
    final result = i.inspectionResult ?? 'ถูกต้อง ครบถ้วนตามสัญญา';
    final isCorrect = result.startsWith('ถูกต้อง');
    final isComplete = result == 'ถูกต้อง ครบถ้วนตามสัญญา';
    final isIncomplete = !isComplete;
    return {
      'check_correct_on': isCorrect,
      'check_correct_off': !isCorrect,
      'check_complete_on': isComplete,
      'check_complete_off': !isComplete,
      'check_incomplete_on': isIncomplete,
      'check_incomplete_off': !isIncomplete,
      'check_has_penalty_on': i.hasPenalty,
      'check_has_penalty_off': !i.hasPenalty,
      'check_no_penalty_on': !i.hasPenalty,
      'check_no_penalty_off': i.hasPenalty,
    };
  }

  /// แยกวันที่รูปแบบ "D เดือนไทย พ.ศ. Y" (เช่น "28 พฤศจิกายน 2568") ออกเป็น
  /// วัน/เดือน/ปี แยกกัน — บางเทมเพลต (เช่นใบส่งมอบงานรายงวด) เขียนคำว่า
  /// "เดือน"/"พ.ศ." เป็นตัวหนังสือคงที่แล้วแทรกแค่ตัวเลข/ชื่อเดือนแยกจุด ทำให้
  /// ต้องมี placeholder ย่อยสามตัวแทนที่จะใช้ก้อนวันที่รวมตัวเดียว
  static (String day, String month, String year) _splitThaiDate(String? date) {
    if (date == null || date.trim().isEmpty) return ('', '', '');
    final parts = date.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) return ('', '', '');
    return (parts[0], parts[1], parts[2]);
  }

  /// สร้างชุด field ที่จะทับ field map ปกติของ order เมื่อสร้างเอกสารของ
  /// งวดใดงวดหนึ่ง (สัญญาแบบต่อเนื่องหลายเดือน เช่น อาหารกลางวัน)
  ///
  /// หมายเหตุสำคัญ: {{current_order_price}}/{{total_price_th}} ปล่อยให้เป็น
  /// ยอด "รวมทั้งสัญญา" ตามปกติ (ไม่ทับ) เพราะ ใบตรวจรับพัสดุ ต้องอ้างอิงยอด
  /// เต็มสัญญาตรงต้นเอกสาร แล้วค่อยระบุยอดที่เบิกจริงของงวดนี้แยกไว้ต่างหาก
  /// ที่ {{period_amount}}/{{period_amount_th}} — เทียบจากเอกสารจริงที่ใช้งาน
  /// (ใบตรวจรับพัสดุ: "...เป็นจำนวนเงินทั้งสิ้น [ยอดเต็มสัญญา] ...๓. การเบิกจ่าย
  /// เบิกจ่ายเงิน เป็นจำนวนเงินทั้งสิ้น [ยอดงวดนี้]")
  static Map<String, String> buildInstallmentOverrides(
    ProcurementOrder order,
    ProcurementInstallment i,
  ) {
    final amount = i.amount ?? 0;
    final bahtPart = amount.truncate();
    final satangPart = ((amount - bahtPart) * 100).round();

    final shippingDate = _splitThaiDate(i.dateDelivery);
    final contractDate = _splitThaiDate(order.dateContractSigned);
    final disbursementDate = _splitThaiDate(i.dateDisbursement);

    return {
      'period_amount': formatBaht(i.amount),
      'period_amount_th': i.amountTh ?? '',
      'date_shipping': i.dateDelivery ?? '',
      'date_shipping_day': shippingDate.$1,
      'date_shipping_month': shippingDate.$2,
      'date_shipping_year': shippingDate.$3,
      'date_contract_signed_day': contractDate.$1,
      'date_contract_signed_month': contractDate.$2,
      'date_contract_signed_year': contractDate.$3,
      'date_disbursement_day': disbursementDate.$1,
      'date_disbursement_month': disbursementDate.$2,
      'date_disbursement_year': disbursementDate.$3,
      'date_inspection': i.dateInspection ?? '',
      'date_disbursement': i.dateDisbursement ?? '',
      'inspection_control_number': i.controlNumberInspection ?? '',
      'period_no': i.periodNo.toString(),
      'period_label': i.periodLabel ?? '',
      'period_amount_baht': formatBaht(bahtPart).split('.').first,
      'period_amount_satang': satangPart == 0 ? '-' : satangPart.toString().padLeft(2, '0'),
    };
  }

  /// รวมเอกสารทั้งหมดของสัญญาต่อเนื่อง (เอกสารจัดจ้างตอนแรก + ใบสั่งจ้าง +
  /// ชุดเอกสารรายงวดทุกงวด) เป็นไฟล์ .docx เดียว เรียงตามลำดับที่ใช้งานจริง
  /// เหมือนที่โรงเรียนเก็บไว้จริง — ใช้ตอนงานเสร็จแล้วอยากได้ไฟล์เดียวรวมทุก
  /// อย่าง ไม่ต้องแยกเปิดทีละไฟล์
  static Future<File> generateCombinedRecurringContractFile({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    required List<ProcurementInstallment> installments,
  }) async {
    final parts = <Uint8List>[
      // บันทึกขออนุมัติใช้งบ + TOR + ใบสั่งจ้างตัวจริง (แบบมีตราครุฑ) ทั้งหมด
      // รวมอยู่ใน master_template เดียวอยู่แล้ว (ส่วนใบสั่งจ้างอยู่ต่อจาก TOR
      // ก่อนช่วง single_purchase_completion_docs ที่ตัดออกเมื่อเป็นสัญญาต่อเนื่อง
      // — ดู buildConditionalFlags ใน document_generator.dart) จึง "ไม่" ต้อง
      // แทรก ProcurementDocumentType.purchaseOrder (เทมเพลตธรรมดา ไม่มีตราครุฑ)
      // ซ้ำอีกที มิเช่นนั้นจะได้ใบสั่งจ้างซ้ำกัน 2 ใบในไฟล์เดียว
      await DocumentGenerator.generateBytes(order: order, school: school, items: items),
    ];

    // ส่วนที่ 3 เป็นต้นไป: ชุดเอกสารรายงวด (ใบส่งมอบงาน → ใบตรวจรับการจัดซื้อ/
    // จัดจ้าง → บันทึกข้อความส่งเบิกเงิน → ใบสำคัญรับเงิน) เรียงตามงวดที่ 1, 2, 3, ...
    final sortedInstallments = [...installments]..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    for (final installment in sortedInstallments) {
      final overrides = buildInstallmentOverrides(order, installment);
      final checkFlags = buildInstallmentConditionalFlags(installment);
      for (final type in [
        ProcurementDocumentType.installmentDeliveryNote,
        ProcurementDocumentType.inspectionReceipt,
        ProcurementDocumentType.installmentDisbursementMemo,
        ProcurementDocumentType.paymentReceipt,
      ]) {
        parts.add(await generateBytes(
          type: type,
          order: order,
          school: school,
          items: items,
          overrideFields: overrides,
          extraConditionalFlags: checkFlags,
        ));
      }
    }

    final mergedBytes = DocxTemplateService.mergeDocxBodies(parts);

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = '${docsDir.path}/$folderName';

    // ชื่อไฟล์ = "เอกสารรวม_{เลขที่จัดซื้อ}_{หัวเรื่อง}"
    return DocxTemplateService.saveOutput(
      docxBytes: mergedBytes,
      outputDir: outputDir,
      procurementNumber: 'เอกสารรวม_${order.procurementNumber ?? "ไม่ระบุเลขที่"}',
      projectName: order.procurementSubject ?? 'ไม่ระบุหัวเรื่อง',
    );
  }

  /// รวมชุดเอกสาร 4 ไฟล์ของ "งวดเดียว" (ใบส่งมอบงาน → ใบตรวจรับการจัดซื้อ/
  /// จัดจ้าง → บันทึกข้อความส่งเบิกเงิน → ใบสำคัญรับเงิน) เป็นไฟล์ .docx เดียว —
  /// ใช้ตอนกดปุ่ม "สร้างชุดเอกสาร" รายงวดจากตาราง ไม่ต้องเปิดทีละ 4 ไฟล์
  static Future<File> generateInstallmentDocumentSetFile({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    required ProcurementInstallment installment,
  }) async {
    final overrides = buildInstallmentOverrides(order, installment);
    final checkFlags = buildInstallmentConditionalFlags(installment);
    final parts = <Uint8List>[];
    for (final type in [
      ProcurementDocumentType.installmentDeliveryNote,
      ProcurementDocumentType.inspectionReceipt,
      ProcurementDocumentType.installmentDisbursementMemo,
      ProcurementDocumentType.paymentReceipt,
    ]) {
      parts.add(await generateBytes(
        type: type,
        order: order,
        school: school,
        items: items,
        overrideFields: overrides,
        extraConditionalFlags: checkFlags,
      ));
    }

    final mergedBytes = DocxTemplateService.mergeDocxBodies(parts);

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = '${docsDir.path}/$folderName';

    // ชื่อไฟล์ = "ชุดเอกสารงวด{N}_{เลขที่จัดซื้อ}_{หัวเรื่อง}"
    return DocxTemplateService.saveOutput(
      docxBytes: mergedBytes,
      outputDir: outputDir,
      procurementNumber:
          'ชุดเอกสารงวด${installment.periodNo}_${order.procurementNumber ?? "ไม่ระบุเลขที่"}',
      projectName: order.procurementSubject ?? 'ไม่ระบุหัวเรื่อง',
    );
  }

  static Future<File> generateInstallmentDocumentSetFileAndOpen({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    required ProcurementInstallment installment,
  }) async {
    final file = await generateInstallmentDocumentSetFile(
      order: order,
      school: school,
      items: items,
      installment: installment,
    );
    await _openFile(file.path);
    return file;
  }

  static Future<File> generateCombinedRecurringContractFileAndOpen({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
    required List<ProcurementInstallment> installments,
  }) async {
    final file = await generateCombinedRecurringContractFile(
      order: order,
      school: school,
      items: items,
      installments: installments,
    );
    await _openFile(file.path);
    return file;
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
      // ไม่ throw ต่อ — ไฟล์สร้างสำเร็จแล้ว แค่เปิดอัตโนมัติไม่ได้
    }
  }
}
