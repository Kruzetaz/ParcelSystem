// annual_count_screen.dart
// ตรวจนับพัสดุประจำปี (blueprint หน้าที่ 10) — บันทึกประวัติการตรวจสอบ
// สินทรัพย์ตามกฎหมายประจำปีงบประมาณ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/annual_count.dart';
import '../services/annual_count_export_service.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant;
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

/// สร้างกรอบช่องกรอกในป๊อปอัพให้ชัดเจนกว่าค่าเริ่มต้นของธีม (colors.outline
/// จางเกินไปสำหรับช่องกรอกเดี่ยวๆ ที่ไม่มีเงา/สีพื้นต่างช่วยตัดขอบ)
InputDecoration _dialogFieldDecoration(BuildContext context, {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
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
String _currentFiscalYear() {
  final now = DateTime.now();
  final buddhistYear = now.year + 543;
  return now.month >= 10 ? '${buddhistYear + 1}' : '$buddhistYear';
}

class AnnualCountScreen extends StatefulWidget {
  const AnnualCountScreen({super.key});
  @override
  State<AnnualCountScreen> createState() => _AnnualCountScreenState();
}

class _AnnualCountScreenState extends State<AnnualCountScreen> {
  final _repo = ProcurementRepository();
  List<AnnualCount> _counts = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllAnnualCounts();
    if (!mounted) return;
    setState(() {
      _counts = list;
      _loading = false;
    });
  }

  Future<void> _startNewCount() async {
    final totalItems = await _repo.countAllAssetsAndMaterials();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnualCountFormDialog(suggestedTotal: totalItems),
    );
    if (saved == true) _load();
  }

  Future<void> _openForm(AnnualCount existing) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnualCountFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(AnnualCount a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบบันทึกการตรวจนับปี ${a.fiscalYear} ใช่หรือไม่?', style: const TextStyle(fontSize: 15, height: 1.4)),
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
    if (confirmed == true && a.id != null) {
      await _repo.deleteAnnualCount(a.id!);
      _load();
    }
  }

  /// ส่งออกประวัติการตรวจนับที่เห็นอยู่ตอนนี้เป็นไฟล์ Excel แล้วเปิดไฟล์ให้อัตโนมัติ
  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await AnnualCountExportService.exportAndOpen(_counts);
      if (!mounted) return;
      showAppToast('ส่งออกไฟล์ Excel แล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('ส่งออกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าตรวจนับพัสดุประจำปี',
      icon: Icons.checklist_outlined,
      steps: const [
        'ใช้บันทึกผลการตรวจนับพัสดุ/ครุภัณฑ์จริงประจำปีงบประมาณ เทียบกับจำนวนที่มีอยู่ในทะเบียน ตามที่ระเบียบพัสดุกำหนดให้ตรวจนับอย่างน้อยปีละ 1 ครั้ง',
        'กด "เริ่มการตรวจนับ" มุมขวาล่างเพื่อเปิดรอบตรวจนับใหม่ของปีงบประมาณปัจจุบัน',
        'บันทึกจำนวนที่พบจริง/ชำรุด/สูญหาย ไว้เป็นหลักฐานประกอบการรายงาน สตง. และใช้เทียบกับรอบก่อนหน้าได้',
        'กดปุ่ม "ส่งออก Excel" มุมบนขวาเพื่อบันทึกประวัติการตรวจนับที่เห็นอยู่ตอนนี้เป็นไฟล์ .xlsx',
      ],
      // มุมขวาบนชนกับปุ่ม "ส่งออก Excel" ในหัวหน้า และมุมขวาล่างมี FAB
      // "เริ่มการตรวจนับ" อยู่แล้ว — เหลือแค่มุมซ้ายล่างที่ว่าง
      corner: Alignment.bottomLeft,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_outlined, color: BrandAccent.tealOn(context), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('ตรวจนับพัสดุประจำปี ${_currentFiscalYear()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _counts.isEmpty || _exporting ? null : _exportToExcel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                          icon: _exporting
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurfaceVariant))
                              : const Icon(Icons.file_download_outlined, size: 18),
                          label: Text(_exporting ? 'กำลังส่งออก...' : 'ส่งออก Excel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _counts.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.checklist_outlined, size: 64, color: colors.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text('ยังไม่มีประวัติการตรวจนับ\nกด "เริ่มการตรวจนับ" เพื่อเริ่มต้น',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _counts.length,
                                  padding: const EdgeInsets.only(bottom: 80),
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _buildCard(context, colors, _counts[i]),
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
              heroTag: 'annual_count_add_fab',
              onPressed: _startNewCount,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เริ่มการตรวจนับ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, AnnualCount a) {
    final isDone = a.status == 'เสร็จสิ้น';
    final hasIssue = (a.damagedLostItems ?? 0) > 0;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(a),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandAccent.teal(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(RadiusSize.sm),
                    ),
                    child: Text('ปี ${a.fiscalYear}',
                      style: TextStyle(fontSize: AppTypography.caption, color: BrandAccent.tealOn(context), fontWeight: AppTypography.weightSemiBold)),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: a.status,
                    variant: isDone ? BadgeVariant.success : BadgeVariant.warning,
                    compact: true,
                  ),
                  if (hasIssue) ...[
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: 'พบชำรุด/สูญหาย ${a.damagedLostItems}',
                      variant: BadgeVariant.danger,
                      compact: true,
                    ),
                  ],
                  const Spacer(),
                  DsActionIconButtons(
                    actions: [
                      DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(a), danger: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('เริ่มตรวจ: ${a.startDate ?? "-"}  ·  ผู้รับผิดชอบ: ${a.responsiblePersons ?? "-"}',
                style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('ทั้งหมด ${a.totalItems ?? "-"} รายการ  ·  พบจริง ${a.foundItems ?? "-"} รายการ  ·  ชำรุด/สูญหาย ${a.damagedLostItems ?? 0} รายการ',
                style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface)),
              if (a.summaryNotes != null && a.summaryNotes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.summaryNotes!, style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnualCountFormDialog extends StatefulWidget {
  final AnnualCount? existing;
  final int? suggestedTotal;
  const _AnnualCountFormDialog({this.existing, this.suggestedTotal});
  @override
  State<_AnnualCountFormDialog> createState() => _AnnualCountFormDialogState();
}

class _AnnualCountFormDialogState extends State<_AnnualCountFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fiscalYearCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _foundCtrl;
  late final TextEditingController _damagedCtrl;
  late final TextEditingController _notesCtrl;
  String? _startDate;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _fiscalYearCtrl = TextEditingController(text: a?.fiscalYear ?? _currentFiscalYear());
    _responsibleCtrl = TextEditingController(text: a?.responsiblePersons ?? '');
    _totalCtrl = TextEditingController(text: a?.totalItems?.toString() ?? widget.suggestedTotal?.toString() ?? '');
    _foundCtrl = TextEditingController(text: a?.foundItems?.toString() ?? '');
    _damagedCtrl = TextEditingController(text: a?.damagedLostItems?.toString() ?? '0');
    _notesCtrl = TextEditingController(text: a?.summaryNotes ?? '');
    _startDate = a?.startDate ?? _formatThai(DateTime.now());
    _status = a?.status ?? 'กำลังดำเนินการ';
  }

  @override
  void dispose() {
    _fiscalYearCtrl.dispose();
    _responsibleCtrl.dispose();
    _totalCtrl.dispose();
    _foundCtrl.dispose();
    _damagedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 1),
      helpText: 'วันที่เริ่มตรวจ',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => _startDate = _formatThai(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final a = AnnualCount(
      id: widget.existing?.id,
      fiscalYear: _fiscalYearCtrl.text.trim(),
      startDate: _startDate,
      responsiblePersons: _responsibleCtrl.text.trim().isEmpty ? null : _responsibleCtrl.text.trim(),
      totalItems: int.tryParse(_totalCtrl.text.trim()),
      foundItems: int.tryParse(_foundCtrl.text.trim()),
      damagedLostItems: int.tryParse(_damagedCtrl.text.trim()) ?? 0,
      status: _status,
      summaryNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (widget.existing == null) {
      await _repo.insertAnnualCount(a);
    } else {
      await _repo.updateAnnualCount(a);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขบันทึกการตรวจนับ' : 'เริ่มการตรวจนับพัสดุ', style: _dialogTitleStyle),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: _fiscalYearCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context, label: 'ปีงบประมาณ *', hint: 'เช่น 2569'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกปีงบประมาณ' : null,
                  ),
                ),
                InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(RadiusSize.md),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: InputDecorator(
                      decoration: _dialogFieldDecoration(context, label: 'วันที่เริ่มตรวจ').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                      child: Text(_startDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: _responsibleCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context, label: 'ผู้รับผิดชอบ (ชื่อกรรมการ)', hint: 'คั่นด้วยจุลภาคถ้ามีหลายคน'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: TextFormField(
                          controller: _totalCtrl,
                          style: _dialogFieldStyle,
                          keyboardType: TextInputType.number,
                          decoration: _dialogFieldDecoration(context, label: 'จำนวนรายการทั้งหมด', hint: 'เช่น 50'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: TextFormField(
                          controller: _foundCtrl,
                          style: _dialogFieldStyle,
                          keyboardType: TextInputType.number,
                          decoration: _dialogFieldDecoration(context, label: 'จำนวนที่พบจริง', hint: 'เช่น 48'),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: _damagedCtrl,
                    style: _dialogFieldStyle,
                    keyboardType: TextInputType.number,
                    decoration: _dialogFieldDecoration(context, label: 'จำนวนที่ชำรุด/สูญหาย', hint: 'เช่น 2'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(context, label: 'สถานะ').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    items: const [
                      DropdownMenuItem(value: 'กำลังดำเนินการ', child: Text('กำลังดำเนินการ')),
                      DropdownMenuItem(value: 'เสร็จสิ้น', child: Text('เสร็จสิ้น')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'กำลังดำเนินการ'),
                  ),
                ),
                TextFormField(
                  controller: _notesCtrl,
                  style: _dialogFieldStyle,
                  maxLines: 3,
                  decoration: _dialogFieldDecoration(context, label: 'สรุปผลรายงานการตรวจสอบ', hint: 'เช่น ตรวจนับครุภัณฑ์ครบถ้วน พบชำรุด 2 รายการ'),
                ),
              ],
            ),
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
              : Text(isEdit ? 'บันทึก' : 'เริ่มตรวจนับ'),
        ),
      ],
    );
  }
}
