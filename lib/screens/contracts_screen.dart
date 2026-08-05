// contracts_screen.dart
// บริหารสัญญา/ใบสั่งซื้อ/สั่งจ้าง (blueprint หน้าที่ 5) — ผูกกับรายการจัดซื้อ
// จัดจ้าง (procurement_orders) ได้แบบไม่บังคับ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/contract.dart';
import '../models/procurement_order.dart';
import '../services/procurement_document_generator.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../services/toast_service.dart';

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
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final contracts = await _repo.getAllContracts();
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
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบสัญญา "${c.contractNumber ?? "(ไม่มีเลขที่)"}" ใช่หรือไม่?'),
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
                          _buildSummaryBar(colors),
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
                                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _contracts.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _buildCard(colors, _contracts[i]),
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

  Widget _buildSummaryBar(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined, color: colors.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('มูลค่าสัญญารวมทั้งหมด', style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer)),
                Text('${formatBaht(_totalContractValue)} บาท (${_contracts.length} สัญญา)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.onPrimaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ColorScheme colors, Contract c) {
    final statusColor = switch (c.status) {
      'ครบกำหนดแล้ว' => Colors.green,
      'ยกเลิก' => Colors.redAccent,
      _ => Colors.orange,
    };
    final linkedOrder = c.orderId != null ? _ordersById[c.orderId] : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(existing: c),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(c.contractType!,
                            style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(c.status,
                          style: TextStyle(fontSize: 11.5, color: statusColor, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(c.contractNumber ?? '(ไม่มีเลขที่สัญญา)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (c.vendorName != null) ...[
                      const SizedBox(height: 2),
                      Text('คู่สัญญา: ${c.vendorName}', style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (linkedOrder != null) ...[
                      const SizedBox(height: 2),
                      Text('รายการ: ${linkedOrder.projectName ?? linkedOrder.procurementSubject ?? "-"}',
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (c.startDate != null || c.endDate != null) ...[
                      const SizedBox(height: 2),
                      Text('${c.startDate ?? "-"} ถึง ${c.endDate ?? "-"}',
                        style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (c.contractAmount != null)
                Text('${formatBaht(c.contractAmount)} บาท',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.primary)),
              if (linkedOrder != null) ...[
                const SizedBox(width: 4),
                (_exportingId == c.id)
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : Row(
                        children: [
                          // ปุ่มลัด "ดูตัวอย่าง" — ออกเอกสารหลักของสัญญา (รายงาน
                          // ขอซื้อ/ขอจ้าง) ให้ทันทีในคลิกเดียว ไม่ต้องเลือกจากเมนู
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            visualDensity: VisualDensity.compact,
                            color: colors.onSurfaceVariant,
                            tooltip: 'ดูตัวอย่างเอกสาร',
                            onPressed: () => _exportWord(c, ProcurementDocumentType.contractOrderReport),
                          ),
                          PopupMenuButton<ProcurementDocumentType>(
                            icon: Icon(Icons.description_outlined, color: colors.primary, size: 18),
                            tooltip: 'สร้างเอกสาร (เลือกประเภท)',
                            onSelected: _exportingId != null ? null : (type) => _exportWord(c, type),
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
                          ),
                        ],
                      ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                visualDensity: VisualDensity.compact,
                color: colors.onSurfaceVariant,
                tooltip: 'คัดลอกสัญญา',
                onPressed: () => _duplicateContract(c),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                visualDensity: VisualDensity.compact,
                tooltip: 'ลบ',
                onPressed: () => _confirmDelete(c),
              ),
            ],
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
      title: Text(isEdit ? 'แก้ไขสัญญา' : 'เพิ่มสัญญา'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _field(_contractNumberCtrl, 'เลขที่สัญญา')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_egpNumberCtrl, 'เลขที่ e-GP')),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int?>(
                    initialValue: _orderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'รายการจัดซื้อจัดจ้างที่เกี่ยวข้อง', border: OutlineInputBorder(), isDense: true,
                      helperText: 'เลือกแล้วระบบจะดึงเลขที่คุมสัญญา/e-GP/ผู้ขาย/วงเงินจากรายการนี้มาเติมให้อัตโนมัติทันที (ทับข้อมูลเดิมในช่องนั้นถ้ามี)',
                      helperMaxLines: 2,
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _contractType,
                    decoration: const InputDecoration(
                      labelText: 'ประเภทสัญญา', border: OutlineInputBorder(), isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ..._contractTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() => _contractType = v),
                  ),
                ),
                _field(_vendorNameCtrl, 'คู่สัญญา (ชื่อบริษัท/ร้านค้า)'),
                Row(
                  children: [
                    Expanded(child: _field(_contractAmountCtrl, 'วงเงินตามสัญญา (บาท)', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_installmentCtrl, 'จำนวนงวดงาน', keyboardType: TextInputType.number)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isStart: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'วันที่เริ่มสัญญา', border: OutlineInputBorder(), isDense: true),
                          child: Text(_startDate ?? 'เลือกวันที่'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isStart: false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'วันที่สิ้นสุดสัญญา', border: OutlineInputBorder(), isDense: true),
                          child: Text(_endDate ?? 'เลือกวันที่'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'สถานะสัญญา', border: OutlineInputBorder(), isDense: true),
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
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }
}
