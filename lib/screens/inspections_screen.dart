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
import '../services/procurement_document_generator.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../services/toast_service.dart';

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
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final inspections = await _repo.getAllInspections();
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
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรายการตรวจรับ "${i.inspectionNumber ?? "-"}" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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
          title: const Text('คำนวณค่าปรับไม่ได้'),
          content: const Text('ต้องมีวันที่ครบกำหนดและวันที่ส่งมอบจริง และวันที่ส่งมอบจริงต้องเกินกำหนดเท่านั้น'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
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
        title: const Text('ค่าปรับโดยประมาณ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ล่าช้า $daysLate วัน'),
            Text('วงเงิน ${formatBaht(baseAmount)} บาท × อัตราค่าปรับ $penaltyRate% ต่อวัน'),
            const SizedBox(height: 8),
            Text('≈ ${formatBaht(estimated)} บาท',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'ตัวเลขนี้เป็นค่าประมาณการเท่านั้น โปรดตรวจสอบอัตราค่าปรับตามสัญญาจริงอีกครั้งก่อนใช้อ้างอิงในเอกสารราชการ',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ปิด')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึกค่านี้')),
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
                          _buildSummaryCards(colors),
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
                                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _inspections.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _buildCard(colors, _inspections[i]),
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

  Widget _buildSummaryCards(ColorScheme colors) {
    Widget card(String label, int count, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        card('รอตรวจรับ', _pendingCount, Colors.orange),
        const SizedBox(width: 12),
        card('ตรวจรับเสร็จสิ้น', _completedCount, Colors.green),
        const SizedBox(width: 12),
        card('มีปัญหา/ล่าช้า', _problemCount, Colors.redAccent),
      ],
    );
  }

  Widget _buildCard(ColorScheme colors, Inspection i) {
    final order = i.orderId != null ? _ordersById[i.orderId] : null;
    final late = _isLate(i);
    final resultColor = i.result == 'ผ่าน' ? Colors.green : (i.result == 'ไม่ผ่าน' ? Colors.redAccent : Colors.orange);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(existing: i),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: resultColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(i.result ?? 'รอตรวจรับ',
                          style: TextStyle(fontSize: 11.5, color: resultColor, fontWeight: FontWeight.w600)),
                      ),
                      if (late) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                          child: const Text('ส่งมอบล่าช้า', style: TextStyle(fontSize: 11.5, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Text(i.inspectionNumber ?? '(ไม่มีเลขที่ตรวจรับ)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (order != null) ...[
                      const SizedBox(height: 2),
                      Text('${order.projectName ?? order.procurementSubject ?? "-"} · ผู้ส่งมอบ: ${order.vendorName ?? "-"}',
                        style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 2),
                    Text('ครบกำหนด: ${i.dueDate ?? "-"}  ·  ส่งมอบจริง: ${i.actualDeliveryDate ?? "-"}',
                      style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                    if (i.penaltyAmount != null) ...[
                      const SizedBox(height: 2),
                      Text('ค่าปรับโดยประมาณ: ${formatBaht(i.penaltyAmount)} บาท',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              if (late)
                TextButton(
                  onPressed: () => _calculatePenalty(i),
                  child: const Text('คำนวณค่าปรับ', style: TextStyle(fontSize: 12)),
                ),
              if (order != null)
                IconButton(
                  icon: _exportingId == i.id
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.description_outlined),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  // ตรวจรับพัสดุมีเอกสารที่เกี่ยวข้องแบบเดียว (บันทึกขออนุมัติ
                  // เบิกจ่าย หลังตรวจรับผ่านแล้ว) จึงมีปุ่มเดียวทำหน้าที่ทั้งดู
                  // ตัวอย่างและสร้างเอกสารในตัว ไม่แยก 2 ปุ่มให้สับสนเพราะเป็น
                  // เอกสารใบเดียวกัน
                  tooltip: 'สร้าง/ดูเอกสารบันทึกขออนุมัติเบิกจ่าย',
                  color: colors.primary,
                  onPressed: _exportingId != null ? null : () => _exportDisbursementMemo(i),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: 'ลบ',
                onPressed: () => _confirmDelete(i),
              ),
            ],
          ),
        ),
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
      title: Text(isEdit ? 'แก้ไขรายการตรวจรับ' : 'เพิ่มรายการตรวจรับ'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _numberCtrl,
                  decoration: const InputDecoration(labelText: 'เลขที่ตรวจรับ', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int?>(
                  initialValue: _orderId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'รายการจัดซื้อจัดจ้าง', border: OutlineInputBorder(), isDense: true),
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
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'วันที่ครบกำหนด', border: OutlineInputBorder(), isDense: true),
                        child: Text(_dueDate ?? 'เลือกวันที่'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isDue: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'วันที่ส่งมอบจริง', border: OutlineInputBorder(), isDense: true),
                        child: Text(_actualDate ?? 'เลือกวันที่'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _result,
                decoration: const InputDecoration(labelText: 'ผลการตรวจรับ', border: OutlineInputBorder(), isDense: true),
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
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
