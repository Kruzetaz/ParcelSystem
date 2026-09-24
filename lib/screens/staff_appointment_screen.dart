// staff_appointment_screen.dart
// คำสั่งแต่งตั้งหัวหน้าเจ้าหน้าที่พัสดุ/เจ้าหน้าที่พัสดุ ประจำปีงบประมาณ —
// แยกออกมาจากตรวจนับพัสดุประจำปี เพราะเป็นคำสั่งแต่งตั้งบุคคล ไม่ใช่คำสั่ง
// เกี่ยวกับการตรวจนับ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/staff_appointment_order.dart';
import '../models/personnel.dart';
import '../services/staff_appointment_document_service.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../widgets/memory_text_field.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/status_badge.dart'
    show StatusBadge, BadgeVariant;
import '../widgets/design_system/data_table_shell.dart'
    show DsActionIconButtons, DsRowAction;
import '../widgets/design_system/clearable_text_field.dart';

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle =
    TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

/// สร้างกรอบช่องกรอกในป๊อปอัพให้ชัดเจนกว่าค่าเริ่มต้นของธีม (colors.outline
/// จางเกินไปสำหรับช่องกรอกเดี่ยวๆ ที่ไม่มีเงา/สีพื้นต่างช่วยตัดขอบ)
InputDecoration _dialogFieldDecoration(BuildContext context,
    {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.outline;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(
        color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
    ),
  );
}

const _thaiMonths = [
  '',
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];
String _formatThai(DateTime d) =>
    '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';
String _currentFiscalYear() {
  final now = DateTime.now();
  final buddhistYear = now.year + 543;
  return now.month >= 10 ? '${buddhistYear + 1}' : '$buddhistYear';
}

class StaffAppointmentScreen extends StatefulWidget {
  const StaffAppointmentScreen({super.key});
  @override
  State<StaffAppointmentScreen> createState() => _StaffAppointmentScreenState();
}

class _StaffAppointmentScreenState extends State<StaffAppointmentScreen> {
  final _repo = ProcurementRepository();
  List<StaffAppointmentOrder> _orders = [];
  bool _loading = true;
  int? _printingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllStaffAppointmentOrders();
    if (!mounted) return;
    setState(() {
      _orders = list;
      _loading = false;
    });
  }

  Future<void> _openForm({StaffAppointmentOrder? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StaffAppointmentFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(StaffAppointmentOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบคำสั่งแต่งตั้งปี ${o.fiscalYear} ใช่หรือไม่?',
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
                textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && o.id != null) {
      await _repo.deleteStaffAppointmentOrder(o.id!);
      _load();
    }
  }

  Future<void> _printOrder(StaffAppointmentOrder o) async {
    if (o.staff.isEmpty) {
      showAppToast('กรุณากรอกรายชื่อผู้ได้รับแต่งตั้งก่อนพิมพ์เอกสาร',
          isError: true);
      return;
    }
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน',
          isError: true);
      return;
    }
    setState(() => _printingId = o.id);
    try {
      await StaffAppointmentDocumentService.exportAndOpen(
          order: o, school: school);
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _printingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าแต่งตั้งเจ้าหน้าที่พัสดุ',
      icon: Icons.badge_outlined,
      steps: const [
        'ใช้บันทึกคำสั่งแต่งตั้งหัวหน้าเจ้าหน้าที่พัสดุ/เจ้าหน้าที่พัสดุ ประจำปีงบประมาณ — แยกต่างหากจากตรวจนับพัสดุประจำปี เพราะเป็นคำสั่งแต่งตั้งบุคคล',
        'กด "เพิ่มคำสั่ง" มุมขวาล่าง กรอกเลขที่/วันที่คำสั่ง วันที่มีผล และรายชื่อผู้ได้รับแต่งตั้ง (เลือกจากทำเนียบบุคลากรได้)',
        'กดไอคอนพิมพ์ที่การ์ดแต่ละรอบเพื่อสร้างเอกสาร Word ตามแบบคำสั่งที่กรอกไว้',
      ],
      corner: Alignment.bottomLeft,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            color: BrandAccent.tealOn(context), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('แต่งตั้งเจ้าหน้าที่พัสดุ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: AppTypography.heading2,
                                  fontWeight: AppTypography.weightExtraBold,
                                  color: colors.onSurface)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _orders.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.badge_outlined,
                                          size: 64,
                                          color: colors.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text(
                                          'ยังไม่มีคำสั่งแต่งตั้งเจ้าหน้าที่พัสดุ\nกด "เพิ่มคำสั่ง" เพื่อเริ่มต้น',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              fontSize:
                                                  AppTypography.heading4)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _orders.length,
                                  padding: const EdgeInsets.only(bottom: 80),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) =>
                                      _buildCard(context, colors, _orders[i]),
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
              heroTag: 'staff_appointment_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มคำสั่ง'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, ColorScheme colors, StaffAppointmentOrder o) {
    final isPrintingThis = _printingId == o.id;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(existing: o),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandAccent.teal(context)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(RadiusSize.sm),
                          ),
                          child: Text('ปี ${o.fiscalYear}',
                              style: TextStyle(
                                  fontSize: AppTypography.caption,
                                  color: BrandAccent.tealOn(context),
                                  fontWeight: AppTypography.weightSemiBold)),
                        ),
                        if (o.orderNumber != null &&
                            o.orderNumber!.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          StatusBadge(
                              label: 'ที่ ${o.orderNumber}',
                              variant: BadgeVariant.info,
                              compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'ผู้ได้รับแต่งตั้ง ${o.staff.length} คน  ·  วันที่คำสั่ง ${o.orderDate ?? "-"}',
                        style: TextStyle(
                            fontSize: AppTypography.bodyMedium,
                            color: colors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (isPrintingThis)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RadiusSize.sm),
                    border: Border.all(color: colors.outline),
                  ),
                  child: const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              DsActionIconButtons(
                actions: [
                  if (!isPrintingThis)
                    DsRowAction(
                        icon: Icons.print_outlined,
                        tooltip: 'พิมพ์คำสั่ง',
                        onTap: () => _printOrder(o)),
                  DsRowAction(
                      icon: Icons.delete_outline,
                      tooltip: 'ลบ',
                      onTap: () => _confirmDelete(o),
                      danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffAppointmentFormDialog extends StatefulWidget {
  final StaffAppointmentOrder? existing;
  const _StaffAppointmentFormDialog({this.existing});
  @override
  State<_StaffAppointmentFormDialog> createState() =>
      _StaffAppointmentFormDialogState();
}

class _StaffAppointmentFormDialogState
    extends State<_StaffAppointmentFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fiscalYearCtrl;
  late final TextEditingController _orderNumberCtrl;
  String? _orderDate;
  String? _effectiveDate;
  bool _saving = false;
  late List<StaffAppointmentMember> _staff;
  late List<TextEditingController> _nameCtrls;
  late List<TextEditingController> _positionCtrls;
  List<Personnel> _personnel = [];

  @override
  void initState() {
    super.initState();
    final o = widget.existing;
    _fiscalYearCtrl =
        TextEditingController(text: o?.fiscalYear ?? _currentFiscalYear());
    _orderNumberCtrl = TextEditingController(text: o?.orderNumber ?? '');
    _orderDate = o?.orderDate;
    _effectiveDate = o?.effectiveDate;
    _staff = List.of(o?.staff ?? const []);
    _nameCtrls = [for (final s in _staff) TextEditingController(text: s.name)];
    _positionCtrls = [
      for (final s in _staff) TextEditingController(text: s.position)
    ];
    _loadPersonnel();
  }

  Future<void> _loadPersonnel() async {
    final list = await _repo.getAllPersonnel(activeOnly: true);
    if (!mounted) return;
    setState(() => _personnel = list);
  }

  @override
  void dispose() {
    _fiscalYearCtrl.dispose();
    _orderNumberCtrl.dispose();
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _positionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(
      String helpText, String? current, void Function(String) onPicked) async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 1),
      helpText: helpText,
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => onPicked(_formatThai(picked)));
  }

  void _addStaff() {
    setState(() {
      _staff = [
        ..._staff,
        const StaffAppointmentMember(name: '', role: 'เจ้าหน้าที่พัสดุ')
      ];
      _nameCtrls = [..._nameCtrls, TextEditingController()];
      _positionCtrls = [..._positionCtrls, TextEditingController()];
    });
  }

  void _removeStaff(int i) {
    setState(() {
      _staff = [..._staff]..removeAt(i);
      _nameCtrls.removeAt(i).dispose();
      _positionCtrls.removeAt(i).dispose();
    });
  }

  void _updateRole(int i, String role) {
    final s = _staff[i];
    setState(() => _staff = [..._staff]..[i] =
        StaffAppointmentMember(name: s.name, position: s.position, role: role));
  }

  void _onNameChanged(int i, String v) {
    final s = _staff[i];
    _staff = [..._staff]..[i] =
        StaffAppointmentMember(name: v, position: s.position, role: s.role);
  }

  void _onPositionChanged(int i, String v) {
    final s = _staff[i];
    _staff = [..._staff]..[i] =
        StaffAppointmentMember(name: s.name, position: v, role: s.role);
  }

  void _pickPersonnel(int i, Personnel p) {
    setState(() {
      _nameCtrls[i].text = p.name;
      _positionCtrls[i].text = p.position ?? '';
      _staff = [..._staff]..[i] = StaffAppointmentMember(
          name: p.name, position: p.position ?? '', role: _staff[i].role);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final o = StaffAppointmentOrder(
      id: widget.existing?.id,
      fiscalYear: _fiscalYearCtrl.text.trim(),
      orderNumber: _orderNumberCtrl.text.trim().isEmpty
          ? null
          : _orderNumberCtrl.text.trim(),
      orderDate: _orderDate,
      effectiveDate: _effectiveDate,
      staff: _staff.where((s) => s.name.trim().isNotEmpty).toList(),
    );
    if (widget.existing == null) {
      await _repo.insertStaffAppointmentOrder(o);
    } else {
      await _repo.updateStaffAppointmentOrder(o);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _buildStaffRow(BuildContext context, int i) {
    final s = _staff[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: MemoryTextField(
              fieldKey: 'staffAppointment.name',
              controller: _nameCtrls[i],
              presetOptions: _personnel.map((p) => p.name).toList(),
              decoration: _dialogFieldDecoration(context,
                      label: 'ชื่อ-สกุล', hint: 'เช่น นายสมชาย ใจดี')
                  .copyWith(
                suffixIcon: PopupMenuButton<Personnel>(
                  icon: Icon(Icons.people_alt_outlined,
                      size: 20, color: BrandAccent.tealOn(context)),
                  tooltip: 'เลือกจากทำเนียบบุคลากร',
                  enabled: _personnel.isNotEmpty,
                  itemBuilder: (ctx) => [
                    for (final p in _personnel)
                      PopupMenuItem(
                        value: p,
                        child: Text(
                          (p.position?.trim().isNotEmpty ?? false)
                              ? '${p.name} — ${p.position}'
                              : p.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onSelected: (p) => _pickPersonnel(i, p),
                ),
              ),
              onChanged: (v) => _onNameChanged(i, v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: MemoryTextField(
              fieldKey: 'staffAppointment.position',
              controller: _positionCtrls[i],
              decoration: _dialogFieldDecoration(context,
                  label: 'ตำแหน่ง', hint: 'เช่น ครู'),
              onChanged: (v) => _onPositionChanged(i, v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: staffAppointmentRoles.contains(s.role)
                  ? s.role
                  : 'เจ้าหน้าที่พัสดุ',
              style: _dialogFieldStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface),
              decoration: _dialogFieldDecoration(context, label: 'บทบาท')
                  .copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
              isExpanded: true,
              items: staffAppointmentRoles
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => _updateRole(i, v ?? 'เจ้าหน้าที่พัสดุ'),
            ),
          ),
          IconButton(
            tooltip: 'ลบคนนี้',
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _removeStaff(i),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(
          isEdit
              ? 'แก้ไขคำสั่งแต่งตั้งเจ้าหน้าที่พัสดุ'
              : 'เพิ่มคำสั่งแต่งตั้งเจ้าหน้าที่พัสดุ',
          style: _dialogTitleStyle),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClearableTextField(
                    controller: _fiscalYearCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context,
                        label: 'ปีงบประมาณ *', hint: 'เช่น 2569'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกปีงบประมาณ'
                        : null,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: ClearableTextField(
                          controller: _orderNumberCtrl,
                          style: _dialogFieldStyle,
                          decoration: _dialogFieldDecoration(context,
                              label: 'เลขที่คำสั่ง', hint: 'เช่น 70/2569'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: InkWell(
                          onTap: () => _pickDate(
                              'วันที่สั่ง', _orderDate, (v) => _orderDate = v),
                          borderRadius: BorderRadius.circular(RadiusSize.md),
                          child: InputDecorator(
                            decoration: _dialogFieldDecoration(context,
                                    label: 'วันที่สั่ง')
                                .copyWith(
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.auto),
                            child: Text(_orderDate ?? 'เลือกวันที่',
                                style: _dialogFieldStyle,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: InkWell(
                    onTap: () => _pickDate('วันที่เริ่มปฏิบัติหน้าที่',
                        _effectiveDate, (v) => _effectiveDate = v),
                    borderRadius: BorderRadius.circular(RadiusSize.md),
                    child: InputDecorator(
                      decoration: _dialogFieldDecoration(context,
                              label: 'วันที่เริ่มปฏิบัติหน้าที่ (ตั้งแต่)')
                          .copyWith(
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.auto),
                      child: Text(_effectiveDate ?? 'เลือกวันที่',
                          style: _dialogFieldStyle,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          'รายชื่อผู้ได้รับแต่งตั้ง (${_staff.length} คน)',
                          style: TextStyle(
                              fontSize: AppTypography.bodyMedium,
                              fontWeight: AppTypography.weightSemiBold,
                              color: colors.onSurfaceVariant)),
                    ),
                    TextButton.icon(
                        onPressed: _addStaff,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('เพิ่มรายชื่อ')),
                  ],
                ),
                for (var i = 0; i < _staff.length; i++)
                  _buildStaffRow(context, i),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
              padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: _dialogButtonPadding,
              textStyle: _dialogButtonTextStyle),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
