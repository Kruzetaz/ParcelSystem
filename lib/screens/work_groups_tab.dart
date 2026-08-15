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
import '../theme/design_tokens.dart';
import '../widgets/design_system/data_table_shell.dart'
    show
        DsActionIconButtons,
        DsRowAction,
        DsColumn,
        DsTableHeader,
        DsTableRow,
        DsCell;
import '../widgets/design_system/app_card.dart';
import '../widgets/design_system/status_badge.dart'
    show StatusBadge, BadgeVariant;

const _dialogLabelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
const _dialogFieldStyle = TextStyle(fontSize: 17);

/// เดิมฟอร์มนี้ใช้ `border: OutlineInputBorder()` เปล่าๆ (ไม่ระบุสี) ซึ่งเมื่อ
/// decoration.border ถูกกำหนดเอง Flutter จะทับค่า default จาก
/// InputDecorationTheme ของธีมทั้งหมด ผลคือช่องกรอกมีเส้นขอบดำเถื่อนตายตัว
/// ไม่ตอบสนองธีมสว่าง/มืด — เปลี่ยนมาใช้สูตร `_dialogFieldDecoration` เดียวกับ
/// ที่ใช้แก้ปัญหานี้ในหน้าอื่น (contracts_screen, guarantees_screen ฯลฯ) แทน
InputDecoration _dialogFieldDecoration(BuildContext context, {required String label}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    labelStyle: _dialogLabelStyle.copyWith(color: colors.onSurfaceVariant),
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

class WorkGroupsTab extends StatefulWidget {
  const WorkGroupsTab({super.key});

  @override
  State<WorkGroupsTab> createState() => _WorkGroupsTabState();
}

class _WorkGroupsTabState extends State<WorkGroupsTab> {
  static const _dialogTitleStyle =
      TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
  static const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
  static const _dialogButtonTextStyle =
      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
  static const _dialogButtonPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 12);

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
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text(
          'ต้องการลบกลุ่มงาน "${group.name}" ใช่หรือไม่?\n(แผนงบที่เคยใช้กลุ่มงานนี้จะยังคงข้อความเดิมไว้)',
          style: _dialogContentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: _dialogButtonPadding,
              textStyle: _dialogButtonTextStyle,
            ),
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

  // ระยะห่างระหว่างคอลัมน์ — เดิมไม่มีเลย ทำให้ชื่อกลุ่มงาน/หัวหน้ากลุ่มงาน
  // ดูติดกันเกินไปเวลาชื่อยาว
  static const _spacing = 14.0;

  static const _columns = [
    DsColumn('ชื่อกลุ่มงาน/ฝ่าย', flex: 2),
    DsColumn('หัวหน้ากลุ่มงาน', flex: 2),
    DsColumn('สถานะ', width: 84),
    DsColumn('', width: 68),
  ];

  Widget _buildRow(ColorScheme colors, WorkGroup g, int index) {
    return DsTableRow(
      index: index,
      spacing: _spacing,
      onTap: () => _openForm(existing: g),
      cells: [
        DsCell(
          column: _columns[0],
          child: Text(g.name,
              style: TextStyle(
                  fontWeight: AppTypography.weightSemiBold,
                  fontSize: AppTypography.body,
                  color: colors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        DsCell(
          column: _columns[1],
          child: Text(
            (g.headName?.trim().isNotEmpty ?? false)
                ? g.headName!
                : 'ยังไม่กำหนดหัวหน้ากลุ่มงาน',
            style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTypography.bodyMedium),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DsCell(
          column: _columns[2],
          child: Align(
            alignment: Alignment.center,
            child: StatusBadge(
              label: g.active ? 'ใช้งานอยู่' : 'ปิดใช้งาน',
              variant: g.active ? BadgeVariant.success : BadgeVariant.neutral,
              compact: true,
            ),
          ),
        ),
        DsCell(
          column: _columns[3],
          child: DsActionIconButtons(
            actions: [
              DsRowAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'แก้ไข',
                  onTap: () => _openForm(existing: g)),
              DsRowAction(
                  icon: Icons.delete_outline,
                  tooltip: 'ลบ',
                  onTap: () => _confirmDelete(g),
                  danger: true),
            ],
          ),
        ),
      ],
    );
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined,
                              size: 64, color: colors.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                              'ยังไม่มีกลุ่มงาน\nกด "เพิ่มกลุ่มงาน" เพื่อเริ่มต้น',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 15)),
                        ],
                      ),
                    )
                  // [แก้บั๊ก RenderFlex unbounded height]: AppCard ห่อ child
                  // ด้วย Padding เฉยๆ ไม่มี Expanded ให้ — ใส่ ListView.builder
                  // ใน Expanded ไว้ข้างในตรงๆ แล้วชนกับ unbounded height
                  // constraint แตกทันที เปลี่ยนมาแสดงทุกแถวตรงๆ (ไม่สกอลล์ใน
                  // การ์ด) แล้วให้ทั้งหน้าเลื่อนแทนด้วย SingleChildScrollView
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppCard(
                            padding: EdgeInsets.zero,
                            titleWidget: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'กลุ่มงาน/ฝ่าย',
                                  style: TextStyle(
                                      fontSize: AppTypography.heading4,
                                      fontWeight: AppTypography.weightExtraBold,
                                      color: colors.onSurface),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: BrandAccent.surface2(context),
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.full),
                                  ),
                                  child: Text(
                                    '${_groups.length} กลุ่ม',
                                    style: TextStyle(
                                        fontSize: AppTypography.micro,
                                        fontWeight: AppTypography.weightBold,
                                        color: colors.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DsTableHeader(
                                    columns: _columns, spacing: _spacing),
                                for (var i = 0; i < _groups.length; i++)
                                  _buildRow(colors, _groups[i], i),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
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
      headName:
          _headNameCtrl.text.trim().isEmpty ? null : _headNameCtrl.text.trim(),
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
      title: Text(
        isEdit ? 'แก้ไขกลุ่มงาน' : 'เพิ่มกลุ่มงาน',
        style: const TextStyle(
            fontSize: AppTypography.heading2,
            fontWeight: AppTypography.weightExtraBold),
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _nameCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context, label: 'ชื่อกลุ่มงาน/ฝ่าย *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกชื่อกลุ่มงาน'
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MemoryTextField(
                    fieldKey: 'workgroup.headName',
                    presetOptions: _personnel.map((p) => p.name).toList(),
                    controller: _headNameCtrl,
                    decoration: _dialogFieldDecoration(context, label: 'หัวหน้ากลุ่มงาน'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ใช้งานอยู่',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'ปิดไว้เพื่อซ่อนจากตัวเลือกโดยไม่ต้องลบประวัติ',
                      style: TextStyle(fontSize: 13)),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BrandAccent.teal(context),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
