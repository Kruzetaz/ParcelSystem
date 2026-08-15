// budget_import_dialog.dart
// พรีวิว/แก้ไขรายการแผนงบประมาณที่นำเข้าจากไฟล์ ก่อนบันทึกลงฐานข้อมูลจริง

import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../theme/design_tokens.dart';
import 'design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

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

  // ปุ่ม/ตัวหนังสือในกล่องนี้ ใหญ่กว่า default ของธีมกลางตรงๆ (เหมือนกล่องยืนยัน
  // อื่นๆ ในหน้าแผนงบประมาณ) เพราะ titleLarge/labelLarge ของธีมกลางถูกจูนไว้
  // เล็กสำหรับตารางข้อมูลหนาแน่น ไม่เหมาะกับกล่องโต้ตอบที่ต้องอ่าน/ตัดสินใจจริงจัง
  static const _buttonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.card)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open_outlined, color: BrandAccent.teal(context), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'ตรวจสอบแผนงบประมาณที่นำเข้า',
                    style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ตรวจสอบและแก้ไขข้อมูลได้ก่อนบันทึกจริง',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium),
              ),
              const SizedBox(height: 14),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('ไม่พบรายการ',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.body)),
                  ),
                )
              else
                // เปลี่ยนจาก SingleChildScrollView+Column (สร้างทุกแถวพร้อมกัน
                // ทีเดียวตั้งแต่เปิดกล่อง) มาใช้ ListView.builder แทน — สร้าง
                // เฉพาะแถวที่อยู่ในจอ/ใกล้จอเท่านั้น (lazy) กันหน่วงตอนไฟล์ที่
                // import มีหลักร้อยรายการขึ้นไป ยังอยู่ใน Flexible เหมือนเดิม
                // (ไม่ใช้ shrinkWrap:true เพราะนั่นจะบังคับวัดทุก item ทันที
                // เหมือนเดิม ทำให้เสียประโยชน์ของ lazy loading ไปเปล่าๆ)
                Flexible(
                  child: ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, i) => _buildRow(colors, i),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(padding: _buttonPadding, textStyle: _buttonTextStyle),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _rows.isEmpty
                        ? null
                        : () => Navigator.pop(context, _rows.map((r) => r.toBudget()).toList()),
                    icon: const Icon(Icons.check),
                    label: Text('ยืนยันนำเข้าข้อมูล (${_rows.length} รายการ)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandAccent.teal(context),
                      padding: _buttonPadding,
                      textStyle: _buttonTextStyle,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                    ),
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
    const fieldStyle = TextStyle(fontSize: AppTypography.body);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 92,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: row.fiscalYear,
                    style: fieldStyle,
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
                    style: fieldStyle,
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
                    style: fieldStyle,
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
                    style: fieldStyle,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, hintText: 'วงเงิน'),
                  ),
                ),
              ),
              DsActionIconButtons(
                actions: [
                  DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบแถวนี้ออกจากการนำเข้า', onTap: () => _removeAt(index), danger: true),
                ],
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
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    elevation: 6,
                    decoration: const InputDecoration(
                      isDense: true, hintText: 'ฝ่าย/แผนงาน (ไม่ระบุ)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
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
                    style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
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
