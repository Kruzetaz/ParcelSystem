// work_groups_tab.dart
// แท็บ "กลุ่มงาน" ในหน้าตั้งค่า — ตารางจัดการกลุ่มงาน/ฝ่ายได้จริง แทนที่
// budgetDepartmentGroups ที่เคยล็อกเป็น 5 ค่าคงที่ในโค้ด แต่ละกลุ่มงานกำหนด
// "หัวหน้ากลุ่มงาน" ได้ (เลือกจากทำเนียบบุคลากร)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/personnel.dart';
import '../models/work_group.dart';
import '../services/toast_service.dart';
import '../widgets/memory_text_field.dart';

class WorkGroupsTab extends StatefulWidget {
  const WorkGroupsTab({super.key});

  @override
  State<WorkGroupsTab> createState() => _WorkGroupsTabState();
}

class _WorkGroupsTabState extends State<WorkGroupsTab> {
  final _repo = ProcurementRepository();
  List<WorkGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllWorkGroups();
    if (!mounted) return;
    setState(() {
      _groups = list;
      _loading = false;
    });
  }

  Future<void> _openForm({WorkGroup? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _WorkGroupFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(WorkGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบกลุ่มงาน "${group.name}" ใช่หรือไม่?\n(แผนงบที่เคยใช้กลุ่มงานนี้จะยังคงข้อความเดิมไว้)'),
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
    if (confirmed == true && group.id != null) {
      await _repo.deleteWorkGroup(group.id!);
      if (!mounted) return;
      showAppToast('ลบกลุ่มงานแล้ว');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _groups.isEmpty
                  ? Center(
                      child: Text('ยังไม่มีกลุ่มงาน\nกด "เพิ่มกลุ่มงาน" เพื่อเริ่มต้น',
                        textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final g = _groups[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(10),
                            color: g.active ? null : colors.surfaceContainerHighest.withValues(alpha: 0.4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(g.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  (g.headName?.trim().isNotEmpty ?? false) ? 'หัวหน้า: ${g.headName}' : 'ยังไม่กำหนดหัวหน้ากลุ่มงาน',
                                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!g.active)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('ปิดใช้งาน', style: TextStyle(fontSize: 11)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'แก้ไข',
                                onPressed: () => _openForm(existing: g),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'ลบ',
                                onPressed: () => _confirmDelete(g),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: FloatingActionButton.extended(
            heroTag: 'work_group_add_fab',
            onPressed: () => _openForm(),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มกลุ่มงาน'),
          ),
        ),
      ],
    );
  }
}

class _WorkGroupFormDialog extends StatefulWidget {
  final WorkGroup? existing;
  const _WorkGroupFormDialog({this.existing});

  @override
  State<_WorkGroupFormDialog> createState() => _WorkGroupFormDialogState();
}

class _WorkGroupFormDialogState extends State<_WorkGroupFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _headNameCtrl;
  late bool _active;
  bool _saving = false;
  List<Personnel> _personnel = [];

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _headNameCtrl = TextEditingController(text: g?.headName ?? '');
    _active = g?.active ?? true;
    _loadPersonnel();
  }

  Future<void> _loadPersonnel() async {
    final list = await _repo.getAllPersonnel(activeOnly: true);
    if (!mounted) return;
    setState(() => _personnel = list);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _headNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final group = WorkGroup(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      headName: _headNameCtrl.text.trim().isEmpty ? null : _headNameCtrl.text.trim(),
      active: _active,
    );
    if (widget.existing == null) {
      await _repo.insertWorkGroup(group);
    } else {
      await _repo.updateWorkGroup(group);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขกลุ่มงาน' : 'เพิ่มกลุ่มงาน'),
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
                    decoration: const InputDecoration(labelText: 'ชื่อกลุ่มงาน/ฝ่าย *', border: OutlineInputBorder(), isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อกลุ่มงาน' : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MemoryTextField(
                    fieldKey: 'workgroup.headName',
                    presetOptions: _personnel.map((p) => p.name).toList(),
                    controller: _headNameCtrl,
                    decoration: const InputDecoration(labelText: 'หัวหน้ากลุ่มงาน', border: OutlineInputBorder(), isDense: true),
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
