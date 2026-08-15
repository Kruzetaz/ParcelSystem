// disposals_screen.dart
// จำหน่ายพัสดุ (blueprint หน้าที่ 11) — ผูกกับทะเบียนครุภัณฑ์แบบไม่บังคับ
// เลือกจากรายการที่มีสถานะ "รอจำหน่าย" ได้สะดวก

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/disposal.dart';
import '../models/fixed_asset.dart';
import '../services/disposal_export_service.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant;
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

const _disposalMethods = ['ขายทอดตลาด', 'โอนให้หน่วยงานอื่น', 'ทำลาย'];
const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
String _formatThai(DateTime d) => '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';

class DisposalsScreen extends StatefulWidget {
  const DisposalsScreen({super.key});
  @override
  State<DisposalsScreen> createState() => _DisposalsScreenState();
}

class _DisposalsScreenState extends State<DisposalsScreen> {
  final _repo = ProcurementRepository();
  List<Disposal> _disposals = [];
  Map<int, FixedAsset> _assetsById = {};
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final disposals = await _repo.getAllDisposals();
    final assets = await _repo.getAllFixedAssets();
    if (!mounted) return;
    setState(() {
      _disposals = disposals;
      _assetsById = {for (final a in assets) if (a.id != null) a.id!: a};
      _loading = false;
    });
  }

  Future<void> _openForm({Disposal? existing}) async {
    final assets = await _repo.getAllFixedAssets();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DisposalFormDialog(existing: existing, assets: assets),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Disposal d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: const Text('ต้องการลบบันทึกการจำหน่ายนี้ใช่หรือไม่?', style: _dialogContentStyle),
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
    if (confirmed == true && d.id != null) {
      await _repo.deleteDisposal(d.id!);
      _load();
    }
  }

  Future<void> _markCommitted(Disposal d) async {
    if (d.id == null) return;
    await _repo.updateDisposal(Disposal(
      id: d.id,
      assetId: d.assetId,
      itemName: d.itemName,
      disposalMethod: d.disposalMethod,
      approvedDate: d.approvedDate,
      approverName: d.approverName,
      status: 'ตัดยอดแล้ว',
    ));
    _load();
  }

  /// ส่งออกทะเบียนจำหน่ายพัสดุที่เห็นอยู่ตอนนี้เป็นไฟล์ Excel แล้วเปิดไฟล์ให้อัตโนมัติ
  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await DisposalExportService.exportAndOpen(_disposals, _assetsById);
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
      title: 'วิธีใช้หน้าจำหน่ายพัสดุ',
      icon: Icons.delete_sweep_outlined,
      steps: const [
        'ใช้บันทึกการจำหน่ายพัสดุ/ครุภัณฑ์ที่ชำรุด/หมดความจำเป็น ออกจากทะเบียนตามระเบียบพัสดุ (ขาย/แลกเปลี่ยน/โอน/แปรสภาพ/ทำลาย)',
        'ผูกกับรายการในทะเบียนครุภัณฑ์ได้โดยตรง (เลือกจากรายการที่มีอยู่แล้ว) หรือกรอกชื่อรายการเองก็ได้',
        'สถานะ "ตัดยอดแล้ว" หมายถึงดำเนินการจำหน่ายออกจากบัญชีทรัพย์สินเสร็จสมบูรณ์แล้ว ควรอัปเดตหลังได้รับอนุมัติจากผู้มีอำนาจ',
        'กด "เพิ่มรายการจำหน่าย" มุมขวาล่างเพื่อเริ่มบันทึกรายการใหม่',
        'กดปุ่ม "ส่งออก Excel" มุมบนขวาเพื่อบันทึกทะเบียนจำหน่ายพัสดุที่เห็นอยู่ตอนนี้เป็นไฟล์ .xlsx',
      ],
      // มุมขวาบนชนกับปุ่ม "ส่งออก Excel" ในหัวหน้า และมุมขวาล่างมี FAB
      // "เพิ่มรายการจำหน่าย" อยู่แล้ว — เหลือแค่มุมซ้ายล่างที่ว่าง
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
                        Icon(Icons.delete_sweep_outlined, color: BrandAccent.tealOn(context), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('จำหน่ายพัสดุ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _disposals.isEmpty || _exporting ? null : _exportToExcel,
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
                          : _disposals.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_sweep_outlined, size: 64, color: colors.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text('ยังไม่มีรายการจำหน่ายพัสดุ\nกด "เพิ่มรายการจำหน่าย" เพื่อเริ่มต้น',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _disposals.length,
                                  padding: const EdgeInsets.only(bottom: 80),
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _buildCard(context, colors, _disposals[i]),
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
              heroTag: 'disposals_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มรายการจำหน่าย'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, Disposal d) {
    final asset = d.assetId != null ? _assetsById[d.assetId] : null;
    final itemLabel = asset?.name ?? d.itemName ?? '(ไม่ระบุรายการ)';
    final isCommitted = d.status == 'ตัดยอดแล้ว';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(existing: d),
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
                    Row(children: [
                      if (asset?.assetNumber != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandAccent.teal(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(RadiusSize.sm),
                          ),
                          child: Text(asset!.assetNumber!,
                            style: TextStyle(fontSize: AppTypography.caption, color: BrandAccent.tealOn(context), fontWeight: AppTypography.weightSemiBold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (d.disposalMethod != null) ...[
                        Text(d.disposalMethod!, style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                        const SizedBox(width: 8),
                      ],
                      StatusBadge(
                        label: d.status,
                        variant: isCommitted ? BadgeVariant.success : BadgeVariant.warning,
                        compact: true,
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(itemLabel, style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.heading4, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('อนุมัติเมื่อ: ${d.approvedDate ?? "-"}  ·  ผู้ลงนาม: ${d.approverName ?? "-"}',
                      style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (!isCommitted)
                TextButton(
                  onPressed: () => _markCommitted(d),
                  style: TextButton.styleFrom(textStyle: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightBold)),
                  child: const Text('ตัดยอดออกจากบัญชี'),
                ),
              const SizedBox(width: 4),
              DsActionIconButtons(
                actions: [
                  DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(d), danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisposalFormDialog extends StatefulWidget {
  final Disposal? existing;
  final List<FixedAsset> assets;
  const _DisposalFormDialog({this.existing, required this.assets});
  @override
  State<_DisposalFormDialog> createState() => _DisposalFormDialogState();
}

class _DisposalFormDialogState extends State<_DisposalFormDialog> {
  final _repo = ProcurementRepository();
  late final TextEditingController _itemNameCtrl;
  late final TextEditingController _approverCtrl;
  int? _assetId;
  String? _method;
  String? _approvedDate;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _itemNameCtrl = TextEditingController(text: d?.itemName ?? '');
    _approverCtrl = TextEditingController(text: d?.approverName ?? '');
    _assetId = d?.assetId;
    _method = d?.disposalMethod;
    _approvedDate = d?.approvedDate;
    _status = d?.status ?? 'รอดำเนินการ';
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _approverCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 1),
      helpText: 'วันที่อนุมัติจำหน่าย',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => _approvedDate = _formatThai(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final d = Disposal(
      id: widget.existing?.id,
      assetId: _assetId,
      itemName: _itemNameCtrl.text.trim().isEmpty ? null : _itemNameCtrl.text.trim(),
      disposalMethod: _method,
      approvedDate: _approvedDate,
      approverName: _approverCtrl.text.trim().isEmpty ? null : _approverCtrl.text.trim(),
      status: _status,
    );
    if (widget.existing == null) {
      await _repo.insertDisposal(d);
    } else {
      await _repo.updateDisposal(d);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  InputDecoration _fieldDecoration(BuildContext context, String label) {
    final colors = Theme.of(context).colorScheme;
    // colors.outline (0xFFE1E7EB โหมดสว่าง) จางเกินไปสำหรับช่องกรอกลอยเดี่ยวๆ
    // ในป๊อปอัพ (ไม่มีเงา/สีพื้นต่างจากไดอะล็อกช่วยตัดขอบให้เหมือนตารางอื่น) —
    // ใช้ onSurfaceVariant ผสมความจางแทนให้กรอบเห็นชัดขึ้น
    final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
    return InputDecoration(
      labelText: label,
      labelStyle: _dialogLabelStyle.copyWith(color: colors.onSurfaceVariant),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขรายการจำหน่าย' : 'เพิ่มรายการจำหน่าย', style: _dialogTitleStyle),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: DropdownButtonFormField<int?>(
                  initialValue: _assetId,
                  isExpanded: true,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _fieldDecoration(context, 'ครุภัณฑ์ที่จะจำหน่าย'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('(พิมพ์ชื่อรายการเอง)')),
                    ...widget.assets.where((a) => a.id != null).map((a) => DropdownMenuItem<int?>(
                          value: a.id,
                          child: Text('${a.assetNumber ?? ""} ${a.name}'.trim(), overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _assetId = v),
                ),
              ),
              if (_assetId == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextField(
                    controller: _itemNameCtrl,
                    style: _dialogFieldStyle,
                    decoration: _fieldDecoration(context, 'ชื่อรายการ'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: DropdownButtonFormField<String?>(
                  initialValue: _method,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _fieldDecoration(context, 'วิธีการจำหน่าย'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                    ..._disposalMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                  ],
                  onChanged: (v) => setState(() => _method = v),
                ),
              ),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(RadiusSize.md),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: InputDecorator(
                    decoration: _fieldDecoration(context, 'วันที่อนุมัติจำหน่าย'),
                    child: Text(_approvedDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TextField(
                  controller: _approverCtrl,
                  style: _dialogFieldStyle,
                  decoration: _fieldDecoration(context, 'ผู้ลงนามอนุมัติ'),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                decoration: _fieldDecoration(context, 'สถานะการตัดยอด'),
                items: const [
                  DropdownMenuItem(value: 'รอดำเนินการ', child: Text('รอดำเนินการ')),
                  DropdownMenuItem(value: 'ตัดยอดแล้ว', child: Text('ตัดยอดแล้ว')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'รอดำเนินการ'),
              ),
            ],
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
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
