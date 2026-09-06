// contracts_screen.dart
// บริหารสัญญา/ใบสั่งซื้อ/สั่งจ้าง (blueprint หน้าที่ 5) — ผูกกับรายการจัดซื้อ
// จัดจ้าง (procurement_orders) ได้แบบไม่บังคับ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/contract.dart';
import '../models/procurement_order.dart';
import '../services/fiscal_year_controller.dart';
import '../services/procurement_document_generator.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../services/toast_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant;
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

InputDecoration _dialogFieldDecoration(BuildContext context, {required String label, String? hint, String? helper}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
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

const _contractTypes = ['สัญญาซื้อขาย', 'สัญญาจ้าง', 'ใบสั่งซื้อ', 'ใบสั่งจ้าง'];
const _contractStatuses = ['กำลังดำเนินการ', 'ครบกำหนดแล้ว', 'ยกเลิก'];
const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String _formatThai(DateTime d) => '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});
  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final _repo = ProcurementRepository();
  List<Contract> _contracts = [];
  Map<int, ProcurementOrder> _ordersById = {};
  bool _loading = true;
  int? _exportingId;

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
    final contracts = await _repo.getAllContracts(fiscalYear: FiscalYearController.instance.viewingYear);
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    setState(() {
      _contracts = contracts;
      _ordersById = {for (final o in orders) if (o.id != null) o.id!: o};
      _loading = false;
    });
  }

  Future<void> _openForm({Contract? existing}) async {
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ContractFormDialog(existing: existing, orders: orders),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Contract c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบสัญญา "${c.contractNumber ?? "(ไม่มีเลขที่)"}" ใช่หรือไม่?', style: _dialogContentStyle),
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
    if (confirmed == true && c.id != null) {
      await _repo.deleteContract(c.id!);
      _load();
    }
  }

  /// คัดลอกสัญญาเป็นรายการใหม่ — คัดลอกทุกช่องมาตรงๆ ไม่ล้างอะไรเลย เติมแค่
  /// "(สำเนา)" ต่อเลขที่สัญญา ให้ไปแก้เองว่าช่องไหนต้องเปลี่ยน — **ไม่ผูกกับ
  /// รายการจัดซื้อจัดจ้างเดิม** (order_id เป็นค่าว่าง) กันสัญญาสำเนาไปทับ/แย่ง
  /// การ auto-sync ข้อมูลจากรายการเดิม (สัญญาแต่ละใบผูกกับ order ได้แค่ 1 ใบ)
  Future<void> _duplicateContract(Contract c) async {
    try {
      final map = c.toMap();
      map.remove('id');
      map['order_id'] = null;
      map['contract_number'] =
          '${(c.contractNumber?.trim().isNotEmpty ?? false) ? c.contractNumber! : "(ไม่มีเลขที่)"} (สำเนา)';
      await _repo.insertContract(Contract.fromMap(map));
      if (!mounted) return;
      showAppToast('คัดลอกสัญญาแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกสัญญาไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _exportWord(Contract c, ProcurementDocumentType type) async {
    final order = c.orderId != null ? _ordersById[c.orderId] : null;
    if (order == null) {
      showAppToast('สัญญานี้ไม่ได้ผูกกับรายการจัดซื้อจัดจ้าง จึงออกเอกสารไม่ได้', isError: true);
      return;
    }
    final school = await _repo.getSchoolSettings();
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    setState(() => _exportingId = c.id);
    try {
      final items = await _repo.getItems(order.id!);
      await ProcurementDocumentGenerator.generateAndOpen(
        type: type,
        order: order,
        school: school,
        items: items,
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  double get _totalContractValue => _contracts.fold(0, (s, c) => s + (c.contractAmount ?? 0));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าบริหารสัญญา',
      icon: Icons.article_outlined,
      steps: const [
        'บันทึกสัญญา/ใบสั่งซื้อ-สั่งจ้างแต่ละฉบับ ผูกกับรายการจัดซื้อจัดจ้างที่มีอยู่แล้วได้ (ไม่บังคับ) เพื่อดึงข้อมูลมาเติมในเอกสารอัตโนมัติ',
        'เลือกประเภทสัญญาให้ตรงกับลักษณะงาน (สัญญาซื้อขาย/สัญญาจ้าง/ใบสั่งซื้อ/ใบสั่งจ้าง) และอัปเดตสถานะเมื่อครบกำหนดหรือยกเลิก',
        'กดไอคอนที่การ์ดแต่ละสัญญาเพื่อสร้างเอกสาร Word (รายงานขอซื้อ, ประกาศผู้ชนะ, ใบเสนอราคา ฯลฯ) ได้ทันทีโดยไม่ต้องไปหน้าอื่น',
        'กด "เพิ่มสัญญา" มุมขวาล่างเพื่อบันทึกรายการใหม่',
      ],
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
                              Icon(Icons.article_outlined, color: BrandAccent.tealOn(context), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('บริหารสัญญา',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryBar(context, colors),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _contracts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.article_outlined, size: 64, color: colors.onSurfaceVariant),
                                        const SizedBox(height: 12),
                                        Text('ยังไม่มีสัญญา/ใบสั่งซื้อ-สั่งจ้าง\nกด "เพิ่มสัญญา" เพื่อเริ่มต้น',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _contracts.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _buildCard(context, colors, _contracts[i]),
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
              heroTag: 'contracts_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มสัญญา'),
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
          Icon(Icons.summarize_outlined, color: BrandAccent.tealOn(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('มูลค่าสัญญารวมทั้งหมด', style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                Text('${formatBaht(_totalContractValue)} บาท (${_contracts.length} สัญญา)',
                  style: TextStyle(fontSize: AppTypography.heading3, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, Contract c) {
    final statusVariant = switch (c.status) {
      'ครบกำหนดแล้ว' => BadgeVariant.success,
      'ยกเลิก' => BadgeVariant.danger,
      _ => BadgeVariant.warning,
    };
    final linkedOrder = c.orderId != null ? _ordersById[c.orderId] : null;
    final isExportingThis = _exportingId == c.id;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(existing: c),
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
                      if (c.contractType != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandAccent.teal(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(RadiusSize.sm),
                          ),
                          child: Text(c.contractType!,
                            style: TextStyle(fontSize: AppTypography.caption, color: BrandAccent.tealOn(context), fontWeight: AppTypography.weightSemiBold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      StatusBadge(label: c.status, variant: statusVariant, compact: true),
                    ]),
                    const SizedBox(height: 6),
                    Text(c.contractNumber ?? '(ไม่มีเลขที่สัญญา)',
                      style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.heading4, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (c.vendorName != null) ...[
                      const SizedBox(height: 2),
                      Text('คู่สัญญา: ${c.vendorName}', style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (linkedOrder != null) ...[
                      const SizedBox(height: 2),
                      Text('รายการ: ${linkedOrder.projectName ?? linkedOrder.procurementSubject ?? "-"}',
                        style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (c.startDate != null || c.endDate != null) ...[
                      const SizedBox(height: 2),
                      Text('${c.startDate ?? "-"} ถึง ${c.endDate ?? "-"}',
                        style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (c.contractAmount != null)
                Text('${formatBaht(c.contractAmount)} บาท',
                  style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodyMedium, color: BrandAccent.tealOn(context))),
              if (linkedOrder != null) ...[
                const SizedBox(width: 4),
                isExportingThis
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : Row(
                        children: [
                          // ปุ่มลัด "ดูตัวอย่าง" — ออกเอกสารหลักของสัญญา (รายงาน
                          // ขอซื้อ/ขอจ้าง) ให้ทันทีในคลิกเดียว ไม่ต้องเลือกจากเมนู
                          DsActionIconButtons(
                            actions: [
                              DsRowAction(
                                icon: Icons.visibility_outlined,
                                tooltip: 'ดูตัวอย่างเอกสาร',
                                onTap: () => _exportWord(c, ProcurementDocumentType.contractOrderReport),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: _DocMenuButton(
                              enabled: _exportingId == null,
                              onSelected: (type) => _exportWord(c, type),
                            ),
                          ),
                        ],
                      ),
              ],
              const SizedBox(width: 4),
              DsActionIconButtons(
                actions: [
                  DsRowAction(icon: Icons.copy_all_outlined, tooltip: 'คัดลอกสัญญา', onTap: () => _duplicateContract(c)),
                  DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(c), danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ปุ่ม "สร้างเอกสาร (เลือกประเภท)" — ครอบ PopupMenuButton ด้วยกล่อง 28x28 ที่
/// เปลี่ยนสีพื้น/ขอบตอน hover เหมือนกับ DsActionIconButtons เป๊ะๆ (ใช้ child: แทน
/// icon: ของ PopupMenuButton เพื่อคุมการวาดเองทั้งหมด กันไม่ให้ ripple วงกลม
/// เริ่มต้นของ PopupMenuButton ไปทับกรอบกล่อง ทำให้ดูไม่เข้าชุดกับปุ่มข้างๆ)
class _DocMenuButton extends StatefulWidget {
  const _DocMenuButton({required this.enabled, required this.onSelected});
  final bool enabled;
  final ValueChanged<ProcurementDocumentType> onSelected;

  @override
  State<_DocMenuButton> createState() => _DocMenuButtonState();
}

class _DocMenuButtonState extends State<_DocMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hoverColor = BrandAccent.navy(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: 'สร้างเอกสาร (เลือกประเภท)',
        child: PopupMenuButton<ProcurementDocumentType>(
          padding: EdgeInsets.zero,
          enabled: widget.enabled,
          onSelected: widget.onSelected,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: ProcurementDocumentType.contractOrderReport,
              child: Text('รายงานขอซื้อ/ขอจ้าง'),
            ),
            PopupMenuItem(
              value: ProcurementDocumentType.contractAnnouncement,
              child: Text('ประกาศผู้ชนะการเสนอราคา'),
            ),
            PopupMenuItem(
              value: ProcurementDocumentType.quotation,
              child: Text('ใบเสนอราคา'),
            ),
            PopupMenuItem(
              value: ProcurementDocumentType.deliveryNote,
              child: Text('ใบส่งมอบงาน'),
            ),
          ],
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? hoverColor : colors.surface,
              borderRadius: BorderRadius.circular(RadiusSize.sm),
              border: Border.all(color: _hover ? hoverColor : colors.outline),
            ),
            child: Icon(
              Icons.description_outlined,
              size: IconSizes.md,
              color: _hover ? Colors.white : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractFormDialog extends StatefulWidget {
  final Contract? existing;
  final List<ProcurementOrder> orders;
  const _ContractFormDialog({this.existing, required this.orders});
  @override
  State<_ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends State<_ContractFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contractNumberCtrl;
  late final TextEditingController _egpNumberCtrl;
  late final TextEditingController _contractAmountCtrl;
  late final TextEditingController _vendorNameCtrl;
  late final TextEditingController _installmentCtrl;
  String? _contractType;
  late String _status;
  int? _orderId;
  String? _startDate;
  String? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _contractNumberCtrl = TextEditingController(text: c?.contractNumber ?? '');
    _egpNumberCtrl = TextEditingController(text: c?.egpNumber ?? '');
    _contractAmountCtrl = TextEditingController(text: c?.contractAmount?.toStringAsFixed(2) ?? '');
    _vendorNameCtrl = TextEditingController(text: c?.vendorName ?? '');
    _installmentCtrl = TextEditingController(text: c?.installmentCount?.toString() ?? '');
    _contractType = c?.contractType;
    _status = c?.status ?? 'กำลังดำเนินการ';
    _orderId = c?.orderId;
    _startDate = c?.startDate;
    _endDate = c?.endDate;
  }

  @override
  void dispose() {
    _contractNumberCtrl.dispose();
    _egpNumberCtrl.dispose();
    _contractAmountCtrl.dispose();
    _vendorNameCtrl.dispose();
    _installmentCtrl.dispose();
    super.dispose();
  }

  /// เลือก "รายการจัดซื้อจัดจ้างที่เกี่ยวข้อง" แล้ว — ดึงข้อมูลที่มีอยู่แล้วใน
  /// รายการนั้น (เลขที่คุมสัญญา, เลขที่ e-GP, ผู้ขาย, วงเงิน, วันที่เซ็นสัญญา)
  /// มาเติมให้อัตโนมัติทั้งหมดทันทีที่เลือก (ทับของเดิมในช่องนั้นๆ ถ้ามี) —
  /// ปลอดภัยเพราะฟังก์ชันนี้ทำงานเฉพาะตอนผู้ใช้เปลี่ยน dropdown เองเท่านั้น
  /// ไม่ได้รันตอนเปิดฟอร์มแก้ไขสัญญาเดิม จึงไม่มีทางไปทับข้อมูลโดยไม่ตั้งใจ
  void _onOrderSelected(int? orderId) {
    setState(() => _orderId = orderId);
    if (orderId == null) return;
    ProcurementOrder? order;
    for (final o in widget.orders) {
      if (o.id == orderId) { order = o; break; }
    }
    if (order == null) return;
    final selectedOrder = order;
    setState(() {
      if (selectedOrder.contractControlNumber?.trim().isNotEmpty ?? false) {
        _contractNumberCtrl.text = selectedOrder.contractControlNumber!;
      }
      if (selectedOrder.egpProjectId?.trim().isNotEmpty ?? false) {
        _egpNumberCtrl.text = selectedOrder.egpProjectId!;
      }
      if (selectedOrder.vendorName?.trim().isNotEmpty ?? false) {
        _vendorNameCtrl.text = selectedOrder.vendorName!;
      }
      final amount = selectedOrder.currentOrderPrice ?? selectedOrder.netPayableAmount ?? selectedOrder.allocatedAmount;
      if (amount != null) _contractAmountCtrl.text = amount.toStringAsFixed(2);
      if (selectedOrder.dateContractSigned?.trim().isNotEmpty ?? false) {
        _startDate = selectedOrder.dateContractSigned;
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
      helpText: isStart ? 'วันที่เริ่มสัญญา' : 'วันที่สิ้นสุดสัญญา',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = _formatThai(picked);
      } else {
        _endDate = _formatThai(picked);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final contract = Contract(
      id: widget.existing?.id,
      contractNumber: _contractNumberCtrl.text.trim().isEmpty ? null : _contractNumberCtrl.text.trim(),
      egpNumber: _egpNumberCtrl.text.trim().isEmpty ? null : _egpNumberCtrl.text.trim(),
      orderId: _orderId,
      contractType: _contractType,
      contractAmount: double.tryParse(_contractAmountCtrl.text.trim()),
      vendorName: _vendorNameCtrl.text.trim().isEmpty ? null : _vendorNameCtrl.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      installmentCount: int.tryParse(_installmentCtrl.text.trim()),
      status: _status,
    );
    if (widget.existing == null) {
      await _repo.insertContract(contract);
    } else {
      await _repo.updateContract(contract);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขสัญญา' : 'เพิ่มสัญญา', style: _dialogTitleStyle),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _field(_contractNumberCtrl, 'เลขที่สัญญา', hint: 'เช่น สัญญาที่ 5/2569')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_egpNumberCtrl, 'เลขที่ e-GP', hint: 'เช่น 69000000000')),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<int?>(
                    initialValue: _orderId,
                    isExpanded: true,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(
                      context,
                      label: 'รายการจัดซื้อจัดจ้างที่เกี่ยวข้อง',
                      helper: 'เลือกแล้วระบบจะดึงเลขที่คุมสัญญา/e-GP/ผู้ขาย/วงเงินจากรายการนี้มาเติมให้อัตโนมัติทันที (ทับข้อมูลเดิมในช่องนั้นถ้ามี)',
                    ).copyWith(
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      suffixIcon: _orderId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'ล้างค่าที่เลือก',
                              onPressed: () => _onOrderSelected(null),
                            )
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('(ไม่ผูกกับเอกสาร)')),
                      ...widget.orders.where((o) => o.id != null).map((o) => DropdownMenuItem<int?>(
                            value: o.id,
                            child: Text(
                              o.projectName ?? o.procurementSubject ?? 'เอกสาร #${o.id}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: _onOrderSelected,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _contractType,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(context, label: 'ประเภทสัญญา').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ..._contractTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() => _contractType = v),
                  ),
                ),
                _field(_vendorNameCtrl, 'คู่สัญญา (ชื่อบริษัท/ร้านค้า)', hint: 'เช่น บริษัท เอบีซี จำกัด'),
                Row(
                  children: [
                    Expanded(child: _field(_contractAmountCtrl, 'วงเงินตามสัญญา (บาท)', keyboardType: TextInputType.number, hint: 'เช่น 50000.00')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_installmentCtrl, 'จำนวนงวดงาน', keyboardType: TextInputType.number, hint: 'เช่น 3')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isStart: true),
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: InputDecorator(
                            decoration: _dialogFieldDecoration(context, label: 'วันที่เริ่มสัญญา').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                            child: Text(_startDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isStart: false),
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: InputDecorator(
                            decoration: _dialogFieldDecoration(context, label: 'วันที่สิ้นสุดสัญญา').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                            child: Text(_endDate ?? 'เลือกวันที่', style: _dialogFieldStyle),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                  decoration: _dialogFieldDecoration(context, label: 'สถานะสัญญา').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                  items: _contractStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'กำลังดำเนินการ'),
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
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: ctrl,
        style: _dialogFieldStyle,
        keyboardType: keyboardType,
        decoration: _dialogFieldDecoration(context, label: label, hint: hint),
      ),
    );
  }
}
