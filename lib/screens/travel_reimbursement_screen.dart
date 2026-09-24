// travel_reimbursement_screen.dart
// จอหลักของโมดูล "เบิกจ่ายค่าใช้จ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)" — สลับระหว่าง
// "รายการที่เคยบันทึกไว้" (list) กับวิซาร์ดกรอกข้อมูล ([TravelReimbursementWizardScreen])
// กด "+ สร้างใหม่" หรือแตะแถวเดิมเพื่อกลับเข้าไปแก้ไข — บันทึกเสร็จจะกลับมาที่
// รายการอัตโนมัติ (ตรงกับที่ผู้ใช้ถามหา "กดบันทึกแล้วดูที่เคยทำได้ตรงไหน")

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/personnel.dart';
import '../models/school_settings.dart';
import '../models/travel_participant.dart';
import '../models/travel_reimbursement.dart';
import '../services/travel_document_generator.dart';
import '../services/toast_service.dart';
import '../theme/design_tokens.dart';
import '../utils/money_format.dart';
import '../widgets/design_system/data_table_shell.dart'
    show
        DsActionIconButtons,
        DsRowAction,
        DsColumn,
        DsTableHeader,
        DsTableRow,
        DsCell,
        DsTwoLineCell,
        DsAmountCell;
import '../widgets/design_system/kpi_card.dart';
import '../widgets/guide_panel.dart';
import 'travel_reimbursement_wizard_screen.dart';

class TravelReimbursementScreen extends StatefulWidget {
  const TravelReimbursementScreen({super.key});
  @override
  State<TravelReimbursementScreen> createState() =>
      _TravelReimbursementScreenState();
}

const _columns = [
  DsColumn('เรื่อง / สถานที่', flex: 3),
  DsColumn('ช่วงวันเดินทาง', width: 180),
  DsColumn('ยอดรวม', width: 130, align: TextAlign.right),
  DsColumn('ดำเนินการ', width: 130, align: TextAlign.right),
];

class _TravelReimbursementScreenState extends State<TravelReimbursementScreen> {
  final _repo = ProcurementRepository();
  bool _loading = true;
  List<TravelReimbursement> _items = [];
  TravelReimbursement? _editing;
  bool _showWizard = false;
  int? _generatingId;

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
    return _items
        .where((r) => r.startDate?.trim().endsWith(buddhistYear) ?? false)
        .length;
  }

  double get _totalAmount =>
      _items.fold(0, (sum, r) => sum + (r.totalAmount ?? 0));

  Future<void> _delete(TravelReimbursement r) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text(
            'ลบใบเบิก "${r.subject ?? r.documentNumber ?? '(ไม่มีชื่อเรื่อง)'}" — ลบแล้วกู้คืนไม่ได้'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
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

  /// สร้างเอกสารทั้ง 3 ใบตรงจากรายการเลย ไม่ต้องเปิดวิซาร์ดก่อน — ใช้ผู้รับเงิน/
  /// ผู้ตรวจสอบตามที่บันทึกไว้แล้ว (logic เดียวกับปุ่ม "สร้างเอกสาร Word" ในวิซาร์ด)
  Future<void> _generateDocumentsFor(TravelReimbursement item) async {
    if (item.id == null) return;
    setState(() => _generatingId = item.id);
    try {
      final participants = await _repo.getTravelParticipants(item.id!);
      if (participants.isEmpty) {
        if (!mounted) return;
        ToastController.instance.show(
            'ยังไม่มีรายชื่อผู้เดินทาง — เปิดเข้าไปเพิ่มก่อน',
            isError: true);
        return;
      }
      final school = await _repo.getSchoolSettings() ?? const SchoolSettings();
      final personnel = await _repo.getAllPersonnel(activeOnly: true);
      Personnel? findPersonnel(int? id) {
        if (id == null) return null;
        for (final p in personnel) {
          if (p.id == id) return p;
        }
        return null;
      }

      final payee = item.isAdvancePayer
          ? findPersonnel(item.advancePayerPersonnelId)
          : findPersonnel(item.requesterPersonnelId);
      final checker = findPersonnel(item.checkerPersonnelId);
      final files = await TravelDocumentGenerator.generateAll(
        reimbursement: item,
        participants: participants,
        school: school,
        payee: payee,
        checker: checker,
      );
      if (!mounted) return;
      ToastController.instance.show('สร้างเอกสารสำเร็จ ${files.length} ไฟล์');
      if (files.isNotEmpty) {
        await TravelDocumentGenerator.openFile(files.first.path);
      }
    } catch (e) {
      if (!mounted) return;
      ToastController.instance.show('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingId = null);
    }
  }

  /// คัดลอกใบเบิกเป็นรายการใหม่พร้อมรายชื่อผู้เดินทางทั้งหมด — ไม่ผูกกับ id เดิม
  /// เลย (ทั้งใบเบิกและผู้เดินทางแต่ละคน) กันไปทับ/แย่งกับรายการต้นฉบับ
  Future<void> _duplicate(TravelReimbursement item) async {
    if (item.id == null) return;
    try {
      final participants = await _repo.getTravelParticipants(item.id!);
      final map = item.toMap();
      map.remove('id');
      map['document_number'] =
          '${(item.documentNumber?.trim().isNotEmpty ?? false) ? item.documentNumber! : "(ไม่มีเลขที่)"} (สำเนา)';
      map['created_at'] = null;
      final copy = TravelReimbursement.fromMap(map);
      final newParticipants = participants
          .map((p) => TravelParticipant(
                personnelId: p.personnelId,
                participantName: p.participantName,
                position: p.position,
                allowanceAmount: p.allowanceAmount,
                accommodationAmount: p.accommodationAmount,
                transportAmount: p.transportAmount,
                registrationFee: p.registrationFee,
              ))
          .toList();
      await _repo.saveTravelReimbursementWithParticipants(
          copy, newParticipants);
      if (!mounted) return;
      ToastController.instance.show('คัดลอกใบเบิกแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      ToastController.instance.show('คัดลอกไม่สำเร็จ: $e', isError: true);
    }
  }

  List<Widget> _cellsFor(TravelReimbursement item) {
    final colors = Theme.of(context).colorScheme;
    final hasSubject = item.subject?.trim().isNotEmpty ?? false;
    final dateRange = [item.startDate, item.endDate]
        .where((d) => d != null && d.isNotEmpty)
        .join(' - ');
    return [
      DsCell(
        column: _columns[0],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BrandAccent.teal(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(RadiusSize.sm),
                ),
                child: Icon(Icons.card_travel_outlined,
                    size: 16, color: BrandAccent.tealOn(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DsTwoLineCell(
                  primary: hasSubject ? item.subject! : 'ยังไม่ระบุเรื่อง',
                  secondary: item.destination,
                ),
              ),
            ],
          ),
        ),
      ),
      DsCell(
        column: _columns[1],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 12, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Flexible(
              child: Text(dateRange.isEmpty ? '-' : dateRange,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppTypography.bodySmall,
                      color: colors.onSurfaceVariant)),
            ),
          ],
        ),
      ),
      DsCell(
        column: _columns[2],
        child: DsAmountCell(
            amount: item.totalAmount != null
                ? '${formatBaht(item.totalAmount)} บาท'
                : '-'),
      ),
      DsCell(
        column: _columns[3],
        child: _generatingId == item.id
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : DsActionIconButtons(
                actions: [
                  DsRowAction(
                      icon: Icons.visibility_outlined,
                      tooltip: 'เปิด/แก้ไข',
                      onTap: () => _openExisting(item)),
                  DsRowAction(
                      icon: Icons.print_outlined,
                      tooltip: 'สร้างเอกสาร Word',
                      onTap: () => _generateDocumentsFor(item)),
                  DsRowAction(
                      icon: Icons.copy_all_outlined,
                      tooltip: 'คัดลอกใบเบิก',
                      onTap: () => _duplicate(item)),
                  DsRowAction(
                      icon: Icons.delete_outline,
                      tooltip: 'ลบ',
                      onTap: () => _delete(item),
                      danger: true),
                ],
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_showWizard) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant))),
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
                  style: TextStyle(
                      fontSize: AppTypography.heading3,
                      fontWeight: AppTypography.weightBold),
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
                          Icon(Icons.card_travel_outlined,
                              color: BrandAccent.tealOn(context), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('เบิกจ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppTypography.heading2,
                                    fontWeight: AppTypography.weightExtraBold,
                                    color: colors.onSurface)),
                          ),
                          FilledButton.icon(
                            onPressed: _openNew,
                            icon: const Icon(Icons.add),
                            label: const Text('สร้างใหม่'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(RadiusSize.md)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'รายการใบเบิกค่าใช้จ่ายเดินทางไปราชการที่เคยบันทึกไว้ — แตะเพื่อแก้ไขหรือสร้างเอกสารซ้ำ',
                          style: TextStyle(
                              fontSize: AppTypography.bodyMedium,
                              color: colors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.card_travel_outlined,
                                        size: 64,
                                        color: colors.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text(
                                        'ยังไม่มีรายการ — กด "สร้างใหม่" เพื่อเริ่มใบแรก',
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 16)),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius:
                                      BorderRadius.circular(RadiusSize.card),
                                  border: Border.all(color: colors.outline),
                                  boxShadow: AppShadows.light1,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DsTableHeader(columns: _columns),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _items.length,
                                        itemBuilder: (context, i) => DsTableRow(
                                          index: i,
                                          onTap: () => _openExisting(_items[i]),
                                          cells: _cellsFor(_items[i]),
                                        ),
                                      ),
                                    ),
                                  ],
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
