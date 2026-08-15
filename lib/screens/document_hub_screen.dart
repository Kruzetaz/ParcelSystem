// document_hub_screen.dart
// "สร้างเอกสารราชการ" — หน้ารวมศูนย์สำหรับออกเอกสาร Word ทั้งหมดของระบบไว้ที่
// เดียว แทนที่จะต้องไปกดปุ่ม export กระจายอยู่คนละหน้า (TOR/บริหารสัญญา/
// ตรวจรับพัสดุ) — เลือก "รายการอ้างอิง" ครั้งเดียวด้านบน แล้วเอกสารทุกใบด้านล่าง
// จะดึงข้อมูลจากรายการนั้นให้หมด

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../models/school_settings.dart';
import '../services/document_generator.dart';
import '../services/tor_document_generator.dart';
import '../services/procurement_document_generator.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';

class DocumentHubScreen extends StatefulWidget {
  // เปิดมาจากปุ่มลัด "สร้างเอกสาร" ที่การ์ดรายการใน Dashboard/ทะเบียน — ให้เลือก
  // รายการอ้างอิงไว้ให้ล่วงหน้า ไม่ต้องมาเลือกจาก dropdown ซ้ำ
  final int? initialOrderId;

  const DocumentHubScreen({super.key, this.initialOrderId});
  @override
  State<DocumentHubScreen> createState() => _DocumentHubScreenState();
}

/// เอกสารแต่ละใบที่ hub นี้ทำได้ — แยกจาก ProcurementDocumentType ของ service
/// เพราะรวม TOR/master ที่ใช้ generator คนละตัวเข้าไว้ในลิสต์เดียวกันด้วย
enum _DocKind { masterFull, tor, contractOrderReport, purchaseOrder, contractAnnouncement, quotation, requisition, deliveryNote, disbursementMemo }

class _DocCardInfo {
  final _DocKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  const _DocCardInfo({required this.kind, required this.title, required this.subtitle, required this.icon});
}

const _docCards = [
  _DocCardInfo(
    kind: _DocKind.masterFull,
    title: 'บันทึกขอใช้งบประมาณ (ชุดเต็ม)',
    subtitle: 'เอกสาร ซ. ฉบับเต็มตั้งแต่ขอใช้งบจนถึงเบิกจ่าย',
    icon: Icons.description_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.tor,
    title: 'TOR / ขอบเขตของงาน',
    subtitle: 'บันทึกแต่งตั้งผู้จัดทำ TOR + เอกสารสเปก',
    icon: Icons.assignment_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.contractOrderReport,
    title: 'รายงานขอซื้อ/ขอจ้าง',
    subtitle: 'พร้อมคำสั่งแต่งตั้งผู้ตรวจรับพัสดุ',
    icon: Icons.fact_check_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.purchaseOrder,
    title: 'ใบสั่งซื้อ/ใบสั่งจ้าง',
    subtitle: 'เอกสารสั่งซื้อ/จ้างจริงที่ส่งให้ร้านค้า',
    icon: Icons.shopping_cart_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.contractAnnouncement,
    title: 'ประกาศผู้ชนะการเสนอราคา',
    subtitle: 'รายงานผลการพิจารณา + ประกาศผู้ชนะ',
    icon: Icons.campaign_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.quotation,
    title: 'ใบเสนอราคา',
    subtitle: 'เอกสารฝั่งผู้ขาย/ผู้รับจ้าง',
    icon: Icons.receipt_long_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.requisition,
    title: 'ใบเบิกพัสดุ',
    subtitle: 'เบิกวัสดุ/ครุภัณฑ์จากคลังไปใช้งาน',
    icon: Icons.assignment_return_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.deliveryNote,
    title: 'ใบส่งมอบงาน',
    subtitle: 'แจ้งส่งมอบงานเพื่อขอเบิกจ่าย',
    icon: Icons.local_shipping_outlined,
  ),
  _DocCardInfo(
    kind: _DocKind.disbursementMemo,
    title: 'บันทึกขออนุมัติเบิกจ่าย',
    subtitle: 'หลังตรวจรับพัสดุแล้ว ขอเบิกจ่ายเงิน',
    icon: Icons.payments_outlined,
  ),
];

class _DocumentHubScreenState extends State<DocumentHubScreen> {
  final _repo = ProcurementRepository();
  List<ProcurementOrder> _orders = [];
  SchoolSettings? _school;
  ProcurementOrder? _selectedOrder;
  bool _loading = true;
  _DocKind? _generatingKind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repo.getAllOrders();
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    ProcurementOrder? initial = orders.isNotEmpty ? orders.first : null;
    if (widget.initialOrderId != null) {
      for (final o in orders) {
        if (o.id == widget.initialOrderId) {
          initial = o;
          break;
        }
      }
    }
    setState(() {
      _orders = orders;
      _school = school;
      _selectedOrder = initial;
      _loading = false;
    });
  }

  Future<void> _generate(_DocKind kind) async {
    final order = _selectedOrder;
    if (order == null) {
      showAppToast('กรุณาเลือกรายการอ้างอิงก่อน', isError: true);
      return;
    }
    final school = _school;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    setState(() => _generatingKind = kind);
    try {
      final items = await _repo.getItems(order.id!);
      switch (kind) {
        case _DocKind.masterFull:
          await DocumentGenerator.generateAndOpen(order: order, school: school, items: items);
        case _DocKind.tor:
          await TorDocumentGenerator.generateAndOpen(order: order, school: school, items: items);
        case _DocKind.contractOrderReport:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.contractOrderReport, order: order, school: school, items: items);
        case _DocKind.purchaseOrder:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.purchaseOrder, order: order, school: school, items: items);
        case _DocKind.contractAnnouncement:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.contractAnnouncement, order: order, school: school, items: items);
        case _DocKind.quotation:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.quotation, order: order, school: school, items: items);
        case _DocKind.requisition:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.requisition, order: order, school: school, items: items);
        case _DocKind.deliveryNote:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.deliveryNote, order: order, school: school, items: items);
        case _DocKind.disbursementMemo:
          await ProcurementDocumentGenerator.generateAndOpen(
              type: ProcurementDocumentType.disbursementMemo, order: order, school: school, items: items);
      }
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingKind = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return GuideFabOverlay(
      title: 'วิธีใช้หน้าสร้างเอกสารราชการ',
      icon: Icons.description_outlined,
      steps: const [
        'เลือก "รายการอ้างอิง" (คำสั่งซื้อ/สั่งจ้าง) จากช่องด้านบนก่อนครั้งเดียว — เอกสารทุกใบด้านล่างจะดึงข้อมูลจากรายการนั้นให้อัตโนมัติ',
        'เอกสารครบชุด (คำสั่งซื้อ+ผู้ตรวจรับ) ใช้ตอนอนุมัติจัดซื้อ, ประกาศผู้ชนะ ใช้ตอนประกาศผลผู้ขาย',
        '"ใบสั่งซื้อ/ใบสั่งจ้าง" คือเอกสารสั่งซื้อจริงที่ส่งให้ร้านค้า — คนละใบกับ "รายงานขอซื้อ/ขอจ้าง" ที่เป็นบันทึกขออนุมัติภายในโรงเรียนเท่านั้น',
        'ใบเสนอราคา/ใบส่งมอบงาน ให้ผู้ขายเซ็นตอนส่งของ, บันทึกขออนุมัติเบิกจ่าย ใช้ตอนจ่ายเงินจริง',
        'TOR/ข้อบเขตของงาน ใช้ตอนกำหนดสเปกก่อนเริ่มจัดซื้อ — ถ้ายังไม่มี TOR ของรายการนี้ ให้ไปสร้างที่หน้า "TOR/คุณลักษณะ" ก่อน',
        'กดที่การ์ดเอกสารที่ต้องการ ระบบจะสร้างไฟล์ .docx แล้วเปิดด้วยโปรแกรม Word ให้อัตโนมัติ',
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.description_outlined, color: BrandAccent.tealOn(context), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('สร้างเอกสารราชการ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'เลือกรายการจัดซื้อจัดจ้างที่ต้องการอ้างอิงครั้งเดียว แล้วออกเอกสารที่ต้องการด้านล่างได้เลย',
                style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _buildOrderPicker(context, colors),
              const SizedBox(height: 20),
              Expanded(
                child: _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_copy_outlined, size: 64, color: colors.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'ยังไม่มีรายการจัดซื้อจัดจ้างในระบบ\nไปสร้างรายการก่อนที่หน้า "สร้างใหม่" หรือ "Easy Wizard"',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisExtent: 170,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _docCards.length,
                        itemBuilder: (_, i) => _buildDocCard(context, colors, _docCards[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildOrderPicker(BuildContext context, ColorScheme colors) {
    return DropdownButtonFormField<ProcurementOrder?>(
      initialValue: _selectedOrder,
      isExpanded: true,
      style: TextStyle(fontSize: AppTypography.body, color: colors.onSurface),
      decoration: InputDecoration(
        labelText: 'รายการจัดซื้อจัดจ้างที่อ้างอิง',
        labelStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
        isDense: true,
        prefixIcon: const Icon(Icons.link),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
        ),
      ),
      borderRadius: BorderRadius.circular(RadiusSize.md),
      items: _orders
          .map((o) => DropdownMenuItem<ProcurementOrder?>(
                value: o,
                child: Text(
                  '${o.procurementNumber ?? "(ไม่มีเลขที่)"} — ${o.projectName ?? o.procurementSubject ?? "เอกสาร #${o.id}"}',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedOrder = v),
    );
  }

  Widget _buildDocCard(BuildContext context, ColorScheme colors, _DocCardInfo info) {
    final isGenerating = _generatingKind == info.kind;
    final ready = _selectedOrder != null && _school != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, size: 20, color: BrandAccent.tealOn(context)),
              const Spacer(),
              Icon(Icons.circle, size: 9, color: ready ? BrandAccent.green(context) : colors.outlineVariant),
            ],
          ),
          const SizedBox(height: 6),
          // ใช้ SizedBox กำหนดความสูงตรงๆ แทน Expanded — กันปัญหาตัวอักษรไทย
          // (สระบน/ล่าง) ถูกตัดครึ่งเวลาพื้นที่เหลือถูกบีบจนเกือบเป็น 0
          // (Expanded คำนวณพื้นที่เหลือหลังหักส่วนอื่นแล้ว ถ้า title ยาว 2 บรรทัด
          // จะเหลือพื้นที่ให้ subtitle น้อยมากจนวาดสระซ้อนกันเป็นภาพเพี้ยน)
          SizedBox(
            height: 36,
            child: Text(info.title,
              style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body, height: 1.25, color: colors.onSurface),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 28,
            child: Text(info.subtitle,
              style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant, height: 1.25),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (_generatingKind != null) ? null : () => _generate(info.kind),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: colors.outline),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              child: isGenerating
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                  : const Text('สร้างเอกสาร →'),
            ),
          ),
        ],
      ),
    );
  }
}
