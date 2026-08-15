// inspections_screen.dart
// ตรวจรับพัสดุ (blueprint หน้าที่ 7) — ผูกกับ procurement_orders เพื่อดึงชื่อ
// ผู้ส่งมอบและอัตราค่าปรับมาคำนวณค่าปรับโดยประมาณเมื่อส่งมอบล่าช้า
//
// [หมายเหตุสำคัญ]: ตัวเลขค่าปรับที่คำนวณให้เป็น "ค่าประมาณการ" เท่านั้น ไม่ใช่
// การรับรองความถูกต้องทางกฎหมาย ผู้ใช้ต้องตรวจสอบอัตราตามสัญญาจริงอีกครั้งก่อนใช้
// อ้างอิงในเอกสารราชการ — สอดคล้องกับหลักการที่ตกลงกันไว้ว่าแอปนี้ไม่ทำหน้าที่
// รับรองความถูกต้องทางกฎหมายให้

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/inspection.dart';
import '../models/procurement_order.dart';
import '../services/fiscal_year_controller.dart';
import '../services/procurement_document_generator.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../services/toast_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kpi_card.dart';
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant;
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

InputDecoration _dialogFieldDecoration(BuildContext context, {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: _dialogLabelStyle.copyWith(color: colors.onSurfaceVariant),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.3),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.3),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.6),
    ),
  );
}

const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String _formatThai(DateTime d) => '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';

DateTime? _parseThai(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final parts = text.trim().split(' ');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final monthIndex = _thaiMonths.indexOf(parts[1]);
  final buddhistYear = int.tryParse(parts[2]);
  if (day == null || monthIndex < 1 || buddhistYear == null) return null;
  return DateTime(buddhistYear - 543, monthIndex, day);
}

class InspectionsScreen extends StatefulWidget {
  const InspectionsScreen({super.key});
  @override
  State<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends State<InspectionsScreen> {
  final _repo = ProcurementRepository();
  List<Inspection> _inspections = [];
  Map<int, ProcurementOrder> _ordersById = {};
  bool _loading = true;
  int? _exportingId;

  @override
  void initState() {
    super.initState();
    _load();
    FiscalYearController.instance.addListener(_onFiscalYearChanged);
  }

  @override
  void dispose() {
    FiscalYearController.instance.removeListener(_onFiscalYearChanged);
    super.dispose();
  }

  void _onFiscalYearChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final inspections = await _repo.getAllInspections(fiscalYear: FiscalYearController.instance.viewingYear);
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    setState(() {
      _inspections = inspections;
      _ordersById = {for (final o in orders) if (o.id != null) o.id!: o};
      _loading = false;
    });
  }

  bool _isLate(Inspection i) {
    final due = _parseThai(i.dueDate);
    final actual = _parseThai(i.actualDeliveryDate);
    if (due == null || actual == null) return false;
    return actual.isAfter(due);
  }

  int get _pendingCount => _inspections.where((i) => i.result == null).length;
  int get _completedCount => _inspections.where((i) => i.result != null).length;
  int get _problemCount => _inspections.where((i) => i.result == 'ไม่ผ่าน' || _isLate(i)).length;

  Future<void> _openForm({Inspection? existing}) async {
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InspectionFormDialog(existing: existing, orders: orders),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Inspection i) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบรายการตรวจรับ "${i.inspectionNumber ?? "-"}" ใช่หรือไม่?', style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && i.id != null) {
      await _repo.deleteInspection(i.id!);
      _load();
    }
  }

  Future<void> _calculatePenalty(Inspection i) async {
    final due = _parseThai(i.dueDate);
    final actual = _parseThai(i.actualDeliveryDate);
    if (due == null || actual == null || !actual.isAfter(due)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('คำนวณค่าปรับไม่ได้', style: _dialogTitleStyle),
          content: const Text('ต้องมีวันที่ครบกำหนดและวันที่ส่งมอบจริง และวันที่ส่งมอบจริงต้องเกินกำหนดเท่านั้น', style: _dialogContentStyle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
      return;
    }
    final order = i.orderId != null ? _ordersById[i.orderId] : null;
    final daysLate = actual.difference(due).inDays;
    final baseAmount = order?.currentOrderPrice ?? order?.allocatedAmount ?? 0;
    final penaltyRate = order?.penaltyRate ?? 0.20;
    final estimated = baseAmount * (penaltyRate / 100) * daysLate;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ค่าปรับโดยประมาณ', style: _dialogTitleStyle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ล่าช้า $daysLate วัน', style: _dialogContentStyle),
            Text('วงเงิน ${formatBaht(baseAmount)} บาท × อัตราค่าปรับ $penaltyRate% ต่อวัน', style: _dialogContentStyle),
            const SizedBox(height: 8),
            Text('≈ ${formatBaht(estimated)} บาท',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'ตัวเลขนี้เป็นค่าประมาณการเท่านั้น โปรดตรวจสอบอัตราค่าปรับตามสัญญาจริงอีกครั้งก่อนใช้อ้างอิงในเอกสารราชการ',
              style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ปิด'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('บันทึกค่านี้'),
          ),
        ],
      ),
    );
    if (confirmed == true && i.id != null) {
      await _repo.updateInspection(Inspection(
        id: i.id,
        inspectionNumber: i.inspectionNumber,
        orderId: i.orderId,
        dueDate: i.dueDate,
        actualDeliveryDate: i.actualDeliveryDate,
        result: i.result,
        penaltyAmount: estimated,
        notes: i.notes,
      ));
      _load();
    }
  }

  Future<void> _exportDisbursementMemo(Inspection i) async {
    final order = i.orderId != null ? _ordersById[i.orderId] : null;
    if (order == null) {
      showAppToast('รายการตรวจรับนี้ไม่ได้ผูกกับรายการจัดซื้อจัดจ้าง จึงออกเอกสารไม่ได้', isError: true);
      return;
    }
    final school = await _repo.getSchoolSettings();
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    setState(() => _exportingId = i.id);
    try {
      final items = await _repo.getItems(order.id!);
      await ProcurementDocumentGenerator.generateAndOpen(
        type: ProcurementDocumentType.disbursementMemo,
        order: order,
        school: school,
        items: items,
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าตรวจรับพัสดุ',
      icon: Icons.fact_check_outlined,
      // การ์ดสรุปด้านบนกว้างเต็มจอ การ์ดขวาสุดโดนปุ่มไกด์มุมขวาบน (ค่า default)
      // บังตัวเลข ย้ายไปมุมซ้ายล่างแทน — มุมขวาล่างมีปุ่ม "เพิ่มรายการตรวจรับ" อยู่แล้ว
      corner: Alignment.bottomLeft,
      steps: const [
        'บันทึกผลการตรวจรับพัสดุ/งานจ้าง เทียบกับวันครบกำหนดส่งมอบตามสัญญา/ใบสั่งซื้อ',
        'ถ้าส่งมอบเกินกำหนด ระบบจะคำนวณ "ค่าปรับโดยประมาณ" ให้อัตโนมัติ — เป็นแค่ตัวเลขประมาณการเท่านั้น ให้ตรวจสอบอัตราค่าปรับที่แท้จริงจากสัญญาก่อนใช้ยืนยันทุกครั้ง',
        'เลือกประเภทเอกสารตรวจรับให้ตรงกับลักษณะงาน (พัสดุ/งานจ้าง/งานก่อสร้าง) และกรอกเลขที่เอกสารให้ครบ',
        'กด "เพิ่มรายการตรวจรับ" มุมขวาล่างเพื่อเริ่มบันทึกรายการใหม่',
      ],
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.fact_check_outlined, color: BrandAccent.tealOn(context), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('ตรวจรับพัสดุ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryCards(context, colors),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _inspections.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fact_check_outlined, size: 64, color: colors.onSurfaceVariant),
                                        const SizedBox(height: 12),
                                        Text('ยังไม่มีรายการตรวจรับ\nกด "เพิ่มรายการตรวจรับ" เพื่อเริ่มต้น',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _inspections.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _buildCard(context, colors, _inspections[i]),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'inspections_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มรายการตรวจรับ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'รอตรวจรับ',
            value: '$_pendingCount',
            unit: 'รายการ',
            icon: Icons.hourglass_empty_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'ตรวจรับเสร็จสิ้น',
            value: '$_completedCount',
            unit: 'รายการ',
            icon: Icons.check_circle_outline,
            variant: KpiCardVariant.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RedKpiCard(
            label: 'มีปัญหา/ล่าช้า',
            value: '$_problemCount',
            unit: 'รายการ',
            icon: Icons.error_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, Inspection i) {
    final order = i.orderId != null ? _ordersById[i.orderId] : null;
    final late = _isLate(i);
    final resultVariant = i.result == 'ผ่าน'
        ? BadgeVariant.success
        : (i.result == 'ไม่ผ่าน' ? BadgeVariant.danger : BadgeVariant.warning);
    final isExportingThis = _exportingId == i.id;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(existing: i),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      StatusBadge(label: i.result ?? 'รอตรวจรับ', variant: resultVariant, compact: true),
                      if (late) ...[
                        const SizedBox(width: 6),
                        StatusBadge(label: 'ส่งมอบล่าช้า', variant: BadgeVariant.danger, compact: true),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Text(i.inspectionNumber ?? '(ไม่มีเลขที่ตรวจรับ)',
                      style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.heading4, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (order != null) ...[
                      const SizedBox(height: 2),
                      Text('${order.projectName ?? order.procurementSubject ?? "-"} · ผู้ส่งมอบ: ${order.vendorName ?? "-"}',
                        style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 2),
                    Text('ครบกำหนด: ${i.dueDate ?? "-"}  ·  ส่งมอบจริง: ${i.actualDeliveryDate ?? "-"}',
                      style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                    if (i.penaltyAmount != null) ...[
                      const SizedBox(height: 2),
                      Text('ค่าปรับโดยประมาณ: ${formatBaht(i.penaltyAmount)} บาท',
                        style: TextStyle(fontSize: AppTypography.bodyMedium, color: BrandAccent.red(context), fontWeight: AppTypography.weightSemiBold)),
                    ],
                  ],
                ),
              ),
              if (late)
                TextButton(
                  onPressed: () => _calculatePenalty(i),
                  style: TextButton.styleFrom(textStyle: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightBold)),
                  child: const Text('คำนวณค่าปรับ'),
                ),
              const SizedBox(width: 4),
              // ตรวจรับพัสดุมีเอกสารที่เกี่ยวข้องแบบเดียว (บันทึกขออนุมัติ
              // เบิกจ่าย หลังตรวจรับผ่านแล้ว) จึงมีปุ่มเดียวทำหน้าที่ทั้งดู
              // ตัวอย่างและสร้างเอกสารในตัว ไม่แยก 2 ปุ่มให้สับสนเพราะเป็น
              // เอกสารใบเดียวกัน
              if (order != null && isExportingThis)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RadiusSize.sm),
                    border: Border.all(color: colors.outline),
                  ),
                  child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              DsActionIconButtons(
                actions: [
                  if (order != null && !isExportingThis)
                    DsRowAction(
                      icon: Icons.description_outlined,
                      tooltip: 'สร้าง/ดูเอกสารบันทึกขออนุมัติเบิกจ่าย',
                      onTap: () => _exportDisbursementMemo(i),
                    ),
                  DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(i), danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// การ์ด KPI โทนแดง — KpiCard ของดีไซน์ระบบไม่มี variant สีแดงในชุดโทเค็น จึง
/// ต้องสร้างเองแยกต่างหาก แต่ต้องเลียนแบบโครงสร้างจริงของ KpiCard ให้ครบ (แถบสี
/// บนสุด + ไอคอนในกล่องสี่เหลี่ยมมุมมน + ตัวเลขใหญ่) ไม่งั้นจะดูไม่เข้าชุดกับ
/// การ์ดข้างๆ ที่เป็น KpiCard จริง
class _RedKpiCard extends StatelessWidget {
  const _RedKpiCard({required this.label, required this.value, required this.unit, required this.icon});
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = BrandAccent.red(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(color: accent, boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 14)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: Dimensions.kpiIconSize,
                      height: Dimensions.kpiIconSize,
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(RadiusSize.md)),
                      child: Icon(icon, size: IconSizes.md, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                        style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(value,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppTypography.display1, fontWeight: AppTypography.weightExtraBold, letterSpacing: -1.1, height: 1, color: colors.onSurface)),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(unit, style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionFormDialog extends StatefulWidget {
  final Inspection? existing;
  final List<ProcurementOrder> orders;
  const _InspectionFormDialog({this.existing, required this.orders});
  @override
  State<_InspectionFormDialog> createState() => _InspectionFormDialogState();
}

class _InspectionFormDialogState extends State<_InspectionFormDialog> {
  final _repo = ProcurementRepository();
  late final TextEditingController _numberCtrl;
  int? _orderId;
  String? _dueDate;
  String? _actualDate;
  String? _result;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.existing;
    _numberCtrl = TextEditingController(text: i?.inspectionNumber ?? '');
    _orderId = i?.orderId;
    _dueDate = i?.dueDate;
    _actualDate = i?.actualDeliveryDate;
    _result = i?.result;
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDue}) async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
      helpText: isDue ? 'วันที่ครบกำหนด' : 'วันที่ส่งมอบจริง',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() {
      if (isDue) {
        _dueDate = _formatThai(picked);
      } else {
        _actualDate = _formatThai(picked);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final i = Inspection(
      id: widget.existing?.id,
      inspectionNumber: _numberCtrl.text.trim().isEmpty ? null : _numberCtrl.text.trim(),
      orderId: _orderId,
      dueDate: _dueDate,
      actualDeliveryDate: _actualDate,
      result: _result,
      penaltyAmount: widget.existing?.penaltyAmount,
    );
    if (widget.existing == null) {
      await _repo.insertInspection(i);
    } else {
      await _repo.updateInspection(i);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขรายการตรวจรับ' : 'เพิ่มรายการตรวจรับ', style: _dialogTitleStyle),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TextFormField(
                  controller: _numberCtrl,
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(context, label: 'เลขที่ตรวจรับ'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: DropdownButtonFormField<int?>(
                  initialValue: _orderId,
                  isExpanded: true,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _dialogFieldDecoration(context, label: 'รายการจัดซื้อจัดจ้าง'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('(ไม่ผูกกับเอกสาร)')),
                    ...widget.orders.where((o) => o.id != null).map((o) => DropdownMenuItem<int?>(
                          value: o.id,
                          child: Text(o.projectName ?? o.procurementSubject ?? 'เอกสาร #${o.id}', overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _orderId = v),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isDue: true),
                      borderRadius: BorderRadius.circular(RadiusSize.md),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: InputDecorator(
                          decoration: _dialogFieldDecoration(context, label: 'วันที่ครบกำหนด'),
                          child: Text(_dueDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isDue: false),
                      borderRadius: BorderRadius.circular(RadiusSize.md),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: InputDecorator(
                          decoration: _dialogFieldDecoration(context, label: 'วันที่ส่งมอบจริง'),
                          child: Text(_actualDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String?>(
                initialValue: _result,
                style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                decoration: _dialogFieldDecoration(context, label: 'ผลการตรวจรับ'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('รอตรวจรับ')),
                  DropdownMenuItem<String?>(value: 'ผ่าน', child: Text('ผ่าน')),
                  DropdownMenuItem<String?>(value: 'ไม่ผ่าน', child: Text('ไม่ผ่าน')),
                ],
                onChanged: (v) => setState(() => _result = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.primary, padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
