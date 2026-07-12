// tor_screen.dart
// เขียน TOR / จัดทำคุณลักษณะเฉพาะ — ทะเบียนร่าง/อนุมัติสเปกก่อนเข้าสู่ขั้นตอน
// จัดซื้อจัดจ้างจริง (blueprint หน้าที่ 4)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../models/tor_document.dart';
import '../models/tor_template.dart';
import '../services/tor_document_generator.dart';
import '../services/toast_service.dart';

const _torCategories = ['ครุภัณฑ์', 'วัสดุ', 'จ้าง'];
const _torStatuses = ['ร่าง', 'อนุมัติ'];
const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String _todayThai() {
  final now = DateTime.now();
  return '${now.day} ${_thaiMonths[now.month]} ${now.year + 543}';
}

class TorScreen extends StatefulWidget {
  const TorScreen({super.key});
  @override
  State<TorScreen> createState() => _TorScreenState();
}

class _TorScreenState extends State<TorScreen> {
  final _repo = ProcurementRepository();
  List<TorDocument> _docs = [];
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
    final list = await _repo.getAllTorDocuments();
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    setState(() {
      _docs = list;
      _ordersById = {for (final o in orders) if (o.id != null) o.id!: o};
      _loading = false;
    });
  }

  Future<void> _exportWord(TorDocument doc) async {
    final order = doc.orderId != null ? _ordersById[doc.orderId] : null;
    if (order == null) {
      showAppToast('TOR นี้ไม่ได้ผูกกับรายการจัดซื้อจัดจ้าง จึงออกเอกสารไม่ได้', isError: true);
      return;
    }
    final school = await _repo.getSchoolSettings();
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    setState(() => _exportingId = doc.id);
    try {
      final items = await _repo.getItems(order.id!);
      await TorDocumentGenerator.generateAndOpen(order: order, school: school, items: items);
      if (!mounted) return;
      showAppToast('สร้างเอกสาร TOR แล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  Future<void> _openForm({TorDocument? existing}) async {
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TorFormDialog(existing: existing, orders: orders),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(TorDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "${doc.title}" ใช่หรือไม่?'),
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
    if (confirmed == true && doc.id != null) {
      await _repo.deleteTorDocument(doc.id!);
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _docs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description_outlined, size: 64, color: colors.onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text('ยังไม่มี TOR / ข้อมูลคุณลักษณะเฉพาะ\nกด "เพิ่ม TOR" เพื่อเริ่มต้น',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _docs.length,
                          padding: const EdgeInsets.only(bottom: 80),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildCard(colors, _docs[i]),
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
            label: const Text('เพิ่ม TOR'),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ColorScheme colors, TorDocument doc) {
    final isApproved = doc.status == 'อนุมัติ';
    final statusColor = isApproved ? Colors.green : Colors.orange;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(existing: doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (doc.documentNumber != null && doc.documentNumber!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(doc.documentNumber!,
                            style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (doc.category != null) ...[
                        Text(doc.category!, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(doc.status,
                          style: TextStyle(fontSize: 11.5, color: statusColor, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(doc.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (doc.createdDate != null) ...[
                      const SizedBox(height: 2),
                      Text('สร้างเมื่อ ${doc.createdDate}', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                    ],
                    if (doc.orderId != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 13, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('ผูกกับรายการจัดซื้อจัดจ้าง', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (doc.estimatedAmount != null) ...[
                Text('${doc.estimatedAmount!.toStringAsFixed(2)} บาท',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.primary)),
                const SizedBox(width: 8),
              ],
              if (doc.orderId != null)
                _exportingId == doc.id
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.description_outlined),
                        tooltip: 'ออกเอกสาร Word',
                        onPressed: () => _exportWord(doc),
                      ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'ลบ',
                onPressed: () => _confirmDelete(doc),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TorFormDialog extends StatefulWidget {
  final TorDocument? existing;
  final List<ProcurementOrder> orders;
  const _TorFormDialog({this.existing, required this.orders});
  @override
  State<_TorFormDialog> createState() => _TorFormDialogState();
}

class _TorFormDialogState extends State<_TorFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _documentNumberCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _estimatedAmountCtrl;
  late final TextEditingController _specTextCtrl;
  String? _category;
  late String _status;
  int? _orderId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _documentNumberCtrl = TextEditingController(text: d?.documentNumber ?? '');
    _titleCtrl = TextEditingController(text: d?.title ?? '');
    _estimatedAmountCtrl = TextEditingController(text: d?.estimatedAmount?.toStringAsFixed(2) ?? '');
    _specTextCtrl = TextEditingController(text: d?.specificationText ?? '');
    _category = d?.category;
    _status = d?.status ?? 'ร่าง';
    _orderId = d?.orderId;
  }

  @override
  void dispose() {
    _documentNumberCtrl.dispose();
    _titleCtrl.dispose();
    _estimatedAmountCtrl.dispose();
    _specTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromTemplate() async {
    final templates = await _repo.getAllTorTemplates();
    if (!mounted) return;
    if (templates.isEmpty) {
      showAppToast('ยังไม่มี Template ที่บันทึกไว้');
      return;
    }
    final selected = await showDialog<TorTemplate>(
      context: context,
      builder: (ctx) => _TemplatePickerDialog(templates: templates, repo: _repo),
    );
    if (selected != null) {
      setState(() {
        if (selected.category != null) _category = selected.category;
        _specTextCtrl.text = selected.specificationText ?? '';
      });
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_specTextCtrl.text.trim().isEmpty) {
      showAppToast('กรุณากรอกรายละเอียดคุณลักษณะเฉพาะก่อนบันทึกเป็น Template', isError: true);
      return;
    }
    final nameCtrl = TextEditingController(text: _titleCtrl.text.trim());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('บันทึกเป็น Template'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ชื่อ Template', hintText: 'เช่น เครื่องคอมพิวเตอร์แบบตั้งโต๊ะ (สพฐ.)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _repo.insertTorTemplate(TorTemplate(
      name: name,
      category: _category,
      specificationText: _specTextCtrl.text.trim(),
    ));
    if (!mounted) return;
    showAppToast('บันทึก Template "$name" แล้ว');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final doc = TorDocument(
      id: widget.existing?.id,
      documentNumber: _documentNumberCtrl.text.trim().isEmpty ? null : _documentNumberCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      category: _category,
      estimatedAmount: double.tryParse(_estimatedAmountCtrl.text.trim()),
      createdDate: widget.existing?.createdDate ?? _todayThai(),
      status: _status,
      specificationText: _specTextCtrl.text.trim().isEmpty ? null : _specTextCtrl.text.trim(),
      orderId: _orderId,
    );
    if (widget.existing == null) {
      await _repo.insertTorDocument(doc);
    } else {
      await _repo.updateTorDocument(doc);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไข TOR / คุณลักษณะเฉพาะ' : 'เพิ่ม TOR / คุณลักษณะเฉพาะ'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_documentNumberCtrl, 'เลขที่'),
                _field(_titleCtrl, 'ชื่อโครงการ/รายชื่อพัสดุ *', required: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int?>(
                    initialValue: _orderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'ผูกกับรายการจัดซื้อจัดจ้าง (สำหรับออกเอกสาร Word)',
                      border: OutlineInputBorder(), isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('(ไม่ผูก)')),
                      ...widget.orders.where((o) => o.id != null).map((o) => DropdownMenuItem<int?>(
                            value: o.id,
                            child: Text(o.projectName ?? o.procurementSubject ?? 'เอกสาร #${o.id}', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _orderId = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'ประเภท', border: OutlineInputBorder(), isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ..._torCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                _field(_estimatedAmountCtrl, 'วงเงินโดยประมาณ (บาท)', keyboardType: TextInputType.number),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'สถานะ', border: OutlineInputBorder(), isDense: true,
                    ),
                    items: _torStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'ร่าง'),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รายละเอียดคุณลักษณะเฉพาะ', style: TextStyle(fontSize: 12.5)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: _pickFromTemplate,
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('เลือกจาก Template'),
                        ),
                        TextButton.icon(
                          onPressed: _saveAsTemplate,
                          icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                          label: const Text('บันทึกเป็น Template'),
                        ),
                      ],
                    ),
                  ],
                ),
                _field(_specTextCtrl, 'รายละเอียดคุณลักษณะเฉพาะ', maxLines: 6),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(), isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null
            : null,
      ),
    );
  }
}

class _TemplatePickerDialog extends StatefulWidget {
  final List<TorTemplate> templates;
  final ProcurementRepository repo;
  const _TemplatePickerDialog({required this.templates, required this.repo});

  @override
  State<_TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<_TemplatePickerDialog> {
  late List<TorTemplate> _templates;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _templates = widget.templates;
  }

  Future<void> _delete(TorTemplate t) async {
    if (t.id == null) return;
    await widget.repo.deleteTorTemplate(t.id!);
    setState(() => _templates = _templates.where((x) => x.id != t.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _query.isEmpty
        ? _templates
        : _templates.where((t) => t.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('เลือกจาก Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 20), hintText: 'ค้นหา Template'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('ไม่พบ Template', style: TextStyle(color: colors.onSurfaceVariant))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final t = filtered[i];
                          return ListTile(
                            dense: true,
                            title: Text(t.name),
                            subtitle: t.category != null ? Text(t.category!) : null,
                            onTap: () => Navigator.pop(context, t),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _delete(t),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
