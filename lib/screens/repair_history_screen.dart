// repair_history_screen.dart
// "ประวัติซ่อมครุภัณฑ์" (เมนูรวมศูนย์) — ก่อนหน้านี้ดูประวัติซ่อมได้แค่ทีละชิ้น
// ในหน้าทะเบียนครุภัณฑ์ (แผงรายละเอียดด้านขวา) หน้านี้รวมประวัติซ่อมของครุภัณฑ์
// ทุกชิ้นมาไว้ที่เดียว เรียงตามวันที่ล่าสุด ค้นหา/กดดูครุภัณฑ์ต้นทางได้ทันที

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/asset_repair_entry.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';

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
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบประวัติซ่อม "${e.assetName}" วันที่ ${e.eventDate ?? "-"} ใช่หรือไม่?'),
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
                      _buildSummaryCards(colors),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 20),
                          hintText: 'ค้นหาชื่อ/เลขครุภัณฑ์',
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _filtered.isEmpty
                            ? Center(
                                child: Text(
                                  _entries.isEmpty
                                      ? 'ยังไม่มีประวัติซ่อมครุภัณฑ์\nไปบันทึกที่หน้า "ทะเบียนครุภัณฑ์" ก่อน'
                                      : 'ไม่พบรายการที่ค้นหา',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => _buildRow(colors, _filtered[i]),
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
        card('ประวัติซ่อมทั้งหมด', '${_entries.length} รายการ', colors.primary),
        const SizedBox(width: 12),
        card('ปีงบประมาณนี้', '$_thisYearCount รายการ', Colors.orange),
        const SizedBox(width: 12),
        card('จำนวนครุภัณฑ์ที่เคยซ่อม', '$_distinctAssetCount ชิ้น', Colors.redAccent),
      ],
    );
  }

  Widget _buildRow(ColorScheme colors, AssetRepairEntry e) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.build_outlined, size: 18, color: colors.primary),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(e.eventDate ?? '-', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                    ],
                  ),
                  if (e.description?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(e.description!, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
                  ],
                  if (e.assetLocation?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text('สถานที่: ${e.assetLocation}', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              color: colors.primary,
              tooltip: 'ดูครุภัณฑ์',
              onPressed: () => widget.onViewAsset(e.assetId),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              tooltip: 'ลบ',
              onPressed: () => _confirmDelete(e),
            ),
          ],
        ),
      ),
    );
  }
}
