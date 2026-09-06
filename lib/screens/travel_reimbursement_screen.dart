// travel_reimbursement_screen.dart
// จอหลักของโมดูล "เบิกจ่ายค่าใช้จ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)" — สลับระหว่าง
// "รายการที่เคยบันทึกไว้" (list) กับวิซาร์ดกรอกข้อมูล ([TravelReimbursementWizardScreen])
// กด "+ สร้างใหม่" หรือแตะแถวเดิมเพื่อกลับเข้าไปแก้ไข — บันทึกเสร็จจะกลับมาที่
// รายการอัตโนมัติ (ตรงกับที่ผู้ใช้ถามหา "กดบันทึกแล้วดูที่เคยทำได้ตรงไหน")

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/travel_reimbursement.dart';
import '../theme/design_tokens.dart';
import '../utils/money_format.dart';
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;
import '../widgets/design_system/kpi_card.dart';
import '../widgets/guide_panel.dart';
import 'travel_reimbursement_wizard_screen.dart';

class TravelReimbursementScreen extends StatefulWidget {
  const TravelReimbursementScreen({super.key});
  @override
  State<TravelReimbursementScreen> createState() => _TravelReimbursementScreenState();
}

class _TravelReimbursementScreenState extends State<TravelReimbursementScreen> {
  final _repo = ProcurementRepository();
  bool _loading = true;
  List<TravelReimbursement> _items = [];
  TravelReimbursement? _editing;
  bool _showWizard = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.getAllTravelReimbursements();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _openNew() {
    setState(() {
      _editing = null;
      _showWizard = true;
    });
  }

  void _openExisting(TravelReimbursement r) {
    setState(() {
      _editing = r;
      _showWizard = true;
    });
  }

  void _onSaved() {
    setState(() => _showWizard = false);
    _load();
  }

  int get _thisYearCount {
    final buddhistYear = (DateTime.now().year + 543).toString();
    return _items.where((r) => r.startDate?.trim().endsWith(buddhistYear) ?? false).length;
  }

  double get _totalAmount => _items.fold(0, (sum, r) => sum + (r.totalAmount ?? 0));

  Future<void> _delete(TravelReimbursement r) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text('ลบใบเบิก "${r.subject ?? r.documentNumber ?? '(ไม่มีชื่อเรื่อง)'}" — ลบแล้วกู้คืนไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || r.id == null) return;
    await _repo.deleteTravelReimbursement(r.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_showWizard) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'กลับไปหน้ารายการ',
                  onPressed: () => setState(() => _showWizard = false),
                ),
                const SizedBox(width: 8),
                Text(
                  _editing == null ? 'สร้างใบเบิกใหม่' : 'แก้ไขใบเบิก',
                  style: TextStyle(fontSize: AppTypography.heading3, fontWeight: AppTypography.weightBold),
                ),
              ],
            ),
          ),
          Expanded(
            child: TravelReimbursementWizardScreen(
              key: ValueKey(_editing?.id ?? 'new'),
              existingReimbursement: _editing,
              onSaved: _onSaved,
            ),
          ),
        ],
      );
    }

    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้เบิกจ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)',
      icon: Icons.card_travel_outlined,
      steps: const [
        'หน้านี้แสดงรายการใบเบิกที่เคยบันทึกไว้ทั้งหมด — แตะแถวไหนก็เข้าไปแก้ไขต่อได้',
        'กด "+ สร้างใหม่" เพื่อเริ่มใบเบิกใหม่ 1 ใบต่อการเดินทาง 1 ครั้ง',
        'กรอกครบ 3 แท็บแล้วกด "สร้างเอกสาร Word" ระบบจะสร้างให้ครบ 3 ใบพร้อมกัน และบันทึกกลับมาที่รายการนี้ให้อัตโนมัติ',
      ],
      corner: Alignment.bottomRight,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.card_travel_outlined, color: BrandAccent.tealOn(context), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('เบิกจ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                          ),
                          FilledButton.icon(
                            onPressed: _openNew,
                            icon: const Icon(Icons.add),
                            label: const Text('สร้างใหม่'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('รายการใบเบิกค่าใช้จ่ายเดินทางไปราชการที่เคยบันทึกไว้ — แตะเพื่อแก้ไขหรือสร้างเอกสารซ้ำ',
                          style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.card_travel_outlined, size: 64, color: colors.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text('ยังไม่มีรายการ — กด "สร้างใหม่" เพื่อเริ่มใบแรก',
                                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) => _ReimbursementRow(
                                  item: _items[i],
                                  onTap: () => _openExisting(_items[i]),
                                  onDelete: () => _delete(_items[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'ใบเบิกทั้งหมด',
            value: '${_items.length}',
            unit: 'ใบ',
            icon: Icons.card_travel_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'ปีงบประมาณนี้',
            value: '$_thisYearCount',
            unit: 'ใบ',
            icon: Icons.event_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'ยอดเบิกจ่ายรวมทั้งหมด',
            value: formatBaht(_totalAmount),
            unit: 'บาท',
            icon: Icons.payments_outlined,
            variant: KpiCardVariant.teal,
          ),
        ),
      ],
    );
  }
}

class _ReimbursementRow extends StatelessWidget {
  final TravelReimbursement item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReimbursementRow({required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasSubject = item.subject?.trim().isNotEmpty ?? false;
    final dateRange = [item.startDate, item.endDate].where((d) => d != null && d.isNotEmpty).join(' - ');
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RadiusSize.card),
            border: Border.all(color: colors.outline),
            boxShadow: AppShadows.light1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BrandAccent.teal(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(RadiusSize.md),
                ),
                child: Icon(Icons.card_travel_outlined, size: 20, color: BrandAccent.tealOn(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasSubject ? item.subject! : 'ยังไม่ระบุเรื่อง',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: AppTypography.weightSemiBold,
                          fontSize: AppTypography.body,
                          color: hasSubject ? colors.onSurface : colors.onSurfaceVariant,
                          fontStyle: hasSubject ? FontStyle.normal : FontStyle.italic,
                        )),
                    if (item.destination?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 13, color: colors.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(item.destination!,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (dateRange.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 13, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(dateRange,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: Text(
                  item.totalAmount != null ? '${formatBaht(item.totalAmount)} บาท' : '-',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: AppTypography.weightBold, color: colors.primary),
                ),
              ),
              const SizedBox(width: 4),
              DsActionIconButtons(
                actions: [
                  DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: onDelete, danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
