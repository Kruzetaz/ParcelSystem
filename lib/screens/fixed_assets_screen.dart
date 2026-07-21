// fixed_assets_screen.dart
// ทะเบียนครุภัณฑ์ (blueprint หน้าที่ 8) — หน้าจอเดียวที่ใช้ Split-pane
// (รายการซ้าย + รายละเอียดขวา) ตามที่ตกลงกันไว้ มีสลับมุมมองตาราง/กริดรูปภาพ
// รูปภาพเก็บเป็นไฟล์ในเครื่อง (local storage) เท่านั้น ไม่อัปโหลดขึ้น cloud

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/procurement_repository.dart';
import '../models/asset_event.dart';
import '../models/fixed_asset.dart';
import '../services/toast_service.dart';
import '../utils/app_folder_name.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';

enum _AssetViewMode { table, grid }

const _assetStatuses = ['ใช้งานปกติ', 'ชำรุด', 'รอจำหน่าย'];
const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
String _formatThai(DateTime d) => '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';

/// แปลงสตริงวันที่รูปแบบ "${d} ${เดือนไทย} ${ปี พ.ศ.}" กลับเป็น DateTime (ค.ศ.)
/// ใช้คำนวณค่าเสื่อมราคา — คืน null ถ้าแปลงไม่ได้ (ยังไม่ได้กรอก/รูปแบบเก่า)
DateTime? _parseThaiDate(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final parts = text.trim().split(' ');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final monthIdx = _thaiMonths.indexOf(parts[1]);
  final beYear = int.tryParse(parts[2]);
  if (day == null || monthIdx <= 0 || beYear == null) return null;
  try {
    return DateTime(beYear - 543, monthIdx, day);
  } catch (_) {
    return null;
  }
}

Future<String> _copyPhotoLocally(String sourcePath) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final folderName = await getSchoolDocumentsFolderName();
  final assetsDir = Directory(p.join(docsDir.path, folderName, 'AssetPhotos'));
  if (!assetsDir.existsSync()) assetsDir.createSync(recursive: true);
  final ext = p.extension(sourcePath);
  final destPath = p.join(assetsDir.path, 'asset_${DateTime.now().microsecondsSinceEpoch}$ext');
  await File(sourcePath).copy(destPath);
  return destPath;
}

class FixedAssetsScreen extends StatefulWidget {
  const FixedAssetsScreen({super.key});
  @override
  State<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenState extends State<FixedAssetsScreen> {
  final _repo = ProcurementRepository();
  List<FixedAsset> _assets = [];
  bool _loading = true;
  _AssetViewMode _viewMode = _AssetViewMode.table;
  int? _selectedId;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? keepSelected}) async {
    setState(() => _loading = true);
    final list = await _repo.getAllFixedAssets();
    if (!mounted) return;
    setState(() {
      _assets = list;
      _loading = false;
      _selectedId = keepSelected ?? _selectedId;
      if (_selectedId != null && !list.any((a) => a.id == _selectedId)) _selectedId = null;
    });
  }

  List<FixedAsset> get _filtered =>
      _statusFilter == null ? _assets : _assets.where((a) => a.status == _statusFilter).toList();

  FixedAsset? get _selected => _selectedId == null ? null : _assets.where((a) => a.id == _selectedId).firstOrNull;

  double get _totalValue => _assets.fold(0, (s, a) => s + a.totalValue);
  int _countByStatus(String s) => _assets.where((a) => a.status == s).length;

  double get _totalNetBookValue => _assets.fold(0, (s, a) {
        final dep = calcDepreciation(a, _parseThaiDate(a.acquiredDate));
        return s + (dep?.netBookValue ?? a.totalValue);
      });

  Future<void> _openForm({FixedAsset? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssetFormDialog(existing: existing),
    );
    if (saved == true) _load(keepSelected: existing?.id);
  }

  Future<void> _confirmDelete(FixedAsset a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบครุภัณฑ์ "${a.name}" ใช่หรือไม่?'),
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
    if (confirmed == true && a.id != null) {
      await _repo.deleteFixedAsset(a.id!);
      if (_selectedId == a.id) _selectedId = null;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าทะเบียนครุภัณฑ์',
      icon: Icons.inventory_2_outlined,
      steps: const [
        'สลับมุมมองตาราง/กริดรูปภาพได้ที่ปุ่มมุมขวาของรายการ — มุมมองกริดเหมาะกับตอนต้องดูรูปครุภัณฑ์ประกอบ',
        'กดที่รายการในตารางเพื่อเปิดแผงรายละเอียดด้านขวา ดูประวัติการใช้งาน/ซ่อมบำรุงของครุภัณฑ์ชิ้นนั้น',
        'กรอกผู้ขาย/ประเภทเงิน/วิธีการได้มา/อายุการใช้งาน ให้ครบเพื่อให้ตรงกับแบบฟอร์มทะเบียนคุมครุภัณฑ์ของราชการ — ถ้ากรอกอายุการใช้งาน ระบบจะคำนวณค่าเสื่อมราคาโดยประมาณให้อัตโนมัติ (เป็นค่าประมาณการ ไม่ใช่ตัวเลขบัญชีที่รับรองอย่างเป็นทางการ)',
        'รูปถ่ายครุภัณฑ์ที่แนบไว้ เก็บเป็นไฟล์ในเครื่องนี้เท่านั้น ไม่ได้อัปโหลดขึ้น cloud ที่ใดทั้งสิ้น',
        'กด "เพิ่มครุภัณฑ์" มุมขวาล่างเพื่อลงทะเบียนรายการใหม่',
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
                      _buildSummaryCards(colors),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildListPane(colors)),
                            if (_selected != null) ...[
                              const SizedBox(width: 16),
                              SizedBox(width: 360, child: _buildDetailPane(colors, _selected!)),
                            ],
                          ],
                        ),
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
              label: const Text('เพิ่มครุภัณฑ์'),
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
        card('ใช้งานปกติ', '${_countByStatus('ใช้งานปกติ')} รายการ', Colors.green),
        const SizedBox(width: 12),
        card('ชำรุด', '${_countByStatus('ชำรุด')} รายการ', Colors.redAccent),
        const SizedBox(width: 12),
        card('รอจำหน่าย', '${_countByStatus('รอจำหน่าย')} รายการ', Colors.orange),
        const SizedBox(width: 12),
        card('มูลค่ารวมทั้งหมด', '${formatBaht(_totalValue)} บาท', colors.primary),
        const SizedBox(width: 12),
        card('มูลค่าสุทธิรวม (ประมาณ)', '${formatBaht(_totalNetBookValue)} บาท', Colors.teal),
      ],
    );
  }

  Widget _buildListPane(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: _buildStatusFilterChips(colors)),
                SegmentedButton<_AssetViewMode>(
                  segments: const [
                    ButtonSegment(value: _AssetViewMode.table, icon: Icon(Icons.table_chart_outlined)),
                    ButtonSegment(value: _AssetViewMode.grid, icon: Icon(Icons.grid_view_outlined)),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      _assets.isEmpty ? 'ยังไม่มีครุภัณฑ์\nกด "เพิ่มครุภัณฑ์" เพื่อเริ่มต้น' : 'ไม่พบรายการในสถานะนี้',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : (_viewMode == _AssetViewMode.table ? _buildTable(colors) : _buildGrid(colors)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips(ColorScheme colors) {
    Widget chip(String label, String? value) {
      final selected = _statusFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) => setState(() => _statusFilter = value),
          selectedColor: colors.primary,
          labelStyle: TextStyle(color: selected ? colors.onPrimary : colors.onSurfaceVariant),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [chip('ทั้งหมด', null), for (final s in _assetStatuses) chip(s, s)]),
    );
  }

  Widget _buildTable(ColorScheme colors) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final a = _filtered[i];
        final selected = a.id == _selectedId;
        return ListTile(
          selected: selected,
          selectedTileColor: colors.primaryContainer.withValues(alpha: 0.4),
          leading: _thumbnail(a, colors, size: 40),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a.assetNumber ?? "-"} · ${a.location ?? "-"}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: _statusBadge(a.status),
          onTap: () => setState(() => _selectedId = a.id),
        );
      },
    );
  }

  Widget _buildGrid(ColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final a = _filtered[i];
        final selected = a.id == _selectedId;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedId = a.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 2 : 1),
            ),
            child: Column(
              children: [
                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(9)), child: _thumbnail(a, colors, size: double.infinity))),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      _statusBadge(a.status, small: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumbnail(FixedAsset a, ColorScheme colors, {required double size}) {
    if (a.photoPath != null && File(a.photoPath!).existsSync()) {
      return Image.file(File(a.photoPath!), width: size == double.infinity ? null : size, height: size == double.infinity ? null : size, fit: BoxFit.cover);
    }
    return Container(
      width: size == double.infinity ? null : size,
      height: size == double.infinity ? null : size,
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.inventory_2_outlined, color: colors.onSurfaceVariant, size: size == double.infinity ? 32 : size * 0.5),
    );
  }

  Widget _statusBadge(String status, {bool small = false}) {
    final color = switch (status) {
      'ชำรุด' => Colors.redAccent,
      'รอจำหน่าย' => Colors.orange,
      _ => Colors.green,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: small ? 10 : 11.5, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDetailPane(ColorScheme colors, FixedAsset a) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(height: 140, width: double.infinity, child: _thumbnail(a, colors, size: double.infinity)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                _statusBadge(a.status),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow(colors, 'เลขครุภัณฑ์', a.assetNumber ?? '-'),
            _detailRow(colors, 'จำนวน', '${a.quantity}'),
            _detailRow(colors, 'ราคาต่อหน่วย', '${a.unitPrice != null ? formatBaht(a.unitPrice) : "-"} บาท'),
            _detailRow(colors, 'มูลค่ารวม', '${formatBaht(a.totalValue)} บาท'),
            _detailRow(colors, 'สถานที่จัดวาง', a.location ?? '-'),
            _detailRow(colors, 'วันที่ได้มา', a.acquiredDate ?? '-'),
            _detailRow(colors, 'ผู้ขาย/ผู้รับจ้าง', a.vendorName ?? '-'),
            _detailRow(colors, 'ประเภทเงิน', a.fundType ?? '-'),
            _detailRow(colors, 'วิธีการได้มา', a.procurementMethod ?? '-'),
            _detailRow(colors, 'อายุการใช้งาน', a.usefulLifeYears != null ? '${a.usefulLifeYears} ปี' : '-'),
            Builder(builder: (context) {
              final dep = calcDepreciation(a, _parseThaiDate(a.acquiredDate));
              if (dep == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ค่าเสื่อมราคา (ประมาณการ)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      _detailRow(colors, 'อัตรา/ปี', '${dep.ratePercentPerYear.toStringAsFixed(2)} %'),
                      _detailRow(colors, 'ค่าเสื่อมต่อปี', '${formatBaht(dep.annualDepreciation)} บาท'),
                      _detailRow(colors, 'ค่าเสื่อมสะสม', '${formatBaht(dep.accumulatedDepreciation)} บาท'),
                      _detailRow(colors, 'มูลค่าสุทธิ', '${formatBaht(dep.netBookValue)} บาท'),
                      const SizedBox(height: 4),
                      Text(
                        'คำนวณแบบเส้นตรงจากอายุการใช้งานที่กรอกไว้ เป็นค่าประมาณการเท่านั้น ไม่ใช่ตัวเลขทางบัญชีที่รับรองอย่างเป็นทางการ',
                        style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: () => _openForm(existing: a), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('แก้ไข')),
                OutlinedButton.icon(onPressed: () => _logRepair(a), icon: const Icon(Icons.build_outlined, size: 16), label: const Text('บันทึกซ่อมแซม')),
                OutlinedButton.icon(onPressed: () => _transferLocation(a), icon: const Icon(Icons.move_down_outlined, size: 16), label: const Text('โอนย้าย')),
                OutlinedButton.icon(
                  onPressed: () => _markForDisposal(a),
                  icon: const Icon(Icons.delete_forever_outlined, size: 16),
                  label: const Text('จำหน่ายพัสดุ'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(a)),
              ],
            ),
            const SizedBox(height: 16),
            Text('ประวัติ', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(height: 6),
            FutureBuilder(
              future: _repo.getAssetEvents(a.id!),
              builder: (context, snapshot) {
                final events = snapshot.data ?? [];
                if (events.isEmpty) {
                  return Text('ยังไม่มีประวัติ', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5));
                }
                return Column(
                  children: [
                    for (final e in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 6, color: colors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e.eventType} · ${e.eventDate ?? "-"}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  if (e.description != null) Text(e.description!, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(ColorScheme colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  Future<void> _logRepair(FixedAsset a) async {
    final descCtrl = TextEditingController();
    final desc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('บันทึกประวัติซ่อมแซม'),
        content: TextField(controller: descCtrl, autofocus: true, maxLines: 3, decoration: const InputDecoration(labelText: 'รายละเอียดการซ่อม')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, descCtrl.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
    if (desc == null || desc.isEmpty || a.id == null) return;
    await _repo.insertAssetEvent(AssetEvent(assetId: a.id!, eventType: 'ซ่อมแซม', eventDate: _formatThai(DateTime.now()), description: desc));
    if (!mounted) return;
    showAppToast('บันทึกประวัติซ่อมแซมแล้ว');
    setState(() {});
  }

  Future<void> _transferLocation(FixedAsset a) async {
    final locCtrl = TextEditingController(text: a.location ?? '');
    final newLocation = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('โอนย้ายสถานที่'),
        content: TextField(controller: locCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'สถานที่ใหม่')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, locCtrl.text.trim()), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (newLocation == null || newLocation.isEmpty || a.id == null) return;
    await _repo.updateFixedAsset(a.copyWith(location: newLocation));
    await _repo.insertAssetEvent(AssetEvent(
      assetId: a.id!,
      eventType: 'โอนย้าย',
      eventDate: _formatThai(DateTime.now()),
      description: 'ย้ายจาก "${a.location ?? "-"}" ไปยัง "$newLocation"',
    ));
    if (!mounted) return;
    showAppToast('โอนย้ายสถานที่แล้ว');
    _load(keepSelected: a.id);
  }

  Future<void> _markForDisposal(FixedAsset a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('จำหน่ายพัสดุ'),
        content: Text('ยืนยันเปลี่ยนสถานะ "${a.name}" เป็น "รอจำหน่าย" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true || a.id == null) return;
    await _repo.updateFixedAsset(a.copyWith(status: 'รอจำหน่าย'));
    await _repo.insertAssetEvent(AssetEvent(assetId: a.id!, eventType: 'จำหน่าย', eventDate: _formatThai(DateTime.now()), description: 'ทำเครื่องหมายรอจำหน่าย'));
    if (!mounted) return;
    showAppToast('เปลี่ยนสถานะเป็น "รอจำหน่าย" แล้ว');
    _load(keepSelected: a.id);
  }
}

class _AssetFormDialog extends StatefulWidget {
  final FixedAsset? existing;
  const _AssetFormDialog({this.existing});
  @override
  State<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<_AssetFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _assetNumberCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _unitPriceCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _vendorNameCtrl;
  late final TextEditingController _usefulLifeYearsCtrl;
  String? _acquiredDate;
  String? _photoPath;
  late String _status;
  String? _fundType;
  String? _procurementMethod;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _assetNumberCtrl = TextEditingController(text: a?.assetNumber ?? '');
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _quantityCtrl = TextEditingController(text: a?.quantity.toString() ?? '1');
    _unitPriceCtrl = TextEditingController(text: a?.unitPrice?.toStringAsFixed(2) ?? '');
    _locationCtrl = TextEditingController(text: a?.location ?? '');
    _vendorNameCtrl = TextEditingController(text: a?.vendorName ?? '');
    _usefulLifeYearsCtrl = TextEditingController(text: a?.usefulLifeYears?.toString() ?? '');
    _acquiredDate = a?.acquiredDate;
    _photoPath = a?.photoPath;
    _status = a?.status ?? 'ใช้งานปกติ';
    _fundType = fixedAssetFundTypes.contains(a?.fundType) ? a?.fundType : null;
    _procurementMethod =
        fixedAssetProcurementMethods.contains(a?.procurementMethod) ? a?.procurementMethod : null;
  }

  @override
  void dispose() {
    _assetNumberCtrl.dispose();
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _unitPriceCtrl.dispose();
    _locationCtrl.dispose();
    _vendorNameCtrl.dispose();
    _usefulLifeYearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
      dialogTitle: 'เลือกรูปครุภัณฑ์',
    );
    if (result == null || result.files.single.path == null) return;
    final saved = await _copyPhotoLocally(result.files.single.path!);
    setState(() => _photoPath = saved);
  }

  Future<void> _pickAcquiredDate() async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 20),
      lastDate: DateTime(initial.year + 1),
      helpText: 'วันที่ได้มา',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => _acquiredDate = _formatThai(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final a = FixedAsset(
      id: widget.existing?.id,
      assetNumber: _assetNumberCtrl.text.trim().isEmpty ? null : _assetNumberCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      quantity: double.tryParse(_quantityCtrl.text.trim()) ?? 1,
      unitPrice: double.tryParse(_unitPriceCtrl.text.trim()),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      acquiredDate: _acquiredDate,
      photoPath: _photoPath,
      status: _status,
      vendorName: _vendorNameCtrl.text.trim().isEmpty ? null : _vendorNameCtrl.text.trim(),
      fundType: _fundType,
      procurementMethod: _procurementMethod,
      usefulLifeYears: int.tryParse(_usefulLifeYearsCtrl.text.trim()),
    );
    if (widget.existing == null) {
      await _repo.insertFixedAsset(a);
    } else {
      await _repo.updateFixedAsset(a);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขครุภัณฑ์' : 'เพิ่มครุภัณฑ์'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: InkWell(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: colors.surfaceContainerHighest,
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: _photoPath != null && File(_photoPath!).existsSync()
                          ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.file(File(_photoPath!), fit: BoxFit.cover))
                          : Icon(Icons.add_a_photo_outlined, color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _field(_assetNumberCtrl, 'เลขครุภัณฑ์'),
                _field(_nameCtrl, 'รายการ *', required: true),
                Row(
                  children: [
                    Expanded(child: _field(_quantityCtrl, 'จำนวน', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_unitPriceCtrl, 'ราคาต่อหน่วย (บาท)', keyboardType: TextInputType.number)),
                  ],
                ),
                _field(_locationCtrl, 'สถานที่จัดวาง'),
                InkWell(
                  onTap: _pickAcquiredDate,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'วันที่ได้มา', border: OutlineInputBorder(), isDense: true),
                      child: Text(_acquiredDate ?? 'เลือกวันที่'),
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'สถานะ', border: OutlineInputBorder(), isDense: true),
                  items: _assetStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'ใช้งานปกติ'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ข้อมูลสำหรับทะเบียนคุมครุภัณฑ์/ทรัพย์สิน',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),
                _field(_vendorNameCtrl, 'ผู้ขาย/ผู้รับจ้าง'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _fundType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ประเภทเงิน', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ...fixedAssetFundTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (v) => setState(() => _fundType = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _procurementMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'วิธีการได้มา', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ...fixedAssetProcurementMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _procurementMethod = v),
                  ),
                ),
                _field(_usefulLifeYearsCtrl, 'อายุการใช้งาน (ปี)', keyboardType: TextInputType.number),
                Text(
                  'กรอกอายุการใช้งานเพื่อให้ระบบคำนวณค่าเสื่อมราคาโดยประมาณให้อัตโนมัติ (ไม่บังคับ)',
                  style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
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

  Widget _field(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null : null,
      ),
    );
  }
}
