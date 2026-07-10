// materials_screen.dart
// วัสดุ/คลังพัสดุ (blueprint หน้าที่ 9) — ของสิ้นเปลือง มีปุ่ม +รับเข้า/-เบิกจ่าย
// สลับมุมมองตาราง/กริดได้ (ไม่มี split-pane ตามที่ตกลงกันไว้ว่าใช้เฉพาะ
// ทะเบียนครุภัณฑ์เท่านั้น)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/material_item.dart';
import '../services/toast_service.dart';

enum _MaterialViewMode { table, grid }

const _materialCategories = ['สำนักงาน', 'ไฟฟ้า', 'งานบ้าน', 'อื่นๆ'];

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _repo = ProcurementRepository();
  List<MaterialItem> _materials = [];
  bool _loading = true;
  _MaterialViewMode _viewMode = _MaterialViewMode.table;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllMaterials();
    if (!mounted) return;
    setState(() {
      _materials = list;
      _loading = false;
    });
  }

  List<MaterialItem> get _filtered => _searchQuery.isEmpty
      ? _materials
      : _materials.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  double get _totalValue => _materials.fold(0, (s, m) => s + m.totalValue);
  int get _lowStockCount => _materials.where((m) => m.remaining <= 5).length;

  Future<void> _openForm({MaterialItem? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaterialFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(MaterialItem m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "${m.name}" ใช่หรือไม่?'),
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
    if (confirmed == true && m.id != null) {
      await _repo.deleteMaterial(m.id!);
      _load();
    }
  }

  Future<void> _adjustStock(MaterialItem m, {required bool isIn}) async {
    final qtyCtrl = TextEditingController();
    final qtyText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? 'รับเข้า "${m.name}"' : 'เบิกจ่าย "${m.name}"'),
        content: TextField(
          controller: qtyCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'จำนวน${isIn ? "ที่รับเข้า" : "ที่เบิกจ่าย"} (${m.unit ?? "หน่วย"})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, qtyCtrl.text.trim()), child: const Text('ยืนยัน')),
        ],
      ),
    );
    final qty = double.tryParse(qtyText ?? '');
    if (qty == null || qty <= 0 || m.id == null) return;

    if (!isIn && qty > m.remaining) {
      showAppToast('เบิกจ่ายไม่ได้ — คงเหลือแค่ ${m.remaining} ${m.unit ?? ""}', isError: true);
      return;
    }

    final updated = isIn ? m.copyWith(stockIn: m.stockIn + qty) : m.copyWith(stockOut: m.stockOut + qty);
    await _repo.updateMaterial(updated);
    if (!mounted) return;
    showAppToast(isIn ? 'รับเข้า $qty ${m.unit ?? ""} แล้ว' : 'เบิกจ่าย $qty ${m.unit ?? ""} แล้ว');
    _load();
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCards(colors),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 20), hintText: 'ค้นหาชื่อวัสดุ'),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<_MaterialViewMode>(
                          segments: const [
                            ButtonSegment(value: _MaterialViewMode.table, icon: Icon(Icons.table_chart_outlined)),
                            ButtonSegment(value: _MaterialViewMode.grid, icon: Icon(Icons.grid_view_outlined)),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _materials.isEmpty ? 'ยังไม่มีวัสดุ\nกด "เพิ่มวัสดุ" เพื่อเริ่มต้น' : 'ไม่พบรายการที่ค้นหา',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                              ),
                            )
                          : (_viewMode == _MaterialViewMode.table ? _buildTable(colors) : _buildGrid(colors)),
                    ),
                  ],
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
            label: const Text('เพิ่มวัสดุ'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(ColorScheme colors) {
    Widget card(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        card('รายการวัสดุทั้งหมด', '${_materials.length} รายการ', colors.primary),
        const SizedBox(width: 12),
        card('มูลค่าคงคลังรวม', '${_totalValue.toStringAsFixed(2)} บาท', Colors.amber.shade800),
        const SizedBox(width: 12),
        card('ใกล้หมด (≤5)', '$_lowStockCount รายการ', Colors.redAccent),
      ],
    );
  }

  Widget _buildTable(ColorScheme colors) {
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 1.5))),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text('รหัส', style: headerStyle)),
                  Expanded(flex: 3, child: Text('ชื่อวัสดุ', style: headerStyle)),
                  SizedBox(width: 90, child: Text('ประเภท', style: headerStyle)),
                  SizedBox(width: 80, child: Text('รับเข้า', style: headerStyle, textAlign: TextAlign.right)),
                  SizedBox(width: 80, child: Text('จ่ายออก', style: headerStyle, textAlign: TextAlign.right)),
                  SizedBox(width: 80, child: Text('คงเหลือ', style: headerStyle, textAlign: TextAlign.right)),
                  SizedBox(width: 100, child: Text('มูลค่ารวม', style: headerStyle, textAlign: TextAlign.right)),
                  const SizedBox(width: 140),
                ],
              ),
            ),
            for (final m in _filtered) _buildRow(colors, m),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, MaterialItem m) {
    final lowStock = m.remaining <= 5;
    return InkWell(
      onTap: () => _openForm(existing: m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(m.materialCode ?? '-', style: const TextStyle(fontSize: 12.5))),
            Expanded(flex: 3, child: Text(m.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 90, child: Text(m.category ?? '-', style: const TextStyle(fontSize: 12.5))),
            SizedBox(width: 80, child: Text(m.stockIn.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
            SizedBox(width: 80, child: Text(m.stockOut.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
            SizedBox(
              width: 80,
              child: Text('${m.remaining.toStringAsFixed(0)} ${m.unit ?? ""}',
                textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lowStock ? Colors.redAccent : null)),
            ),
            SizedBox(width: 100, child: Text(m.totalValue.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
            SizedBox(
              width: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20), tooltip: 'รับเข้า', onPressed: () => _adjustStock(m, isIn: true)),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 20), tooltip: 'เบิกจ่าย', onPressed: () => _adjustStock(m, isIn: false)),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _confirmDelete(m)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final m = _filtered[i];
        final lowStock = m.remaining <= 5;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openForm(existing: m),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_outlined, color: colors.primary, size: 20),
                    const Spacer(),
                    if (m.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(m.category!, style: TextStyle(fontSize: 10, color: colors.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('คงเหลือ ${m.remaining.toStringAsFixed(0)} ${m.unit ?? ""}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lowStock ? Colors.redAccent : colors.primary)),
                Text('${m.totalValue.toStringAsFixed(2)} บาท', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _adjustStock(m, isIn: true),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                        child: const Icon(Icons.add, size: 16, color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _adjustStock(m, isIn: false),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                        child: const Icon(Icons.remove, size: 16, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MaterialFormDialog extends StatefulWidget {
  final MaterialItem? existing;
  const _MaterialFormDialog({this.existing});
  @override
  State<_MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<_MaterialFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _unitPriceCtrl;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _codeCtrl = TextEditingController(text: m?.materialCode ?? '');
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _unitCtrl = TextEditingController(text: m?.unit ?? '');
    _unitPriceCtrl = TextEditingController(text: m?.unitPrice?.toStringAsFixed(2) ?? '');
    _category = m?.category;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _unitPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final m = MaterialItem(
      id: widget.existing?.id,
      materialCode: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      category: _category,
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      stockIn: widget.existing?.stockIn ?? 0,
      stockOut: widget.existing?.stockOut ?? 0,
      unitPrice: double.tryParse(_unitPriceCtrl.text.trim()),
    );
    if (widget.existing == null) {
      await _repo.insertMaterial(m);
    } else {
      await _repo.updateMaterial(m);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขวัสดุ' : 'เพิ่มวัสดุ'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: 'รหัสวัสดุ', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่อวัสดุ *', border: OutlineInputBorder(), isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อวัสดุ' : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'ประเภทวัสดุ', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ..._materialCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _unitCtrl,
                          decoration: const InputDecoration(labelText: 'หน่วยนับ', hintText: 'เช่น ชิ้น, กล่อง', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _unitPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'ราคาต่อหน่วย', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'จำนวนรับเข้า/เบิกจ่าย ปรับได้ทีหลังจากปุ่ม +รับเข้า / -เบิกจ่าย ในตาราง',
                      style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
                    ),
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
