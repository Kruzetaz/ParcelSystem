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
import '../services/asset_control_ledger_export_service.dart';
import '../services/depreciation_schedule_export_service.dart';
import '../services/toast_service.dart';
import '../utils/app_folder_name.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/standard_price_picker_dialog.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kpi_card.dart';
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant, DSFilterChip;
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

InputDecoration _dialogFieldDecoration(BuildContext context, {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
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
  // เปิดมาจากปุ่มลัด "ดูครุภัณฑ์" ในหน้าประวัติซ่อม — ให้เลือกชิ้นนี้ไว้ล่วงหน้า
  final int? initialSelectedId;

  const FixedAssetsScreen({super.key, this.initialSelectedId});
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
  // ตัวกรอง "ปีที่ได้มา" — แยกต่างหากจากตัวสลับปีงบหลักที่ AppBar โดยตั้งใจ
  // (ครุภัณฑ์เป็นทะเบียนทรัพย์สินสะสม ไม่ได้ "หมดอายุ" ตามปีงบแบบโครงการจัดซื้อ
  // ทั่วไป — ของที่ซื้อปี 2568 ก็ยังเป็นทรัพย์สินโรงเรียนอยู่ปี 2569 ถ้าผูกกับ
  // ตัวสลับปีงบหลักจะเสี่ยงทำให้ครุภัณฑ์ "หายไป" จากสายตาโดยไม่ได้ตั้งใจ) —
  // default ว่าง = โชว์ทุกปี ผู้ใช้ต้องเลือกเองถึงจะกรอง
  String? _acquiredYearFilter;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
    _load(keepSelected: widget.initialSelectedId);
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

  List<FixedAsset> get _filtered => _assets
      .where((a) => _statusFilter == null || a.status == _statusFilter)
      .where((a) => _acquiredYearFilter == null || _acquiredYearOf(a) == _acquiredYearFilter)
      .toList();

  /// ปีที่ได้มา (พ.ศ.) ของครุภัณฑ์ชิ้นนี้ — ดึงตรงจากส่วนท้ายสตริงวันที่ (เช่น
  /// "28 พฤศจิกายน 2568" -> "2568") ไม่ต้องแปลงผ่าน DateTime ให้ยุ่งยาก เพราะ
  /// ปี พ.ศ. อยู่ในสตริงอยู่แล้วตรงๆ
  String? _acquiredYearOf(FixedAsset a) {
    final text = a.acquiredDate?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(' ');
    return parts.length == 3 ? parts.last : null;
  }

  /// ปีที่มีครุภัณฑ์อยู่จริง (distinct, เรียงใหม่ไปเก่า) — ใช้ทำตัวเลือกใน
  /// dropdown กรอง ไม่โชว์ปีที่ไม่มีครุภัณฑ์เลย
  List<String> get _availableAcquiredYears {
    final years = _assets.map(_acquiredYearOf).whereType<String>().toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  FixedAsset? get _selected => _selectedId == null ? null : _assets.where((a) => a.id == _selectedId).firstOrNull;

  double get _totalValue => _assets.fold(0, (s, a) => s + a.totalValue);
  int _countByStatus(String s) => _assets.where((a) => a.status == s).length;

  double get _totalNetBookValue => _assets.fold(0, (s, a) {
        final dep = calcDepreciation(a, _parseThaiDate(a.acquiredDate));
        return s + (dep?.netBookValue ?? a.totalValue);
      });

  /// ครุภัณฑ์ที่กรอกอายุการใช้งานไว้ครบพอจะคำนวณตารางค่าเสื่อมราคารายปีได้
  List<FixedAsset> get _assetsWithDepreciation =>
      _assets.where((a) => (a.usefulLifeYears ?? 0) > 0 && a.totalValue > 0).toList();

  bool _exportingDepreciation = false;

  Future<void> _exportDepreciationSchedule() async {
    setState(() => _exportingDepreciation = true);
    try {
      await DepreciationScheduleExportService.exportAndOpen(_assetsWithDepreciation);
      if (!mounted) return;
      showAppToast('สร้างตารางค่าเสื่อมราคาแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างตารางไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingDepreciation = false);
    }
  }

  bool _exportingLedger = false;

  Future<void> _exportAssetControlLedger() async {
    setState(() => _exportingLedger = true);
    try {
      await AssetControlLedgerExportService.exportAndOpen(_assets, parseDate: _parseThaiDate);
      if (!mounted) return;
      showAppToast('สร้างทะเบียนคุมทรัพย์สินแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างทะเบียนไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingLedger = false);
    }
  }

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
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบครุภัณฑ์ "${a.name}" ใช่หรือไม่?', style: _dialogContentStyle),
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
    if (confirmed == true && a.id != null) {
      await _repo.deleteFixedAsset(a.id!);
      if (_selectedId == a.id) _selectedId = null;
      _load();
    }
  }

  /// คัดลอกครุภัณฑ์เป็นรายการใหม่ทั้งชิ้น — เหมาะกับตอนซื้อของแบบเดียวกันหลายชิ้น
  /// พร้อมกัน (เช่น โต๊ะ 10 ตัว) คัดลอกทุกช่องมาตรงๆ ไม่ล้างอะไรเลย เติมแค่
  /// "(สำเนา)" ต่อชื่อ ให้ไปแก้เลขครุภัณฑ์/จำนวนเองทีหลัง — ไม่คัดลอกรูปถ่ายและ
  /// ประวัติซ่อมแซม/โอนย้าย เพราะเป็นข้อมูลเฉพาะของชิ้นเดิมจริงๆ
  Future<void> _duplicateAsset(FixedAsset a) async {
    try {
      final map = a.toMap();
      map.remove('id');
      map['name'] = '${a.name} (สำเนา)';
      map['photo_path'] = null;
      await _repo.insertFixedAsset(FixedAsset.fromMap(map));
      if (!mounted) return;
      showAppToast('คัดลอกครุภัณฑ์แล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกครุภัณฑ์ไม่สำเร็จ: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าทะเบียนครุภัณฑ์',
      icon: Icons.inventory_2_outlined,
      // มุมขวาบนมีปุ่ม "พิมพ์ตารางค่าเสื่อมราคา" อยู่แล้ว และมุมขวาล่างมีปุ่ม
      // "เพิ่มครุภัณฑ์" อยู่แล้ว ย้ายปุ่มไกด์ไปมุมซ้ายบนแทน (ไม่มีอะไรชน)
      corner: Alignment.topLeft,
      steps: const [
        'สลับมุมมองตาราง/กริดรูปภาพได้ที่ปุ่มมุมขวาของรายการ — มุมมองกริดเหมาะกับตอนต้องดูรูปครุภัณฑ์ประกอบ',
        'กดที่รายการในตารางเพื่อเปิดแผงรายละเอียดด้านขวา ดูประวัติการใช้งาน/ซ่อมบำรุงของครุภัณฑ์ชิ้นนั้น',
        'กรอกผู้ขาย/ประเภทเงิน/วิธีการได้มา/อายุการใช้งาน ให้ครบเพื่อให้ตรงกับแบบฟอร์มทะเบียนคุมครุภัณฑ์ของราชการ — ถ้ากรอกอายุการใช้งาน ระบบจะคำนวณค่าเสื่อมราคาโดยประมาณให้อัตโนมัติ (เป็นค่าประมาณการ ไม่ใช่ตัวเลขบัญชีที่รับรองอย่างเป็นทางการ)',
        'กด "พิมพ์ตารางค่าเสื่อมราคา" มุมขวาบนเพื่อส่งออกตารางค่าเสื่อมราคารายปีของครุภัณฑ์ทุกชิ้นที่กรอกอายุการใช้งานไว้แล้ว เป็นไฟล์ Excel พิมพ์ได้ (แสดงทุกปีตั้งแต่ปีที่ 1 จนครบอายุการใช้งาน)',
        'กด "ทะเบียนคุมทรัพย์สิน" เพื่อส่งออกทะเบียนคุมครุภัณฑ์ทุกชิ้นเป็นไฟล์ Excel ตามแบบฟอร์มทะเบียนคุมทรัพย์สินของราชการ (ประเภทเงิน/วิธีการได้มา/ค่าเสื่อมราคา/มูลค่าสุทธิ ครบตามที่กรอกไว้)',
        'กดปุ่ม "ค้นหาราคากลาง (สำนักงบประมาณ)" ในฟอร์มเพิ่ม/แก้ไข เพื่อค้นหาชื่อ+ราคากลางจากบัญชีราคามาตรฐานครุภัณฑ์มาเติมให้อัตโนมัติ (เป็นราคาประมาณการเบื้องต้น ควรตรวจสอบราคากลางจริงก่อนใช้อ้างอิงในเอกสารราชการ)',
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
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: BrandAccent.tealOn(context), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('ทะเบียนครุภัณฑ์',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (_assets.isEmpty || _exportingLedger) ? null : _exportAssetControlLedger,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              side: BorderSide(color: colors.outline),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            icon: _exportingLedger
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurfaceVariant))
                                : const Icon(Icons.receipt_long_outlined, size: 18),
                            label: Text(_exportingLedger ? 'กำลังสร้าง...' : 'ทะเบียนคุมทรัพย์สิน'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (_assetsWithDepreciation.isEmpty || _exportingDepreciation)
                                ? null
                                : _exportDepreciationSchedule,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              side: BorderSide(color: colors.outline),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            icon: _exportingDepreciation
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurfaceVariant))
                                : const Icon(Icons.print_outlined, size: 18),
                            label: Text(_exportingDepreciation ? 'กำลังสร้าง...' : 'พิมพ์ตารางค่าเสื่อมราคา'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCards(context, colors),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildListPane(context, colors)),
                            if (_selected != null) ...[
                              const SizedBox(width: 16),
                              SizedBox(width: 360, child: _buildDetailPane(context, colors, _selected!)),
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
              heroTag: 'fixed_assets_add_fab',
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

  Widget _buildSummaryCards(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'ใช้งานปกติ',
            value: '${_countByStatus('ใช้งานปกติ')}',
            unit: 'รายการ',
            icon: Icons.check_circle_outline,
            variant: KpiCardVariant.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RedKpiCard(
            label: 'ชำรุด',
            value: '${_countByStatus('ชำรุด')}',
            unit: 'รายการ',
            icon: Icons.error_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'รอจำหน่าย',
            value: '${_countByStatus('รอจำหน่าย')}',
            unit: 'รายการ',
            icon: Icons.delete_sweep_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'มูลค่ารวมทั้งหมด',
            value: formatBaht(_totalValue),
            unit: 'บาท',
            icon: Icons.inventory_2_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'มูลค่าสุทธิรวม (ประมาณ)',
            value: formatBaht(_totalNetBookValue),
            unit: 'บาท',
            icon: Icons.trending_down_outlined,
            variant: KpiCardVariant.teal,
          ),
        ),
        // เว้นที่ว่างท้ายแถวไว้ให้ปุ่มไกด์ลอยมุมซ้ายบน (แต่การ์ดยังต้องไม่ชนขอบขวา)
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildListPane(BuildContext context, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: _buildStatusFilterChips(colors)),
                _buildAcquiredYearFilter(context, colors),
                const SizedBox(width: 8),
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
          Divider(height: 1, color: colors.outline),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: colors.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          _assets.isEmpty ? 'ยังไม่มีครุภัณฑ์\nกด "เพิ่มครุภัณฑ์" เพื่อเริ่มต้น' : 'ไม่พบรายการตามตัวกรองที่เลือก',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4),
                        ),
                      ],
                    ),
                  )
                : (_viewMode == _AssetViewMode.table ? _buildTable(context, colors) : _buildGrid(context, colors)),
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
        child: DSFilterChip(
          label: label,
          isSelected: selected,
          onTap: () => setState(() => _statusFilter = value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [chip('ทั้งหมด', null), for (final s in _assetStatuses) chip(s, s)]),
    );
  }

  /// ตัวกรอง "ปีที่ได้มา" — แยกอิสระจากตัวสลับปีงบหลักที่ AppBar โดยตั้งใจ (ดู
  /// เหตุผลที่ field _acquiredYearFilter) ซ่อนไปเลยถ้ายังไม่มีครุภัณฑ์ที่มีวันที่
  /// ได้มาระบุไว้สักชิ้น กันโชว์ dropdown ว่างเปล่าไม่มีประโยชน์
  Widget _buildAcquiredYearFilter(BuildContext context, ColorScheme colors) {
    final years = _availableAcquiredYears;
    if (years.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _acquiredYearFilter,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18),
          hint: Text('ปีที่ได้มา (ทั้งหมด)', style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
          style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
          dropdownColor: colors.surface,
          items: [
            const DropdownMenuItem(value: null, child: Text('ปีที่ได้มา (ทั้งหมด)')),
            for (final y in years) DropdownMenuItem(value: y, child: Text('ปี $y')),
          ],
          onChanged: (v) => setState(() => _acquiredYearFilter = v),
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, ColorScheme colors) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.outlineVariant),
      itemBuilder: (_, i) {
        final a = _filtered[i];
        final selected = a.id == _selectedId;
        return ListTile(
          selected: selected,
          selectedTileColor: BrandAccent.teal(context).withValues(alpha: 0.1),
          leading: _thumbnail(a, colors, size: 40),
          title: Text(a.name, style: TextStyle(fontSize: AppTypography.body, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a.assetNumber ?? "-"} · ${a.location ?? "-"}', style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: _statusBadge(a.status),
          onTap: () => setState(() => _selectedId = a.id),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, ColorScheme colors) {
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
          borderRadius: BorderRadius.circular(RadiusSize.card),
          onTap: () => setState(() => _selectedId = a.id),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RadiusSize.card),
              border: Border.all(color: selected ? BrandAccent.teal(context) : colors.outline, width: selected ? 2 : 1),
              boxShadow: AppShadows.light1,
            ),
            child: Column(
              children: [
                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(9)), child: _thumbnail(a, colors, size: double.infinity))),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        '${a.assetNumber ?? "-"} · จำนวน ${a.quantity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 3),
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
    final variant = switch (status) {
      'ชำรุด' => BadgeVariant.danger,
      'รอจำหน่าย' => BadgeVariant.warning,
      _ => BadgeVariant.success,
    };
    return StatusBadge(label: status, variant: variant, compact: true);
  }

  Widget _buildDetailPane(BuildContext context, ColorScheme colors, FixedAsset a) {
    final amberBg = Color.alphaBlend(BrandColors.amber.withValues(alpha: 0.12), colors.surface);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RadiusSize.card),
                child: SizedBox(height: 140, width: double.infinity, child: _thumbnail(a, colors, size: double.infinity)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(a.name, style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.heading3, color: colors.onSurface))),
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
                    color: amberBg,
                    borderRadius: BorderRadius.circular(RadiusSize.md),
                    border: Border.all(color: BrandColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ค่าเสื่อมราคา (ประมาณการ)',
                        style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      _detailRow(colors, 'อัตรา/ปี', '${dep.ratePercentPerYear.toStringAsFixed(2)} %'),
                      _detailRow(colors, 'ค่าเสื่อมต่อปี', '${formatBaht(dep.annualDepreciation)} บาท'),
                      _detailRow(colors, 'ค่าเสื่อมสะสม', '${formatBaht(dep.accumulatedDepreciation)} บาท'),
                      _detailRow(colors, 'มูลค่าสุทธิ', '${formatBaht(dep.netBookValue)} บาท'),
                      const SizedBox(height: 4),
                      Text(
                        'คำนวณแบบเส้นตรงจากอายุการใช้งานที่กรอกไว้ เป็นค่าประมาณการเท่านั้น ไม่ใช่ตัวเลขทางบัญชีที่รับรองอย่างเป็นทางการ',
                        style: TextStyle(fontSize: AppTypography.micro, color: colors.onSurfaceVariant),
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _detailActionButton(colors, onTap: () => _openForm(existing: a), icon: Icons.edit_outlined, label: 'แก้ไข'),
                _detailActionButton(colors, onTap: () => _logRepair(a), icon: Icons.build_outlined, label: 'บันทึกซ่อมแซม'),
                _detailActionButton(colors, onTap: () => _transferLocation(a), icon: Icons.move_down_outlined, label: 'โอนย้าย'),
                _detailActionButton(colors, onTap: () => _markForDisposal(a), icon: Icons.delete_forever_outlined, label: 'จำหน่ายพัสดุ', danger: true),
                _detailActionButton(colors, onTap: () => _duplicateAsset(a), icon: Icons.copy_all_outlined, label: 'คัดลอก'),
                DsActionIconButtons(
                  actions: [
                    DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(a), danger: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('ประวัติ', style: TextStyle(fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant, fontSize: AppTypography.bodySmall)),
            const SizedBox(height: 6),
            FutureBuilder(
              future: _repo.getAssetEvents(a.id!),
              builder: (context, snapshot) {
                final events = snapshot.data ?? [];
                if (events.isEmpty) {
                  return Text('ยังไม่มีประวัติ', style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodySmall));
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
                                  Text('${e.eventType} · ${e.eventDate ?? "-"}', style: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface)),
                                  if (e.description != null) Text(e.description!, style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
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

  Widget _detailActionButton(ColorScheme colors, {required VoidCallback onTap, required IconData icon, required String label, bool danger = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? Colors.redAccent : colors.onSurface,
        side: BorderSide(color: danger ? Colors.redAccent.withValues(alpha: 0.5) : colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _detailRow(ColorScheme colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant))),
          Expanded(child: Text(value, style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurface))),
        ],
      ),
    );
  }

  Future<void> _logRepair(FixedAsset a) async {
    final descCtrl = TextEditingController();
    final desc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('บันทึกประวัติซ่อมแซม', style: _dialogTitleStyle),
        content: TextField(
          controller: descCtrl,
          autofocus: true,
          maxLines: 3,
          style: _dialogFieldStyle,
          decoration: _dialogFieldDecoration(ctx, label: 'รายละเอียดการซ่อม', hint: 'เช่น เปลี่ยนแบตเตอรี่'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, descCtrl.text.trim()),
            child: const Text('บันทึก'),
          ),
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
        title: const Text('โอนย้ายสถานที่', style: _dialogTitleStyle),
        content: TextField(
          controller: locCtrl,
          autofocus: true,
          style: _dialogFieldStyle,
          decoration: _dialogFieldDecoration(ctx, label: 'สถานที่ใหม่', hint: 'เช่น ห้องพัสดุ ชั้น 2'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, locCtrl.text.trim()),
            child: const Text('ยืนยัน'),
          ),
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
        title: const Text('จำหน่ายพัสดุ', style: _dialogTitleStyle),
        content: Text('ยืนยันเปลี่ยนสถานะ "${a.name}" เป็น "รอจำหน่าย" ใช่หรือไม่?', style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
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

/// การ์ด KPI โทนแดง — KpiCard ของดีไซน์ระบบไม่มี variant สีแดงในชุดโทเค็น จึง
/// ต้องสร้างเองแยกต่างหาก แต่ต้องเลียนแบบโครงสร้างจริงของ KpiCard ให้ครบ (แถบสี
/// บนสุด + ไอคอนในกล่องสี่เหลี่ยมมุมมน + ตัวเลขใหญ่) ไม่งั้นจะดูไม่เข้าชุดกับ
/// การ์ดข้างๆ ที่เป็น KpiCard จริง
class _RedKpiCard extends StatelessWidget {
  const _RedKpiCard({required this.label, required this.value, required this.unit, required this.icon});
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = BrandAccent.red(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(color: accent, boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 14)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: Dimensions.kpiIconSize,
                      height: Dimensions.kpiIconSize,
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(RadiusSize.md)),
                      child: Icon(icon, size: IconSizes.md, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                        style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(value,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppTypography.display1, fontWeight: AppTypography.weightExtraBold, letterSpacing: -1.1, height: 1, color: colors.onSurface)),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(unit, style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Future<void> _pickStandardPrice() async {
    final selected = await showStandardPricePickerDialog(context);
    if (selected == null) return;
    setState(() {
      if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = selected.name;
      _unitPriceCtrl.text = selected.price.toStringAsFixed(2);
    });
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
      title: Text(isEdit ? 'แก้ไขครุภัณฑ์' : 'เพิ่มครุภัณฑ์', style: _dialogTitleStyle),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(RadiusSize.card),
                        color: colors.surfaceContainerHighest,
                        border: Border.all(color: colors.outline),
                      ),
                      child: _photoPath != null && File(_photoPath!).existsSync()
                          ? ClipRRect(borderRadius: BorderRadius.circular(RadiusSize.card - 1), child: Image.file(File(_photoPath!), fit: BoxFit.cover))
                          : Icon(Icons.add_a_photo_outlined, color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _field(_assetNumberCtrl, 'เลขครุภัณฑ์', hint: 'เช่น ครภ.001/2569'),
                _field(_nameCtrl, 'รายการ *', required: true, hint: 'เช่น โต๊ะทำงาน'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: OutlinedButton.icon(
                      onPressed: _pickStandardPrice,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        side: BorderSide(color: colors.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.price_change_outlined, size: 16),
                      label: const Text('ค้นหาราคากลาง (สำนักงบประมาณ)'),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _field(_quantityCtrl, 'จำนวน', keyboardType: TextInputType.number, hint: 'เช่น 1')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_unitPriceCtrl, 'ราคาต่อหน่วย (บาท)', keyboardType: TextInputType.number, hint: 'เช่น 3500.00')),
                  ],
                ),
                _field(_locationCtrl, 'สถานที่จัดวาง', hint: 'เช่น ห้องพัสดุ ชั้น 2'),
                InkWell(
                  onTap: _pickAcquiredDate,
                  borderRadius: BorderRadius.circular(RadiusSize.md),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: InputDecorator(
                      decoration: _dialogFieldDecoration(context, label: 'วันที่ได้มา').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                      child: Text(_acquiredDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _dialogFieldDecoration(context, label: 'สถานะ').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                  items: _assetStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'ใช้งานปกติ'),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ข้อมูลสำหรับทะเบียนคุมครุภัณฑ์/ทรัพย์สิน',
                    style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                ),
                const SizedBox(height: 10),
                _field(_vendorNameCtrl, 'ผู้ขาย/ผู้รับจ้าง', hint: 'เช่น ร้านเจริญพาณิชย์'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _fundType,
                    isExpanded: true,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(context, label: 'ประเภทเงิน').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ...fixedAssetFundTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (v) => setState(() => _fundType = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _procurementMethod,
                    isExpanded: true,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(context, label: 'วิธีการได้มา').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ...fixedAssetProcurementMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _procurementMethod = v),
                  ),
                ),
                _field(_usefulLifeYearsCtrl, 'อายุการใช้งาน (ปี)', keyboardType: TextInputType.number, hint: 'เช่น 5'),
                Text(
                  'กรอกอายุการใช้งานเพื่อให้ระบบคำนวณค่าเสื่อมราคาโดยประมาณให้อัตโนมัติ (ไม่บังคับ)',
                  style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant),
                ),
              ],
            ),
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

  Widget _field(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: ctrl,
        style: _dialogFieldStyle,
        keyboardType: keyboardType,
        decoration: _dialogFieldDecoration(context, label: label, hint: hint),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null : null,
      ),
    );
  }
}
