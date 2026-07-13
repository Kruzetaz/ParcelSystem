// guarantees_screen.dart
// ทะเบียนหลักประกัน (blueprint หน้าที่ 6) — กรองตามประเภทด้วยชิป (แทนแท็บ
// ให้สอดคล้องกับรูปแบบตัวกรองที่ใช้อยู่แล้วในหน้าอื่นของแอป)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/guarantee.dart';
import '../models/contract.dart';

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
  String? _selectedType; // null = ทั้งหมด

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllGuarantees();
    final contracts = await _repo.getAllContracts();
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
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบหลักประกันของ "${g.counterpartyName ?? "-"}" ใช่หรือไม่?'),
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
    if (confirmed == true && g.id != null) {
      await _repo.deleteGuarantee(g.id!);
      _load();
    }
  }

  Future<void> _returnGuarantee(Guarantee g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('คืนหลักประกัน'),
        content: Text('ยืนยันคืนหลักประกันของ "${g.counterpartyName ?? "-"}" '
            '(${g.amount?.toStringAsFixed(2) ?? "-"} บาท) ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
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
                        if (_contractsMissingGuarantee.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildMissingGuaranteeBanner(colors),
                        ],
                        const SizedBox(height: 16),
                        _buildFilterChips(colors),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    _guarantees.isEmpty ? 'ยังไม่มีหลักประกัน\nกด "เพิ่มหลักประกัน" เพื่อเริ่มต้น' : 'ไม่พบรายการในประเภทนี้',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _filtered.length,
                                  padding: const EdgeInsets.only(bottom: 80),
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _buildCard(colors, _filtered[i]),
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
            label: const Text('เพิ่มหลักประกัน'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: colors.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ยอดหลักประกันที่ถืออยู่ในปัจจุบัน', style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer)),
                Text('${_totalHeld.toStringAsFixed(2)} บาท',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.onPrimaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingGuaranteeBanner(ColorScheme colors) {
    final contracts = _contractsMissingGuarantee;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'พบ ${contracts.length} สัญญาที่วงเงินถึงเกณฑ์ต้องวางหลักประกัน แต่ยังไม่ได้บันทึก',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ตามระเบียบฯ สัญญาวงเงิน ≥ ${_guaranteeRequiredThreshold.toStringAsFixed(0)} บาท ทั่วไปต้องวางหลักประกัน '
            '(ประมาณ ${(_guaranteeRate * 100).toStringAsFixed(0)}% ของวงเงิน) — เป็นคำแนะนำเบื้องต้นเท่านั้น '
            'โปรดตรวจสอบเงื่อนไขในสัญญาจริงอีกครั้ง',
            style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
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
                      '(${(c.contractAmount ?? 0).toStringAsFixed(2)} บาท)',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _openForm(prefillContract: c),
                    child: const Text('ไปบันทึก', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          if (contracts.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('และอีก ${contracts.length - 5} รายการ', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
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
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _selectedType = value),
          selectedColor: colors.primary,
          labelStyle: TextStyle(color: selected ? colors.onPrimary : colors.onSurfaceVariant),
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

  Widget _buildCard(ColorScheme colors, Guarantee g) {
    final isHeld = g.status == 'ถืออยู่';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(existing: g),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(g.guaranteeType!, style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isHeld ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(g.status,
                          style: TextStyle(fontSize: 11.5, color: isHeld ? Colors.orange : Colors.green, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(g.counterpartyName ?? '(ไม่ระบุคู่สัญญา)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (g.startDate != null || g.expiryDate != null) ...[
                      const SizedBox(height: 2),
                      Text('${g.startDate ?? "-"} ถึง ${g.expiryDate ?? "-"}', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                    ],
                    if (g.returnedDate != null) ...[
                      const SizedBox(height: 2),
                      Text('คืนเมื่อ ${g.returnedDate}', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (g.amount != null)
                    Text('${g.amount!.toStringAsFixed(2)} บาท',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.primary)),
                  if (isHeld)
                    TextButton(
                      onPressed: () => _returnGuarantee(g),
                      child: const Text('คืนหลักประกัน', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'ลบ',
                onPressed: () => _confirmDelete(g),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
      helpText: isStart ? 'วันที่เริ่มค้ำประกัน' : 'วันที่หมดอายุการค้ำประกัน',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: colors.primary, onPrimary: colors.onPrimary, onSurface: colors.primary),
        ),
        child: child!,
      ),
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
      title: Text(isEdit ? 'แก้ไขหลักประกัน' : 'เพิ่มหลักประกัน'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String?>(
                  initialValue: _guaranteeType,
                  decoration: const InputDecoration(labelText: 'ประเภทหลักประกัน', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                    ..._guaranteeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                  ],
                  onChanged: (v) => setState(() => _guaranteeType = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int?>(
                  initialValue: _contractId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ผูกกับสัญญา', border: OutlineInputBorder(), isDense: true),
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
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _counterpartyCtrl,
                  decoration: const InputDecoration(labelText: 'ผู้เสนอราคา/คู่สัญญา', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'วงเงินค้ำประกัน (บาท)', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'วันที่เริ่มค้ำประกัน', border: OutlineInputBorder(), isDense: true),
                        child: Text(_startDate ?? 'เลือกวันที่'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'วันหมดอายุ', border: OutlineInputBorder(), isDense: true),
                        child: Text(_expiryDate ?? 'เลือกวันที่'),
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
}
