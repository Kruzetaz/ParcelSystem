// budget_list_screen.dart
import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget.dart';

const _brandColor = Color(0xFF1A3A5C);

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});
  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  final _repo = ProcurementRepository();
  List<Budget> _budgets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllBudgets();
    if (!mounted) return;
    setState(() { _budgets = list; _loading = false; });
  }

  Future<void> _openForm({Budget? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BudgetFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบแผนงบ "${budget.projectName ?? "(ไม่มีชื่อโครงการ)"}" ใช่หรือไม่?'),
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
    if (confirmed == true && budget.id != null) {
      await _repo.deleteBudget(budget.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _budgets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('ยังไม่มีแผนงบประมาณ\nกด "เพิ่มแผนงบ" เพื่อเริ่มต้น',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _budgets.length,
                          // เผื่อพื้นที่ด้านล่างไม่ให้ FAB ลอยทับรายการสุดท้าย
                          padding: const EdgeInsets.only(bottom: 80),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildCard(_budgets[i]),
                        ),
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            backgroundColor: _brandColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มแผนงบ'),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Budget b) {
    final remaining = b.remainingAmount ?? b.allocatedAmount ?? 0;
    final allocated = b.allocatedAmount ?? 0;
    final ratio = allocated > 0 ? (remaining / allocated).clamp(0.0, 1.0) : 1.0;
    final remainColor = ratio > 0.5 ? Colors.green : ratio > 0.2 ? Colors.orange : Colors.redAccent;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openForm(existing: b),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _brandColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('ปี ${b.fiscalYear}',
                          style: const TextStyle(fontSize: 12, color: _brandColor, fontWeight: FontWeight.w600)),
                      ),
                      if (b.groupName != null) ...[
                        const SizedBox(width: 8),
                        Text(b.groupName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Text(b.projectName ?? '(ไม่มีชื่อโครงการ)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (b.activityName != null) ...[
                      const SizedBox(height: 2),
                      Text(b.activityName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (b.egpNumber != null) ...[
                      const SizedBox(height: 2),
                      Text('e-GP: ${b.egpNumber}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('คงเหลือ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  Text('${remaining.toStringAsFixed(2)} บาท',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: remainColor)),
                  Text('จาก ${allocated.toStringAsFixed(2)} บาท',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'ลบ',
                onPressed: () => _confirmDelete(b),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetFormDialog extends StatefulWidget {
  final Budget? existing;
  const _BudgetFormDialog({this.existing});
  @override
  State<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends State<_BudgetFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fiscalYear;
  late final TextEditingController _groupName;
  late final TextEditingController _projectName;
  late final TextEditingController _activityName;
  late final TextEditingController _egpNumber;
  late final TextEditingController _allocatedAmount;
  late final TextEditingController _responsiblePerson;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _fiscalYear = TextEditingController(text: b?.fiscalYear ?? '');
    _groupName = TextEditingController(text: b?.groupName ?? '');
    _projectName = TextEditingController(text: b?.projectName ?? '');
    _activityName = TextEditingController(text: b?.activityName ?? '');
    _egpNumber = TextEditingController(text: b?.egpNumber ?? '');
    _allocatedAmount = TextEditingController(text: b?.allocatedAmount?.toStringAsFixed(2) ?? '');
    _responsiblePerson = TextEditingController(text: b?.responsiblePerson ?? '');
  }

  @override
  void dispose() {
    for (final c in [_fiscalYear, _groupName, _projectName, _activityName, _egpNumber, _allocatedAmount, _responsiblePerson]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final allocated = double.tryParse(_allocatedAmount.text.trim()) ?? 0;
    final b = Budget(
      id: widget.existing?.id,
      fiscalYear: _fiscalYear.text.trim(),
      groupName: _groupName.text.trim().isEmpty ? null : _groupName.text.trim(),
      projectName: _projectName.text.trim().isEmpty ? null : _projectName.text.trim(),
      activityName: _activityName.text.trim().isEmpty ? null : _activityName.text.trim(),
      egpNumber: _egpNumber.text.trim().isEmpty ? null : _egpNumber.text.trim(),
      allocatedAmount: allocated,
      remainingAmount: widget.existing?.remainingAmount ?? allocated,
      responsiblePerson: _responsiblePerson.text.trim().isEmpty ? null : _responsiblePerson.text.trim(),
    );
    if (widget.existing == null) {
      await _repo.insertBudget(b);
    } else {
      await _repo.updateBudget(b);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขแผนงบประมาณ' : 'เพิ่มแผนงบประมาณ'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_fiscalYear, 'ปีงบประมาณ *', required: true, hint: 'เช่น 2568'),
                _field(_groupName, 'แผนงาน', hint: 'เช่น แผนงานบริหารงานทั่วไป'),
                _field(_projectName, 'ชื่อโครงการ'),
                _field(_activityName, 'กิจกรรม'),
                _field(_egpNumber, 'เลขที่ e-GP'),
                _field(_allocatedAmount, 'วงเงินที่ได้รับจัดสรร (บาท) *',
                  required: true, keyboardType: TextInputType.number, hint: 'เช่น 50000.00'),
                _field(_responsiblePerson, 'ผู้รับผิดชอบ'),
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
          style: FilledButton.styleFrom(backgroundColor: _brandColor),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          border: const OutlineInputBorder(), isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null
            : null,
      ),
    );
  }
}