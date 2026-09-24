// order_quick_edit_dialog.dart
// แก้ไขโครงการที่มีอยู่แล้วแบบเร็ว — หน้าตา/ความหนาแน่นของฟอร์มเหมือนหน้า
// "ตรวจสอบโครงการที่นำเข้า" (procurement_import_dialog.dart) ที่ผู้ใช้ชอบ
// (ป๊อปอัพเดียว กรอกครบทุกฟิลด์สำคัญ ไม่ต้องไล่ทีละแท็บเหมือนหน้าสร้างใหม่เต็ม
// รูปแบบ) ใช้ตอนแค่อยากแก้เลขที่เอกสาร/วันที่/ผู้ขาย/ผู้ตรวจรับเร็วๆ จากหน้าหลัก
// โดยไม่ต้องเปิด wizard 5 แท็บ — ไม่แตะ budgetId/projectName/activityName/
// ผู้อำนวยการ/เจ้าหน้าที่พัสดุ ที่ผูกกับแผนงบ/ข้อมูลโรงเรียนไว้แล้วจาก wizard
// เต็มรูปแบบ (แก้เฉพาะฟิลด์ที่ผู้ใช้กรอกเองได้จริงในหน้านี้เท่านั้น)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import '../theme/design_tokens.dart';
import '../utils/calc_engine.dart';
import '../widgets/design_system/clearable_text_field.dart';

/// แสดง dialog แก้ไขด่วน — คืนค่า true ถ้าบันทึกสำเร็จ (ให้หน้าเรียกโหลดใหม่)
Future<bool?> showOrderQuickEditDialog(
  BuildContext context, {
  required ProcurementOrder order,
  required List<ProcurementItem> items,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => OrderQuickEditDialog(order: order, items: items),
  );
}

class OrderQuickEditDialog extends StatefulWidget {
  final ProcurementOrder order;
  final List<ProcurementItem> items;
  const OrderQuickEditDialog(
      {super.key, required this.order, required this.items});

  @override
  State<OrderQuickEditDialog> createState() => _OrderQuickEditDialogState();
}

class _EditableItemRow {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;

  _EditableItemRow(ProcurementItem i)
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

class _OrderQuickEditDialogState extends State<OrderQuickEditDialog> {
  final _repo = ProcurementRepository();
  bool _saving = false;

  late final TextEditingController _orderNumber;
  late String _orderType;
  late final TextEditingController _procurementSubject;
  late final TextEditingController _fiscalYear;
  late final TextEditingController _dateOrderCreated;
  late final TextEditingController _procurementMethod;
  late final TextEditingController _vendorName;
  late final TextEditingController _vendorOwner;
  late final TextEditingController _vendorAddressNo;
  late final TextEditingController _vendorSubdistrict;
  late final TextEditingController _vendorDistrict;
  late final TextEditingController _vendorProvince;
  late final TextEditingController _vendorPostalCode;
  late final TextEditingController _vendorPhone;
  late final TextEditingController _vendorTaxId;
  late final TextEditingController _inspector1;
  late final TextEditingController _inspector1Pos;
  late final TextEditingController _inspector2;
  late final TextEditingController _inspector2Pos;
  late final TextEditingController _inspector3;
  late final TextEditingController _inspector3Pos;
  late final TextEditingController _dateAnnouncement;
  late final TextEditingController _dateQuotation;
  late final TextEditingController _dateContractSigned;
  late final TextEditingController _dateDeadline;
  late final TextEditingController _dateShipping;
  late final TextEditingController _dateInspection;
  late final TextEditingController _dateDisbursement;
  late final TextEditingController _contractControlNumber;
  late final TextEditingController _egpProjectId;
  late List<_EditableItemRow> _items;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _orderNumber = TextEditingController(text: o.orderNumber ?? '');
    _orderType = o.orderType ?? 'ซื้อ';
    _procurementSubject =
        TextEditingController(text: o.procurementSubject ?? '');
    _fiscalYear = TextEditingController(text: o.fiscalYear ?? '');
    _dateOrderCreated = TextEditingController(text: o.dateOrderCreated ?? '');
    _procurementMethod =
        TextEditingController(text: o.procurementMethod ?? 'เฉพาะเจาะจง');
    _vendorName = TextEditingController(text: o.vendorName ?? '');
    _vendorOwner = TextEditingController(text: o.vendorOwner ?? '');
    _vendorAddressNo = TextEditingController(text: o.vendorAddressNo ?? '');
    _vendorSubdistrict = TextEditingController(text: o.vendorSubdistrict ?? '');
    _vendorDistrict = TextEditingController(text: o.vendorDistrict ?? '');
    _vendorProvince = TextEditingController(text: o.vendorProvince ?? '');
    _vendorPostalCode = TextEditingController(text: o.vendorPostalCode ?? '');
    _vendorPhone = TextEditingController(text: o.vendorPhone ?? '');
    _vendorTaxId = TextEditingController(text: o.vendorTaxId ?? '');
    _inspector1 = TextEditingController(text: o.inspector1 ?? '');
    _inspector1Pos = TextEditingController(text: o.inspector1Pos ?? '');
    _inspector2 = TextEditingController(text: o.inspector2 ?? '');
    _inspector2Pos = TextEditingController(text: o.inspector2Pos ?? '');
    _inspector3 = TextEditingController(text: o.inspector3 ?? '');
    _inspector3Pos = TextEditingController(text: o.inspector3Pos ?? '');
    _dateAnnouncement = TextEditingController(text: o.dateAnnouncement ?? '');
    _dateQuotation = TextEditingController(text: o.dateQuotation ?? '');
    _dateContractSigned =
        TextEditingController(text: o.dateContractSigned ?? '');
    _dateDeadline = TextEditingController(text: o.dateDeadline ?? '');
    _dateShipping = TextEditingController(text: o.dateShipping ?? '');
    _dateInspection = TextEditingController(text: o.dateInspection ?? '');
    _dateDisbursement = TextEditingController(text: o.dateDisbursement ?? '');
    _contractControlNumber =
        TextEditingController(text: o.contractControlNumber ?? '');
    _egpProjectId = TextEditingController(text: o.egpProjectId ?? '');
    _items = widget.items.map(_EditableItemRow.new).toList();
  }

  @override
  void dispose() {
    _orderNumber.dispose();
    _procurementSubject.dispose();
    _fiscalYear.dispose();
    _dateOrderCreated.dispose();
    _procurementMethod.dispose();
    _vendorName.dispose();
    _vendorOwner.dispose();
    _vendorAddressNo.dispose();
    _vendorSubdistrict.dispose();
    _vendorDistrict.dispose();
    _vendorProvince.dispose();
    _vendorPostalCode.dispose();
    _vendorPhone.dispose();
    _vendorTaxId.dispose();
    _inspector1.dispose();
    _inspector1Pos.dispose();
    _inspector2.dispose();
    _inspector2Pos.dispose();
    _inspector3.dispose();
    _inspector3Pos.dispose();
    _dateAnnouncement.dispose();
    _dateQuotation.dispose();
    _dateContractSigned.dispose();
    _dateDeadline.dispose();
    _dateShipping.dispose();
    _dateInspection.dispose();
    _dateDisbursement.dispose();
    _contractControlNumber.dispose();
    _egpProjectId.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  double get _totalPrice => _items.fold(
      0,
      (sum, i) =>
          sum +
          ((double.tryParse(i.quantity.text) ?? 0) *
              (double.tryParse(i.unitPrice.text) ?? 0)));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final o = widget.order;
      // คำนวณยอดเงิน/VAT ใหม่จากรายการพัสดุ (เผื่อแก้ไขรายการ/ราคาไป) โดยใช้
      // อัตรา VAT/หัก ณ ที่จ่ายเดิมของโครงการนี้ ไม่ hardcode ทับอัตราที่เคย
      // ตั้งไว้เฉพาะโครงการ
      final calc = CalcEngine.calcAllWithRates(_totalPrice,
          vatRate: o.vatRate, withholdingRate: o.withholdingTaxRate);
      final updated = o.copyWith(
        orderNumber:
            _orderNumber.text.trim().isEmpty ? null : _orderNumber.text.trim(),
        procurementNumber:
            _orderNumber.text.trim().isEmpty ? null : _orderNumber.text.trim(),
        orderType: _orderType,
        procurementSubject: _procurementSubject.text.trim().isEmpty
            ? null
            : _procurementSubject.text.trim(),
        fiscalYear:
            _fiscalYear.text.trim().isEmpty ? null : _fiscalYear.text.trim(),
        dateOrderCreated: _dateOrderCreated.text.trim().isEmpty
            ? null
            : _dateOrderCreated.text.trim(),
        procurementMethod: _procurementMethod.text.trim().isEmpty
            ? null
            : _procurementMethod.text.trim(),
        vendorName:
            _vendorName.text.trim().isEmpty ? null : _vendorName.text.trim(),
        vendorOwner:
            _vendorOwner.text.trim().isEmpty ? null : _vendorOwner.text.trim(),
        vendorAddressNo: _vendorAddressNo.text.trim().isEmpty
            ? null
            : _vendorAddressNo.text.trim(),
        vendorSubdistrict: _vendorSubdistrict.text.trim().isEmpty
            ? null
            : _vendorSubdistrict.text.trim(),
        vendorDistrict: _vendorDistrict.text.trim().isEmpty
            ? null
            : _vendorDistrict.text.trim(),
        vendorProvince: _vendorProvince.text.trim().isEmpty
            ? null
            : _vendorProvince.text.trim(),
        vendorPostalCode: _vendorPostalCode.text.trim().isEmpty
            ? null
            : _vendorPostalCode.text.trim(),
        vendorPhone:
            _vendorPhone.text.trim().isEmpty ? null : _vendorPhone.text.trim(),
        vendorTaxId:
            _vendorTaxId.text.trim().isEmpty ? null : _vendorTaxId.text.trim(),
        inspector1:
            _inspector1.text.trim().isEmpty ? null : _inspector1.text.trim(),
        inspector1Pos: _inspector1Pos.text.trim().isEmpty
            ? null
            : _inspector1Pos.text.trim(),
        inspector2:
            _inspector2.text.trim().isEmpty ? null : _inspector2.text.trim(),
        inspector2Pos: _inspector2Pos.text.trim().isEmpty
            ? null
            : _inspector2Pos.text.trim(),
        inspector3:
            _inspector3.text.trim().isEmpty ? null : _inspector3.text.trim(),
        inspector3Pos: _inspector3Pos.text.trim().isEmpty
            ? null
            : _inspector3Pos.text.trim(),
        dateAnnouncement: _dateAnnouncement.text.trim().isEmpty
            ? null
            : _dateAnnouncement.text.trim(),
        dateQuotation: _dateQuotation.text.trim().isEmpty
            ? null
            : _dateQuotation.text.trim(),
        dateContractSigned: _dateContractSigned.text.trim().isEmpty
            ? null
            : _dateContractSigned.text.trim(),
        dateDeadline: _dateDeadline.text.trim().isEmpty
            ? null
            : _dateDeadline.text.trim(),
        dateShipping: _dateShipping.text.trim().isEmpty
            ? null
            : _dateShipping.text.trim(),
        dateInspection: _dateInspection.text.trim().isEmpty
            ? null
            : _dateInspection.text.trim(),
        dateDisbursement: _dateDisbursement.text.trim().isEmpty
            ? null
            : _dateDisbursement.text.trim(),
        contractControlNumber: _contractControlNumber.text.trim().isEmpty
            ? null
            : _contractControlNumber.text.trim(),
        egpProjectId: _egpProjectId.text.trim().isEmpty
            ? null
            : _egpProjectId.text.trim(),
        currentOrderPrice: calc['current_order_price'],
        totalPriceTh: CalcEngine.bahtText(calc['current_order_price']!),
        subtotalBeforeVat: calc['subtotal_before_vat'],
        vatAmount: calc['vat_amount'],
        taxWithholdingAmount: calc['tax_withholding_amount'],
        netPayableAmount: calc['net_payable_amount'],
      );
      final resultItems = _items
          .map((i) => i.toItem())
          .where((i) => i.itemName.isNotEmpty)
          .toList();
      await _repo.saveOrderWithItems(updated, resultItems);
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                  Icon(Icons.bolt_outlined,
                      color: BrandAccent.teal(context), size: 24),
                  const SizedBox(width: 8),
                  const Text('แก้ไขโครงการด่วน',
                      style: TextStyle(
                          fontWeight: AppTypography.weightExtraBold,
                          fontSize: AppTypography.heading2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  'แก้ไขฟิลด์สำคัญได้เร็วๆ โดยไม่ต้องเปิดหน้าสร้าง/แก้ไขเต็มรูปแบบ — โครงการ/กิจกรรมที่ผูกกับแผนงบ และชื่อผู้อำนวยการ/เจ้าหน้าที่พัสดุ ไม่ได้แก้ที่นี่',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AppTypography.bodyMedium)),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 130,
                            child: ClearableTextField(
                                controller: _orderNumber,
                                style: _fieldStyle,
                                decoration: _dec('เลขที่เอกสาร')),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              initialValue: _orderType,
                              isDense: true,
                              isExpanded: true,
                              decoration: _dec('ประเภท'),
                              style:
                                  _fieldStyle.copyWith(color: colors.onSurface),
                              items: const [
                                DropdownMenuItem(
                                    value: 'ซื้อ', child: Text('ซื้อ')),
                                DropdownMenuItem(
                                    value: 'จ้าง', child: Text('จ้าง')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _orderType = v ?? 'ซื้อ'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClearableTextField(
                                controller: _procurementSubject,
                                style: _fieldStyle,
                                decoration: _dec('หัวเรื่อง')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateOrderCreated,
                                style: _fieldStyle,
                                decoration: _dec('วันที่'))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: ClearableTextField(
                              controller: _fiscalYear,
                              style: _fieldStyle,
                              decoration: _dec('ปีงบประมาณ')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _procurementMethod,
                                style: _fieldStyle,
                                decoration: _dec('วิธีจัดซื้อจัดจ้าง'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            flex: 2,
                            child: ClearableTextField(
                                controller: _vendorName,
                                style: _fieldStyle,
                                decoration: _dec('ชื่อร้าน/ผู้รับจ้าง'))),
                        const SizedBox(width: 8),
                        Expanded(
                            flex: 2,
                            child: ClearableTextField(
                                controller: _vendorOwner,
                                style: _fieldStyle,
                                decoration: _dec('ชื่อเจ้าของร้าน'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorAddressNo,
                                style: _fieldStyle,
                                decoration: _dec('ที่อยู่ (เลขที่/หมู่)'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorSubdistrict,
                                style: _fieldStyle,
                                decoration: _dec('ตำบล'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorDistrict,
                                style: _fieldStyle,
                                decoration: _dec('อำเภอ'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorProvince,
                                style: _fieldStyle,
                                decoration: _dec('จังหวัด'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorPostalCode,
                                style: _fieldStyle,
                                decoration: _dec('รหัสไปรษณีย์'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorPhone,
                                style: _fieldStyle,
                                decoration: _dec('เบอร์โทร'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _vendorTaxId,
                                style: _fieldStyle,
                                decoration: _dec('เลขผู้เสียภาษี'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _inspector1,
                                style: _fieldStyle,
                                decoration: _dec('ผู้ตรวจรับพัสดุ'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _inspector1Pos,
                                style: _fieldStyle,
                                decoration: _dec('ตำแหน่ง'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _inspector2,
                                style: _fieldStyle,
                                decoration: _dec('ผู้ตรวจรับพัสดุ คนที่ 2'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _inspector2Pos,
                                style: _fieldStyle,
                                decoration: _dec('ตำแหน่ง'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _inspector3,
                                style: _fieldStyle,
                                decoration: _dec('ผู้ตรวจรับพัสดุ คนที่ 3'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _inspector3Pos,
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
                                controller: _dateAnnouncement,
                                style: _fieldStyle,
                                decoration: _dec('วันที่ประกาศผู้ชนะ'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateQuotation,
                                style: _fieldStyle,
                                decoration: _dec('วันที่เสนอราคา'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateContractSigned,
                                style: _fieldStyle,
                                decoration: _dec('วันที่ลงนามสัญญา'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateDeadline,
                                style: _fieldStyle,
                                decoration: _dec('วันครบกำหนดส่งมอบ'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateShipping,
                                style: _fieldStyle,
                                decoration: _dec('วันที่ส่งมอบจริง'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateInspection,
                                style: _fieldStyle,
                                decoration: _dec('วันที่ตรวจรับ'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ClearableTextField(
                                controller: _dateDisbursement,
                                style: _fieldStyle,
                                decoration: _dec('วันที่เบิกจ่ายเงิน'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _contractControlNumber,
                                style: _fieldStyle,
                                decoration: _dec('เลขคุมสัญญา'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ClearableTextField(
                                controller: _egpProjectId,
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
                            onPressed: () => setState(() => _items = [
                                  ..._items,
                                  _EditableItemRow(const ProcurementItem(
                                      itemName: '', quantity: 1, unitPrice: 0)),
                                ]),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('เพิ่มรายการ'),
                          ),
                        ],
                      ),
                      for (var i = 0; i < _items.length; i++) _buildItemRow(i),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                        padding: _buttonPadding, textStyle: _buttonTextStyle),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
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

  Widget _buildItemRow(int i) {
    final item = _items[i];
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
              _items = [..._items]..removeAt(i);
            }),
          ),
        ],
      ),
    );
  }
}
