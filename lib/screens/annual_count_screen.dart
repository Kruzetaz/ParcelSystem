// annual_count_screen.dart
// ตรวจนับพัสดุประจำปี (blueprint หน้าที่ 10) — บันทึกประวัติการตรวจสอบ
// สินทรัพย์ตามกฎหมายประจำปีงบประมาณ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/annual_count.dart';

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
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบบันทึกการตรวจนับปี ${a.fiscalYear} ใช่หรือไม่?'),
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
    if (confirmed == true && a.id != null) {
      await _repo.deleteAnnualCount(a.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ตรวจนับพัสดุประจำปี ${_currentFiscalYear()}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _counts.length,
                                padding: const EdgeInsets.only(bottom: 80),
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => _buildCard(colors, _counts[i]),
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
            onPressed: _startNewCount,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            icon: const Icon(Icons.add),
            label: const Text('เริ่มการตรวจนับ'),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ColorScheme colors, AnnualCount a) {
    final isDone = a.status == 'เสร็จสิ้น';
    final hasIssue = (a.damagedLostItems ?? 0) > 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(a),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('ปี ${a.fiscalYear}', style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDone ? Colors.green : Colors.orange).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(a.status, style: TextStyle(fontSize: 11.5, color: isDone ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                  if (hasIssue) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text('พบชำรุด/สูญหาย ${a.damagedLostItems}', style: const TextStyle(fontSize: 11.5, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(a)),
                ],
              ),
              const SizedBox(height: 8),
              Text('เริ่มตรวจ: ${a.startDate ?? "-"}  ·  ผู้รับผิดชอบ: ${a.responsiblePersons ?? "-"}',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('ทั้งหมด ${a.totalItems ?? "-"} รายการ  ·  พบจริง ${a.foundItems ?? "-"} รายการ  ·  ชำรุด/สูญหาย ${a.damagedLostItems ?? 0} รายการ',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (a.summaryNotes != null && a.summaryNotes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.summaryNotes!, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 1),
      helpText: 'วันที่เริ่มตรวจ',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: colors.primary, onPrimary: colors.onPrimary, onSurface: colors.primary),
        ),
        child: child!,
      ),
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
      title: Text(isEdit ? 'แก้ไขบันทึกการตรวจนับ' : 'เริ่มการตรวจนับพัสดุ'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _fiscalYearCtrl,
                    decoration: const InputDecoration(labelText: 'ปีงบประมาณ *', border: OutlineInputBorder(), isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกปีงบประมาณ' : null,
                  ),
                ),
                InkWell(
                  onTap: _pickStartDate,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'วันที่เริ่มตรวจ', border: OutlineInputBorder(), isDense: true),
                      child: Text(_startDate ?? 'เลือกวันที่'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _responsibleCtrl,
                    decoration: const InputDecoration(labelText: 'ผู้รับผิดชอบ (ชื่อกรรมการ)', hintText: 'คั่นด้วยจุลภาคถ้ามีหลายคน', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _totalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'จำนวนรายการทั้งหมด', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _foundCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'จำนวนที่พบจริง', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _damagedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'จำนวนที่ชำรุด/สูญหาย', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'สถานะ', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'กำลังดำเนินการ', child: Text('กำลังดำเนินการ')),
                      DropdownMenuItem(value: 'เสร็จสิ้น', child: Text('เสร็จสิ้น')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'กำลังดำเนินการ'),
                  ),
                ),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'สรุปผลรายงานการตรวจสอบ', border: OutlineInputBorder(), isDense: true),
                ),
              ],
            ),
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
              : Text(isEdit ? 'บันทึก' : 'เริ่มตรวจนับ'),
        ),
      ],
    );
  }
}
