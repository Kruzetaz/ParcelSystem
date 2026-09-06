// vendor_management_tab.dart
// แท็บ "ผู้รับจ้าง/ร้านค้า" ในหน้าตั้งค่า — จัดการข้อมูลร้านค้า/คู่ค้าแบบเต็มรูปแบบ
// (ประเภทบุคคลธรรมดา/นิติบุคคล, ที่อยู่ครบ, สถานะใช้งาน) แยกจากการ auto-save
// จาก wizard ซึ่งกรอกได้แค่บางฟิลด์

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/vendor.dart';
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

/// เดิมฟอร์มนี้ใช้ `border: const OutlineInputBorder()` เปล่าๆ (ไม่ระบุสี) ซึ่ง
/// เมื่อ decoration.border ถูกกำหนดเอง Flutter จะทับค่า default จาก
/// InputDecorationTheme ของธีมทั้งหมด ผลคือช่องกรอกมีเส้นขอบดำเถื่อนตายตัว
/// ไม่ตอบสนองธีมสว่าง/มืด — เปลี่ยนมาใช้สูตร `_dialogFieldDecoration` เดียวกับ
/// ที่ใช้แก้ปัญหานี้ในหน้าอื่น (contracts_screen, guarantees_screen ฯลฯ) แทน
InputDecoration _dialogFieldDecoration(BuildContext context, {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
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

class VendorManagementTab extends StatefulWidget {
  const VendorManagementTab({super.key});

  @override
  State<VendorManagementTab> createState() => _VendorManagementTabState();
}

class _VendorManagementTabState extends State<VendorManagementTab> {
  static const _dialogTitleStyle =
      TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
  static const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
  static const _dialogButtonTextStyle =
      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
  static const _dialogButtonPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  final _repo = ProcurementRepository();
  List<Vendor> _vendors = [];
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
    final list = await _repo.getAllVendors();
    if (!mounted) return;
    setState(() {
      _vendors = list;
      _loading = false;
    });
  }

  List<Vendor> get _filtered => _query.isEmpty
      ? _vendors
      : _vendors
          .where((v) =>
              v.name.toLowerCase().contains(_query) ||
              (v.owner ?? '').toLowerCase().contains(_query))
          .toList();

  Future<void> _openForm({Vendor? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _VendorFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Vendor vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text(
            'ต้องการลบ "${vendor.name}" ออกจากทำเนียบร้านค้าใช่หรือไม่?',
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
    if (confirmed == true && vendor.id != null) {
      await _repo.deleteVendor(vendor.id!);
      if (!mounted) return;
      showAppToast('ลบร้านค้าแล้ว');
      _load();
    }
  }

  // ระยะห่างระหว่างคอลัมน์ — เดิมไม่มีเลย ทำให้ป้ายประเภท/ข้อมูลคอลัมน์ถัดไป
  // ดูติดกันเกินไปเวลาข้อความในคอลัมน์แรกยาวเกือบเต็มความกว้างที่กันไว้
  static const _spacing = 22.0;

  static const _columns = [
    DsColumn('ประเภท', width: 96),
    DsColumn('ชื่อร้านค้า/เจ้าของร้าน', flex: 2),
    DsColumn('เลขผู้เสียภาษี', width: 130),
    DsColumn('เบอร์โทรศัพท์', width: 120),
    DsColumn('สถานะ', width: 84),
    DsColumn('', width: 68),
  ];

  Widget _buildRow(ColorScheme colors, Vendor v, int index) {
    return DsTableRow(
      index: index,
      spacing: _spacing,
      onTap: () => _openForm(existing: v),
      cells: [
        DsCell(
          column: _columns[0],
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              label: v.vendorType,
              variant: v.vendorType == vendorTypeJuristic
                  ? BadgeVariant.warning
                  : BadgeVariant.info,
              compact: true,
            ),
          ),
        ),
        DsCell(
          column: _columns[1],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(v.name,
                  style: TextStyle(
                      fontWeight: AppTypography.weightSemiBold,
                      fontSize: AppTypography.body,
                      color: colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (v.owner?.trim().isNotEmpty ?? false)
                Text(v.owner!,
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: AppTypography.bodySmall),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        DsCell(
          column: _columns[2],
          child: Text(v.taxId ?? '-',
              style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTypography.bodyMedium),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        DsCell(
          column: _columns[3],
          child: Text(v.phone ?? '-',
              style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTypography.bodyMedium)),
        ),
        DsCell(
          column: _columns[4],
          child: Align(
            alignment: Alignment.center,
            child: StatusBadge(
              label: v.active ? 'ใช้งานอยู่' : 'ปิดใช้งาน',
              variant: v.active ? BadgeVariant.success : BadgeVariant.neutral,
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
                  onTap: () => _openForm(existing: v)),
              DsRowAction(
                  icon: Icons.delete_outline,
                  tooltip: 'ลบ',
                  onTap: () => _confirmDelete(v),
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
              TextField(
                controller: _searchCtrl,
                style: TextStyle(
                    fontSize: AppTypography.bodyMedium,
                    color: colors.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'ค้นหาชื่อร้านค้า/เจ้าของร้าน',
                  hintStyle: TextStyle(
                      fontSize: AppTypography.bodyMedium,
                      color: colors.onSurfaceVariant),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront_outlined,
                                    size: 64, color: colors.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text(
                                  _vendors.isEmpty
                                      ? 'ยังไม่มีข้อมูลร้านค้า\nกด "เพิ่มร้านค้า" เพื่อเริ่มต้น'
                                      : 'ไม่พบรายการที่ตรงกับคำค้นหา',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        // [แก้บั๊ก RenderFlex unbounded height]: AppCard ห่อ
                        // child ด้วย Padding เฉยๆ ไม่มี Expanded ให้ — ใส่
                        // ListView.builder ใน Expanded ไว้ข้างในตรงๆ แล้วชนกับ
                        // unbounded height constraint แตกทันที เปลี่ยนมาแสดง
                        // ทุกแถวตรงๆ (ไม่สกอลล์ในการ์ด) แล้วให้ทั้งหน้าเลื่อน
                        // แทนด้วย SingleChildScrollView
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
                                        'ผู้รับจ้าง/ร้านค้า',
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
                                          '${_filtered.length} ร้าน',
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
            heroTag: 'vendor_add_fab',
            onPressed: () => _openForm(),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มร้านค้า'),
          ),
        ),
      ],
    );
  }
}

class _VendorFormDialog extends StatefulWidget {
  final Vendor? existing;
  const _VendorFormDialog({this.existing});

  @override
  State<_VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<_VendorFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _addressNoCtrl;
  late final TextEditingController _mooNumberCtrl;
  late final TextEditingController _subdistrictCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _postalCodeCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _taxIdCtrl;
  late String _vendorType;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _ownerCtrl = TextEditingController(text: v?.owner ?? '');
    _addressNoCtrl = TextEditingController(text: v?.addressNo ?? '');
    _mooNumberCtrl = TextEditingController(text: v?.mooNumber ?? '');
    _subdistrictCtrl = TextEditingController(text: v?.subdistrict ?? '');
    _districtCtrl = TextEditingController(text: v?.district ?? '');
    _provinceCtrl = TextEditingController(text: v?.province ?? '');
    _postalCodeCtrl = TextEditingController(text: v?.postalCode ?? '');
    _phoneCtrl = TextEditingController(text: v?.phone ?? '');
    _taxIdCtrl = TextEditingController(text: v?.taxId ?? '');
    _vendorType = v?.vendorType ?? vendorTypeIndividual;
    _active = v?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _ownerCtrl,
      _addressNoCtrl,
      _mooNumberCtrl,
      _subdistrictCtrl,
      _districtCtrl,
      _provinceCtrl,
      _postalCodeCtrl,
      _phoneCtrl,
      _taxIdCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final vendor = Vendor(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      owner: _ownerCtrl.text.trim().isEmpty ? null : _ownerCtrl.text.trim(),
      addressNo: _addressNoCtrl.text.trim().isEmpty
          ? null
          : _addressNoCtrl.text.trim(),
      mooNumber: _mooNumberCtrl.text.trim().isEmpty
          ? null
          : _mooNumberCtrl.text.trim(),
      subdistrict: _subdistrictCtrl.text.trim().isEmpty
          ? null
          : _subdistrictCtrl.text.trim(),
      district:
          _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
      province:
          _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
      postalCode: _postalCodeCtrl.text.trim().isEmpty
          ? null
          : _postalCodeCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
      vendorType: _vendorType,
      active: _active,
    );
    try {
      if (widget.existing == null) {
        await _repo.upsertVendor(vendor);
      } else {
        await _repo.updateVendor(vendor);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAppToast('บันทึกไม่สำเร็จ: $e', isError: true);
      setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, String? fieldKey, String? hint}) {
    final decoration = _dialogFieldDecoration(context, label: label, hint: hint);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: fieldKey != null
          ? MemoryTextField(
              fieldKey: fieldKey,
              controller: ctrl,
              decoration: decoration,
            )
          : TextFormField(
              controller: ctrl,
              style: _dialogFieldStyle,
              decoration: decoration,
              validator: required
                  ? (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null
                  : null,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(
        isEdit ? 'แก้ไขร้านค้า' : 'เพิ่มร้านค้า',
        style: const TextStyle(
            fontSize: AppTypography.heading2,
            fontWeight: AppTypography.weightExtraBold),
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _vendorType,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    decoration: _dialogFieldDecoration(context, label: 'ประเภท').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    items: vendorTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _vendorType = v ?? vendorTypeIndividual),
                  ),
                ),
                _field(_nameCtrl, 'ชื่อร้านค้า/บริษัท *', required: true, hint: 'เช่น ร้านเจริญพาณิชย์'),
                _field(_ownerCtrl, 'เจ้าของร้าน', hint: 'เช่น นายสมชาย ใจดี'),
                _field(_taxIdCtrl, 'เลขประจำตัวผู้เสียภาษี', hint: 'เช่น 1234567890123'),
                _field(_phoneCtrl, 'เบอร์โทรศัพท์', hint: 'เช่น 081-234-5678'),
                _field(_addressNoCtrl, 'เลขที่ตั้ง/ที่อยู่',
                    fieldKey: 'vendor.addressNo', hint: 'เช่น 123 หมู่ 4 ถนนราชมนตรี'),
                _field(_mooNumberCtrl, 'หมู่ที่', hint: 'เช่น 4'),
                _field(_subdistrictCtrl, 'ตำบล/แขวง',
                    fieldKey: 'address.subdistrict', hint: 'เช่น ในเมือง'),
                _field(_districtCtrl, 'อำเภอ/เขต',
                    fieldKey: 'address.district', hint: 'เช่น เมืองลำพูน'),
                _field(_provinceCtrl, 'จังหวัด', fieldKey: 'address.province', hint: 'เช่น ลำพูน'),
                _field(_postalCodeCtrl, 'รหัสไปรษณีย์', hint: 'เช่น 51000'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ใช้งานอยู่',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'ปิดไว้เพื่อซ่อนจากตัวเลือกใน wizard โดยไม่ต้องลบประวัติ',
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
