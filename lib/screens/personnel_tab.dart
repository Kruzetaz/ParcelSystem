// personnel_tab.dart
// แท็บ "บุคลากร" ในหน้าตั้งค่า — ทำเนียบครู/เจ้าหน้าที่กลางของโรงเรียน ให้ทุก
// ช่องกรอกชื่อ-ตำแหน่งทั่วแอป (เช่น wizard Tab 2) เลือกใช้ซ้ำได้แทนพิมพ์เอง
// แก้ที่นี่ที่เดียว ทุกจุดที่อ้างอิงชื่อนี้จะเห็นตำแหน่ง/เบอร์ล่าสุดตรงกัน

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/personnel.dart';
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

/// เดิมฟอร์มนี้ใช้ `border: OutlineInputBorder()` เปล่าๆ (ไม่ระบุสี) ในทุกช่อง
/// กรอก ซึ่งเมื่อ decoration.border ถูกกำหนดเอง Flutter จะ "ทับ" ค่า default
/// จาก InputDecorationTheme ของธีมทั้งหมด (ไม่ fallback ไปที่ enabledBorder/
/// focusedBorder ของธีม) ผลคือช่องกรอกทุกช่องมีเส้นขอบดำเถื่อนตายตัว ไม่ตอบ
/// สนองธีมสว่าง/มืดเลย — เปลี่ยนมาใช้สูตร `_dialogFieldDecoration` เดียวกับที่
/// ใช้แก้ปัญหานี้ในหน้าอื่น (contracts_screen, guarantees_screen ฯลฯ) แทน
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
  // สไตล์กล่องยืนยัน — เหมือนกับที่ใช้ในหน้าแผนงบประมาณ (ธีมกลางตั้ง
  // titleLarge/labelLarge ไว้เล็กสำหรับตารางหนาแน่น ไม่เหมาะกับกล่องโต้ตอบ)
  static const _dialogTitleStyle =
      TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
  static const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
  static const _dialogButtonTextStyle =
      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
  static const _dialogButtonPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  final _repo = ProcurementRepository();
  List<Personnel> _people = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
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
      : _people
          .where((p) =>
              p.name.toLowerCase().contains(_query) ||
              (p.position ?? '').toLowerCase().contains(_query))
          .toList();

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
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text(
            'ต้องการลบ "${person.name}" ออกจากทำเนียบบุคลากรใช่หรือไม่?',
            style: _dialogContentStyle),
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
    if (confirmed == true && person.id != null) {
      await _repo.deletePersonnel(person.id!);
      if (!mounted) return;
      showAppToast('ลบบุคลากรแล้ว');
      _load();
    }
  }

  Color _positionColor(ColorScheme colors, String? position) {
    if (position == null || position.isEmpty) return colors.onSurfaceVariant;
    if (position.contains('ผู้อำนวยการ')) return Colors.indigo;
    if (position.contains('ชำนาญการพิเศษ')) return Colors.deepOrange;
    if (position.contains('ชำนาญการ')) return Colors.orange;
    if (position.contains('เชี่ยวชาญ')) return Colors.purple;
    if (position.contains('ผู้ช่วย')) return Colors.blueGrey;
    if (position.contains('พัสดุ') || position.contains('การเงิน'))
      return Colors.teal;
    return colors.primary;
  }

  /// ป้ายตำแหน่งแบบ pill โปร่งแสง + จุดนำหน้า — ทำตามสูตรเดียวกับ StatusBadge
  /// (compact:true) ในหน้าหลักเป๊ะๆ แต่ StatusBadge เองรับได้แค่สีตาม
  /// BadgeVariant ที่กำหนดไว้ล่วงหน้า (ไม่พอกับจำนวนสีตามตำแหน่งที่หลากหลาย
  /// กว่านั้นในทำเนียบบุคลากร) เลยทำ pill รับสีเองได้อิสระแทน
  Widget _positionPill(BuildContext context, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RadiusSize.xxl),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)
              ],
            ),
          ),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: AppTypography.mini,
                  fontWeight: AppTypography.weightBold,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ระยะห่างระหว่างคอลัมน์ — เดิมไม่มีเลย ทำให้ป้ายตำแหน่ง/ข้อมูลคอลัมน์ถัดไป
  // ดูติดกันเกินไป
  static const _spacing = 22.0;

  // ตรงกับ DsColumn ที่ตารางหลักในหน้าแดชบอร์ดใช้ — ทำให้ตารางในหน้านี้เป็น
  // การ์ดตารางเดียวกันเลย (หัวตารางพื้นเข้ม + แถวสลับสี zebra + hover) แทนที่
  // จะเป็นการ์ดย่อยลอยแยกทีละแถวแบบเดิม
  static const _columns = [
    DsColumn('ชื่อ-นามสกุล', flex: 2),
    DsColumn('ตำแหน่ง', width: 160),
    DsColumn('เบอร์โทรศัพท์', width: 130),
    DsColumn('อีเมล', flex: 2),
    DsColumn('สถานะ', width: 84),
    DsColumn('', width: 68),
  ];

  Widget _buildRow(ColorScheme colors, Personnel p, int index) {
    return DsTableRow(
      index: index,
      spacing: _spacing,
      onTap: () => _openForm(existing: p),
      cells: [
        DsCell(
          column: _columns[0],
          child: Text(p.name,
              style: TextStyle(
                  fontWeight: AppTypography.weightSemiBold,
                  fontSize: AppTypography.body,
                  color: colors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        DsCell(
          column: _columns[1],
          child: (p.position?.trim().isNotEmpty ?? false)
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: _positionPill(
                      context, _positionColor(colors, p.position), p.position!),
                )
              : Text('-', style: TextStyle(color: colors.onSurfaceVariant)),
        ),
        DsCell(
          column: _columns[2],
          child: Text(p.phone ?? '-',
              style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTypography.bodyMedium)),
        ),
        DsCell(
          column: _columns[3],
          child: Text(p.email ?? '-',
              style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTypography.bodyMedium),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        DsCell(
          column: _columns[4],
          child: Align(
            alignment: Alignment.center,
            child: StatusBadge(
              label: p.active ? 'ใช้งานอยู่' : 'ปิดใช้งาน',
              variant: p.active ? BadgeVariant.success : BadgeVariant.neutral,
              compact: true,
            ),
          ),
        ),
        DsCell(
          column: _columns[5],
          child: DsActionIconButtons(
            actions: [
              DsRowAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'แก้ไข',
                  onTap: () => _openForm(existing: p)),
              DsRowAction(
                  icon: Icons.delete_outline,
                  tooltip: 'ลบ',
                  onTap: () => _confirmDelete(p),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(
                          fontSize: AppTypography.bodyMedium,
                          color: colors.onSurface),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'ค้นหาชื่อ/ตำแหน่ง',
                        hintStyle: TextStyle(
                            fontSize: AppTypography.bodyMedium,
                            color: colors.onSurfaceVariant),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(RadiusSize.md),
                          borderSide: BorderSide(color: colors.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(RadiusSize.md),
                          borderSide: BorderSide(color: colors.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(RadiusSize.md),
                          borderSide: BorderSide(
                              color: BrandAccent.teal(context), width: 1.5),
                        ),
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
                                Icon(Icons.badge_outlined,
                                    size: 64, color: colors.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text(
                                  _people.isEmpty
                                      ? 'ยังไม่มีข้อมูลบุคลากร\nกด "เพิ่มบุคลากร" เพื่อเริ่มต้น'
                                      : 'ไม่พบรายการที่ตรงกับคำค้นหา',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        // ตารางเดียวห่อด้วย AppCard เหมือนตารางหลักในหน้าแดชบอร์ด
                        // (หัวตาราง + แถว zebra/hover ของ DsTableHeader/DsTableRow)
                        // แทนที่การ์ดย่อยแยกทีละแถวแบบเดิม ให้เป็นชุดตารางเดียว
                        //
                        // [แก้บั๊ก RenderFlex unbounded height]: AppCard ห่อ
                        // child ด้วย Padding เฉยๆ ไม่ได้ครอบ Expanded ให้ (ถูก
                        // ออกแบบมาสำหรับเนื้อหาสูงตามธรรมชาติ ไม่ใช่เนื้อหาที่
                        // ต้อง "เติมพื้นที่ที่เหลือ") พอใส่ ListView.builder ใน
                        // Expanded ไว้ข้างในเลยเจอ unbounded height constraint
                        // แตก (Padding ไม่บีบความสูงให้ลูกที่ไม่ใช่ flex child)
                        // แก้โดยเลิกสกอลล์ในการ์ด ให้การ์ดสูงตามเนื้อหาจริง
                        // (แสดงทุกแถวตรงๆ แบบเดียวกับตารางหลักในหน้าแดชบอร์ด)
                        // แล้วให้ทั้งหน้าเลื่อนแทนด้วย SingleChildScrollView
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
                                        'ทำเนียบบุคลากร',
                                        style: TextStyle(
                                            fontSize: AppTypography.heading4,
                                            fontWeight:
                                                AppTypography.weightExtraBold,
                                            color: colors.onSurface),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: BrandAccent.surface2(context),
                                          borderRadius: BorderRadius.circular(
                                              RadiusSize.full),
                                        ),
                                        child: Text(
                                          '${_filtered.length} คน',
                                          style: TextStyle(
                                              fontSize: AppTypography.micro,
                                              fontWeight:
                                                  AppTypography.weightBold,
                                              color: colors.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      DsTableHeader(
                                          columns: _columns, spacing: _spacing),
                                      for (var i = 0; i < _filtered.length; i++)
                                        _buildRow(colors, _filtered[i], i),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
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
      position:
          _positionCtrl.text.trim().isEmpty ? null : _positionCtrl.text.trim(),
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
      title: Text(
        isEdit ? 'แก้ไขบุคลากร' : 'เพิ่มบุคลากร',
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
                    decoration: _dialogFieldDecoration(context, label: 'ชื่อ-นามสกุล *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกชื่อ'
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MemoryTextField(
                    fieldKey: 'personnel.position',
                    controller: _positionCtrl,
                    presetOptions: commonPositions,
                    decoration: _dialogFieldDecoration(context, label: 'ตำแหน่ง'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _phoneCtrl,
                    style: _dialogFieldStyle,
                    keyboardType: TextInputType.phone,
                    decoration: _dialogFieldDecoration(context, label: 'เบอร์โทรศัพท์'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _emailCtrl,
                    style: _dialogFieldStyle,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dialogFieldDecoration(context, label: 'อีเมล'),
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
