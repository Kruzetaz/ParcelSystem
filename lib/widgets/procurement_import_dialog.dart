// procurement_import_dialog.dart
// พรีวิว/แก้ไขโครงการจัดซื้อจัดจ้างที่นำเข้าจากไฟล์เก่า (.docx/.pdf/.xlsx) ก่อน
// บันทึกลงฐานข้อมูลจริง — ต้องผ่านหน้านี้เสมอ เพราะ AI อ่านผิดพลาดได้ โดยเฉพาะ
// เลขที่เอกสาร/ราคา ที่ต้องแม่นเป๊ะ (ตามที่ผู้ใช้ยืนยันไว้ตอนคุยเรื่อง import)

import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import '../models/school_settings.dart';
import '../services/procurement_import_service.dart';
import '../theme/design_tokens.dart';
import '../utils/calc_engine.dart';
import '../utils/thai_text_similarity.dart';
import 'design_system/data_table_shell.dart'
    show DsActionIconButtons, DsRowAction;
import 'design_system/clearable_text_field.dart';

/// รายการที่นำเข้าจากไฟล์ 1 ไฟล์ — สำเร็จ (order+items) หรือพัง (errorMessage)
class ImportAttempt {
  final String fileName;
  final ProcurementOrder? order;
  final List<ProcurementItem> items;
  final String? errorMessage;
  // เก็บ path ไฟล์ต้นฉบับไว้ด้วย (ถ้ามี) — ใช้ตอนกด "ลองใหม่" ไฟล์ที่อ่านไม่
  // สำเร็จ (เช่น โดน rate limit ของ AI ชั่วคราว) โดยไม่ต้องให้ผู้ใช้เลือกไฟล์
  // ทั้งชุดใหม่ทั้งหมดอีกรอบ
  final String? filePath;

  const ImportAttempt.success(this.fileName, this.order, this.items,
      [this.filePath])
      : errorMessage = null;
  const ImportAttempt.failure(this.fileName, this.errorMessage, [this.filePath])
      : order = null,
        items = const [];

  bool get ok => order != null;
}

class _EditableItem {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;

  _EditableItem(ProcurementItem i)
      : name = TextEditingController(text: i.itemName),
        quantity = TextEditingController(
            text: i.quantity == i.quantity.roundToDouble()
                ? i.quantity.toStringAsFixed(0)
                : i.quantity.toString()),
        unit = TextEditingController(text: i.unit ?? ''),
        unitPrice = TextEditingController(text: i.unitPrice.toStringAsFixed(2));

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
  }

  ProcurementItem toItem() => ProcurementItem(
        itemName: name.text.trim(),
        quantity: double.tryParse(quantity.text.trim()) ?? 1,
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        unitPrice: double.tryParse(unitPrice.text.trim()) ?? 0,
      );
}

class _EditableProject {
  final String fileName;
  final TextEditingController orderNumber;
  String orderType;
  final TextEditingController procurementSubject;
  final TextEditingController dateOrderCreated;
  final TextEditingController fiscalYear;
  final TextEditingController procurementMethod;
  final TextEditingController vendorName;
  final TextEditingController vendorOwner;
  final TextEditingController vendorAddressNo;
  final TextEditingController vendorSubdistrict;
  final TextEditingController vendorDistrict;
  final TextEditingController vendorProvince;
  final TextEditingController vendorPostalCode;
  final TextEditingController vendorPhone;
  final TextEditingController vendorTaxId;
  final TextEditingController inspector1;
  final TextEditingController inspector1Pos;
  final TextEditingController inspector2;
  final TextEditingController inspector2Pos;
  final TextEditingController inspector3;
  final TextEditingController inspector3Pos;
  final TextEditingController dateAnnouncement;
  final TextEditingController dateQuotation;
  final TextEditingController dateContractSigned;
  final TextEditingController dateDeadline;
  final TextEditingController dateShipping;
  final TextEditingController dateInspection;
  final TextEditingController dateDisbursement;
  final TextEditingController contractControlNumber;
  final TextEditingController egpProjectId;
  List<_EditableItem> items;
  bool expanded = false;
  // แผนงบที่จับคู่ไว้ (อัตโนมัติแบบคร่าวๆ จากชื่อหัวเรื่อง หรือผู้ใช้เลือกเอง) —
  // ต้องให้ผู้ใช้ยืนยัน/แก้ไขเองเสมอ เพราะชื่อจากไฟล์เก่าอาจสะกดไม่ตรงกับแผนงบ
  // เป๊ะๆ จับผิดได้ (ตามที่ผู้ใช้ระบุไว้ตอนคุยเรื่องนี้)
  Budget? matchedBudget;
  final SchoolSettings? school;

  _EditableProject(this.fileName, ProcurementOrder o, List<ProcurementItem> its,
      List<Budget> availableBudgets, this.school)
      : matchedBudget = bestBudgetMatch(o.procurementSubject, availableBudgets),
        orderNumber = TextEditingController(text: o.orderNumber ?? ''),
        orderType = o.orderType ?? 'ซื้อ',
        procurementSubject =
            TextEditingController(text: o.procurementSubject ?? ''),
        dateOrderCreated =
            TextEditingController(text: o.dateOrderCreated ?? ''),
        fiscalYear = TextEditingController(text: o.fiscalYear ?? ''),
        procurementMethod =
            TextEditingController(text: o.procurementMethod ?? 'เฉพาะเจาะจง'),
        vendorName = TextEditingController(text: o.vendorName ?? ''),
        vendorOwner = TextEditingController(text: o.vendorOwner ?? ''),
        vendorAddressNo = TextEditingController(text: o.vendorAddressNo ?? ''),
        vendorSubdistrict =
            TextEditingController(text: o.vendorSubdistrict ?? ''),
        vendorDistrict = TextEditingController(text: o.vendorDistrict ?? ''),
        vendorProvince = TextEditingController(text: o.vendorProvince ?? ''),
        vendorPostalCode =
            TextEditingController(text: o.vendorPostalCode ?? ''),
        vendorPhone = TextEditingController(text: o.vendorPhone ?? ''),
        vendorTaxId = TextEditingController(text: o.vendorTaxId ?? ''),
        inspector1 = TextEditingController(text: o.inspector1 ?? ''),
        inspector1Pos = TextEditingController(text: o.inspector1Pos ?? ''),
        inspector2 = TextEditingController(text: o.inspector2 ?? ''),
        inspector2Pos = TextEditingController(text: o.inspector2Pos ?? ''),
        inspector3 = TextEditingController(text: o.inspector3 ?? ''),
        inspector3Pos = TextEditingController(text: o.inspector3Pos ?? ''),
        dateAnnouncement =
            TextEditingController(text: o.dateAnnouncement ?? ''),
        dateQuotation = TextEditingController(text: o.dateQuotation ?? ''),
        dateContractSigned =
            TextEditingController(text: o.dateContractSigned ?? ''),
        dateDeadline = TextEditingController(text: o.dateDeadline ?? ''),
        dateShipping = TextEditingController(text: o.dateShipping ?? ''),
        dateInspection = TextEditingController(text: o.dateInspection ?? ''),
        dateDisbursement =
            TextEditingController(text: o.dateDisbursement ?? ''),
        contractControlNumber =
            TextEditingController(text: o.contractControlNumber ?? ''),
        egpProjectId = TextEditingController(text: o.egpProjectId ?? ''),
        items = its.map(_EditableItem.new).toList();

  void dispose() {
    orderNumber.dispose();
    procurementSubject.dispose();
    dateOrderCreated.dispose();
    fiscalYear.dispose();
    procurementMethod.dispose();
    vendorName.dispose();
    vendorOwner.dispose();
    vendorAddressNo.dispose();
    vendorSubdistrict.dispose();
    vendorDistrict.dispose();
    vendorProvince.dispose();
    vendorPostalCode.dispose();
    vendorPhone.dispose();
    vendorTaxId.dispose();
    inspector1.dispose();
    inspector1Pos.dispose();
    inspector2.dispose();
    inspector2Pos.dispose();
    inspector3.dispose();
    inspector3Pos.dispose();
    dateAnnouncement.dispose();
    dateQuotation.dispose();
    dateContractSigned.dispose();
    dateDeadline.dispose();
    dateShipping.dispose();
    dateInspection.dispose();
    dateDisbursement.dispose();
    contractControlNumber.dispose();
    egpProjectId.dispose();
    for (final i in items) {
      i.dispose();
    }
  }

  double get totalPrice => items.fold(
      0,
      (sum, i) =>
          sum +
          ((double.tryParse(i.quantity.text) ?? 0) *
              (double.tryParse(i.unitPrice.text) ?? 0)));

  ({ProcurementOrder order, List<ProcurementItem> items}) toResult() {
    // คำนวณยอดเงิน/VAT ให้เหมือนตอนกดบันทึกใน wizard ปกติ (CalcEngine ตัวเดียวกัน)
    // เพราะการนำเข้าไฟล์เก่าบันทึกตรงเข้า DB ไม่ผ่าน wizard เลย ถ้าไม่คำนวณให้ตรงนี้
    // ใบสั่งซื้อ/สั่งจ้างจะว่างเปล่าไม่มียอดรวม/VAT/ยอดสุทธิ
    const vatRate = 0.07;
    const withholdingRate = 0.01;
    final calc = CalcEngine.calcAllWithRates(totalPrice,
        vatRate: vatRate, withholdingRate: withholdingRate);
    // เดากลุ่มผู้ตรวจรับจากจำนวนชื่อที่กรอก — มี 2-3 คนถือเป็นคณะกรรมการ มีคนเดียว
    // ถือเป็นผู้ตรวจรับคนเดียว (ค่านี้มีผลต่อย่อหน้าเงื่อนไขในคำสั่งแต่งตั้งฯ ถ้า
    // ปล่อยว่างจะ fallback เป็น "คนเดียว" เสมอซึ่งอาจผิดถ้าจริงๆ มีหลายคน)
    final hasCommittee =
        inspector2.text.trim().isNotEmpty || inspector3.text.trim().isNotEmpty;
    final responsiblePerson = matchedBudget?.responsiblePerson?.trim();
    final hasResponsiblePerson =
        responsiblePerson != null && responsiblePerson.isNotEmpty;
    final order = ProcurementOrder(
      budgetId: matchedBudget?.id,
      fiscalYear: matchedBudget?.fiscalYear ??
          (fiscalYear.text.trim().isEmpty ? null : fiscalYear.text.trim()),
      projectName: matchedBudget?.projectName,
      activityName: matchedBudget?.activityName,
      // ชื่อผู้เสนอ/ผู้จัดทำสเปค — ถ้าผูกแผนงบไว้ใช้ผู้รับผิดชอบของแผนงบนั้นเลย
      // (พฤติกรรมเดียวกับตอนเลือกแผนงบใน wizard)
      ownerName: hasResponsiblePerson ? responsiblePerson : null,
      specCreatorName: hasResponsiblePerson ? responsiblePerson : null,
      // ผู้อำนวยการ/เจ้าหน้าที่พัสดุ/หัวหน้าเจ้าหน้าที่พัสดุ/เจ้าหน้าที่การเงิน —
      // ดึงจากข้อมูลโรงเรียนส่วนกลางเหมือนที่ wizard ทำตอนเปิดหน้าสร้างใหม่
      directorName: school?.directorName,
      procurementOfficer: school?.procurementOfficer,
      procurementHead: school?.procurementHead,
      financeOfficer: school?.financeOfficer,
      inspectorTitleGroup:
          hasCommittee ? 'คณะกรรมการตรวจรับ' : 'ผู้ตรวจรับพัสดุ',
      currentOrderPrice: calc['current_order_price'],
      totalPriceTh: CalcEngine.bahtText(calc['current_order_price']!),
      subtotalBeforeVat: calc['subtotal_before_vat'],
      vatRate: vatRate,
      vatAmount: calc['vat_amount'],
      withholdingTaxRate: withholdingRate,
      taxWithholdingAmount: calc['tax_withholding_amount'],
      netPayableAmount: calc['net_payable_amount'],
      orderNumber:
          orderNumber.text.trim().isEmpty ? null : orderNumber.text.trim(),
      procurementNumber:
          orderNumber.text.trim().isEmpty ? null : orderNumber.text.trim(),
      orderType: orderType,
      procurementSubject: procurementSubject.text.trim().isEmpty
          ? null
          : procurementSubject.text.trim(),
      dateOrderCreated: dateOrderCreated.text.trim().isEmpty
          ? null
          : dateOrderCreated.text.trim(),
      procurementMethod: procurementMethod.text.trim().isEmpty
          ? null
          : procurementMethod.text.trim(),
      vendorName:
          vendorName.text.trim().isEmpty ? null : vendorName.text.trim(),
      vendorOwner:
          vendorOwner.text.trim().isEmpty ? null : vendorOwner.text.trim(),
      vendorAddressNo: vendorAddressNo.text.trim().isEmpty
          ? null
          : vendorAddressNo.text.trim(),
      vendorSubdistrict: vendorSubdistrict.text.trim().isEmpty
          ? null
          : vendorSubdistrict.text.trim(),
      vendorDistrict: vendorDistrict.text.trim().isEmpty
          ? null
          : vendorDistrict.text.trim(),
      vendorProvince: vendorProvince.text.trim().isEmpty
          ? null
          : vendorProvince.text.trim(),
      vendorPostalCode: vendorPostalCode.text.trim().isEmpty
          ? null
          : vendorPostalCode.text.trim(),
      vendorPhone:
          vendorPhone.text.trim().isEmpty ? null : vendorPhone.text.trim(),
      vendorTaxId:
          vendorTaxId.text.trim().isEmpty ? null : vendorTaxId.text.trim(),
      inspector1:
          inspector1.text.trim().isEmpty ? null : inspector1.text.trim(),
      inspector1Pos:
          inspector1Pos.text.trim().isEmpty ? null : inspector1Pos.text.trim(),
      inspector2:
          inspector2.text.trim().isEmpty ? null : inspector2.text.trim(),
      inspector2Pos:
          inspector2Pos.text.trim().isEmpty ? null : inspector2Pos.text.trim(),
      inspector3:
          inspector3.text.trim().isEmpty ? null : inspector3.text.trim(),
      inspector3Pos:
          inspector3Pos.text.trim().isEmpty ? null : inspector3Pos.text.trim(),
      dateAnnouncement: dateAnnouncement.text.trim().isEmpty
          ? null
          : dateAnnouncement.text.trim(),
      dateQuotation:
          dateQuotation.text.trim().isEmpty ? null : dateQuotation.text.trim(),
      dateContractSigned: dateContractSigned.text.trim().isEmpty
          ? null
          : dateContractSigned.text.trim(),
      dateDeadline:
          dateDeadline.text.trim().isEmpty ? null : dateDeadline.text.trim(),
      dateShipping:
          dateShipping.text.trim().isEmpty ? null : dateShipping.text.trim(),
      dateInspection: dateInspection.text.trim().isEmpty
          ? null
          : dateInspection.text.trim(),
      dateDisbursement: dateDisbursement.text.trim().isEmpty
          ? null
          : dateDisbursement.text.trim(),
      contractControlNumber: contractControlNumber.text.trim().isEmpty
          ? null
          : contractControlNumber.text.trim(),
      egpProjectId:
          egpProjectId.text.trim().isEmpty ? null : egpProjectId.text.trim(),
    );
    final resultItems = items
        .map((i) => i.toItem())
        .where((i) => i.itemName.isNotEmpty)
        .toList();
    return (order: order, items: resultItems);
  }
}

/// แสดง dialog พรีวิว — คืนค่า list ของ (order, items) ที่ยืนยันแล้ว หรือ null
/// ถ้ายกเลิก [existingOrderNumbers] ใช้เตือน (ไม่บล็อก) ถ้าเลขที่ซ้ำของเดิมในระบบ
/// [availableBudgets] ใช้จับคู่แผนงบอัตโนมัติแบบคร่าวๆ ให้ผู้ใช้ยืนยัน/แก้ไขเอง
Future<List<({ProcurementOrder order, List<ProcurementItem> items})>?>
    showProcurementImportPreviewDialog(
  BuildContext context,
  List<ImportAttempt> attempts,
  Set<String> existingOrderNumbers, {
  List<Budget> availableBudgets = const [],
  SchoolSettings? school,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ProcurementImportPreviewDialog(
      attempts: attempts,
      existingOrderNumbers: existingOrderNumbers,
      availableBudgets: availableBudgets,
      school: school,
    ),
  );
}

class _ProcurementImportPreviewDialog extends StatefulWidget {
  final List<ImportAttempt> attempts;
  final Set<String> existingOrderNumbers;
  final List<Budget> availableBudgets;
  final SchoolSettings? school;
  const _ProcurementImportPreviewDialog(
      {required this.attempts,
      required this.existingOrderNumbers,
      required this.school,
      required this.availableBudgets});

  @override
  State<_ProcurementImportPreviewDialog> createState() =>
      _ProcurementImportPreviewDialogState();
}

class _ProcurementImportPreviewDialogState
    extends State<_ProcurementImportPreviewDialog> {
  late List<_EditableProject> _projects;
  late List<ImportAttempt> _failed;
  final Set<ImportAttempt> _retryingAttempts = {};

  @override
  void initState() {
    super.initState();
    _projects = widget.attempts
        .where((a) => a.ok)
        .map((a) => _EditableProject(a.fileName, a.order!, a.items,
            widget.availableBudgets, widget.school))
        .toList();
    _failed = widget.attempts.where((a) => !a.ok).toList();
  }

  @override
  void dispose() {
    for (final p in _projects) {
      p.dispose();
    }
    super.dispose();
  }

  void _removeAt(int index) {
    setState(() {
      _projects[index].dispose();
      _projects.removeAt(index);
    });
  }

  /// ลองอ่านไฟล์ที่อ่านไม่สำเร็จใหม่อีกครั้ง (เช่น โดน rate limit ของ AI
  /// ชั่วคราว) โดยไม่ต้องให้ผู้ใช้เลือกไฟล์ทั้งชุดใหม่ — ใช้ path เดิมที่เก็บไว้
  Future<void> _retryFile(ImportAttempt attempt) async {
    if (attempt.filePath == null) return;
    setState(() => _retryingAttempts.add(attempt));
    try {
      final parsed = await ProcurementImportService.instance
          .importFromFile(attempt.filePath!);
      if (!mounted) return;
      setState(() {
        _retryingAttempts.remove(attempt);
        _failed.remove(attempt);
        for (final p in parsed) {
          _projects.add(_EditableProject(attempt.fileName, p.order, p.items,
              widget.availableBudgets, widget.school));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retryingAttempts.remove(attempt);
        final idx = _failed.indexOf(attempt);
        if (idx != -1) {
          _failed[idx] =
              ImportAttempt.failure(attempt.fileName, '$e', attempt.filePath);
        }
      });
    }
  }

  Widget _buildFailedRow(
      BuildContext context, ColorScheme colors, ImportAttempt f) {
    final retrying = _retryingAttempts.contains(f);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('${f.fileName} (${f.errorMessage})',
                style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: BrandAccent.red(context))),
          ),
          if (f.filePath != null) ...[
            const SizedBox(width: 8),
            retrying
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: BrandAccent.red(context)))
                : InkWell(
                    onTap: () => _retryFile(f),
                    child: Text('ลองใหม่',
                        style: TextStyle(
                            fontSize: AppTypography.caption,
                            fontWeight: AppTypography.weightSemiBold,
                            color: BrandAccent.teal(context),
                            decoration: TextDecoration.underline)),
                  ),
          ],
        ],
      ),
    );
  }

  static const _buttonTextStyle =
      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
  static const _buttonPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 12);
  static const _fieldStyle = TextStyle(fontSize: 14);

  InputDecoration _dec(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      labelText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.card)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open_outlined,
                      color: BrandAccent.teal(context), size: 24),
                  const SizedBox(width: 8),
                  const Text('ตรวจสอบโครงการที่นำเข้า',
                      style: TextStyle(
                          fontWeight: AppTypography.weightExtraBold,
                          fontSize: AppTypography.heading2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  'AI อ่านข้อมูลจากไฟล์เก่ามาให้ — ตรวจสอบและแก้ไขให้ถูกต้องก่อนบันทึกจริง โดยเฉพาะเลขที่เอกสารและราคา',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AppTypography.bodyMedium)),
              if (_failed.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BrandAccent.red(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(RadiusSize.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('อ่านไม่สำเร็จ ${_failed.length} ไฟล์',
                          style: TextStyle(
                              fontSize: AppTypography.bodySmall,
                              fontWeight: AppTypography.weightSemiBold,
                              color: BrandAccent.red(context))),
                      for (final f in _failed)
                        _buildFailedRow(context, colors, f),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_projects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('ไม่มีรายการที่นำเข้าสำเร็จ',
                          style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: AppTypography.body))),
                )
              else
                Flexible(
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, i) =>
                        _buildProjectCard(context, colors, i),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                        padding: _buttonPadding, textStyle: _buttonTextStyle),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _projects.isEmpty
                        ? null
                        : () => Navigator.pop(context,
                            _projects.map((p) => p.toResult()).toList()),
                    icon: const Icon(Icons.check),
                    label: Text('ยืนยันนำเข้า (${_projects.length} โครงการ)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandAccent.teal(context),
                      padding: _buttonPadding,
                      textStyle: _buttonTextStyle,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RadiusSize.md)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(
      BuildContext context, ColorScheme colors, int index) {
    final p = _projects[index];
    final isDuplicate = p.orderNumber.text.trim().isNotEmpty &&
        widget.existingOrderNumbers.contains(p.orderNumber.text.trim());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(RadiusSize.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: ClearableTextField(
                    controller: p.orderNumber,
                    style: _fieldStyle,
                    decoration: _dec('เลขที่เอกสาร')),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: p.orderType,
                  isDense: true,
                  isExpanded: true,
                  decoration: _dec('ประเภท'),
                  style: _fieldStyle.copyWith(color: colors.onSurface),
                  items: const [
                    DropdownMenuItem(value: 'ซื้อ', child: Text('ซื้อ')),
                    DropdownMenuItem(value: 'จ้าง', child: Text('จ้าง')),
                  ],
                  onChanged: (v) => setState(() => p.orderType = v ?? 'ซื้อ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClearableTextField(
                    controller: p.procurementSubject,
                    style: _fieldStyle,
                    decoration: _dec('หัวเรื่อง')),
              ),
              DsActionIconButtons(
                actions: [
                  DsRowAction(
                      icon: Icons.delete_outline,
                      tooltip: 'ไม่นำเข้าโครงการนี้',
                      onTap: () => _removeAt(index),
                      danger: true),
                ],
              ),
            ],
          ),
          if (isDuplicate)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  '⚠ เลขที่เอกสารนี้มีอยู่แล้วในระบบ — ถ้าบันทึกจะได้เป็นโครงการซ้ำ',
                  style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: BrandAccent.red(context))),
            ),
          const SizedBox(height: 6),
          Text(
              'ไฟล์: ${p.fileName} • รวม ${p.totalPrice.toStringAsFixed(2)} บาท • ${p.items.length} รายการ',
              style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.onSurfaceVariant)),
          if (p.matchedBudget != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  '🔗 คาดว่าเป็นแผนงบ: ${p.matchedBudget!.projectName ?? ''} — กรุณาตรวจสอบในรายละเอียด',
                  style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: BrandAccent.teal(context))),
            ),
          TextButton(
            onPressed: () => setState(() => p.expanded = !p.expanded),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: Text(
                p.expanded
                    ? 'ซ่อนรายละเอียด ▲'
                    : 'แก้ไขรายละเอียด/รายการพัสดุ ▼',
                style: const TextStyle(fontSize: 13)),
          ),
          if (p.expanded) _buildProjectDetails(context, colors, p),
        ],
      ),
    );
  }

  Widget _buildProjectDetails(
      BuildContext context, ColorScheme colors, _EditableProject p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 20),
        DropdownButtonFormField<Budget?>(
          initialValue: p.matchedBudget,
          isDense: true,
          isExpanded: true,
          decoration: _dec(
              'จับคู่แผนงบประมาณ (ไม่บังคับ — ระบบเดาให้คร่าวๆ กรุณาตรวจสอบ)'),
          style: _fieldStyle.copyWith(color: colors.onSurface),
          items: [
            const DropdownMenuItem<Budget?>(
                value: null, child: Text('— ไม่ผูกกับแผนงบ —')),
            for (final b in widget.availableBudgets)
              DropdownMenuItem<Budget?>(
                value: b,
                child: Text(
                    '${b.fiscalYear} • ${b.projectName ?? ''}${(b.activityName ?? '').isEmpty ? '' : ' / ${b.activityName}'}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => p.matchedBudget = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.dateOrderCreated,
                  style: _fieldStyle,
                  decoration: _dec('วันที่'))),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: ClearableTextField(
                controller: p.fiscalYear,
                style: _fieldStyle,
                // ถ้าผูกแผนงบไว้แล้ว ปีงบจะยึดตามแผนงบเสมอตอนบันทึก (เหมือน
                // wizard) — ปิดช่องนี้ไม่ให้แก้ กันผู้ใช้พิมพ์แล้วค่าที่พิมพ์
                // หายไปเงียบๆ ตอนกดยืนยันโดยไม่รู้ตัวว่าทำไม
                enabled: p.matchedBudget == null,
                decoration: _dec(p.matchedBudget == null
                    ? 'ปีงบประมาณ'
                    : 'ปีงบประมาณ (ยึดตามแผนงบที่ผูกไว้)')),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.procurementMethod,
                  style: _fieldStyle,
                  decoration: _dec('วิธีจัดซื้อจัดจ้าง'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              flex: 2,
              child: ClearableTextField(
                  controller: p.vendorName,
                  style: _fieldStyle,
                  decoration: _dec('ชื่อร้าน/ผู้รับจ้าง'))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: ClearableTextField(
                  controller: p.vendorOwner,
                  style: _fieldStyle,
                  decoration: _dec('ชื่อเจ้าของร้าน'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorAddressNo,
                  style: _fieldStyle,
                  decoration: _dec('ที่อยู่ (เลขที่/หมู่)'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorSubdistrict,
                  style: _fieldStyle,
                  decoration: _dec('ตำบล'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorDistrict,
                  style: _fieldStyle,
                  decoration: _dec('อำเภอ'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorProvince,
                  style: _fieldStyle,
                  decoration: _dec('จังหวัด'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorPostalCode,
                  style: _fieldStyle,
                  decoration: _dec('รหัสไปรษณีย์'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorPhone,
                  style: _fieldStyle,
                  decoration: _dec('เบอร์โทร'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.vendorTaxId,
                  style: _fieldStyle,
                  decoration: _dec('เลขผู้เสียภาษี'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.inspector1,
                  style: _fieldStyle,
                  decoration: _dec('ผู้ตรวจรับพัสดุ'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.inspector1Pos,
                  style: _fieldStyle,
                  decoration: _dec('ตำแหน่ง'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.inspector2,
                  style: _fieldStyle,
                  decoration: _dec('ผู้ตรวจรับพัสดุ คนที่ 2'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.inspector2Pos,
                  style: _fieldStyle,
                  decoration: _dec('ตำแหน่ง'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.inspector3,
                  style: _fieldStyle,
                  decoration: _dec('ผู้ตรวจรับพัสดุ คนที่ 3'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.inspector3Pos,
                  style: _fieldStyle,
                  decoration: _dec('ตำแหน่ง'))),
        ]),
        const SizedBox(height: 12),
        Text('วันที่/เลขอ้างอิงอื่นๆ (ไม่บังคับ)',
            style: TextStyle(
                fontSize: AppTypography.bodyMedium,
                fontWeight: AppTypography.weightSemiBold,
                color: colors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.dateAnnouncement,
                  style: _fieldStyle,
                  decoration: _dec('วันที่ประกาศผู้ชนะ'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.dateQuotation,
                  style: _fieldStyle,
                  decoration: _dec('วันที่เสนอราคา'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.dateContractSigned,
                  style: _fieldStyle,
                  decoration: _dec('วันที่ลงนามสัญญา'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.dateDeadline,
                  style: _fieldStyle,
                  decoration: _dec('วันครบกำหนดส่งมอบ'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.dateShipping,
                  style: _fieldStyle,
                  decoration: _dec('วันที่ส่งมอบจริง'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.dateInspection,
                  style: _fieldStyle,
                  decoration: _dec('วันที่ตรวจรับ'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ClearableTextField(
                  controller: p.dateDisbursement,
                  style: _fieldStyle,
                  decoration: _dec('วันที่เบิกจ่ายเงิน'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.contractControlNumber,
                  style: _fieldStyle,
                  decoration: _dec('เลขคุมสัญญา'))),
          const SizedBox(width: 8),
          Expanded(
              child: ClearableTextField(
                  controller: p.egpProjectId,
                  style: _fieldStyle,
                  decoration: _dec('เลขที่โครงการ e-GP'))),
        ]),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('รายการพัสดุ',
                style: TextStyle(
                    fontSize: AppTypography.bodyMedium,
                    fontWeight: AppTypography.weightSemiBold,
                    color: colors.onSurfaceVariant)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => p.items = [
                    ...p.items,
                    _EditableItem(const ProcurementItem(
                        itemName: '', quantity: 1, unitPrice: 0))
                  ]),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('เพิ่มรายการ'),
            ),
          ],
        ),
        for (var i = 0; i < p.items.length; i++) _buildItemRow(p, i),
      ],
    );
  }

  Widget _buildItemRow(_EditableProject p, int i) {
    final item = p.items[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: ClearableTextField(
                  controller: item.name,
                  style: _fieldStyle,
                  decoration: _dec('ชื่อรายการ'))),
          const SizedBox(width: 6),
          SizedBox(
              width: 70,
              child: ClearableTextField(
                  controller: item.quantity,
                  style: _fieldStyle,
                  decoration: _dec('จำนวน'),
                  onChanged: (_) => setState(() {}))),
          const SizedBox(width: 6),
          SizedBox(
              width: 70,
              child: ClearableTextField(
                  controller: item.unit,
                  style: _fieldStyle,
                  decoration: _dec('หน่วย'))),
          const SizedBox(width: 6),
          SizedBox(
              width: 90,
              child: ClearableTextField(
                  controller: item.unitPrice,
                  style: _fieldStyle,
                  decoration: _dec('ราคา/หน่วย'),
                  onChanged: (_) => setState(() {}))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'ลบรายการนี้',
            onPressed: () => setState(() {
              item.dispose();
              p.items = [...p.items]..removeAt(i);
            }),
          ),
        ],
      ),
    );
  }
}
