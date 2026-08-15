// installment_contracts_screen.dart
// หน้าจัดการ "สัญญาต่อเนื่องหลายเดือน" แยกต่างหากจาก wizard หลัก — เช่น
// จ้างเหมาประกอบอาหารกลางวัน, เช่าอินเทอร์เน็ตรายเดือน ที่ต้องสร้างชุด
// เอกสาร (ใบส่งมอบงาน/ใบตรวจรับพัสดุ/บันทึกขออนุมัติเบิกจ่าย/ใบสำคัญรับเงิน)
// แยกทุกงวด — แยกออกมาจาก order wizard เดิม (เคยเป็น Tab 6) เพราะ 95% ของ
// การใช้งานเป็นการซื้อ/จ้างครั้งเดียวจบ ไม่เกี่ยวกับงวดเลย ใส่ไว้ใน wizard
// จะทำให้สับสน — สัญญาต่อเนื่องยังคงสร้าง "โครงการฐาน" ผ่าน wizard ปกติก่อน
// (ข้อมูลผู้ขาย/คณะกรรมการ/รายการพัสดุเหมือนกันทุกประเภท) แล้วมาเริ่มติดตาม
// งวดที่นี่แทน

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/procurement_installment.dart';
import '../models/school_settings.dart';
import '../services/procurement_document_generator.dart';
import '../services/toast_service.dart';
import '../utils/calc_engine.dart';
import '../utils/money_format.dart';
import '../widgets/thai_date_picker.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kpi_card.dart';
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant;

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

InputDecoration _dialogFieldDecoration(BuildContext context, {required String label, String? hint, Widget? suffixIcon}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
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

class InstallmentContractsScreen extends StatefulWidget {
  const InstallmentContractsScreen({super.key});

  @override
  State<InstallmentContractsScreen> createState() => _InstallmentContractsScreenState();
}

class _InstallmentContractsScreenState extends State<InstallmentContractsScreen> {
  final _repo = ProcurementRepository();
  List<ProcurementOrder> _orders = [];
  Map<int, List<ProcurementInstallment>> _installmentsByOrder = {};
  bool _loading = true;
  int? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repo.getRecurringContractOrders();
    final byOrder = <int, List<ProcurementInstallment>>{};
    for (final o in orders) {
      if (o.id != null) byOrder[o.id!] = await _repo.getInstallments(o.id!);
    }
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _installmentsByOrder = byOrder;
      _loading = false;
    });
  }

  // ทางเข้าสำรอง สำหรับโครงการเก่าที่สร้างไว้ก่อนมีสวิตช์ "สัญญาต่อเนื่อง"
  // ใน Tab 1 — ปกติแนะนำให้เปิดสวิตช์ตอนสร้าง/แก้โครงการแทน
  Future<void> _pickOrderToTrack() async {
    final allOrders = await _repo.getAllOrders();
    if (!mounted) return;
    final trackedIds = _orders.map((o) => o.id).toSet();
    final candidates = allOrders.where((o) => !trackedIds.contains(o.id)).toList();

    final picked = await showDialog<ProcurementOrder>(
      context: context,
      builder: (_) => _OrderPickerDialog(orders: candidates),
    );
    if (picked?.id == null) return;
    await _repo.setRecurringContractFlag(picked!.id!, true);
    setState(() => _selectedOrderId = picked.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedOrderId != null) {
      return _InstallmentDetailPage(
        orderId: _selectedOrderId!,
        repo: _repo,
        onBack: () {
          setState(() => _selectedOrderId = null);
          _load();
        },
      );
    }

    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าสัญญาต่อเนื่องหลายงวด',
      icon: Icons.event_repeat_outlined,
      steps: const [
        'ใช้หน้านี้ติดตามสัญญาแบบต่อเนื่องหลายเดือน เช่น จ้างเหมาประกอบอาหารกลางวัน, จ้างครู/บุคลากรรายเดือน, เช่าอินเทอร์เน็ตรายเดือน, จ้างทำความสะอาด/รปภ.',
        'ต้องสร้างโครงการหลักผ่าน "สร้างใหม่" ตามปกติก่อน (กรอกผู้ขาย/คณะกรรมการ/รายการ) แล้วกด "เพิ่มสัญญาต่อเนื่อง" มุมขวาบนเพื่อเริ่มติดตามงวด',
        'กดที่การ์ดสัญญาเพื่อเปิดดูรายละเอียดงวดงาน/งวดเงิน แล้วเพิ่ม แก้ไข หรือสร้างเอกสารของแต่ละงวดได้จากในนั้น',
        'ในหน้ารายละเอียด ปุ่ม "สร้างงวดอัตโนมัติ" ช่วยสร้างงวดว่างล่วงหน้าได้ทีเดียวหลายงวด แล้วค่อยกรอกวันที่/จำนวนเงินทีหลังตามที่เกิดขึ้นจริง',
      ],
      // ปุ่ม "?" ค่าเริ่มต้นอยู่มุมบนขวา ซึ่งชนกับปุ่ม "เพิ่มสัญญาต่อเนื่อง" ที่
      // อยู่หัวหน้าเช่นกัน — ย้ายลงมุมล่างขวาแทน ตามแพทเทิร์นเดียวกับหน้าอื่นๆ
      // ที่มีปุ่มเพิ่มรายการอยู่หัวหน้า (control_log, order_register, ฯลฯ)
      corner: Alignment.bottomRight,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_repeat_outlined, color: BrandAccent.tealOn(context), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'สัญญาต่อเนื่องหลายงวด',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _pickOrderToTrack,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('เพิ่มสัญญาต่อเนื่อง'),
                      ),
                    ],
                  ),
                  if (_orders.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildKpiSection(context),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BrandAccent.teal(context).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(RadiusSize.card),
                      border: Border.all(color: BrandAccent.teal(context).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: BrandAccent.tealOn(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'สำหรับสัญญาแบบต่อเนื่องหลายเดือน (เช่น จ้างเหมาประกอบอาหารกลางวัน, '
                            'จ้างครู/บุคลากรรายเดือน, เช่าอินเทอร์เน็ตรายเดือน, จ้างทำความสะอาด/รปภ.) '
                            'ที่ต้องสร้างเอกสารส่งมอบงาน/ตรวจรับ/เบิกจ่าย แยกทุกเดือน — สร้างโครงการหลัก'
                            'ผ่าน "สร้างใหม่" ตามปกติก่อน (กรอกผู้ขาย/คณะกรรมการ/รายการ) แล้วกด '
                            '"เพิ่มสัญญาต่อเนื่อง" ที่นี่เพื่อเริ่มติดตามงวด',
                            style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ใช้ Expanded+ListView (แทน SingleChildScrollView ห่อทั้งหน้า)
                  // ให้ Column เต็มความสูงจริงเสมอ ไม่ว่าจำนวนสัญญาจะน้อยแค่ไหน
                  // — กันเนื้อหาลอยกลางจอเมื่อมีสัญญาแค่ 1-2 รายการ
                  Expanded(
                    child: _orders.isEmpty
                        ? _buildEmptyState(colors)
                        : ListView.separated(
                            itemCount: _orders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _buildContractCard(context, colors, _orders[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  /// นับจำนวนงวดที่จ่ายแล้ว/ทั้งหมดของโครงการหนึ่ง — ใช้ร่วมกันทั้งการ์ด
  /// สัญญารายตัวและสรุป KPI รวมด้านบน กันคำนวณซ้ำสองที่
  (int paid, int total) _installmentStats(ProcurementOrder o) {
    final installments = o.id != null ? (_installmentsByOrder[o.id] ?? []) : <ProcurementInstallment>[];
    final paid = installments.where((i) => (i.dateDisbursement ?? '').trim().isNotEmpty).length;
    return (paid, installments.length);
  }

  /// งวดถัดไปที่ยังไม่เบิกจ่าย (เรียงตามงวดที่) — ใช้โชว์บนการ์ดให้เห็นทันที
  /// ว่าสัญญาไหนใกล้ครบกำหนด โดยไม่ต้องกดเข้าไปดูรายละเอียดทีละใบ
  ProcurementInstallment? _nextDueInstallment(ProcurementOrder o) {
    final installments = o.id != null ? (_installmentsByOrder[o.id] ?? []) : <ProcurementInstallment>[];
    final pending = installments.where((i) => (i.dateDisbursement ?? '').trim().isEmpty).toList()
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    return pending.isEmpty ? null : pending.first;
  }

  // สรุปภาพรวมด้วย KpiCard ชุดเดียวกับหน้าหลัก — ให้เห็นสถานะสัญญาทั้งหมดใน
  // มุมเดียวก่อนไล่ดูทีละใบ
  Widget _buildKpiSection(BuildContext context) {
    var completed = 0;
    var totalValue = 0.0;
    for (final o in _orders) {
      final (paid, total) = _installmentStats(o);
      if (total > 0 && paid == total) completed++;
      totalValue += o.currentOrderPrice ?? 0;
    }
    final inProgress = _orders.length - completed;

    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'สัญญาที่ติดตามอยู่',
            value: '${_orders.length}',
            unit: 'สัญญา',
            icon: Icons.event_repeat_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'จ่ายครบทุกงวดแล้ว',
            value: '$completed',
            unit: 'สัญญา',
            icon: Icons.check_circle_outline,
            variant: KpiCardVariant.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'กำลังดำเนินการ',
            value: '$inProgress',
            unit: 'สัญญา',
            icon: Icons.hourglass_bottom_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'มูลค่ารวมตามสัญญา',
            value: formatBaht(totalValue),
            unit: 'บาท',
            icon: Icons.payments_outlined,
            variant: KpiCardVariant.teal,
          ),
        ),
      ],
    );
  }

  /// สถานะว่างเปล่า — ไอคอนใหญ่ + ข้อความเป็นมิตร แทนกล่องขอบบางๆ ข้อความ
  /// ล้วนแบบเดิม ให้ความรู้สึก "ยังไม่เคยเริ่ม" มากกว่า "เกิดข้อผิดพลาด"
  Widget _buildEmptyState(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Icon(Icons.event_repeat_outlined, size: 40, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'ยังไม่มีสัญญาต่อเนื่องที่ติดตามอยู่',
            style: TextStyle(fontSize: AppTypography.heading4, fontWeight: AppTypography.weightSemiBold, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'กด "เพิ่มสัญญาต่อเนื่อง" มุมขวาบนเพื่อเริ่มติดตามงวดของโครงการที่มีอยู่แล้ว',
            style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  /// เดาไอคอนให้เข้ากับประเภทงานจากชื่อโครงการ/หัวข้อจัดซื้อ — หน้านี้ไม่ได้
  /// ใช้แค่จ้างเหมาอาหารกลางวันอย่างเดียว (เดิมใช้ไอคอนช้อนส้อมตายตัวทุก
  /// โครงการ) ยังใช้ติดตามสัญญาต่อเนื่องแบบอื่นได้ด้วย เช่น จ้างครู/บุคลากร,
  /// เช่าเน็ตรายเดือน, จ้างทำความสะอาด/รปภ. — เดาจากคำสำคัญในชื่อโครงการ ถ้า
  /// ไม่เข้าเงื่อนไขไหนเลยค่อย fallback ไปไอคอนสัญญาต่อเนื่องทั่วไป
  static IconData _iconForContract(ProcurementOrder o) {
    final text = '${o.projectName ?? ''} ${o.procurementSubject ?? ''}';
    bool has(List<String> keywords) => keywords.any(text.contains);

    if (has(['อาหาร', 'โภชนาการ', 'ประกอบอาหาร'])) return Icons.restaurant_outlined;
    if (has(['ครู', 'บุคลากร', 'พี่เลี้ยง', 'นักการ', 'ภารโรง', 'จ้างเหมาบริการบุคคล'])) {
      return Icons.badge_outlined;
    }
    if (has(['อินเทอร์เน็ต', 'อินเตอร์เน็ต', 'เน็ต', 'สัญญาณ'])) return Icons.wifi_outlined;
    if (has(['ทำความสะอาด'])) return Icons.cleaning_services_outlined;
    if (has(['รักษาความปลอดภัย', 'รปภ.', 'ยาม'])) return Icons.security_outlined;
    return Icons.event_repeat_outlined;
  }

  // สไตล์การ์ดเดียวกับหน้าหลัก (Dashboard) — badge สถานะ, แถบความคืบหน้า,
  // ยอดเงิน, ปุ่มลัด — ให้หน้าตาคุ้นเคยกันทั้งระบบ ต่างกันแค่แถบความคืบหน้า
  // ที่นี่นับ "จำนวนงวดที่จ่ายแล้ว/ทั้งหมด" แทนความคืบหน้าเอกสารทั่วไป
  Widget _buildContractCard(BuildContext context, ColorScheme colors, ProcurementOrder o) {
    final (paidCount, totalCount) = _installmentStats(o);
    final progress = totalCount == 0 ? 0.0 : paidCount / totalCount;
    final isCompleted = totalCount > 0 && paidCount == totalCount;
    final statusVariant = isCompleted ? BadgeVariant.success : BadgeVariant.warning;
    final progressColor = isCompleted ? BrandAccent.green(context) : BrandAccent.tertiary(context);
    final statusLabel = totalCount == 0
        ? 'ยังไม่มีงวด'
        : isCompleted
            ? 'จ่ายครบทุกงวดแล้ว'
            : 'กำลังดำเนินการ';
    final nextDue = isCompleted ? null : _nextDueInstallment(o);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusSize.card),
          onTap: () => setState(() => _selectedOrderId = o.id),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: BrandAccent.teal(context),
                      child: Icon(_iconForContract(o), color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.projectName?.trim().isNotEmpty == true
                                ? o.projectName!
                                : (o.procurementSubject ?? '(ไม่มีชื่อโครงการ)'),
                            style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.heading4, color: colors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (o.vendorName?.isNotEmpty == true) o.vendorName,
                              '$totalCount งวด',
                            ].join('  •  '),
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '${formatBaht(o.currentOrderPrice)} บาท',
                        style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodyMedium, color: BrandAccent.tealOn(context)),
                      ),
                    ),
                    StatusBadge(label: statusLabel, variant: statusVariant, compact: true),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: colors.outlineVariant,
                          color: progressColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '$paidCount/$totalCount งวด',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightSemiBold, color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                if (nextDue != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 14, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (nextDue.dateDelivery ?? '').trim().isNotEmpty
                              ? 'งวดถัดไป: งวดที่ ${nextDue.periodNo} • กำหนด ${nextDue.dateDelivery}'
                              : nextDue.periodLabel?.trim().isNotEmpty == true
                                  ? 'งวดถัดไป: งวดที่ ${nextDue.periodNo} (${nextDue.periodLabel})'
                                  : 'งวดถัดไป: งวดที่ ${nextDue.periodNo} • ยังไม่ระบุวันที่',
                          style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightSemiBold, color: colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderPickerDialog extends StatefulWidget {
  final List<ProcurementOrder> orders;
  const _OrderPickerDialog({required this.orders});

  @override
  State<_OrderPickerDialog> createState() => _OrderPickerDialogState();
}

class _OrderPickerDialogState extends State<_OrderPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.orders.where((o) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return (o.projectName ?? '').toLowerCase().contains(q) ||
          (o.procurementSubject ?? '').toLowerCase().contains(q) ||
          (o.vendorName ?? '').toLowerCase().contains(q);
    }).toList();

    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('เลือกโครงการที่จะเริ่มติดตามงวด', style: _dialogTitleStyle),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              style: _dialogFieldStyle,
              decoration: _dialogFieldDecoration(context, label: 'ค้นหาชื่อโครงการ/ผู้ขาย', suffixIcon: const Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'ไม่พบโครงการ — สร้างโครงการหลักผ่าน "สร้างใหม่" ก่อน\n'
                        '(โครงการที่ติดตามงวดอยู่แล้วจะไม่แสดงซ้ำในนี้)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AppTypography.body, color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final o = filtered[i];
                        return ListTile(
                          title: Text(o.projectName?.trim().isNotEmpty == true
                              ? o.projectName!
                              : (o.procurementSubject ?? 'ไม่ระบุชื่อโครงการ'),
                            style: TextStyle(fontSize: AppTypography.body, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface)),
                          subtitle: Text(o.vendorName ?? 'ไม่ระบุผู้ขาย/ผู้รับจ้าง', style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
                          onTap: () => Navigator.pop(context, o),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// รายละเอียดสัญญา + งวดการเบิกจ่าย
// ═══════════════════════════════════════════════════════════════════════

class _InstallmentDetailPage extends StatefulWidget {
  final int orderId;
  final ProcurementRepository repo;
  final VoidCallback onBack;

  const _InstallmentDetailPage({
    required this.orderId,
    required this.repo,
    required this.onBack,
  });

  @override
  State<_InstallmentDetailPage> createState() => _InstallmentDetailPageState();
}

class _InstallmentDetailPageState extends State<_InstallmentDetailPage> {
  ProcurementOrder? _order;
  List<ProcurementItem> _items = [];
  List<ProcurementInstallment> _installments = [];
  bool _loading = true;
  int? _generatingId;
  bool _generatingCombined = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final order = await widget.repo.getOrder(widget.orderId);
    final items = await widget.repo.getItems(widget.orderId);
    final installments = await widget.repo.getInstallments(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _items = items;
      _installments = installments;
      _loading = false;
    });
  }

  // สร้างงวดว่างล่วงหน้าทีเดียวหลายงวด (เช่น อาหารกลางวัน มักใช้ 10 งวด/
  // 100 วัน) — เว้นวันที่/จำนวนเงินว่างไว้ให้กรอกทีหลังตามที่เกิดขึ้นจริง
  // แต่ละงวด (ตามแบบฟอร์มจริงที่โรงเรียนใช้ ซึ่งไม่ได้หารเงินเท่ากันทุกงวด)
  Future<void> _generateAutoPeriods() async {
    final countText = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '10');
        return AlertDialog(
          title: const Text('สร้างงวดอัตโนมัติ', style: _dialogTitleStyle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('จำนวนงวดทั้งหมด (ทั่วไปอาหารกลางวัน 1 ภาคเรียน = 10 งวด/100 วัน)', style: _dialogContentStyle),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                style: _dialogFieldStyle,
                keyboardType: TextInputType.number,
                decoration: _dialogFieldDecoration(ctx, label: 'จำนวนงวด'),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: const Text('สร้าง'),
            ),
          ],
        );
      },
    );
    if (countText == null || countText <= 0) return;

    final existingNos = _installments.map((i) => i.periodNo).toSet();
    var nextNo = _installments.isEmpty
        ? 1
        : _installments.map((i) => i.periodNo).reduce((a, b) => a > b ? a : b) + 1;
    var created = 0;
    for (var n = 0; n < countText; n++) {
      while (existingNos.contains(nextNo)) {
        nextNo++;
      }
      await widget.repo.saveInstallment(ProcurementInstallment(orderId: widget.orderId, periodNo: nextNo));
      existingNos.add(nextNo);
      created++;
      nextNo++;
    }
    if (!mounted) return;
    showAppToast('สร้างงวดว่างเพิ่ม $created งวดแล้ว — กรอกวันที่/จำนวนเงินทีหลังตามจริงได้เลย');
    await _load();
  }

  Future<void> _generateCombinedFile() async {
    if (_order == null) return;
    setState(() => _generatingCombined = true);
    try {
      final school = await widget.repo.getSchoolSettings();
      await ProcurementDocumentGenerator.generateCombinedRecurringContractFileAndOpen(
        order: _order!,
        school: school ?? const SchoolSettings(),
        items: _items,
        installments: _installments,
      );
      if (!mounted) return;
      showAppToast('รวมเอกสารเป็นไฟล์เดียวสำเร็จ กำลังเปิดไฟล์...');
    } catch (e) {
      if (!mounted) return;
      showAppToast('รวมเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingCombined = false);
    }
  }

  Future<void> _openEditor({ProcurementInstallment? existing}) async {
    final saved = await showDialog<ProcurementInstallment>(
      context: context,
      builder: (_) => _InstallmentEditorDialog(
        orderId: widget.orderId,
        nextPeriodNo: existing?.periodNo ??
            (_installments.isEmpty
                ? 1
                : _installments.map((i) => i.periodNo).reduce((a, b) => a > b ? a : b) + 1),
        existing: existing,
      ),
    );
    if (saved == null) return;
    await widget.repo.saveInstallment(saved);
    await _load();
  }

  Future<void> _delete(ProcurementInstallment installment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ลบงวดที่ ${installment.periodNo} (${installment.periodLabel ?? "-"}) ใช่หรือไม่?', style: _dialogContentStyle),
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
    if (confirmed != true || installment.id == null) return;
    await widget.repo.deleteInstallment(installment.id!);
    await _load();
  }

  Future<void> _generate(ProcurementInstallment installment, ProcurementDocumentType type) async {
    if (_order == null) return;
    setState(() => _generatingId = installment.id);
    try {
      final school = await widget.repo.getSchoolSettings();
      await ProcurementDocumentGenerator.generateAndOpen(
        type: type,
        order: _order!,
        school: school ?? const SchoolSettings(),
        items: _items,
        overrideFields: ProcurementDocumentGenerator.buildInstallmentOverrides(_order!, installment),
        extraConditionalFlags: ProcurementDocumentGenerator.buildInstallmentConditionalFlags(installment),
        outputSuffix: '_งวด${installment.periodNo}',
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารสำเร็จ กำลังเปิดไฟล์...');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingId = null);
    }
  }

  Future<void> _generateAllFour(ProcurementInstallment installment) async {
    if (_order == null) return;
    setState(() => _generatingId = installment.id);
    try {
      final school = await widget.repo.getSchoolSettings();
      await ProcurementDocumentGenerator.generateInstallmentDocumentSetFileAndOpen(
        order: _order!,
        school: school ?? const SchoolSettings(),
        items: _items,
        installment: installment,
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารชุดงวด ${installment.periodNo} เป็นไฟล์เดียวแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingId = null);
    }
  }

  Widget _headerActionButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required ColorScheme colors,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      icon: icon,
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final order = _order;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  side: BorderSide(color: colors.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.event_repeat_outlined, color: BrandAccent.tealOn(context), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order?.projectName?.trim().isNotEmpty == true ? order!.projectName! : 'สัญญาต่อเนื่อง',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface),
                ),
              ),
              const SizedBox(width: 12),
              _headerActionButton(
                onPressed: _generateAutoPeriods,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: 'สร้างงวดอัตโนมัติ',
                colors: colors,
              ),
              const SizedBox(width: 8),
              _headerActionButton(
                onPressed: (_installments.isEmpty || _generatingCombined) ? null : _generateCombinedFile,
                icon: _generatingCombined
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurfaceVariant))
                    : const Icon(Icons.merge_type, size: 18),
                label: 'รวมเอกสารเป็นไฟล์เดียว',
                colors: colors,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                  textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มงวด'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : order == null
                    ? const Center(child: Text('ไม่พบโครงการนี้ (อาจถูกลบไปแล้ว)'))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildContractHeader(context, colors, order),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 18, color: BrandAccent.tealOn(context)),
                                const SizedBox(width: 8),
                                Text(
                                  'รายละเอียดงวดงาน (การส่งมอบ/ตรวจรับ)',
                                  style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading3, color: colors.onSurface),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildWorkTable(context, colors),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Icon(Icons.payments_outlined, size: 18, color: BrandAccent.tealOn(context)),
                                const SizedBox(width: 8),
                                Text(
                                  'รายละเอียดงวดเงิน (การเบิกจ่าย)',
                                  style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading3, color: colors.onSurface),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildPaymentTable(context, colors),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractHeader(BuildContext context, ColorScheme colors, ProcurementOrder order) {
    final paidCount = _installments.where((i) => (i.dateDisbursement ?? '').trim().isNotEmpty).length;
    final isCompleted = _installments.isNotEmpty && paidCount == _installments.length;
    final statusVariant = isCompleted ? BadgeVariant.success : BadgeVariant.warning;
    final statusLabel = _installments.isEmpty
        ? 'ยังไม่มีงวด'
        : isCompleted
            ? 'จ่ายครบทุกงวดแล้ว'
            : 'กำลังดำเนินการ (ส่งงานตามกำหนด)';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: Text(label, style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium)),
              ),
              Expanded(child: Text(value, style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface))),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('ข้อมูลสัญญา',
                      style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading4, color: colors.onSurface)),
                ),
                StatusBadge(label: statusLabel, variant: statusVariant, compact: true),
              ],
            ),
            Divider(height: 20, color: colors.outlineVariant),
            row('ชื่อผู้ค้า/ผู้รับจ้าง', order.vendorName ?? '-'),
            row('เลขประจำตัวผู้เสียภาษี', order.vendorTaxId ?? '-'),
            row('ประเภทสัญญา', order.orderType == 'จ้าง' ? 'ใบสั่งจ้าง' : 'ใบสั่งซื้อ'),
            row('เลขที่สัญญา', order.procurementNumber ?? '-'),
            row('ลงวันที่', order.dateContractSigned ?? '-'),
            row('เลขคุมสัญญา', order.contractControlNumber ?? '-'),
            row('จำนวนเงินตามสัญญา', '${formatBaht(order.currentOrderPrice)} บาท'),
          ],
        ),
      ),
    );
  }

  static const _headerStyle = TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodySmall);

  Widget _tableContainer(BuildContext context, ColorScheme colors, Widget child) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(RadiusSize.card),
          boxShadow: AppShadows.light1,
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      );

  Widget _emptyRow(ColorScheme colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_note_outlined, size: 32, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text('ยังไม่มีงวดการเบิกจ่าย',
                  style: TextStyle(color: colors.onSurfaceVariant, fontWeight: AppTypography.weightSemiBold, fontSize: AppTypography.body)),
              const SizedBox(height: 2),
              Text('กดปุ่ม "เพิ่มงวด" หรือ "สร้างงวดอัตโนมัติ" มุมขวาบนเพื่อเริ่มต้น',
                  style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.8), fontSize: AppTypography.caption)),
            ],
          ),
        ),
      );

  Widget _rowActionsMenu(ProcurementInstallment i, ColorScheme colors) {
    final busy = _generatingId == i.id;
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'จัดการงวดนี้',
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _openEditor(existing: i);
            break;
          case 'delete':
            _delete(i);
            break;
          case 'all':
            _generateAllFour(i);
            break;
          case 'delivery':
            _generate(i, ProcurementDocumentType.installmentDeliveryNote);
            break;
          case 'inspection':
            _generate(i, ProcurementDocumentType.inspectionReceipt);
            break;
          case 'disbursement':
            _generate(i, ProcurementDocumentType.installmentDisbursementMemo);
            break;
          case 'payment':
            _generate(i, ProcurementDocumentType.paymentReceipt);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('แก้ไขงวดนี้')),
        PopupMenuItem(value: 'delete', child: Text('ลบงวดนี้')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'all', child: Text('สร้างชุดเอกสาร (รวมไฟล์เดียว)')),
        PopupMenuItem(value: 'delivery', child: Text('ใบส่งมอบงาน')),
        PopupMenuItem(value: 'inspection', child: Text('ใบตรวจรับการจัดซื้อ/จัดจ้าง')),
        PopupMenuItem(value: 'disbursement', child: Text('บันทึกข้อความส่งเบิกเงิน')),
        PopupMenuItem(value: 'payment', child: Text('ใบสำคัญรับเงิน')),
      ],
      child: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
    );
  }

  Widget _buildWorkTable(BuildContext context, ColorScheme colors) {
    if (_installments.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(RadiusSize.card),
          boxShadow: AppShadows.light1,
        ),
        child: _emptyRow(colors),
      );
    }
    return _tableContainer(
      context,
      colors,
      DataTable(
        headingRowColor: WidgetStateProperty.all(BrandAccent.surface2(context)),
        columns: const [
          DataColumn(label: Text('งวดที่', style: _headerStyle)),
          DataColumn(label: Text('วันกำหนด/ส่งมอบงาน', style: _headerStyle)),
          DataColumn(label: Text('วันที่ตรวจรับ', style: _headerStyle)),
          DataColumn(label: Text('เลขคุมตรวจรับ', style: _headerStyle)),
          DataColumn(label: Text('สถานะดำเนินการ', style: _headerStyle)),
          DataColumn(label: Text('จัดการ', style: _headerStyle)),
        ],
        rows: [
          for (final (idx, i) in _installments.indexed)
            DataRow(
              color: idx.isOdd ? WidgetStateProperty.all(colors.surfaceContainerHighest.withValues(alpha: 0.25)) : null,
              cells: [
                DataCell(Text(i.periodLabel?.trim().isNotEmpty == true ? '${i.periodNo} (${i.periodLabel})' : '${i.periodNo}')),
                DataCell(Text(i.dateDelivery ?? '-')),
                DataCell(Text(i.dateInspection ?? '-')),
                DataCell(Text(i.controlNumberInspection ?? '-')),
                DataCell(StatusBadge(
                  label: (i.dateInspection ?? '').trim().isNotEmpty
                      ? 'ตรวจรับงานเรียบร้อย'
                      : (i.dateDelivery ?? '').trim().isNotEmpty
                          ? 'รอตรวจรับ'
                          : 'รอส่งมอบงาน',
                  variant: (i.dateInspection ?? '').trim().isNotEmpty ? BadgeVariant.success : BadgeVariant.warning,
                  compact: true,
                )),
                DataCell(_rowActionsMenu(i, colors)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentTable(BuildContext context, ColorScheme colors) {
    if (_installments.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(RadiusSize.card),
          boxShadow: AppShadows.light1,
        ),
        child: _emptyRow(colors),
      );
    }
    return _tableContainer(
      context,
      colors,
      DataTable(
        headingRowColor: WidgetStateProperty.all(BrandAccent.surface2(context)),
        columns: const [
          DataColumn(label: Text('งวดเงิน', style: _headerStyle)),
          DataColumn(label: Text('วันที่จ่ายเงิน', style: _headerStyle)),
          DataColumn(label: Text('จำนวนเงินงวดนี้', style: _headerStyle), numeric: true),
          DataColumn(label: Text('ค่าปรับ', style: _headerStyle)),
          DataColumn(label: Text('สถานะดำเนินการ', style: _headerStyle)),
          DataColumn(label: Text('จัดการ', style: _headerStyle)),
        ],
        rows: [
          for (final (idx, i) in _installments.indexed)
            DataRow(
              color: idx.isOdd ? WidgetStateProperty.all(colors.surfaceContainerHighest.withValues(alpha: 0.25)) : null,
              cells: [
                DataCell(Text('${i.periodNo}')),
                DataCell(Text(i.dateDisbursement ?? '-')),
                DataCell(Text('${formatBaht(i.amount)} บาท')),
                DataCell(Text(i.hasPenalty ? '${formatBaht(i.penaltyAmount)} บาท' : '-')),
                DataCell(StatusBadge(
                  label: (i.dateDisbursement ?? '').trim().isNotEmpty ? 'จ่ายเงินเรียบร้อย' : 'รอเบิกจ่าย',
                  variant: (i.dateDisbursement ?? '').trim().isNotEmpty ? BadgeVariant.success : BadgeVariant.warning,
                  compact: true,
                )),
                DataCell(_rowActionsMenu(i, colors)),
              ],
            ),
        ],
      ),
    );
  }
}

class _InstallmentEditorDialog extends StatefulWidget {
  final int orderId;
  final int nextPeriodNo;
  final ProcurementInstallment? existing;

  const _InstallmentEditorDialog({
    required this.orderId,
    required this.nextPeriodNo,
    this.existing,
  });

  @override
  State<_InstallmentEditorDialog> createState() => _InstallmentEditorDialogState();
}

class _InstallmentEditorDialogState extends State<_InstallmentEditorDialog> {
  late final TextEditingController _periodNoCtrl;
  late final TextEditingController _periodLabelCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _controlNumberCtrl;
  late final TextEditingController _penaltyAmountCtrl;
  String? _dateDelivery;
  String? _dateInspection;
  String? _dateDisbursement;
  String _inspectionResult = 'ถูกต้อง ครบถ้วนตามสัญญา';
  bool _hasPenalty = false;

  static const _inspectionResultOptions = [
    'ถูกต้อง ครบถ้วนตามสัญญา',
    'ถูกต้อง แต่ไม่ครบถ้วนตามสัญญา',
    'ไม่ถูกต้อง',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _periodNoCtrl = TextEditingController(text: (e?.periodNo ?? widget.nextPeriodNo).toString());
    _periodLabelCtrl = TextEditingController(text: e?.periodLabel ?? '');
    _amountCtrl = TextEditingController(text: e?.amount != null ? e!.amount!.toStringAsFixed(2) : '');
    _controlNumberCtrl = TextEditingController(text: e?.controlNumberInspection ?? '');
    _penaltyAmountCtrl = TextEditingController(
      text: e?.penaltyAmount != null ? e!.penaltyAmount!.toStringAsFixed(2) : '',
    );
    _dateDelivery = e?.dateDelivery;
    _dateInspection = e?.dateInspection;
    _dateDisbursement = e?.dateDisbursement;
    _inspectionResult = e?.inspectionResult ?? _inspectionResultOptions.first;
    _hasPenalty = e?.hasPenalty ?? false;
  }

  @override
  void dispose() {
    _periodNoCtrl.dispose();
    _periodLabelCtrl.dispose();
    _amountCtrl.dispose();
    _controlNumberCtrl.dispose();
    _penaltyAmountCtrl.dispose();
    super.dispose();
  }

  static const _thaiMonths = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  DateTime? _parseThaiDate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _thaiMonths.indexOf(parts[1]);
    final buddhistYear = int.tryParse(parts[2]);
    if (day == null || month < 1 || buddhistYear == null) return null;
    try {
      return DateTime(buddhistYear - 543, month, day);
    } catch (_) {
      return null;
    }
  }

  String _formatThaiDate(DateTime date) {
    final y = date.year + 543;
    return '${date.day} ${_thaiMonths[date.month]} $y';
  }

  Future<void> _pickDate(String label, String? current, void Function(String) onPicked) async {
    final colors = Theme.of(context).colorScheme;
    final initial = _parseThaiDate(current) ?? DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
      helpText: label,
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => onPicked(_formatThaiDate(picked)));
  }

  InputDecoration _dec(String label, {Widget? suffixIcon}) =>
      _dialogFieldDecoration(context, label: label, suffixIcon: suffixIcon);

  void _save() {
    final periodNo = int.tryParse(_periodNoCtrl.text.trim()) ?? widget.nextPeriodNo;
    final amount = double.tryParse(_amountCtrl.text.trim());
    final penaltyAmount = double.tryParse(_penaltyAmountCtrl.text.trim());
    final installment = ProcurementInstallment(
      id: widget.existing?.id,
      orderId: widget.orderId,
      periodNo: periodNo,
      periodLabel: _periodLabelCtrl.text.trim().isEmpty ? null : _periodLabelCtrl.text.trim(),
      amount: amount,
      amountTh: amount != null ? CalcEngine.bahtText(amount) : null,
      dateDelivery: _dateDelivery,
      dateInspection: _dateInspection,
      dateDisbursement: _dateDisbursement,
      inspectionResult: _inspectionResult,
      hasPenalty: _hasPenalty,
      penaltyAmount: _hasPenalty ? penaltyAmount : null,
      controlNumberInspection:
          _controlNumberCtrl.text.trim().isEmpty ? null : _controlNumberCtrl.text.trim(),
    );
    Navigator.pop(context, installment);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.existing == null ? 'เพิ่มงวดการเบิกจ่าย' : 'แก้ไขงวดการเบิกจ่าย', style: _dialogTitleStyle),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _periodNoCtrl,
                      style: _dialogFieldStyle,
                      decoration: _dec('งวดที่'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _periodLabelCtrl,
                      style: _dialogFieldStyle,
                      decoration: _dec('ป้ายกำกับงวด (เช่น พฤษภาคม 2569)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amountCtrl,
                style: _dialogFieldStyle,
                decoration: _dec('จำนวนเงินงวดนี้ (บาท)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controlNumberCtrl,
                style: _dialogFieldStyle,
                decoration: _dec('เลขคุมตรวจรับ (ถ้ามี)'),
              ),
              const SizedBox(height: 18),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: _dateDelivery ?? ''),
                style: _dialogFieldStyle,
                decoration: _dec('วันที่ส่งมอบงาน', suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                onTap: () => _pickDate('วันที่ส่งมอบงาน', _dateDelivery, (v) => _dateDelivery = v),
              ),
              const SizedBox(height: 18),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: _dateInspection ?? ''),
                style: _dialogFieldStyle,
                decoration: _dec('วันที่ตรวจรับ', suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                onTap: () => _pickDate('วันที่ตรวจรับ', _dateInspection, (v) => _dateInspection = v),
              ),
              const SizedBox(height: 18),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: _dateDisbursement ?? ''),
                style: _dialogFieldStyle,
                decoration: _dec('วันที่อนุมัติเบิกจ่าย', suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                onTap: () =>
                    _pickDate('วันที่อนุมัติเบิกจ่าย', _dateDisbursement, (v) => _dateDisbursement = v),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _inspectionResult,
                style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                decoration: _dec('ผลการตรวจรับ'),
                items: _inspectionResultOptions
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _inspectionResult = v ?? _inspectionResult),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('มีค่าปรับ', style: TextStyle(fontSize: AppTypography.body, color: colors.onSurface)),
                value: _hasPenalty,
                onChanged: (v) => setState(() => _hasPenalty = v),
              ),
              if (_hasPenalty)
                TextField(
                  controller: _penaltyAmountCtrl,
                  style: _dialogFieldStyle,
                  decoration: _dec('จำนวนเงินค่าปรับ (บาท)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          onPressed: _save,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
