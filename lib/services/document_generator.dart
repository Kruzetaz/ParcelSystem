// document_generator.dart
//
// ตัวเชื่อมระหว่าง UI (order_wizard_screen.dart) กับ docx_template_service.dart
// หน้าที่:
//   1. โหลด master_template.docx จาก assets
//   2. แปลง ProcurementOrder + SchoolSettings + List<ProcurementItem>
//      ให้เป็น Map<String, String> ตรงกับ {{placeholder}} ทุกตัวในเทมเพลต
//   3. เรียก DocxTemplateService.processTemplate + saveOutput
//   4. เปิดไฟล์ผลลัพธ์ด้วยโปรแกรม Word อัตโนมัติ (รองรับ macOS/Windows/Linux)
//
// หมายเหตุสำคัญเรื่อง placeholder ระดับ "รายการสินค้า"
// (idx, item_name, quantity, unit_price, total_price):
// คีย์เหล่านี้ถูกจัดการโดย DocxTemplateService._cloneItemRows() อยู่แล้ว
// (แทนที่เฉพาะในแถวตารางที่ clone ออกมา) จึง "ไม่" ใส่ซ้ำในแมปฟิลด์ระดับฟอร์ม
// ที่ไฟล์นี้สร้าง — ถ้าเทมเพลตมี {{quantity}} หรือ {{unit_price}} หลุดอยู่
// นอกตารางแถวสินค้า ค่าพวกนั้นจะไม่ถูกแทนที่ (ต้องแก้ที่ template แทน)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/school_settings.dart';
import 'docx_template_service.dart';

class DocumentGeneratorException implements Exception {
  final String message;
  DocumentGeneratorException(this.message);
  @override
  String toString() => 'DocumentGeneratorException: $message';
}

class DocumentGenerator {
  static const String _templateAssetPath =
      'assets/templates/master_template.docx';

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'en_US');

  /// สร้างไฟล์ .docx จาก template + ข้อมูล order/settings/items
  /// คืนค่าเป็น File ที่บันทึกเสร็จแล้ว (ยังไม่เปิด)
  static Future<File> generate({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
  }) async {
    // STEP 1: โหลด template จาก assets
    late final ByteData templateData;
    try {
      templateData = await rootBundle.load(_templateAssetPath);
    } catch (e) {
      throw DocumentGeneratorException(
        'ไม่พบไฟล์เทมเพลตที่ $_templateAssetPath\n'
        'ตรวจสอบว่าวางไฟล์ master_template.docx ไว้ที่ assets/templates/ '
        'และมี assets/templates/ อยู่ใน pubspec.yaml แล้ว (มีอยู่แล้วในโปรเจกต์นี้)\n'
        'รายละเอียด: $e',
      );
    }
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );

    // STEP 2: แปลง items -> ProcurementItemData (คำนวณ idx อัตโนมัติ)
    final itemDataList = ProcurementItemData.fromItems(items);

    // STEP 3: สร้าง field map ระดับฟอร์ม
    final fieldValues = _buildFieldMap(order, school);

    // STEP 4: ประมวลผล template
    final resultBytes = DocxTemplateService.processTemplate(
      templateBytes: templateBytes,
      fieldValues: fieldValues,
      items: itemDataList,
    );

    // STEP 5: บันทึกไฟล์ลงโฟลเดอร์ Documents/BanPaLao_Documents
    final docsDir = await getApplicationDocumentsDirectory();
    final outputDir = '${docsDir.path}/BanPaLao_Documents';

    return DocxTemplateService.saveOutput(
      docxBytes: resultBytes,
      outputDir: outputDir,
      procurementNumber: order.procurementNumber ?? 'ไม่ระบุเลขที่',
      projectName: order.projectName ?? 'ไม่ระบุชื่อโครงการ',
    );
  }

  /// สร้างไฟล์แล้วเปิดด้วยโปรแกรมเริ่มต้นของระบบทันที (Word ปกติ)
  static Future<File> generateAndOpen({
    required ProcurementOrder order,
    required SchoolSettings school,
    required List<ProcurementItem> items,
  }) async {
    final file = await generate(order: order, school: school, items: items);
    await _openFile(file.path);
    return file;
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  static Future<void> _openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        // 'start' เป็นคำสั่งภายใน cmd.exe เอง ต้องเรียกผ่าน cmd /c
        // อาร์กิวเมนต์ตัวว่าง '' ตัวแรกหลัง start คือ window title (จำเป็นต้องมี
        // ไม่งั้น start จะเข้าใจ path ที่มีช่องว่างผิดเป็น title)
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      // ไม่ throw ต่อ — ไฟล์สร้างสำเร็จแล้ว แค่เปิดอัตโนมัติไม่ได้
      // (เช่น ไม่มีโปรแกรมเริ่มต้นผูกกับ .docx) ผู้ใช้เปิดเองได้จาก path
    }
  }

  static String _money(double? v) => v == null ? '' : _moneyFmt.format(v);

  static String _str(String? v) => v ?? '';

  static String _intStr(int? v) => v?.toString() ?? '';

  /// อัตราปรับ (penaltyRate) เก็บเป็นสัดส่วนอยู่แล้ว (เช่น 0.20)
  /// เทมเพลตต้องการค่าทศนิยมตรงๆ แบบนี้ ("0.20") ไม่ใช่เปอร์เซ็นต์
  static String _percent(double v) {
    return v.toStringAsFixed(2);
  }

  static Map<String, String> _buildFieldMap(
    ProcurementOrder o,
    SchoolSettings s,
  ) {
    return {
      // ข้อมูลโรงเรียน (school_settings)
      'school_name': _str(s.schoolName),
      'school_address_no': _str(s.schoolAddressNo),
      'school_subdistrict': _str(s.schoolSubdistrict),
      'school_amphoe': _str(s.schoolAmphoe),
      'school_changwat': _str(s.schoolChangwat),

      // ปีงบประมาณ
      'fiscal_year': _str(o.fiscalYear),

      // ข้อมูลโครงการ/กิจกรรม
      'project_name': _str(o.projectName),
      'activity_name': _str(o.activityName),
      'purpose_reason': _str(o.purposeReason),
      'purpose_objective': _str(o.purposeObjective),

      // เลขที่เอกสารต่างๆ
      'procurement_number': _str(o.procurementNumber),
      'order_number': _str(o.orderNumber),
      'egp_project_id': _str(o.egpProjectId),
      'contract_control_number': _str(o.contractControlNumber),
      'inspection_control_number': _str(o.inspectionControlNumber),

      // งบประมาณ
      'allocated_amount': _money(o.allocatedAmount),
      'allocated_amount_th': _str(o.allocatedAmountTh),
      'used_budget': _money(o.usedBudget),
      'remaining_amount': _money(o.remainingAmount),

      // ราคา/ภาษี/ยอดสุทธิ ระดับใบสั่ง (รวมทุกรายการ)
      'current_order_price': _money(o.currentOrderPrice),
      'total_price_th': _str(o.totalPriceTh),
      'subtotal_before_vat': _money(o.subtotalBeforeVat),
      'vat_amount': _money(o.vatAmount),
      'tax_withholding_amount': _money(o.taxWithholdingAmount),
      'net_payable_amount': _money(o.netPayableAmount),
      // total_price ระดับฟอร์ม (ยอดรวมทั้งใบ) แยกจาก total_price รายแถวสินค้า
      // ซึ่งถูกแทนที่ไปแล้วตอน clone แถว — ตัวนี้ครอบ {{total_price}}
      // ที่อาจเหลืออยู่นอกตาราง (เช่นสรุปยอดท้ายเอกสาร)
      'total_price': _money(o.currentOrderPrice),

      // บุคคล/ตำแหน่ง
      'owner_name': _str(o.ownerName),
      'owner_position': _str(o.ownerPosition),
      'finance_officer': _str(o.financeOfficer),
      'spec_creator_name': _str(o.specCreatorName),
      'spec_creator_position': _str(o.specCreatorPosition),
      'procurement_officer': _str(o.procurementOfficer),
      'procurement_head': _str(o.procurementHead),
      'director_name': _str(o.directorName),
      'inspector_title_group': _str(o.inspectorTitleGroup),
      'inspector_1': _str(o.inspector1),
      'inspector_1_pos': _str(o.inspector1Pos),
      'inspector_2': _str(o.inspector2),
      'inspector_2_pos': _str(o.inspector2Pos),
      'inspector_3': _str(o.inspector3),
      'inspector_3_pos': _str(o.inspector3Pos),

      // ผู้ขาย/คู่สัญญา
      'vendor_name': _str(o.vendorName),
      'vendor_owner': _str(o.vendorOwner),
      'vendor_address_no': _str(o.vendorAddressNo),
      'vendor_subdistrict': _str(o.vendorSubdistrict),
      'vendor_district': _str(o.vendorDistrict),
      'vendor_province': _str(o.vendorProvince),
      'vendor_phone': _str(o.vendorPhone),
      'vendor_tax_id': _str(o.vendorTaxId),

      // เงื่อนไข/ระยะเวลา
      'shipping_days': _intStr(o.shippingDays),
      'penalty_rate': _percent(o.penaltyRate),
      'warranty_period': _str(o.warrantyPeriod),
      'delivery_doc_type': _str(o.deliveryDocType),
      'delivery_doc_number': _str(o.deliveryDocNumber),
      
      'delivery_doc_type': _str(o.deliveryDocType),
      'delivery_doc_number': _str(o.deliveryDocNumber),

      // วันที่ (เก็บเป็น string dd/MM/yyyy พ.ศ. อยู่แล้วจาก date picker)
      'date_memo_used': _str(o.dateMemoUsed),
      'date_order_created': _str(o.dateOrderCreated),
      'date_announcement': _str(o.dateAnnouncement),
      'date_quotation': _str(o.dateQuotation),
      'date_contract_signed': _str(o.dateContractSigned),
      'date_deadline': _str(o.dateDeadline),
      'date_shipping': _str(o.dateShipping),
      'date_inspection': _str(o.dateInspection),
      'date_disbursement': _str(o.dateDisbursement),
    };
  }
}