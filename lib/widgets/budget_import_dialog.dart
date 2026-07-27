// budget_import_dialog.dart
// พรีวิว/แก้ไขรายการแผนงบประมาณที่นำเข้าจากไฟล์ ก่อนบันทึกลงฐานข้อมูลจริง

import 'package:flutter/material.dart';
import '../models/budget.dart';

class _EditableBudget {
  final TextEditingController fiscalYear;
  String? groupName;
  final TextEditingController projectName;
  final TextEditingController activityName;
  final TextEditingController allocatedAmount;
  final TextEditingController responsiblePerson;

  _EditableBudget(Budget b, List<String> departmentOptions)
      : fiscalYear = TextEditingController(text: b.fiscalYear),
        groupName = departmentOptions.contains(b.groupName) ? b.groupName : null,
        projectName = TextEditingController(text: b.projectName ?? ''),
        activityName = TextEditingController(text: b.activityName ?? ''),
        allocatedAmount = TextEditingController(text: b.allocatedAmount?.toStringAsFixed(2) ?? ''),
        responsiblePerson = TextEditingController(text: b.responsiblePerson ?? '');

  void dispose() {
    fiscalYear.dispose();
    projectName.dispose();
    activityName.dispose();
    allocatedAmount.dispose();
    responsiblePerson.dispose();
  }

  Budget toBudget() => Budget(
        fiscalYear: fiscalYear.text.trim(),
        groupName: groupName,
        projectName: projectName.text.trim().isEmpty ? null : projectName.text.trim(),
        activityName: activityName.text.trim().isEmpty ? null : activityName.text.trim(),
        allocatedAmount: double.tryParse(allocatedAmount.text.trim()),
        remainingAmount: double.tryParse(allocatedAmount.text.trim()),
        responsiblePerson: responsiblePerson.text.trim().isEmpty ? null : responsiblePerson.text.trim(),
      );
}

/// แสดง dialog พรีวิว — คืนค่า List<Budget> ที่ยืนยันแล้ว หรือ null ถ้ายกเลิก
/// [departmentOptions] คือรายชื่อกลุ่มงานที่ใช้งานอยู่ (จากแท็บ "กลุ่มงาน" ในตั้งค่า)
Future<List<Budget>?> showBudgetImportPreviewDialog(
  BuildContext context,
  List<Budget> parsedBudgets,
  List<String> departmentOptions,
) {
  return showDialog<List<Budget>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BudgetImportPreviewDialog(parsedBudgets: parsedBudgets, departmentOptions: departmentOptions),
  );
}

class _BudgetImportPreviewDialog extends StatefulWidget {
  final List<Budget> parsedBudgets;
  final List<String> departmentOptions;
  const _BudgetImportPreviewDialog({required this.parsedBudgets, required this.departmentOptions});

  @override
  State<_BudgetImportPreviewDialog> createState() => _BudgetImportPreviewDialogState();
}

class _BudgetImportPreviewDialogState extends State<_BudgetImportPreviewDialog> {
  late List<_EditableBudget> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.parsedBudgets.map((b) => _EditableBudget(b, widget.departmentOptions)).toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _removeAt(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open_outlined, color: colors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'ตรวจสอบแผนงบประมาณที่นำเข้า',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ตรวจสอบและแก้ไขข้อมูลได้ก่อนบันทึกจริง',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('ไม่พบรายการ', style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < _rows.length; i++) _buildRow(colors, i),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _rows.isEmpty
                        ? null
                        : () => Navigator.pop(context, _rows.map((r) => r.toBudget()).toList()),
                    icon: const Icon(Icons.check),
                    label: Text('ยืนยันนำเข้าข้อมูล (${_rows.length} รายการ)'),
                    style: FilledButton.styleFrom(backgroundColor: colors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 70,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: row.fiscalYear,
                    decoration: const InputDecoration(isDense: true, hintText: 'ปีงบ'),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: row.projectName,
                    decoration: const InputDecoration(isDense: true, hintText: 'ชื่อโครงการ'),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: row.activityName,
                    decoration: const InputDecoration(isDense: true, hintText: 'กิจกรรม'),
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: row.allocatedAmount,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, hintText: 'วงเงิน'),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _removeAt(index),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 78, right: 40),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: row.groupName,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true, hintText: 'ฝ่าย/แผนงาน (ไม่ระบุ)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุฝ่าย/แผนงาน)')),
                      ...widget.departmentOptions.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => row.groupName = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.responsiblePerson,
                    style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                    decoration: const InputDecoration(
                      isDense: true, hintText: 'ผู้รับผิดชอบ (ไม่ระบุ)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
