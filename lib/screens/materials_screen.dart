// materials_screen.dart
// วัสดุ/คลังพัสดุ (blueprint หน้าที่ 9) — ของสิ้นเปลือง มีปุ่ม +รับเข้า/-เบิกจ่าย
// สลับมุมมองตาราง/กริดได้ (ไม่มี split-pane ตามที่ตกลงกันไว้ว่าใช้เฉพาะ
// ทะเบียนครุภัณฑ์เท่านั้น)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/material_item.dart';
import '../models/material_transaction.dart';
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import '../services/material_ledger_export_service.dart';
import '../services/procurement_document_generator.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';

const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String _todayThai() {
  final now = DateTime.now();
  return '${now.day} ${_thaiMonths[now.month]} ${now.year + 543}';
}

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
  List<MaterialItem> get _lowStockItems => _materials.where((m) => m.isLowStock).toList();
  int get _lowStockCount => _lowStockItems.length;

  bool _exportingLedger = false;

  /// ส่งออก "บัญชีวัสดุ" (บัตรคุมสต๊อก) รวมทุกรายการ พร้อมประวัติรับ-จ่ายทีละ
  /// รายการ — ดึงประวัติของแต่ละชิ้นมาก่อนแล้วค่อยส่งออกรวดเดียว
  Future<void> _exportLedger() async {
    setState(() => _exportingLedger = true);
    try {
      final txByMaterial = <int, List<MaterialTransaction>>{};
      for (final m in _materials) {
        if (m.id == null) continue;
        txByMaterial[m.id!] = await _repo.getMaterialTransactionsChronological(m.id!);
      }
      await MaterialLedgerExportService.exportAndOpen(materials: _materials, transactionsByMaterialId: txByMaterial);
      if (!mounted) return;
      showAppToast('สร้างบัญชีวัสดุแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingLedger = false);
    }
  }

  /// แสดงประวัติรับ-จ่ายทีละรายการของวัสดุชิ้นนี้
  Future<void> _viewHistory(MaterialItem m) async {
    if (m.id == null) return;
    final transactions = await _repo.getMaterialTransactions(m.id!);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ประวัติรับ-จ่าย "${m.name}"'),
        content: SizedBox(
          width: 420,
          height: 400,
          child: transactions.isEmpty
              ? const Center(child: Text('ยังไม่มีประวัติรับ-จ่าย'))
              : ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = transactions[i];
                    final isIn = t.transactionType == 'รับเข้า';
                    final details = [
                      if (t.transactionDate != null) t.transactionDate!,
                      if (t.counterparty?.trim().isNotEmpty ?? false) t.counterparty!,
                      if (t.refDocument?.trim().isNotEmpty ?? false) 'เอกสาร: ${t.refDocument}',
                    ].join(' · ');
                    return ListTile(
                      dense: true,
                      leading: Icon(isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isIn ? Colors.green : Colors.orange),
                      title: Text('${t.transactionType} ${t.quantity.toStringAsFixed(0)} ${m.unit ?? ""}'),
                      subtitle: details.isEmpty ? null : Text(details, style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
      ),
    );
  }

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

  /// คัดลอกวัสดุเป็นรายการใหม่ — คัดลอกข้อมูลบรรยาย (ชื่อ/รหัส/หน่วย/ราคา/ที่เก็บ/
  /// จำนวนอย่างสูง-ต่ำ) มาตรงๆ แต่เริ่มยอดรับ-จ่ายที่ 0 ใหม่เสมอ (ไม่ใช่ล้างข้อมูล
  /// บรรยาย แต่ยอดสต๊อกเป็นประวัติจริงของชิ้นเดิม เอามาใช้กับของชิ้นใหม่ไม่ได้)
  Future<void> _duplicateMaterial(MaterialItem m) async {
    try {
      final map = m.toMap();
      map.remove('id');
      map['name'] = '${m.name} (สำเนา)';
      map['stock_in'] = 0.0;
      map['stock_out'] = 0.0;
      await _repo.insertMaterial(MaterialItem.fromMap(map));
      if (!mounted) return;
      showAppToast('คัดลอกวัสดุแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกวัสดุไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _adjustStock(MaterialItem m, {required bool isIn}) async {
    final qtyCtrl = TextEditingController();
    final counterpartyCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? 'รับเข้า "${m.name}"' : 'เบิกจ่าย "${m.name}"'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'จำนวน${isIn ? "ที่รับเข้า" : "ที่เบิกจ่าย"} (${m.unit ?? "หน่วย"})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: counterpartyCtrl,
                decoration: InputDecoration(labelText: isIn ? 'รับจาก (ไม่บังคับ)' : 'จ่ายให้ (ไม่บังคับ)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'เลขที่เอกสารอ้างอิง (ไม่บังคับ)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;
    final qty = double.tryParse(qtyCtrl.text.trim());
    if (qty == null || qty <= 0 || m.id == null) return;

    if (!isIn && qty > m.remaining) {
      showAppToast('เบิกจ่ายไม่ได้ — คงเหลือแค่ ${m.remaining} ${m.unit ?? ""}', isError: true);
      return;
    }

    final updated = isIn ? m.copyWith(stockIn: m.stockIn + qty) : m.copyWith(stockOut: m.stockOut + qty);
    await _repo.updateMaterial(updated);
    // บันทึกประวัติทีละรายการควบคู่ไปกับยอดสะสม — ใช้พิมพ์บัญชีวัสดุ/บัตรคุมสต๊อกได้
    await _repo.insertMaterialTransaction(MaterialTransaction(
      materialId: m.id!,
      transactionDate: _todayThai(),
      transactionType: isIn ? 'รับเข้า' : 'เบิกจ่าย',
      quantity: qty,
      unitPrice: m.unitPrice,
      refDocument: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
      counterparty: counterpartyCtrl.text.trim().isEmpty ? null : counterpartyCtrl.text.trim(),
    ));
    if (!mounted) return;
    showAppToast(isIn ? 'รับเข้า $qty ${m.unit ?? ""} แล้ว' : 'เบิกจ่าย $qty ${m.unit ?? ""} แล้ว');
    _load();
    if (!isIn) await _offerRequisitionDoc(m, qty);
  }

  Future<void> _offerRequisitionDoc(MaterialItem m, double qty) async {
    if (!mounted) return;
    final wantsDoc = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกเอกสารใบเบิกพัสดุ'),
        content: Text('ต้องการออกเอกสารใบเบิกพัสดุสำหรับ "${m.name}" จำนวน $qty ${m.unit ?? ""} นี้หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ไม่ต้อง')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ออกเอกสาร')),
        ],
      ),
    );
    if (wantsDoc != true) return;
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    try {
      await ProcurementDocumentGenerator.generateAndOpen(
        type: ProcurementDocumentType.requisition,
        order: ProcurementOrder(dateShipping: _todayThai()),
        school: school,
        items: [
          ProcurementItem(itemName: m.name, quantity: qty, unit: m.unit, unitPrice: m.unitPrice ?? 0),
        ],
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าวัสดุ/คลังพัสดุ',
      icon: Icons.inventory_outlined,
      // การ์ดสรุปด้านบนกว้างเต็มจอ ปุ่มไกด์เลยต้องลอยมุมซ้ายล่างแทนมุมขวาบน
      // (มุมขวาล่างมีปุ่ม "เพิ่มวัสดุ" อยู่แล้ว)
      corner: Alignment.bottomLeft,
      steps: const [
        'ยอดคงเหลือคำนวณจากยอด "รับเข้า" ลบ "เบิกจ่าย" สะสมทั้งหมด — ทุกครั้งที่กดรับเข้า/เบิกจ่าย ระบบจะบันทึกประวัติทีละรายการไว้ด้วย (วันที่/รับจาก-จ่ายให้/เลขที่เอกสาร) กดไอคอนนาฬิกาที่แถวรายการเพื่อดูประวัติได้',
        'กด "เบิกจ่าย" ที่รายการวัสดุเพื่อตัดยอดออก ระบบจะเสนอสร้างใบเบิกพัสดุให้อัตโนมัติถ้าต้องการ',
        'ใกล้หมด หมายถึงจำนวนคงเหลือถึงเกณฑ์ "จำนวนอย่างต่ำ" ที่กำหนดไว้ในฟอร์มวัสดุ (ถ้ายังไม่กำหนด ใช้เกณฑ์ทั่วไป ≤5) ควรพิจารณาจัดซื้อเพิ่ม',
        'กรอกขนาด/ที่เก็บ/จำนวนอย่างสูง-ต่ำ ในฟอร์มเพิ่ม/แก้ไข ให้ตรงกับแบบฟอร์มบัญชีวัสดุของราชการ แล้วกด "พิมพ์บัญชีวัสดุ" มุมขวาบนเพื่อส่งออกเป็น Excel พร้อมประวัติรับ-จ่ายครบทุกชิ้น',
        'สลับมุมมองตาราง/กริดได้ที่ปุ่มด้านบนขวาของรายการ ใช้ช่องค้นหาเพื่อหาชื่อวัสดุที่ต้องการเร็วขึ้น',
      ],
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: (_materials.isEmpty || _exportingLedger) ? null : _exportLedger,
                          icon: _exportingLedger
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                              : const Icon(Icons.receipt_long_outlined, size: 18),
                          label: Text(_exportingLedger ? 'กำลังสร้าง...' : 'พิมพ์บัญชีวัสดุ'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSummaryCards(colors),
                    if (_lowStockCount > 0) ...[
                      const SizedBox(height: 12),
                      _buildLowStockBanner(colors),
                    ],
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_outlined, size: 64, color: colors.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                    _materials.isEmpty ? 'ยังไม่มีวัสดุ\nกด "เพิ่มวัสดุ" เพื่อเริ่มต้น' : 'ไม่พบรายการที่ค้นหา',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                                  ),
                                ],
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
      ),
    );
  }

  Widget _buildSummaryCards(ColorScheme colors) {
    Widget card(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
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
        card('มูลค่าคงคลังรวม', '${formatBaht(_totalValue)} บาท', Colors.amber.shade800),
        const SizedBox(width: 12),
        card('ใกล้หมด', '$_lowStockCount รายการ', Colors.redAccent),
      ],
    );
  }

  // แจ้งชื่อวัสดุที่ใกล้หมดตรงๆ แทนที่จะให้ดูแค่ตัวเลขในการ์ดสรุปแล้วต้องไล่หา
  // เองว่ารายการไหนบ้าง
  Widget _buildLowStockBanner(ColorScheme colors) {
    const maxShown = 4;
    final items = _lowStockItems;
    final shownNames = items.take(maxShown).map((m) => m.name).join(', ');
    final remainder = items.length - maxShown;
    final message = remainder > 0
        ? 'วัสดุใกล้หมด: $shownNames และอีก $remainder รายการ — ควรพิจารณาจัดซื้อเพิ่ม'
        : 'วัสดุใกล้หมด: $shownNames — ควรพิจารณาจัดซื้อเพิ่ม';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
                  const SizedBox(width: 206),
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
    final lowStock = m.isLowStock;
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
            SizedBox(width: 100, child: Text(formatBaht(m.totalValue), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
            SizedBox(
              width: 206,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, size: 18),
                    tooltip: 'ดูประวัติรับ-จ่าย',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _viewHistory(m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 18),
                    tooltip: 'รับเข้า',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _adjustStock(m, isIn: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 18),
                    tooltip: 'เบิกจ่าย',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _adjustStock(m, isIn: false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    tooltip: 'คัดลอกวัสดุ',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    visualDensity: VisualDensity.compact,
                    color: colors.onSurfaceVariant,
                    onPressed: () => _duplicateMaterial(m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    tooltip: 'ลบ',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(m),
                  ),
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
        final lowStock = m.isLowStock;
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
                        decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(m.category!, style: TextStyle(fontSize: 10, color: colors.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('คงเหลือ ${m.remaining.toStringAsFixed(0)} ${m.unit ?? ""}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lowStock ? Colors.redAccent : colors.primary)),
                Text('${formatBaht(m.totalValue)} บาท', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _viewHistory(m),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                        child: const Icon(Icons.history, size: 16),
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
  late final TextEditingController _sizeSpecCtrl;
  late final TextEditingController _storageLocationCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _maxStockCtrl;
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
    _sizeSpecCtrl = TextEditingController(text: m?.sizeSpec ?? '');
    _storageLocationCtrl = TextEditingController(text: m?.storageLocation ?? '');
    _minStockCtrl = TextEditingController(text: m?.minStock?.toStringAsFixed(0) ?? '');
    _maxStockCtrl = TextEditingController(text: m?.maxStock?.toStringAsFixed(0) ?? '');
    _category = m?.category;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _unitPriceCtrl.dispose();
    _sizeSpecCtrl.dispose();
    _storageLocationCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
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
      sizeSpec: _sizeSpecCtrl.text.trim().isEmpty ? null : _sizeSpecCtrl.text.trim(),
      storageLocation: _storageLocationCtrl.text.trim().isEmpty ? null : _storageLocationCtrl.text.trim(),
      minStock: double.tryParse(_minStockCtrl.text.trim()),
      maxStock: double.tryParse(_maxStockCtrl.text.trim()),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _sizeSpecCtrl,
                    decoration: const InputDecoration(labelText: 'ขนาดหรือลักษณะ', hintText: 'เช่น 180 แกรม, A4', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _storageLocationCtrl,
                    decoration: const InputDecoration(labelText: 'ที่เก็บ', hintText: 'เช่น ห้องพัสดุ ชั้น 2', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _minStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'จำนวนอย่างต่ำ', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _maxStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'จำนวนอย่างสูง', border: OutlineInputBorder(), isDense: true),
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
