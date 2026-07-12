// disposals_screen.dart
// จำหน่ายพัสดุ (blueprint หน้าที่ 11) — ผูกกับทะเบียนครุภัณฑ์แบบไม่บังคับ
// เลือกจากรายการที่มีสถานะ "รอจำหน่าย" ได้สะดวก

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/disposal.dart';
import '../models/fixed_asset.dart';

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
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบบันทึกการจำหน่ายนี้ใช่หรือไม่?'),
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
                  : _disposals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_sweep_outlined, size: 64, color: colors.onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text('ยังไม่มีรายการจำหน่ายพัสดุ\nกด "เพิ่มรายการจำหน่าย" เพื่อเริ่มต้น',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _disposals.length,
                          padding: const EdgeInsets.only(bottom: 80),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildCard(colors, _disposals[i]),
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
            label: const Text('เพิ่มรายการจำหน่าย'),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ColorScheme colors, Disposal d) {
    final asset = d.assetId != null ? _assetsById[d.assetId] : null;
    final itemLabel = asset?.name ?? d.itemName ?? '(ไม่ระบุรายการ)';
    final isCommitted = d.status == 'ตัดยอดแล้ว';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(existing: d),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(asset!.assetNumber!, style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (d.disposalMethod != null) ...[
                        Text(d.disposalMethod!, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isCommitted ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(d.status, style: TextStyle(fontSize: 11.5, color: isCommitted ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(itemLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('อนุมัติเมื่อ: ${d.approvedDate ?? "-"}  ·  ผู้ลงนาม: ${d.approverName ?? "-"}',
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              if (!isCommitted)
                TextButton(onPressed: () => _markCommitted(d), child: const Text('ตัดยอดออกจากบัญชี', style: TextStyle(fontSize: 12))),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(d)),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 1),
      helpText: 'วันที่อนุมัติจำหน่าย',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: colors.primary, onPrimary: colors.onPrimary, onSurface: colors.primary),
        ),
        child: child!,
      ),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขรายการจำหน่าย' : 'เพิ่มรายการจำหน่าย'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int?>(
                  initialValue: _assetId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ครุภัณฑ์ที่จะจำหน่าย', border: OutlineInputBorder(), isDense: true),
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _itemNameCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่อรายการ', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String?>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'วิธีการจำหน่าย', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                    ..._disposalMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                  ],
                  onChanged: (v) => setState(() => _method = v),
                ),
              ),
              InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'วันที่อนุมัติจำหน่าย', border: OutlineInputBorder(), isDense: true),
                    child: Text(_approvedDate ?? 'เลือกวันที่'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _approverCtrl,
                  decoration: const InputDecoration(labelText: 'ผู้ลงนามอนุมัติ', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'สถานะการตัดยอด', border: OutlineInputBorder(), isDense: true),
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
