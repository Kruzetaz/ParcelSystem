// repair_history_screen.dart
// "ประวัติซ่อมครุภัณฑ์" (เมนูรวมศูนย์) — ก่อนหน้านี้ดูประวัติซ่อมได้แค่ทีละชิ้น
// ในหน้าทะเบียนครุภัณฑ์ (แผงรายละเอียดด้านขวา) หน้านี้รวมประวัติซ่อมของครุภัณฑ์
// ทุกชิ้นมาไว้ที่เดียว เรียงตามวันที่ล่าสุด ค้นหา/กดดูครุภัณฑ์ต้นทางได้ทันที

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/asset_repair_entry.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kpi_card.dart';
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;
import '../services/asset_repair_export_service.dart';

class RepairHistoryScreen extends StatefulWidget {
  // ปุ่มลัด "ดูครุภัณฑ์" ต่อแถว — พาไปหน้าทะเบียนครุภัณฑ์พร้อมเลือกชิ้นนั้นไว้แล้ว
  final void Function(int assetId) onViewAsset;

  const RepairHistoryScreen({super.key, required this.onViewAsset});
  @override
  State<RepairHistoryScreen> createState() => _RepairHistoryScreenState();
}

class _RepairHistoryScreenState extends State<RepairHistoryScreen> {
  final _repo = ProcurementRepository();
  List<AssetRepairEntry> _entries = [];
  bool _loading = true;
  bool _exporting = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repo.getAssetRepairHistory();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<AssetRepairEntry> get _filtered {
    if (_query.trim().isEmpty) return _entries;
    final q = _query.trim().toLowerCase();
    return _entries.where((e) =>
        e.assetName.toLowerCase().contains(q) ||
        (e.assetNumber?.toLowerCase().contains(q) ?? false)).toList();
  }

  int get _thisYearCount {
    final buddhistYear = (DateTime.now().year + 543).toString();
    return _entries.where((e) => e.eventDate?.trim().endsWith(buddhistYear) ?? false).length;
  }

  int get _distinctAssetCount => _entries.map((e) => e.assetId).toSet().length;

  Future<void> _confirmDelete(AssetRepairEntry e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        content: Text(
          'ต้องการลบประวัติซ่อม "${e.assetName}" วันที่ ${e.eventDate ?? "-"} ใช่หรือไม่?',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteAssetEvent(e.eventId);
      if (!mounted) return;
      showAppToast('ลบประวัติซ่อมแล้ว');
      _load();
    } catch (err) {
      if (!mounted) return;
      showAppToast('ลบไม่สำเร็จ: $err', isError: true);
    }
  }

  /// ส่งออกเฉพาะรายการที่กรอง/ค้นหาอยู่ตอนนี้เป็นไฟล์ Excel (ตรงกับที่เห็นบนจอ
  /// จริงๆ ไม่ใช่ทั้งหมดในระบบเสมอ) แล้วเปิดไฟล์ให้อัตโนมัติ
  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await AssetRepairExportService.exportAndOpen(_filtered);
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
      title: 'วิธีใช้หน้าประวัติซ่อมครุภัณฑ์',
      icon: Icons.build_outlined,
      // การ์ดสรุปด้านบนกว้างเต็มจอ การ์ดขวาสุดโดนปุ่มไกด์มุมขวาบน (ค่า default)
      // บังตัวเลข — หน้านี้ไม่มีปุ่มลอยอื่นเลย ย้ายไปมุมขวาล่างแทน
      corner: Alignment.bottomRight,
      steps: const [
        'หน้านี้รวมประวัติซ่อมแซมของครุภัณฑ์ทุกชิ้นมาไว้ที่เดียว เรียงตามวันที่บันทึกล่าสุด',
        'การบันทึกซ่อมแซมยังต้องทำที่หน้า "ทะเบียนครุภัณฑ์" ผ่านปุ่ม "บันทึกซ่อมแซม" ที่แผงรายละเอียดของครุภัณฑ์แต่ละชิ้นเหมือนเดิม — หน้านี้ไว้ดูภาพรวมและค้นหาเท่านั้น',
        'กดปุ่ม "ดูครุภัณฑ์" ที่แถวไหน จะพาไปหน้าทะเบียนครุภัณฑ์พร้อมเลือกชิ้นนั้นไว้ให้ทันที',
        'ถ้าบันทึกผิด กดปุ่มถังขยะที่แถวนั้นเพื่อลบประวัติซ่อมรายการนี้ได้',
        'กดปุ่ม "ส่งออก Excel" เพื่อบันทึกรายการที่เห็นอยู่ตอนนี้ (ตามที่ค้นหา/กรองไว้) เป็นไฟล์ Excel',
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build_outlined, color: BrandAccent.tealOn(context), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('ประวัติซ่อมครุภัณฑ์',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCards(colors),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                hintText: 'ค้นหาชื่อ/เลขครุภัณฑ์',
                                hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
                                ),
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _entries.isEmpty || _exporting ? null : _exportToExcel,
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
                      const SizedBox(height: 12),
                      Expanded(
                        child: _filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.build_outlined, size: 64, color: colors.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text(
                                      _entries.isEmpty
                                          ? 'ยังไม่มีประวัติซ่อมครุภัณฑ์\nไปบันทึกที่หน้า "ทะเบียนครุภัณฑ์" ก่อน'
                                          : 'ไม่พบรายการที่ค้นหา',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => _buildRow(context, colors, _filtered[i]),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'ประวัติซ่อมทั้งหมด',
            value: '${_entries.length}',
            unit: 'รายการ',
            icon: Icons.build_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'ปีงบประมาณนี้',
            value: '$_thisYearCount',
            unit: 'รายการ',
            icon: Icons.event_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'จำนวนครุภัณฑ์ที่เคยซ่อม',
            value: '$_distinctAssetCount',
            unit: 'ชิ้น',
            icon: Icons.inventory_2_outlined,
            variant: KpiCardVariant.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, ColorScheme colors, AssetRepairEntry e) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.build_outlined, size: 18, color: BrandAccent.tealOn(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.assetNumber != null ? '${e.assetName} (${e.assetNumber})' : e.assetName,
                        style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body, color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(e.eventDate ?? '-', style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                  ],
                ),
                if (e.description?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(e.description!, style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (e.assetLocation?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text('สถานที่: ${e.assetLocation}', style: TextStyle(fontSize: AppTypography.tiny, color: colors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          DsActionIconButtons(
            actions: [
              DsRowAction(icon: Icons.inventory_2_outlined, tooltip: 'ดูครุภัณฑ์', onTap: () => widget.onViewAsset(e.assetId)),
              DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(e), danger: true),
            ],
          ),
        ],
      ),
    );
  }
}
