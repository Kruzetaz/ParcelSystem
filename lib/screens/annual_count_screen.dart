// annual_count_screen.dart
// ตรวจนับพัสดุประจำปี (blueprint หน้าที่ 10) — บันทึกประวัติการตรวจสอบ
// สินทรัพย์ตามกฎหมายประจำปีงบประมาณ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/annual_count.dart';
import '../models/fixed_asset.dart';
import '../models/material_item.dart';
import '../models/personnel.dart';
import '../services/annual_count_export_service.dart';
import '../services/annual_inventory_document_service.dart';
import '../services/gemini_service.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../widgets/memory_text_field.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/status_badge.dart'
    show StatusBadge, BadgeVariant;
import '../widgets/design_system/data_table_shell.dart'
    show DsActionIconButtons, DsRowAction;
import '../widgets/design_system/clearable_text_field.dart';

const _memberRoles = ['ประธานกรรมการ', 'กรรมการ', 'กรรมการและเลขานุการ'];

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogButtonTextStyle =
    TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

/// สร้างกรอบช่องกรอกในป๊อปอัพให้ชัดเจนกว่าค่าเริ่มต้นของธีม (colors.outline
/// จางเกินไปสำหรับช่องกรอกเดี่ยวๆ ที่ไม่มีเงา/สีพื้นต่างช่วยตัดขอบ)
InputDecoration _dialogFieldDecoration(BuildContext context,
    {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.outline;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(
        color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
    ),
  );
}

const _thaiMonths = [
  '',
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];
String _formatThai(DateTime d) =>
    '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';
String _currentFiscalYear() {
  final now = DateTime.now();
  final buddhistYear = now.year + 543;
  return now.month >= 10 ? '${buddhistYear + 1}' : '$buddhistYear';
}

class AnnualCountScreen extends StatefulWidget {
  const AnnualCountScreen({super.key});
  @override
  State<AnnualCountScreen> createState() => _AnnualCountScreenState();
}

class _AnnualCountScreenState extends State<AnnualCountScreen> {
  final _repo = ProcurementRepository();
  List<AnnualCount> _counts = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllAnnualCounts();
    if (!mounted) return;
    setState(() {
      _counts = list;
      _loading = false;
    });
  }

  Future<void> _startNewCount() async {
    final totalItems = await _repo.countAllAssetsAndMaterials();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnualCountFormDialog(suggestedTotal: totalItems),
    );
    if (saved == true) _load();
  }

  Future<void> _openForm(AnnualCount existing) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnualCountFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(AnnualCount a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบบันทึกการตรวจนับปี ${a.fiscalYear} ใช่หรือไม่?',
            style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && a.id != null) {
      await _repo.deleteAnnualCount(a.id!);
      _load();
    }
  }

  /// พิมพ์ชุดเอกสารตรวจสอบพัสดุประจำปี (บันทึกขออนุมัติ -> คำสั่งแต่งตั้ง ->
  /// รายงานผล -> บัญชีพัสดุชำรุด) ของรอบตรวจนับนี้เป็นไฟล์ .docx เดียว
  Future<void> _printInventoryDocs(AnnualCount a) async {
    if (a.members.isEmpty) {
      showAppToast(
          'กรุณากรอกรายชื่อคณะกรรมการก่อนพิมพ์เอกสาร (แก้ไขบันทึกนี้แล้วเพิ่มกรรมการ)',
          isError: true);
      return;
    }
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน',
          isError: true);
      return;
    }
    try {
      final fixedAssets = await _repo.getAllFixedAssets();
      if (!mounted) return;
      await AnnualInventoryDocumentService.exportAndOpen(
          count: a, school: school, fixedAssets: fixedAssets);
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    }
  }

  /// ส่งออกประวัติการตรวจนับที่เห็นอยู่ตอนนี้เป็นไฟล์ Excel แล้วเปิดไฟล์ให้อัตโนมัติ
  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await AnnualCountExportService.exportAndOpen(_counts);
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
      title: 'วิธีใช้หน้าตรวจนับพัสดุประจำปี',
      icon: Icons.checklist_outlined,
      steps: const [
        'ใช้บันทึกผลการตรวจนับพัสดุ/ครุภัณฑ์จริงประจำปีงบประมาณ เทียบกับจำนวนที่มีอยู่ในทะเบียน ตามที่ระเบียบพัสดุกำหนดให้ตรวจนับอย่างน้อยปีละ 1 ครั้ง',
        'กด "เริ่มการตรวจนับ" มุมขวาล่างเพื่อเปิดรอบตรวจนับใหม่ของปีงบประมาณปัจจุบัน',
        'บันทึกจำนวนที่พบจริง/ชำรุด/สูญหาย ไว้เป็นหลักฐานประกอบการรายงาน สตง. และใช้เทียบกับรอบก่อนหน้าได้',
        'กรอกเลขที่เอกสาร 3 ฉบับ (บันทึกขออนุมัติ/คำสั่งแต่งตั้ง/รายงานผล) + รายชื่อคณะกรรมการ + รายการพัสดุชำรุด (ถ้ามี) แล้วกดไอคอนพิมพ์ที่การ์ดแต่ละรอบ เพื่อพิมพ์เอกสารชุดตรวจสอบพัสดุประจำปีครบทั้ง 4 ส่วนในไฟล์เดียว',
        'กดปุ่ม "ส่งออก Excel" มุมบนขวาเพื่อบันทึกประวัติการตรวจนับที่เห็นอยู่ตอนนี้เป็นไฟล์ .xlsx',
      ],
      // มุมขวาบนชนกับปุ่ม "ส่งออก Excel" ในหัวหน้า และมุมขวาล่างมี FAB
      // "เริ่มการตรวจนับ" อยู่แล้ว — เหลือแค่มุมซ้ายล่างที่ว่าง
      corner: Alignment.bottomLeft,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_outlined,
                            color: BrandAccent.tealOn(context), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'ตรวจนับพัสดุประจำปี ${_currentFiscalYear()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: AppTypography.heading2,
                                  fontWeight: AppTypography.weightExtraBold,
                                  color: colors.onSurface)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _counts.isEmpty || _exporting
                              ? null
                              : _exportToExcel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(RadiusSize.md)),
                            textStyle: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                          icon: _exporting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onSurfaceVariant))
                              : const Icon(Icons.file_download_outlined,
                                  size: 18),
                          label: Text(
                              _exporting ? 'กำลังส่งออก...' : 'ส่งออก Excel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _counts.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.checklist_outlined,
                                          size: 64,
                                          color: colors.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text(
                                          'ยังไม่มีประวัติการตรวจนับ\nกด "เริ่มการตรวจนับ" เพื่อเริ่มต้น',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              fontSize:
                                                  AppTypography.heading4)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _counts.length,
                                  padding: const EdgeInsets.only(bottom: 80),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) =>
                                      _buildCard(context, colors, _counts[i]),
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
              heroTag: 'annual_count_add_fab',
              onPressed: _startNewCount,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เริ่มการตรวจนับ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, AnnualCount a) {
    final isDone = a.status == 'เสร็จสิ้น';
    final hasIssue = (a.damagedLostItems ?? 0) > 0;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(a),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandAccent.teal(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(RadiusSize.sm),
                    ),
                    child: Text('ปี ${a.fiscalYear}',
                        style: TextStyle(
                            fontSize: AppTypography.caption,
                            color: BrandAccent.tealOn(context),
                            fontWeight: AppTypography.weightSemiBold)),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: a.status,
                    variant:
                        isDone ? BadgeVariant.success : BadgeVariant.warning,
                    compact: true,
                  ),
                  if (hasIssue) ...[
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: 'พบชำรุด/สูญหาย ${a.damagedLostItems}',
                      variant: BadgeVariant.danger,
                      compact: true,
                    ),
                  ],
                  const Spacer(),
                  DsActionIconButtons(
                    actions: [
                      DsRowAction(
                          icon: Icons.print_outlined,
                          tooltip: 'พิมพ์เอกสารชุดตรวจสอบพัสดุประจำปี',
                          onTap: () => _printInventoryDocs(a)),
                      DsRowAction(
                          icon: Icons.delete_outline,
                          tooltip: 'ลบ',
                          onTap: () => _confirmDelete(a),
                          danger: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  'เริ่มตรวจ: ${a.startDate ?? "-"}  ·  ผู้รับผิดชอบ: ${a.responsiblePersons ?? "-"}',
                  style: TextStyle(
                      fontSize: AppTypography.bodyMedium,
                      color: colors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                  'ทั้งหมด ${a.totalItems ?? "-"} รายการ  ·  พบจริง ${a.foundItems ?? "-"} รายการ  ·  ชำรุด/สูญหาย ${a.damagedLostItems ?? 0} รายการ',
                  style: TextStyle(
                      fontSize: AppTypography.bodyMedium,
                      fontWeight: AppTypography.weightSemiBold,
                      color: colors.onSurface)),
              if (a.summaryNotes != null && a.summaryNotes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.summaryNotes!,
                    style: TextStyle(
                        fontSize: AppTypography.bodySmall,
                        color: colors.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnualCountFormDialog extends StatefulWidget {
  final AnnualCount? existing;
  final int? suggestedTotal;
  const _AnnualCountFormDialog({this.existing, this.suggestedTotal});
  @override
  State<_AnnualCountFormDialog> createState() => _AnnualCountFormDialogState();
}

class _AnnualCountFormDialogState extends State<_AnnualCountFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fiscalYearCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _foundCtrl;
  late final TextEditingController _damagedCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _memoNumberCtrl;
  late final TextEditingController _orderNumberCtrl;
  late final TextEditingController _reportNumberCtrl;
  late final TextEditingController _transmittalDistrictNumberCtrl;
  late final TextEditingController _transmittalAuditNumberCtrl;
  String? _startDate;
  String? _memoDate;
  String? _orderDate;
  String? _reportDate;
  String? _transmittalDistrictDate;
  String? _transmittalAuditDate;
  late String _status;
  bool _saving = false;
  bool _generatingSummary = false;
  late List<AnnualCountMember> _members;
  late List<AnnualCountDamagedItem> _damagedItems;
  // ช่องชื่อ/ตำแหน่งกรรมการต้องมี controller จริงต่อแถว (ไม่ใช่แค่ initialValue)
  // เพราะ MemoryTextField ต้องการ controller ถาวรเพื่อผูกกับ RawAutocomplete —
  // คู่ขนานไปกับ _members เสมอ (เพิ่ม/ลบพร้อมกัน ดู _addMember/_removeMember)
  late List<TextEditingController> _memberNameCtrls;
  late List<TextEditingController> _memberPositionCtrls;
  // เหตุผลเดียวกับข้างบน — ต้องมี controller จริงเพื่อให้ปุ่ม "เลือกจากรายการ
  // ที่มีอยู่" เซ็ตข้อความในช่องได้ (initialValue เฉยๆ อัปเดตทีหลังไม่ได้)
  late List<TextEditingController> _damagedNameCtrls;
  List<Personnel> _personnel = [];
  List<FixedAsset> _fixedAssets = [];
  List<MaterialItem> _materials = [];

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _fiscalYearCtrl =
        TextEditingController(text: a?.fiscalYear ?? _currentFiscalYear());
    _responsibleCtrl = TextEditingController(text: a?.responsiblePersons ?? '');
    _totalCtrl = TextEditingController(
        text: a?.totalItems?.toString() ??
            widget.suggestedTotal?.toString() ??
            '');
    _foundCtrl = TextEditingController(text: a?.foundItems?.toString() ?? '');
    _damagedCtrl =
        TextEditingController(text: a?.damagedLostItems?.toString() ?? '0');
    _notesCtrl = TextEditingController(text: a?.summaryNotes ?? '');
    _memoNumberCtrl = TextEditingController(text: a?.memoNumber ?? '');
    _orderNumberCtrl = TextEditingController(text: a?.orderNumber ?? '');
    _reportNumberCtrl = TextEditingController(text: a?.reportNumber ?? '');
    _transmittalDistrictNumberCtrl =
        TextEditingController(text: a?.transmittalDistrictNumber ?? '');
    _transmittalAuditNumberCtrl =
        TextEditingController(text: a?.transmittalAuditNumber ?? '');
    _startDate = a?.startDate ?? _formatThai(DateTime.now());
    _memoDate = a?.memoDate;
    _orderDate = a?.orderDate;
    _reportDate = a?.reportDate;
    _transmittalDistrictDate = a?.transmittalDistrictDate;
    _transmittalAuditDate = a?.transmittalAuditDate;
    _status = a?.status ?? 'กำลังดำเนินการ';
    _members = List.of(a?.members ?? const []);
    _damagedItems = List.of(a?.damagedItems ?? const []);
    _memberNameCtrls = [
      for (final m in _members) TextEditingController(text: m.name)
    ];
    _memberPositionCtrls = [
      for (final m in _members) TextEditingController(text: m.position)
    ];
    _damagedNameCtrls = [
      for (final d in _damagedItems) TextEditingController(text: d.name)
    ];
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    final results = await Future.wait([
      _repo.getAllPersonnel(activeOnly: true),
      _repo.getAllFixedAssets(),
      _repo.getAllMaterials(),
    ]);
    if (!mounted) return;
    setState(() {
      _personnel = results[0] as List<Personnel>;
      _fixedAssets = results[1] as List<FixedAsset>;
      _materials = results[2] as List<MaterialItem>;
    });
  }

  @override
  void dispose() {
    _fiscalYearCtrl.dispose();
    _responsibleCtrl.dispose();
    _totalCtrl.dispose();
    _foundCtrl.dispose();
    _damagedCtrl.dispose();
    _notesCtrl.dispose();
    _memoNumberCtrl.dispose();
    _orderNumberCtrl.dispose();
    _reportNumberCtrl.dispose();
    _transmittalDistrictNumberCtrl.dispose();
    _transmittalAuditNumberCtrl.dispose();
    for (final c in _memberNameCtrls) {
      c.dispose();
    }
    for (final c in _memberPositionCtrls) {
      c.dispose();
    }
    for (final c in _damagedNameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(
      String helpText, String? current, void Function(String) onPicked) async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 1),
      helpText: helpText,
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => onPicked(_formatThai(picked)));
  }

  void _addMember() {
    setState(() {
      _members = [..._members, const AnnualCountMember(name: '')];
      _memberNameCtrls = [..._memberNameCtrls, TextEditingController()];
      _memberPositionCtrls = [..._memberPositionCtrls, TextEditingController()];
    });
  }

  void _removeMember(int i) {
    setState(() {
      _members = [..._members]..removeAt(i);
      _memberNameCtrls.removeAt(i).dispose();
      _memberPositionCtrls.removeAt(i).dispose();
    });
  }

  /// อัปเดตเฉพาะ role (name/position มาจาก controller อยู่แล้ว ไม่ต้องรับ
  /// ค่ามาทับ กันชนกับสิ่งที่ผู้ใช้พิมพ์ค้างอยู่ในช่อง)
  void _updateMemberRole(int i, String role) {
    final m = _members[i];
    setState(() => _members = [..._members]..[i] =
        AnnualCountMember(name: m.name, position: m.position, role: role));
  }

  void _onMemberNameChanged(int i, String v) {
    final m = _members[i];
    _members = [..._members]..[i] =
        AnnualCountMember(name: v, position: m.position, role: m.role);
  }

  void _onMemberPositionChanged(int i, String v) {
    final m = _members[i];
    _members = [..._members]..[i] =
        AnnualCountMember(name: m.name, position: v, role: m.role);
  }

  /// เลือกจากทำเนียบบุคลากร — เติมชื่อ+ตำแหน่งให้ทันที เหมือนช่อง "ผู้ตรวจรับ
  /// พัสดุ" ในตัวช่วยสร้างเอกสารจัดซื้อจัดจ้าง
  void _pickPersonnelForMember(int i, Personnel p) {
    setState(() {
      _memberNameCtrls[i].text = p.name;
      _memberPositionCtrls[i].text = p.position ?? '';
      _members = [..._members]..[i] = AnnualCountMember(
          name: p.name, position: p.position ?? '', role: _members[i].role);
    });
  }

  void _addDamagedItem() {
    setState(() {
      _damagedItems = [
        ..._damagedItems,
        const AnnualCountDamagedItem(name: '')
      ];
      _damagedNameCtrls = [..._damagedNameCtrls, TextEditingController()];
    });
  }

  void _removeDamagedItem(int i) {
    setState(() {
      _damagedItems = [..._damagedItems]..removeAt(i);
      _damagedNameCtrls.removeAt(i).dispose();
    });
  }

  void _updateDamagedItem(int i, AnnualCountDamagedItem updated) {
    setState(() => _damagedItems = [..._damagedItems]..[i] = updated);
  }

  /// เปิดหน้าต่างเลือกครุภัณฑ์/วัสดุที่มีอยู่แล้วในระบบ แทนการพิมพ์ชื่อ/รหัส
  /// เองใหม่ทั้งหมด — เลือกแล้วเติมชื่อ+รหัสให้ทันที (ยี่ห้อ/รายละเอียดความ
  /// เสียหายไม่มีในข้อมูลต้นทาง ต้องกรอกเองต่อ)
  Future<void> _pickExistingItemForDamaged(int i) async {
    var query = '';
    final picked =
        await showDialog<({String name, String? code, double? price})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = query.trim().toLowerCase();
          final assetMatches = _fixedAssets
              .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
              .toList();
          final materialMatches = _materials
              .where((m) => q.isEmpty || m.name.toLowerCase().contains(q))
              .toList();
          return AlertDialog(
            title:
                const Text('เลือกจากรายการที่มีอยู่', style: _dialogTitleStyle),
            content: SizedBox(
              width: 480,
              height: 440,
              child: Column(
                children: [
                  ClearableTextField(
                    autofocus: true,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(ctx,
                        label: 'ค้นหาครุภัณฑ์/วัสดุ'),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        if (assetMatches.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('ครุภัณฑ์',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                          for (final a in assetMatches)
                            ListTile(
                              dense: true,
                              title: Text(a.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: a.assetNumber != null
                                  ? Text(a.assetNumber!)
                                  : null,
                              onTap: () => Navigator.pop(ctx, (
                                name: a.name,
                                code: a.assetNumber,
                                price: a.unitPrice
                              )),
                            ),
                        ],
                        if (materialMatches.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('วัสดุ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                          for (final m in materialMatches)
                            ListTile(
                              dense: true,
                              title: Text(m.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: m.materialCode != null
                                  ? Text(m.materialCode!)
                                  : null,
                              onTap: () => Navigator.pop(ctx, (
                                name: m.name,
                                code: m.materialCode,
                                price: null
                              )),
                            ),
                        ],
                        if (assetMatches.isEmpty && materialMatches.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text('ไม่พบรายการที่ค้นหา',
                                    style: _dialogFieldStyle)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก')),
            ],
          );
        },
      ),
    );
    if (picked == null) return;
    final d = _damagedItems[i];
    _damagedNameCtrls[i].text = picked.name;
    _updateDamagedItem(
      i,
      AnnualCountDamagedItem(
        name: picked.name,
        code: picked.code ?? d.code,
        brand: d.brand,
        damageDetail: d.damageDetail,
        inUse: d.inUse,
        damageType: d.damageType,
        registeredPrice: picked.price ?? d.registeredPrice,
        assignee: d.assignee,
      ),
    );
  }

  /// ให้ AI (Gemini) ช่วยร่างสรุปผลการตรวจสอบ จากข้อมูลที่กรอกไว้แล้วในฟอร์ม
  /// (จำนวนทั้งหมด/พบจริง/ชำรุด + รายชื่อพัสดุชำรุดถ้ามี) — ผู้ใช้แก้ไขต่อได้
  /// ตามปกติ ไม่ได้ล็อกข้อความที่ AI เขียนให้
  Future<void> _generateSummary() async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      showAppToast('กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน',
          isError: true);
      return;
    }
    setState(() => _generatingSummary = true);
    try {
      final total = _totalCtrl.text.trim();
      final found = _foundCtrl.text.trim();
      final damaged = _damagedCtrl.text.trim();
      final damagedNames = _damagedItems
          .where((d) => d.name.trim().isNotEmpty)
          .map((d) => d.name)
          .join(', ');
      final prompt = '''
คุณเป็นเจ้าหน้าที่พัสดุโรงเรียนไทย จงเขียน "สรุปผลรายงานการตรวจสอบพัสดุประจำปี" สั้นๆ กระชับ ไม่เกิน 2-3 บรรทัด
เป็นภาษาราชการที่เป็นทางการ ตอบเป็นข้อความสรุปอย่างเดียว ห้ามมีคำนำ คำอธิบาย หรือเครื่องหมายคำพูดครอบ

ข้อมูลที่มี:
ปีงบประมาณ: ${_fiscalYearCtrl.text.trim()}
จำนวนรายการทั้งหมด: ${total.isEmpty ? 'ไม่ระบุ' : total}
จำนวนที่พบจริง: ${found.isEmpty ? 'ไม่ระบุ' : found}
จำนวนที่ชำรุด/สูญหาย: ${damaged.isEmpty ? '0' : damaged}
รายการที่ชำรุด/สูญหาย: ${damagedNames.isEmpty ? 'ไม่มี' : damagedNames}
''';
      final result = await GeminiService.instance.generateText(prompt);
      if (!mounted) return;
      setState(() {
        _notesCtrl.text = result.trim();
        _generatingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingSummary = false);
      showAppToast('AI เขียนสรุปไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final a = AnnualCount(
      id: widget.existing?.id,
      fiscalYear: _fiscalYearCtrl.text.trim(),
      startDate: _startDate,
      responsiblePersons: _responsibleCtrl.text.trim().isEmpty
          ? null
          : _responsibleCtrl.text.trim(),
      totalItems: int.tryParse(_totalCtrl.text.trim()),
      foundItems: int.tryParse(_foundCtrl.text.trim()),
      damagedLostItems: int.tryParse(_damagedCtrl.text.trim()) ?? 0,
      status: _status,
      summaryNotes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      memoNumber: _memoNumberCtrl.text.trim().isEmpty
          ? null
          : _memoNumberCtrl.text.trim(),
      memoDate: _memoDate,
      orderNumber: _orderNumberCtrl.text.trim().isEmpty
          ? null
          : _orderNumberCtrl.text.trim(),
      orderDate: _orderDate,
      reportNumber: _reportNumberCtrl.text.trim().isEmpty
          ? null
          : _reportNumberCtrl.text.trim(),
      reportDate: _reportDate,
      transmittalDistrictNumber:
          _transmittalDistrictNumberCtrl.text.trim().isEmpty
              ? null
              : _transmittalDistrictNumberCtrl.text.trim(),
      transmittalDistrictDate: _transmittalDistrictDate,
      transmittalAuditNumber: _transmittalAuditNumberCtrl.text.trim().isEmpty
          ? null
          : _transmittalAuditNumberCtrl.text.trim(),
      transmittalAuditDate: _transmittalAuditDate,
      members: _members.where((m) => m.name.trim().isNotEmpty).toList(),
      damagedItems:
          _damagedItems.where((d) => d.name.trim().isNotEmpty).toList(),
    );
    if (widget.existing == null) {
      await _repo.insertAnnualCount(a);
    } else {
      await _repo.updateAnnualCount(a);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _buildDocRow(
    BuildContext context, {
    required String label,
    required TextEditingController numberCtrl,
    required String? date,
    required void Function(String) onPickDate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClearableTextField(
              controller: numberCtrl,
              style: _dialogFieldStyle,
              decoration: _dialogFieldDecoration(context,
                  label: 'เลขที่$label', hint: 'เช่น 34/2569'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _pickDate('วันที่$label', date, onPickDate),
              borderRadius: BorderRadius.circular(RadiusSize.md),
              child: InputDecorator(
                decoration: _dialogFieldDecoration(context, label: 'วันที่')
                    .copyWith(
                        floatingLabelBehavior: FloatingLabelBehavior.auto),
                child: Text(date ?? 'เลือกวันที่',
                    style: _dialogFieldStyle, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(BuildContext context, int i) {
    final m = _members[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: MemoryTextField(
              fieldKey: 'annualCount.memberName',
              controller: _memberNameCtrls[i],
              presetOptions: _personnel.map((p) => p.name).toList(),
              decoration: _dialogFieldDecoration(context,
                      label: 'ชื่อ-สกุล', hint: 'เช่น นายสมชาย ใจดี')
                  .copyWith(
                suffixIcon: PopupMenuButton<Personnel>(
                  icon: Icon(Icons.people_alt_outlined,
                      size: 20, color: BrandAccent.tealOn(context)),
                  tooltip: 'เลือกจากทำเนียบบุคลากร',
                  enabled: _personnel.isNotEmpty,
                  itemBuilder: (ctx) => [
                    for (final p in _personnel)
                      PopupMenuItem(
                        value: p,
                        child: Text(
                          (p.position?.trim().isNotEmpty ?? false)
                              ? '${p.name} — ${p.position}'
                              : p.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onSelected: (p) => _pickPersonnelForMember(i, p),
                ),
              ),
              onChanged: (v) => _onMemberNameChanged(i, v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: MemoryTextField(
              fieldKey: 'annualCount.memberPosition',
              controller: _memberPositionCtrls[i],
              decoration: _dialogFieldDecoration(context,
                  label: 'ตำแหน่ง', hint: 'เช่น ครู'),
              onChanged: (v) => _onMemberPositionChanged(i, v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _memberRoles.contains(m.role) ? m.role : 'กรรมการ',
              style: _dialogFieldStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface),
              decoration: _dialogFieldDecoration(context, label: 'บทบาท')
                  .copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
              isExpanded: true,
              items: _memberRoles
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => _updateMemberRole(i, v ?? 'กรรมการ'),
            ),
          ),
          IconButton(
            tooltip: 'ลบกรรมการคนนี้',
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _removeMember(i),
          ),
        ],
      ),
    );
  }

  Widget _buildDamagedItemRow(BuildContext context, int i) {
    final d = _damagedItems[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(RadiusSize.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClearableTextField(
                  controller: _damagedNameCtrls[i],
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(context,
                      label: 'ชื่อพัสดุ/ครุภัณฑ์',
                      hint: 'เช่น เครื่องพิมพ์ดีด'),
                  onChanged: (v) => _updateDamagedItem(
                      i,
                      AnnualCountDamagedItem(
                          name: v,
                          code: d.code,
                          brand: d.brand,
                          damageDetail: d.damageDetail,
                          inUse: d.inUse,
                          damageType: d.damageType,
                          registeredPrice: d.registeredPrice,
                          assignee: d.assignee)),
                ),
              ),
              IconButton(
                tooltip: 'เลือกจากรายการที่มีอยู่',
                icon: Icon(Icons.checklist_outlined,
                    size: 20, color: BrandAccent.tealOn(context)),
                onPressed: () => _pickExistingItemForDamaged(i),
              ),
              IconButton(
                tooltip: 'ลบรายการนี้',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeDamagedItem(i),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClearableTextField(
                  initialValue: d.code,
                  style: _dialogFieldStyle,
                  decoration:
                      _dialogFieldDecoration(context, label: 'รหัสครุภัณฑ์'),
                  onChanged: (v) => _updateDamagedItem(
                      i,
                      AnnualCountDamagedItem(
                          name: d.name,
                          code: v,
                          brand: d.brand,
                          damageDetail: d.damageDetail,
                          inUse: d.inUse,
                          damageType: d.damageType,
                          registeredPrice: d.registeredPrice,
                          assignee: d.assignee)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClearableTextField(
                  initialValue: d.brand,
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(context, label: 'ยี่ห้อ'),
                  onChanged: (v) => _updateDamagedItem(
                      i,
                      AnnualCountDamagedItem(
                          name: d.name,
                          code: d.code,
                          brand: v,
                          damageDetail: d.damageDetail,
                          inUse: d.inUse,
                          damageType: d.damageType,
                          registeredPrice: d.registeredPrice,
                          assignee: d.assignee)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClearableTextField(
            initialValue: d.damageDetail,
            style: _dialogFieldStyle,
            decoration: _dialogFieldDecoration(context,
                label: 'รายละเอียดความเสียหาย', hint: 'เช่น ชำรุดใช้งานไม่ได้'),
            onChanged: (v) => _updateDamagedItem(
              i,
              AnnualCountDamagedItem(
                name: d.name,
                code: d.code,
                brand: d.brand,
                damageDetail: v,
                inUse: d.inUse,
                damageType: d.damageType,
                registeredPrice: d.registeredPrice,
                assignee: d.assignee,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: annualCountDamageTypes.contains(d.damageType)
                      ? d.damageType
                      : null,
                  style: _dialogFieldStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface),
                  decoration: _dialogFieldDecoration(context, label: 'ลักษณะ')
                      .copyWith(
                          floatingLabelBehavior: FloatingLabelBehavior.auto),
                  isExpanded: true,
                  items: annualCountDamageTypes
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => _updateDamagedItem(
                    i,
                    AnnualCountDamagedItem(
                      name: d.name,
                      code: d.code,
                      brand: d.brand,
                      damageDetail: d.damageDetail,
                      inUse: d.inUse,
                      damageType: v,
                      registeredPrice: d.registeredPrice,
                      assignee: d.assignee,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClearableTextField(
                  initialValue: d.registeredPrice?.toStringAsFixed(2),
                  style: _dialogFieldStyle,
                  keyboardType: TextInputType.number,
                  decoration:
                      _dialogFieldDecoration(context, label: 'ราคาตามทะเบียน'),
                  onChanged: (v) => _updateDamagedItem(
                    i,
                    AnnualCountDamagedItem(
                      name: d.name,
                      code: d.code,
                      brand: d.brand,
                      damageDetail: d.damageDetail,
                      inUse: d.inUse,
                      damageType: d.damageType,
                      registeredPrice: double.tryParse(v.trim()),
                      assignee: d.assignee,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClearableTextField(
                  initialValue: d.assignee,
                  style: _dialogFieldStyle,
                  decoration:
                      _dialogFieldDecoration(context, label: 'ผู้ใช้งาน'),
                  onChanged: (v) => _updateDamagedItem(
                    i,
                    AnnualCountDamagedItem(
                      name: d.name,
                      code: d.code,
                      brand: d.brand,
                      damageDetail: d.damageDetail,
                      inUse: d.inUse,
                      damageType: d.damageType,
                      registeredPrice: d.registeredPrice,
                      assignee: v,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            value: d.inUse,
            onChanged: (v) => _updateDamagedItem(
              i,
              AnnualCountDamagedItem(
                name: d.name,
                code: d.code,
                brand: d.brand,
                damageDetail: d.damageDetail,
                inUse: v ?? false,
                damageType: d.damageType,
                registeredPrice: d.registeredPrice,
                assignee: d.assignee,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title:
                const Text('ยังใช้งานได้อยู่', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    // กัน Esc/ปัดปิดจากคีย์บอร์ดระหว่าง AI กำลังเขียนสรุปผลอยู่ — เหตุผลเดียวกับ
    // ปุ่ม "ยกเลิก" ด้านล่าง (ฟอร์มนี้ไม่มีการบันทึกดราฟต์อัตโนมัติ)
    return PopScope(
      canPop: !_generatingSummary,
      child: AlertDialog(
        title: Text(isEdit ? 'แก้ไขบันทึกการตรวจนับ' : 'เริ่มการตรวจนับพัสดุ',
            style: _dialogTitleStyle),
        content: SizedBox(
          width: 760,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClearableTextField(
                      controller: _fiscalYearCtrl,
                      style: _dialogFieldStyle,
                      decoration: _dialogFieldDecoration(context,
                          label: 'ปีงบประมาณ *', hint: 'เช่น 2569'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกปีงบประมาณ'
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: InkWell(
                      onTap: () => _pickDate(
                          'วันที่เริ่มตรวจ', _startDate, (v) => _startDate = v),
                      borderRadius: BorderRadius.circular(RadiusSize.md),
                      child: InputDecorator(
                        decoration: _dialogFieldDecoration(context,
                                label: 'วันที่เริ่มตรวจ')
                            .copyWith(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto),
                        child: Text(_startDate ?? 'เลือกวันที่',
                            style: _dialogFieldStyle),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClearableTextField(
                      controller: _responsibleCtrl,
                      style: _dialogFieldStyle,
                      decoration: _dialogFieldDecoration(context,
                          label: 'ผู้รับผิดชอบ (ชื่อกรรมการ)',
                          hint: 'คั่นด้วยจุลภาคถ้ามีหลายคน'),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: ClearableTextField(
                            controller: _totalCtrl,
                            style: _dialogFieldStyle,
                            keyboardType: TextInputType.number,
                            decoration: _dialogFieldDecoration(context,
                                label: 'จำนวนรายการทั้งหมด', hint: 'เช่น 50'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: ClearableTextField(
                            controller: _foundCtrl,
                            style: _dialogFieldStyle,
                            keyboardType: TextInputType.number,
                            decoration: _dialogFieldDecoration(context,
                                label: 'จำนวนที่พบจริง', hint: 'เช่น 48'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClearableTextField(
                      controller: _damagedCtrl,
                      style: _dialogFieldStyle,
                      keyboardType: TextInputType.number,
                      decoration: _dialogFieldDecoration(context,
                          label: 'จำนวนที่ชำรุด/สูญหาย', hint: 'เช่น 2'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      style:
                          _dialogFieldStyle.copyWith(color: colors.onSurface),
                      decoration:
                          _dialogFieldDecoration(context, label: 'สถานะ')
                              .copyWith(
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto),
                      items: const [
                        DropdownMenuItem(
                            value: 'กำลังดำเนินการ',
                            child: Text('กำลังดำเนินการ')),
                        DropdownMenuItem(
                            value: 'เสร็จสิ้น', child: Text('เสร็จสิ้น')),
                      ],
                      onChanged: (v) =>
                          setState(() => _status = v ?? 'กำลังดำเนินการ'),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('สรุปผลรายงานการตรวจสอบ',
                          style: TextStyle(
                              fontSize: AppTypography.bodyMedium,
                              fontWeight: AppTypography.weightSemiBold,
                              color: colors.onSurfaceVariant)),
                      TextButton.icon(
                        onPressed: _generatingSummary ? null : _generateSummary,
                        icon: _generatingSummary
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_generatingSummary
                            ? 'กำลังเขียน...'
                            : '✨ ให้ AI ช่วยเขียน'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ClearableTextField(
                      controller: _notesCtrl,
                      style: _dialogFieldStyle,
                      maxLines: 3,
                      decoration: _dialogFieldDecoration(context,
                          label: 'สรุปผลรายงานการตรวจสอบ',
                          hint: 'เช่น ตรวจนับครุภัณฑ์ครบถ้วน พบชำรุด 2 รายการ'),
                    ),
                  ),
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'เลขที่เอกสาร (สำหรับพิมพ์เอกสารชุดตรวจสอบพัสดุประจำปี)',
                        style: TextStyle(
                            fontSize: AppTypography.bodyMedium,
                            fontWeight: AppTypography.weightSemiBold,
                            color: colors.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 12),
                  _buildDocRow(context,
                      label: 'บันทึกขออนุมัติแต่งตั้งกรรมการ',
                      numberCtrl: _memoNumberCtrl,
                      date: _memoDate,
                      onPickDate: (v) => _memoDate = v),
                  _buildDocRow(context,
                      label: 'คำสั่งแต่งตั้งกรรมการ',
                      numberCtrl: _orderNumberCtrl,
                      date: _orderDate,
                      onPickDate: (v) => _orderDate = v),
                  _buildDocRow(context,
                      label: 'บันทึกรายงานผลการตรวจสอบ',
                      numberCtrl: _reportNumberCtrl,
                      date: _reportDate,
                      onPickDate: (v) => _reportDate = v),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            'คณะกรรมการตรวจสอบพัสดุ (${_members.length} คน)',
                            style: TextStyle(
                                fontSize: AppTypography.bodyMedium,
                                fontWeight: AppTypography.weightSemiBold,
                                color: colors.onSurfaceVariant)),
                      ),
                      TextButton.icon(
                          onPressed: _addMember,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('เพิ่มกรรมการ')),
                    ],
                  ),
                  for (var i = 0; i < _members.length; i++)
                    _buildMemberRow(context, i),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            'รายการพัสดุชำรุด/เสื่อมสภาพ/สูญหาย (${_damagedItems.length} รายการ)',
                            style: TextStyle(
                                fontSize: AppTypography.bodyMedium,
                                fontWeight: AppTypography.weightSemiBold,
                                color: colors.onSurfaceVariant)),
                      ),
                      TextButton.icon(
                          onPressed: _addDamagedItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('เพิ่มรายการ')),
                    ],
                  ),
                  for (var i = 0; i < _damagedItems.length; i++)
                    _buildDamagedItemRow(context, i),
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'หนังสือนำส่งสำเนารายงาน (เขตพื้นที่การศึกษา / สตง.)',
                        style: TextStyle(
                            fontSize: AppTypography.bodyMedium,
                            fontWeight: AppTypography.weightSemiBold,
                            color: colors.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 12),
                  _buildDocRow(context,
                      label: 'หนังสือนำส่งเขตพื้นที่การศึกษา',
                      numberCtrl: _transmittalDistrictNumberCtrl,
                      date: _transmittalDistrictDate,
                      onPickDate: (v) => _transmittalDistrictDate = v),
                  _buildDocRow(context,
                      label: 'หนังสือนำส่ง สตง.',
                      numberCtrl: _transmittalAuditNumberCtrl,
                      date: _transmittalAuditDate,
                      onPickDate: (v) => _transmittalAuditDate = v),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            // ห้ามปิดฟอร์มระหว่าง AI กำลังเขียนสรุปผลอยู่ — ฟอร์มนี้เป็นป๊อปอัพ
            // ไม่มีการบันทึกดราฟต์อัตโนมัติ ถ้าปิดกลางคันข้อมูลทั้งฟอร์ม (ไม่ใช่แค่
            // ผลลัพธ์ AI) จะหายหมด
            onPressed: (_saving || _generatingSummary)
                ? null
                : () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.onPrimary))
                : Text(isEdit ? 'บันทึก' : 'เริ่มตรวจนับ'),
          ),
        ],
      ),
    );
  }
}
