// vendor_management_tab.dart
// แท็บ "ผู้รับจ้าง/ร้านค้า" ในหน้าตั้งค่า — จัดการข้อมูลร้านค้า/คู่ค้าแบบเต็มรูปแบบ
// (ประเภทบุคคลธรรมดา/นิติบุคคล, ที่อยู่ครบ, สถานะใช้งาน) แยกจากการ auto-save
// จาก wizard ซึ่งกรอกได้แค่บางฟิลด์

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/vendor.dart';
import '../services/toast_service.dart';
import '../widgets/memory_text_field.dart';

class VendorManagementTab extends StatefulWidget {
  const VendorManagementTab({super.key});

  @override
  State<VendorManagementTab> createState() => _VendorManagementTabState();
}

class _VendorManagementTabState extends State<VendorManagementTab> {
  final _repo = ProcurementRepository();
  List<Vendor> _vendors = [];
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
    final list = await _repo.getAllVendors();
    if (!mounted) return;
    setState(() {
      _vendors = list;
      _loading = false;
    });
  }

  List<Vendor> get _filtered => _query.isEmpty
      ? _vendors
      : _vendors.where((v) =>
          v.name.toLowerCase().contains(_query) ||
          (v.owner ?? '').toLowerCase().contains(_query)).toList();

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
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "${vendor.name}" ออกจากทำเนียบร้านค้าใช่หรือไม่?'),
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
    if (confirmed == true && vendor.id != null) {
      await _repo.deleteVendor(vendor.id!);
      if (!mounted) return;
      showAppToast('ลบร้านค้าแล้ว');
      _load();
    }
  }

  static const _typeColW = 96.0;
  static const _taxIdColW = 130.0;
  static const _phoneColW = 120.0;
  static const _statusColW = 84.0;
  static const _actionsColW = 88.0;

  Widget _buildHeaderRow(ColorScheme colors) {
    final style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(width: _typeColW, child: Text('ประเภท', style: style)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('ชื่อร้านค้า/เจ้าของร้าน', style: style)),
          const SizedBox(width: 12),
          SizedBox(width: _taxIdColW, child: Text('เลขผู้เสียภาษี', style: style)),
          const SizedBox(width: 12),
          SizedBox(width: _phoneColW, child: Text('เบอร์โทรศัพท์', style: style)),
          SizedBox(width: _statusColW, child: Text('', style: style)),
          SizedBox(width: _actionsColW, child: Text('', style: style)),
        ],
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, Vendor v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(10),
        color: v.active ? null : colors.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _typeColW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: v.vendorType == vendorTypeJuristic ? Colors.deepOrange : Colors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(v.vendorType,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (v.owner?.trim().isNotEmpty ?? false)
                  Text(v.owner!, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _taxIdColW,
            child: Text(v.taxId ?? '-', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _phoneColW,
            child: Text(v.phone ?? '-', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ),
          SizedBox(
            width: _statusColW,
            child: !v.active
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
                  onPressed: () => _openForm(existing: v),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'ลบ',
                  onPressed: () => _confirmDelete(v),
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
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'ค้นหาชื่อร้านค้า/เจ้าของร้าน',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _vendors.isEmpty ? 'ยังไม่มีข้อมูลร้านค้า\nกด "เพิ่มร้านค้า" เพื่อเริ่มต้น' : 'ไม่พบรายการที่ตรงกับคำค้นหา',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
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
      _nameCtrl, _ownerCtrl, _addressNoCtrl, _mooNumberCtrl, _subdistrictCtrl,
      _districtCtrl, _provinceCtrl, _postalCodeCtrl, _phoneCtrl, _taxIdCtrl,
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
      addressNo: _addressNoCtrl.text.trim().isEmpty ? null : _addressNoCtrl.text.trim(),
      mooNumber: _mooNumberCtrl.text.trim().isEmpty ? null : _mooNumberCtrl.text.trim(),
      subdistrict: _subdistrictCtrl.text.trim().isEmpty ? null : _subdistrictCtrl.text.trim(),
      district: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
      province: _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
      postalCode: _postalCodeCtrl.text.trim().isEmpty ? null : _postalCodeCtrl.text.trim(),
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

  Widget _field(TextEditingController ctrl, String label, {bool required = false, String? fieldKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fieldKey != null
          ? MemoryTextField(
              fieldKey: fieldKey,
              controller: ctrl,
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
            )
          : TextFormField(
              controller: ctrl,
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
              validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null : null,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขร้านค้า' : 'เพิ่มร้านค้า'),
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
                  child: DropdownButtonFormField<String>(
                    initialValue: _vendorType,
                    decoration: const InputDecoration(labelText: 'ประเภท', border: OutlineInputBorder(), isDense: true),
                    items: vendorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _vendorType = v ?? vendorTypeIndividual),
                  ),
                ),
                _field(_nameCtrl, 'ชื่อร้านค้า/บริษัท *', required: true),
                _field(_ownerCtrl, 'เจ้าของร้าน'),
                _field(_taxIdCtrl, 'เลขประจำตัวผู้เสียภาษี'),
                _field(_phoneCtrl, 'เบอร์โทรศัพท์'),
                _field(_addressNoCtrl, 'เลขที่ตั้ง/ที่อยู่', fieldKey: 'vendor.addressNo'),
                _field(_mooNumberCtrl, 'หมู่ที่'),
                _field(_subdistrictCtrl, 'ตำบล/แขวง', fieldKey: 'address.subdistrict'),
                _field(_districtCtrl, 'อำเภอ/เขต', fieldKey: 'address.district'),
                _field(_provinceCtrl, 'จังหวัด', fieldKey: 'address.province'),
                _field(_postalCodeCtrl, 'รหัสไปรษณีย์'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ใช้งานอยู่'),
                  subtitle: const Text('ปิดไว้เพื่อซ่อนจากตัวเลือกใน wizard โดยไม่ต้องลบประวัติ', style: TextStyle(fontSize: 12)),
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
