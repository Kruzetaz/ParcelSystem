// document_checklist_screen.dart
// "ทะเบียนตรวจสอบเอกสาร" — เทียบมาจากทะเบียนกระดาษเดิมของโรงเรียน (ตาราง
// "ตรวจรับเอกสาร ซื้อ-จ้าง") ใช้ติดตามว่าแต่ละโครงการ (procurement_orders)
// เอกสารครบหรือยัง: มีใบเสร็จจากร้านค้า/ผู้รับจ้างแล้วไหม, ปริ้นเอกสารออกมา
// เซ็นเรียบร้อยแล้วไหม, จ่ายเงินวันไหน, พร้อมช่องหมายเหตุอิสระ — ไม่ต้อง
// กรอกรายการซ้ำ ดึงจาก procurement_orders ที่มีอยู่แล้วในระบบมาแสดงตรงๆ
// (ตั้งฎีกาแล้ว = จริงเสมอเพราะ order ถูกสร้างในระบบแล้ว จึงไม่ต้องมีคอลัมน์นี้)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../utils/thai_date.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';

enum _ChecklistFilter { all, incomplete, complete }

class DocumentChecklistScreen extends StatefulWidget {
  const DocumentChecklistScreen({super.key});
  @override
  State<DocumentChecklistScreen> createState() => _DocumentChecklistScreenState();
}

class _DocumentChecklistScreenState extends State<DocumentChecklistScreen> {
  final _repo = ProcurementRepository();
  List<ProcurementOrder> _orders = [];
  bool _loading = true;
  String? _fiscalYearFilter;
  _ChecklistFilter _statusFilter = _ChecklistFilter.all;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  List<String> get _fiscalYears =>
      _orders.map((o) => o.fiscalYear).whereType<String>().where((s) => s.isNotEmpty).toSet().toList()..sort();

  bool _isComplete(ProcurementOrder o) => o.docChecklistHasReceipt && o.docChecklistPrinted;

  List<ProcurementOrder> get _filtered {
    var list = _orders;
    if (_fiscalYearFilter != null) {
      list = list.where((o) => o.fiscalYear == _fiscalYearFilter).toList();
    }
    if (_statusFilter == _ChecklistFilter.complete) {
      list = list.where(_isComplete).toList();
    } else if (_statusFilter == _ChecklistFilter.incomplete) {
      list = list.where((o) => !_isComplete(o)).toList();
    }
    final q = _searchCtrl.text.trim();
    if (q.isNotEmpty) {
      list = list.where((o) {
        final haystack = [o.orderNumber, o.procurementNumber, o.projectName, o.procurementSubject, o.vendorName]
            .whereType<String>()
            .join(' ')
            .toLowerCase();
        return haystack.contains(q.toLowerCase());
      }).toList();
    }
    return list;
  }

  Future<void> _updateOrder(ProcurementOrder updated) async {
    final idx = _orders.indexWhere((o) => o.id == updated.id);
    if (idx == -1) return;
    setState(() => _orders[idx] = updated);
    try {
      await _repo.updateOrder(updated);
    } catch (e) {
      if (!mounted) return;
      showAppToast('บันทึกไม่สำเร็จ: $e', isError: true);
      _load();
    }
  }

  Future<void> _toggleReceipt(ProcurementOrder o) =>
      _updateOrder(o.copyWith(docChecklistHasReceipt: !o.docChecklistHasReceipt));

  Future<void> _togglePrinted(ProcurementOrder o) =>
      _updateOrder(o.copyWith(docChecklistPrinted: !o.docChecklistPrinted));

  Future<void> _editDetails(ProcurementOrder o) async {
    final noteCtrl = TextEditingController(text: o.docChecklistNote ?? '');
    String? paidDate = o.docChecklistPaidDate;
    final colors = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('แก้ไขเช็คลิสต์เอกสาร'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.procurementSubject ?? o.projectName ?? '(ไม่มีชื่อรายการ)',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final initial = parseThaiDate(paidDate) ?? DateTime.now();
                    final picked = await pickThaiDate(
                      context: ctx,
                      initialDate: initial,
                      firstDate: DateTime(initial.year - 5),
                      lastDate: DateTime(initial.year + 5),
                      helpText: 'วันที่จ่ายเงิน',
                      primaryColor: colors.primary,
                      onPrimaryColor: colors.onPrimary,
                    );
                    if (picked == null) return;
                    final y = picked.year + 543;
                    const months = ['', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
                    setDialogState(() => paidDate = '${picked.day} ${months[picked.month]} $y');
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'วันที่จ่ายเงิน',
                      isDense: true,
                      prefixIcon: const Icon(Icons.event_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                    ),
                    child: Text(paidDate?.isNotEmpty == true ? paidDate! : 'ยังไม่ระบุ'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'หมายเหตุ',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
          ],
        ),
      ),
    );

    if (result == true) {
      await _updateOrder(o.copyWith(
        docChecklistPaidDate: paidDate ?? '',
        docChecklistNote: noteCtrl.text.trim(),
      ));
    }
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final completeCount = _orders.where(_isComplete).length;

    return GuideFabOverlay(
      title: 'วิธีใช้ทะเบียนตรวจสอบเอกสาร',
      icon: Icons.fact_check_outlined,
      steps: const [
        'หน้านี้ไม่ต้องกรอกข้อมูลซ้ำ — ดึงรายการที่บันทึกไว้แล้วมาแสดงเป็นเช็คลิสต์ให้อัตโนมัติ',
        'ติ๊ก "ใบเสร็จ" เมื่อได้รับใบเสร็จจากร้านค้า/ผู้รับจ้างแล้ว และติ๊ก "ปริ้น/เซ็นแล้ว" เมื่อปริ้นเอกสารออกมาเซ็นเรียบร้อยแล้ว',
        'กดไอคอนดินสอเพื่อกรอกวันที่จ่ายเงินจริงและหมายเหตุเพิ่มเติม',
        'โครงการที่ติ๊กครบทั้งใบเสร็จและปริ้นเซ็นแล้ว จะขึ้นสถานะ "ครบ" สีเขียว — ใช้ตัวกรองด้านบนเพื่อดูเฉพาะรายการที่ยังไม่ครบได้',
      ],
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
                      Icon(Icons.fact_check_outlined, color: BrandAccent.tealOn(context), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('ทะเบียนตรวจสอบเอกสาร',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                      ),
                      Text('$completeCount / ${_orders.length} โครงการครบเอกสารแล้ว',
                          style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('ติดตามว่าแต่ละโครงการมีใบเสร็จแล้วหรือยัง ปริ้นเอกสารออกมาเซ็นแล้วหรือยัง และวันที่จ่ายเงินจริง',
                      style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาเลขที่/ชื่อโครงการ/ผู้ขาย',
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(RadiusSize.md),
                              borderSide: BorderSide(color: colors.outline),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _fiscalYearFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'ปีงบประมาณ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('ทั้งหมด')),
                            ..._fiscalYears.map((y) => DropdownMenuItem(value: y, child: Text('ปี $y'))),
                          ],
                          onChanged: (v) => setState(() => _fiscalYearFilter = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SegmentedButton<_ChecklistFilter>(
                        segments: const [
                          ButtonSegment(value: _ChecklistFilter.all, label: Text('ทั้งหมด')),
                          ButtonSegment(value: _ChecklistFilter.incomplete, label: Text('ยังไม่ครบ')),
                          ButtonSegment(value: _ChecklistFilter.complete, label: Text('ครบแล้ว')),
                        ],
                        selected: {_statusFilter},
                        onSelectionChanged: (s) => setState(() => _statusFilter = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fact_check_outlined, size: 64, color: colors.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text(_orders.isEmpty ? 'ยังไม่มีรายการจัดซื้อจัดจ้างในระบบ' : 'ไม่พบรายการที่ตรงกับตัวกรอง',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border.all(color: colors.outline),
                              borderRadius: BorderRadius.circular(RadiusSize.card),
                              boxShadow: AppShadows.light1,
                            ),
                            child: Scrollbar(
                              controller: _scrollCtrl,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _scrollCtrl,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 1180,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildHeaderRow(colors),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          itemCount: filtered.length,
                                          itemBuilder: (_, i) => _buildRow(colors, i + 1, filtered[i]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderRow(ColorScheme colors) {
    final headerStyle = TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 1.5))),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('ที่', style: headerStyle)),
          const SizedBox(width: 6),
          SizedBox(width: 100, child: Text('เลขที่เอกสาร', style: headerStyle)),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: Text('รายการ/โครงการ', style: headerStyle)),
          const SizedBox(width: 6),
          SizedBox(width: 110, child: Text('งบที่ใช้', style: headerStyle, textAlign: TextAlign.right)),
          const SizedBox(width: 6),
          SizedBox(width: 90, child: Text('ใบเสร็จ', style: headerStyle, textAlign: TextAlign.center)),
          const SizedBox(width: 6),
          SizedBox(width: 100, child: Text('ปริ้น/เซ็นแล้ว', style: headerStyle, textAlign: TextAlign.center)),
          const SizedBox(width: 6),
          SizedBox(width: 110, child: Text('วันที่จ่ายเงิน', style: headerStyle)),
          const SizedBox(width: 6),
          SizedBox(width: 150, child: Text('หมายเหตุ', style: headerStyle)),
          const SizedBox(width: 6),
          SizedBox(width: 80, child: Text('สถานะ', style: headerStyle, textAlign: TextAlign.center)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, int index, ProcurementOrder o) {
    final docNumber = o.orderNumber ?? o.procurementNumber ?? '-';
    // เอา procurementSubject ขึ้นก่อน projectName ให้ตรงกับหน้า "สร้างเอกสารราชการ"
    // (document_hub_screen.dart) — subject เป็นชื่อเฉพาะต่อรายการ (มักมีชื่อร้าน/
    // ผู้รับจ้างติดมาด้วย) ต่างจาก projectName ที่เป็นชื่อโครงการรวมๆ ใช้ซ้ำได้
    // หลายรายการ ทำให้แยกแยะแต่ละแถวในตารางนี้ยากถ้าใช้ projectName ก่อน
    final itemLabel = o.procurementSubject ?? o.projectName ?? '(ไม่มีชื่อรายการ)';
    final complete = _isComplete(o);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('$index', style: TextStyle(fontSize: AppTypography.bodyMedium))),
          const SizedBox(width: 6),
          SizedBox(width: 100, child: Text(docNumber, style: TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: Text(itemLabel, style: TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          SizedBox(width: 110, child: Text(o.currentOrderPrice != null ? formatBaht(o.currentOrderPrice) : '-', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Center(
              child: Checkbox(value: o.docChecklistHasReceipt, onChanged: (_) => _toggleReceipt(o)),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 100,
            child: Center(
              child: Checkbox(value: o.docChecklistPrinted, onChanged: (_) => _togglePrinted(o)),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(width: 110, child: Text(o.docChecklistPaidDate?.isNotEmpty == true ? formatThaiDateShort(o.docChecklistPaidDate) : '-', style: TextStyle(fontSize: AppTypography.caption))),
          const SizedBox(width: 6),
          SizedBox(width: 150, child: Text(o.docChecklistNote?.isNotEmpty == true ? o.docChecklistNote! : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant))),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (complete ? BrandAccent.green(context) : Colors.orange).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RadiusSize.sm),
                ),
                child: Text(complete ? 'ครบ' : 'ไม่ครบ',
                    style: TextStyle(fontSize: AppTypography.caption, fontWeight: FontWeight.w700, color: complete ? BrandAccent.green(context) : Colors.orange)),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'แก้ไขวันที่จ่าย/หมายเหตุ',
              onPressed: () => _editDetails(o),
            ),
          ),
        ],
      ),
    );
  }
}
