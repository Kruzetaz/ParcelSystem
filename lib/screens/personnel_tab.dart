// personnel_tab.dart
// แท็บ "บุคลากร" ในหน้าตั้งค่า — ทำเนียบครู/เจ้าหน้าที่กลางของโรงเรียน ให้ทุก
// ช่องกรอกชื่อ-ตำแหน่งทั่วแอป (เช่น wizard Tab 2) เลือกใช้ซ้ำได้แทนพิมพ์เอง
// แก้ที่นี่ที่เดียว ทุกจุดที่อ้างอิงชื่อนี้จะเห็นตำแหน่ง/เบอร์ล่าสุดตรงกัน

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/personnel.dart';
import '../services/toast_service.dart';
import '../widgets/memory_text_field.dart';

/// ตำแหน่งที่พบบ่อย — ตรึงไว้บนสุดของ dropdown ช่อง "ตำแหน่ง" เสมอ ยังพิมพ์
/// ตำแหน่งอื่นเองได้ตามปกติ
const commonPositions = [
  'ผู้อำนวยการ',
  'รองผู้อำนวยการ',
  'ครูผู้ช่วย',
  'ครู',
  'ครูชำนาญการ',
  'ครูชำนาญการพิเศษ',
  'ครูเชี่ยวชาญ',
  'ครูเชี่ยวชาญพิเศษ',
  'เจ้าหน้าที่พัสดุ',
  'หัวหน้าเจ้าหน้าที่พัสดุ',
  'เจ้าหน้าที่การเงิน',
  'ครูธุรการ',
];

class PersonnelTab extends StatefulWidget {
  const PersonnelTab({super.key});

  @override
  State<PersonnelTab> createState() => _PersonnelTabState();
}

class _PersonnelTabState extends State<PersonnelTab> {
  final _repo = ProcurementRepository();
  List<Personnel> _people = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllPersonnel();
    if (!mounted) return;
    setState(() {
      _people = list;
      _loading = false;
    });
  }

  List<Personnel> get _filtered => _query.isEmpty
      ? _people
      : _people.where((p) =>
          p.name.toLowerCase().contains(_query) ||
          (p.position ?? '').toLowerCase().contains(_query)).toList();

  Future<void> _openForm({Personnel? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PersonnelFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Personnel person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "${person.name}" ออกจากทำเนียบบุคลากรใช่หรือไม่?'),
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
    if (confirmed == true && person.id != null) {
      await _repo.deletePersonnel(person.id!);
      if (!mounted) return;
      showAppToast('ลบบุคลากรแล้ว');
      _load();
    }
  }

  Color _positionColor(ColorScheme colors, String? position) {
    if (position == null || position.isEmpty) return colors.surfaceContainerHighest;
    if (position.contains('ผู้อำนวยการ')) return Colors.indigo;
    if (position.contains('ชำนาญการพิเศษ')) return Colors.deepOrange;
    if (position.contains('ชำนาญการ')) return Colors.orange;
    if (position.contains('เชี่ยวชาญ')) return Colors.purple;
    if (position.contains('ผู้ช่วย')) return Colors.blueGrey;
    if (position.contains('พัสดุ') || position.contains('การเงิน')) return Colors.teal;
    return colors.primary;
  }

  static const _positionColW = 160.0;
  static const _phoneColW = 130.0;
  static const _statusColW = 84.0;
  static const _actionsColW = 88.0;

  Widget _buildHeaderRow(ColorScheme colors) {
    final style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('ชื่อ-นามสกุล', style: style)),
          const SizedBox(width: 12),
          SizedBox(width: _positionColW, child: Text('ตำแหน่ง', style: style)),
          const SizedBox(width: 12),
          SizedBox(width: _phoneColW, child: Text('เบอร์โทรศัพท์', style: style)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('อีเมล', style: style)),
          SizedBox(width: _statusColW, child: Text('', style: style)),
          SizedBox(width: _actionsColW, child: Text('', style: style)),
        ],
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, Personnel p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(10),
        color: p.active ? null : colors.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(p.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _positionColW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: (p.position?.trim().isNotEmpty ?? false)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _positionColor(colors, p.position),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p.position!,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    )
                  : Text('-', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _phoneColW,
            child: Text(p.phone ?? '-', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(p.email ?? '-',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: _statusColW,
            child: !p.active
                ? Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
                    child: const Text('ปิดใช้งาน', style: TextStyle(fontSize: 11)),
                  )
                : null,
          ),
          SizedBox(
            width: _actionsColW,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'แก้ไข',
                  onPressed: () => _openForm(existing: p),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'ลบ',
                  onPressed: () => _confirmDelete(p),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'ค้นหาชื่อ/ตำแหน่ง',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.badge_outlined, size: 64, color: colors.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text(
                                  _people.isEmpty ? 'ยังไม่มีข้อมูลบุคลากร\nกด "เพิ่มบุคลากร" เพื่อเริ่มต้น' : 'ไม่พบรายการที่ตรงกับคำค้นหา',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderRow(colors),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  itemCount: _filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _buildRow(colors, _filtered[i]),
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: FloatingActionButton.extended(
            heroTag: 'personnel_add_fab',
            onPressed: () => _openForm(),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มบุคลากร'),
          ),
        ),
      ],
    );
  }
}

class _PersonnelFormDialog extends StatefulWidget {
  final Personnel? existing;
  const _PersonnelFormDialog({this.existing});

  @override
  State<_PersonnelFormDialog> createState() => _PersonnelFormDialogState();
}

class _PersonnelFormDialogState extends State<_PersonnelFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _positionCtrl = TextEditingController(text: p?.position ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final person = Personnel(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      position: _positionCtrl.text.trim().isEmpty ? null : _positionCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      active: _active,
    );
    if (widget.existing == null) {
      await _repo.insertPersonnel(person);
    } else {
      await _repo.updatePersonnel(person);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขบุคลากร' : 'เพิ่มบุคลากร'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล *', border: OutlineInputBorder(), isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MemoryTextField(
                    fieldKey: 'personnel.position',
                    controller: _positionCtrl,
                    presetOptions: commonPositions,
                    decoration: const InputDecoration(labelText: 'ตำแหน่ง', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'อีเมล', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ใช้งานอยู่'),
                  subtitle: const Text('ปิดไว้เพื่อซ่อนจากตัวเลือกโดยไม่ต้องลบประวัติ', style: TextStyle(fontSize: 12)),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
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
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
