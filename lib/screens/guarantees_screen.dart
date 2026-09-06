// guarantees_screen.dart
// ทะเบียนหลักประกัน (blueprint หน้าที่ 6) — กรองตามประเภทด้วยชิป (แทนแท็บ
// ให้สอดคล้องกับรูปแบบตัวกรองที่ใช้อยู่แล้วในหน้าอื่นของแอป)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/guarantee.dart';
import '../models/contract.dart';
import '../services/fiscal_year_controller.dart';
import '../services/guarantee_export_service.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
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

const _guaranteeTypes = ['หลักประกันซอง', 'หลักประกันสัญญา', 'เงินสด', 'หนังสือค้ำประกันธนาคาร'];

// ตามระเบียบกระทรวงการคลังว่าด้วยการจัดซื้อจัดจ้างฯ พ.ศ. 2560 ข้อ 168 + มาตรา 97 —
// สัญญาวงเงิน ≥ 100,000 บาท ต้องวางหลักประกันสัญญา (เกณฑ์ทั่วไป 5% ของวงเงิน)
// เป็นคำแนะนำเบื้องต้นเท่านั้น ไม่ใช่การรับรองความถูกต้องทางกฎหมาย
const _guaranteeRequiredThreshold = 100000.0;
const _guaranteeRate = 0.05;
const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String _formatThai(DateTime d) => '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';

class GuaranteesScreen extends StatefulWidget {
  const GuaranteesScreen({super.key});
  @override
  State<GuaranteesScreen> createState() => _GuaranteesScreenState();
}

class _GuaranteesScreenState extends State<GuaranteesScreen> {
  final _repo = ProcurementRepository();
  List<Guarantee> _guarantees = [];
  List<Contract> _contracts = [];
  bool _loading = true;
  bool _exporting = false;
  String? _selectedType; // null = ทั้งหมด

  @override
  void initState() {
    super.initState();
    _load();
    FiscalYearController.instance.addListener(_onFiscalYearChanged);
  }

  @override
  void dispose() {
    FiscalYearController.instance.removeListener(_onFiscalYearChanged);
    super.dispose();
  }

  void _onFiscalYearChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final viewingYear = FiscalYearController.instance.viewingYear;
    final list = await _repo.getAllGuarantees(fiscalYear: viewingYear);
    // กรองสัญญาตามปีงบเดียวกันด้วย — ใช้คำนวณ "สัญญาที่ยังไม่มีหลักประกัน"
    // (แบนเนอร์แจ้งเตือนด้านบน) ให้สอดคล้องกับปีที่กำลังดูอยู่ ไม่ใช่ปนทุกปี
    final contracts = await _repo.getAllContracts(fiscalYear: viewingYear);
    if (!mounted) return;
    setState(() {
      _guarantees = list;
      _contracts = contracts;
      _loading = false;
    });
  }

  /// สัญญาที่วงเงินถึงเกณฑ์ต้องวางหลักประกัน แต่ยังไม่มีหลักประกันอ้างอิงมาที่
  /// สัญญานั้น (ผ่าน contract_id) — แจ้งเตือนให้ผู้ใช้ไปบันทึกให้ครบ
  List<Contract> get _contractsMissingGuarantee {
    final coveredContractIds = _guarantees.map((g) => g.contractId).whereType<int>().toSet();
    return _contracts
        .where((c) =>
            c.id != null &&
            !coveredContractIds.contains(c.id) &&
            (c.contractAmount ?? 0) >= _guaranteeRequiredThreshold)
        .toList();
  }

  List<Guarantee> get _filtered =>
      _selectedType == null ? _guarantees : _guarantees.where((g) => g.guaranteeType == _selectedType).toList();

  double get _totalHeld => _guarantees.where((g) => g.status == 'ถืออยู่').fold(0, (s, g) => s + (g.amount ?? 0));

  Future<void> _openForm({Guarantee? existing, Contract? prefillContract}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuaranteeFormDialog(existing: existing, prefillContract: prefillContract),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Guarantee g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบหลักประกันของ "${g.counterpartyName ?? "-"}" ใช่หรือไม่?', style: _dialogContentStyle),
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
    if (confirmed == true && g.id != null) {
      await _repo.deleteGuarantee(g.id!);
      _load();
    }
  }

  Future<void> _returnGuarantee(Guarantee g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('คืนหลักประกัน', style: _dialogTitleStyle),
        content: Text('ยืนยันคืนหลักประกันของ "${g.counterpartyName ?? "-"}" '
            '(${g.amount != null ? formatBaht(g.amount) : "-"} บาท) ใช่หรือไม่?', style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันคืน'),
          ),
        ],
      ),
    );
    if (confirmed != true || g.id == null) return;
    await _repo.updateGuarantee(g.copyWith(status: 'คืนแล้ว', returnedDate: _formatThai(DateTime.now())));
    _load();
  }

  /// ส่งออกเฉพาะรายการที่กรอง/ค้นหาอยู่ตอนนี้เป็นไฟล์ Excel (ตรงกับที่เห็นบนจอ
  /// จริงๆ ไม่ใช่ทั้งหมดในระบบเสมอ) แล้วเปิดไฟล์ให้อัตโนมัติ
  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await GuaranteeExportService.exportAndOpen(_filtered);
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
      title: 'วิธีใช้หน้าหลักประกันสัญญา',
      icon: Icons.shield_outlined,
      steps: const [
        'ตามระเบียบพัสดุ ปกติสัญญาที่มีวงเงินตั้งแต่ 100,000 บาทขึ้นไป ต้องมีหลักประกันสัญญา (คำแนะนำเบื้องต้น — ให้ตรวจสอบเงื่อนไขในสัญญาจริงอีกครั้งเสมอ)',
        'อัตราที่ระบบแนะนำอัตโนมัติคือ 5% ของวงเงินสัญญา ก็เป็นเกณฑ์ทั่วไปเท่านั้น สัญญาบางประเภทอาจกำหนดอัตราอื่น',
        'ถ้ามีสัญญาที่วงเงินถึงเกณฑ์แต่ยังไม่มีหลักประกัน ระบบจะขึ้นแบนเนอร์แจ้งเตือนไว้ด้านบน กด "ไปบันทึก" เพื่อกรอกได้ทันที',
        'กด "เพิ่มหลักประกัน" มุมขวาล่างเพื่อบันทึกเองได้ทุกเมื่อ ไม่จำเป็นต้องรอแบนเนอร์แจ้งเตือน',
        'กดปุ่ม "ส่งออก Excel" มุมบนขวาเพื่อบันทึกทะเบียนหลักประกันที่เห็นอยู่ตอนนี้ (ตามตัวกรองที่เลือกไว้) เป็นไฟล์ .xlsx',
      ],
      // มุมขวาบนชนกับปุ่ม "ส่งออก Excel" ในหัวหน้า และมุมขวาล่างมี FAB
      // "เพิ่มหลักประกัน" อยู่แล้ว — เหลือแค่มุมซ้ายล่างที่ว่าง
      corner: Alignment.bottomLeft,
      child: Stack(
        children: [
          Center(
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
                              Icon(Icons.shield_outlined, color: BrandAccent.tealOn(context), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('หลักประกันสัญญา',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _guarantees.isEmpty || _exporting ? null : _exportToExcel,
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
                          const SizedBox(height: 16),
                          _buildSummaryBar(context, colors),
                          if (_contractsMissingGuarantee.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildMissingGuaranteeBanner(context, colors),
                          ],
                          const SizedBox(height: 16),
                          _buildFilterChips(colors),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _filtered.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, size: 64, color: colors.onSurfaceVariant),
                                        const SizedBox(height: 12),
                                        Text(
                                          _guarantees.isEmpty ? 'ยังไม่มีหลักประกัน\nกด "เพิ่มหลักประกัน" เพื่อเริ่มต้น' : 'ไม่พบรายการในประเภทนี้',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _filtered.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _buildCard(context, colors, _filtered[i]),
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
              heroTag: 'guarantees_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มหลักประกัน'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(BuildContext context, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BrandAccent.teal(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: BrandAccent.teal(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: BrandAccent.tealOn(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ยอดหลักประกันที่ถืออยู่ในปัจจุบัน', style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                Text('${formatBaht(_totalHeld)} บาท',
                  style: TextStyle(fontSize: AppTypography.heading3, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingGuaranteeBanner(BuildContext context, ColorScheme colors) {
    final contracts = _contractsMissingGuarantee;
    final amberBg = Color.alphaBlend(BrandColors.amber.withValues(alpha: 0.12), colors.surface);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amberBg,
        borderRadius: BorderRadius.circular(RadiusSize.md),
        border: Border.all(color: BrandColors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: BrandAccent.tertiary(context), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'พบ ${contracts.length} สัญญาที่วงเงินถึงเกณฑ์ต้องวางหลักประกัน แต่ยังไม่ได้บันทึก',
                  style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body, color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ตามระเบียบฯ สัญญาวงเงิน ≥ ${_guaranteeRequiredThreshold.toStringAsFixed(0)} บาท ทั่วไปต้องวางหลักประกัน '
            '(ประมาณ ${(_guaranteeRate * 100).toStringAsFixed(0)}% ของวงเงิน) — เป็นคำแนะนำเบื้องต้นเท่านั้น '
            'โปรดตรวจสอบเงื่อนไขในสัญญาจริงอีกครั้ง',
            style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final c in contracts.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${c.contractNumber ?? "(ไม่มีเลขที่)"} — ${c.vendorName ?? "-"} '
                      '(${formatBaht(c.contractAmount ?? 0)} บาท)',
                      style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _openForm(prefillContract: c),
                    style: FilledButton.styleFrom(textStyle: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightBold)),
                    child: const Text('ไปบันทึก'),
                  ),
                ],
              ),
            ),
          if (contracts.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('และอีก ${contracts.length - 5} รายการ', style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colors) {
    Widget chip(String label, String? value) {
      final selected = _selectedType == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DSFilterChip(
          label: label,
          isSelected: selected,
          onTap: () => setState(() => _selectedType = value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('ทั้งหมด', null),
          for (final t in _guaranteeTypes) chip(t, t),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, Guarantee g) {
    final isHeld = g.status == 'ถืออยู่';
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(existing: g),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (g.guaranteeType != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandAccent.teal(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(RadiusSize.sm),
                          ),
                          child: Text(g.guaranteeType!,
                            style: TextStyle(fontSize: AppTypography.caption, color: BrandAccent.tealOn(context), fontWeight: AppTypography.weightSemiBold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      StatusBadge(
                        label: g.status,
                        variant: isHeld ? BadgeVariant.warning : BadgeVariant.success,
                        compact: true,
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(g.counterpartyName ?? '(ไม่ระบุคู่สัญญา)',
                      style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.heading4, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (g.startDate != null || g.expiryDate != null) ...[
                      const SizedBox(height: 2),
                      Text('${g.startDate ?? "-"} ถึง ${g.expiryDate ?? "-"}', style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                    ],
                    if (g.returnedDate != null) ...[
                      const SizedBox(height: 2),
                      Text('คืนเมื่อ ${g.returnedDate}', style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (g.amount != null)
                    Text('${formatBaht(g.amount)} บาท',
                      style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodyMedium, color: BrandAccent.tealOn(context))),
                  if (isHeld)
                    TextButton(
                      onPressed: () => _returnGuarantee(g),
                      style: TextButton.styleFrom(textStyle: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightBold)),
                      child: const Text('คืนหลักประกัน'),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              DsActionIconButtons(
                actions: [
                  DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(g), danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuaranteeFormDialog extends StatefulWidget {
  final Guarantee? existing;
  // ส่งมาจากปุ่ม "ไปบันทึก" ในแบนเนอร์แจ้งเตือนสัญญาที่ยังไม่มีหลักประกัน —
  // ใช้ prefill ชื่อคู่สัญญา/วงเงิน/ผูกกับสัญญานั้นให้อัตโนมัติ (แก้ไขต่อได้)
  final Contract? prefillContract;
  const _GuaranteeFormDialog({this.existing, this.prefillContract});
  @override
  State<_GuaranteeFormDialog> createState() => _GuaranteeFormDialogState();
}

class _GuaranteeFormDialogState extends State<_GuaranteeFormDialog> {
  final _repo = ProcurementRepository();
  late final TextEditingController _counterpartyCtrl;
  late final TextEditingController _amountCtrl;
  String? _guaranteeType;
  String? _startDate;
  String? _expiryDate;
  int? _contractId;
  List<Contract> _contracts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    final prefill = widget.prefillContract;
    _counterpartyCtrl = TextEditingController(text: g?.counterpartyName ?? prefill?.vendorName ?? '');
    _amountCtrl = TextEditingController(
      text: g?.amount?.toStringAsFixed(2) ??
          (prefill != null ? ((prefill.contractAmount ?? 0) * _guaranteeRate).toStringAsFixed(2) : ''),
    );
    _guaranteeType = g?.guaranteeType ?? (prefill != null ? 'หลักประกันสัญญา' : null);
    _startDate = g?.startDate;
    _expiryDate = g?.expiryDate;
    _contractId = g?.contractId ?? prefill?.id;
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    final list = await _repo.getAllContracts();
    if (!mounted) return;
    setState(() => _contracts = list);
  }

  @override
  void dispose() {
    _counterpartyCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
      helpText: isStart ? 'วันที่เริ่มค้ำประกัน' : 'วันที่หมดอายุการค้ำประกัน',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = _formatThai(picked);
      } else {
        _expiryDate = _formatThai(picked);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final g = Guarantee(
      id: widget.existing?.id,
      guaranteeType: _guaranteeType,
      counterpartyName: _counterpartyCtrl.text.trim().isEmpty ? null : _counterpartyCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text.trim()),
      startDate: _startDate,
      expiryDate: _expiryDate,
      contractId: _contractId,
      status: widget.existing?.status ?? 'ถืออยู่',
      returnedDate: widget.existing?.returnedDate,
    );
    if (widget.existing == null) {
      await _repo.insertGuarantee(g);
    } else {
      await _repo.updateGuarantee(g);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขหลักประกัน' : 'เพิ่มหลักประกัน', style: _dialogTitleStyle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: DropdownButtonFormField<String?>(
                  initialValue: _guaranteeType,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _dialogFieldDecoration(context, label: 'ประเภทหลักประกัน').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                    ..._guaranteeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                  ],
                  onChanged: (v) => setState(() => _guaranteeType = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: DropdownButtonFormField<int?>(
                  initialValue: _contractId,
                  isExpanded: true,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _dialogFieldDecoration(context, label: 'ผูกกับสัญญา').copyWith(
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    suffixIcon: _contractId != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'ล้างค่าที่เลือก',
                            onPressed: () => setState(() => _contractId = null),
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('(ไม่ผูกกับสัญญา)')),
                    ..._contracts.where((c) => c.id != null).map((c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(
                            '${c.contractNumber ?? "เอกสาร #${c.id}"} — ${c.vendorName ?? "-"}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _contractId = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TextFormField(
                  controller: _counterpartyCtrl,
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(context, label: 'ผู้เสนอราคา/คู่สัญญา', hint: 'เช่น บริษัท เอบีซี จำกัด'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TextFormField(
                  controller: _amountCtrl,
                  style: _dialogFieldStyle,
                  keyboardType: TextInputType.number,
                  decoration: _dialogFieldDecoration(context, label: 'วงเงินค้ำประกัน (บาท)', hint: 'เช่น 50000.00'),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      borderRadius: BorderRadius.circular(RadiusSize.md),
                      child: InputDecorator(
                        decoration: _dialogFieldDecoration(context, label: 'วันที่เริ่มค้ำประกัน').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                        child: Text(_startDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      borderRadius: BorderRadius.circular(RadiusSize.md),
                      child: InputDecorator(
                        decoration: _dialogFieldDecoration(context, label: 'วันหมดอายุ').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                        child: Text(_expiryDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
}
