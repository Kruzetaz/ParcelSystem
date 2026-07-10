// budget_list_screen.dart
//
// [อัปเดต]: เพิ่มการจัดกลุ่ม "ฝ่าย" (ใช้ช่อง group_name เดิม แค่เปลี่ยนป้ายชื่อ
// เป็น "ฝ่าย/แผนงาน") และจัดกลุ่ม "โครงการหลัก > โครงการย่อย" โดยใช้ project_name
// เป็นตัวจัดกลุ่ม แล้วให้ activity_name ของแต่ละแถวเป็น "โครงการย่อย/รายการ"
// ใต้โครงการนั้น (ไม่ได้เพิ่ม field ใหม่ในฐานข้อมูล แค่จัดกลุ่มตอนแสดงผล)
// เพิ่มช่องค้นหาชื่อโครงการ + ตัวกรองฝ่าย/โครงการ + มุมมองตาราง (สลับกับการ์ดได้)

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget.dart';
import '../services/budget_import_service.dart';
import '../services/toast_service.dart';
import '../widgets/budget_import_dialog.dart';

enum _BudgetViewMode { card, table }

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});
  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  final _repo = ProcurementRepository();
  List<Budget> _budgets = [];
  bool _loading = true;
  bool _importing = false;

  _BudgetViewMode _viewMode = _BudgetViewMode.card;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment; // null = ทั้งหมด — ใช้ค่าจาก groupName
  String? _selectedProject; // null = ทั้งหมด — ใช้ค่าจาก projectName

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllBudgets();
    if (!mounted) return;
    setState(() {
      _budgets = list;
      _loading = false;
    });
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

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'docx', 'pdf'],
      dialogTitle: 'เลือกไฟล์แผนงบประมาณ',
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importing = true);
    try {
      final parsed = await BudgetImportService.instance.importFromFile(result.files.single.path!);
      if (!mounted) return;
      setState(() => _importing = false);

      if (parsed.isEmpty) {
        showAppToast('ไม่พบรายการแผนงบประมาณในไฟล์นี้', isError: true);
        return;
      }

      final confirmed = await showBudgetImportPreviewDialog(context, parsed);
      if (confirmed != null && confirmed.isNotEmpty) {
        for (final b in confirmed) {
          await _repo.insertBudget(b);
        }
        showAppToast('นำเข้า ${confirmed.length} แผนงบประมาณแล้ว');
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      showAppToast('นำเข้าไฟล์ไม่สำเร็จ: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────
  // การกรอง + จัดกลุ่ม
  // ─────────────────────────────────────────

  List<String> get _departmentOptions =>
      _budgets.map((b) => b.groupName).whereType<String>().where((s) => s.isNotEmpty).toSet().toList()..sort();

  List<String> get _projectOptions => _budgets
      .where((b) => _selectedDepartment == null || b.groupName == _selectedDepartment)
      .map((b) => b.projectName)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<Budget> get _filteredBudgets => _budgets.where((b) {
        if (_selectedDepartment != null && b.groupName != _selectedDepartment) return false;
        if (_selectedProject != null && b.projectName != _selectedProject) return false;
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          final matchesProject = (b.projectName ?? '').toLowerCase().contains(q);
          final matchesActivity = (b.activityName ?? '').toLowerCase().contains(q);
          if (!matchesProject && !matchesActivity) return false;
        }
        return true;
      }).toList();

  /// จัดกลุ่มตาม projectName — เก็บลำดับการปรากฏครั้งแรกไว้ (ไม่เรียงตัวอักษร)
  /// แถวที่ groupName/projectName เหมือนกันจะถูกจัดเป็นกลุ่มเดียว โดยแต่ละแถวคือ
  /// "โครงการย่อย/รายการ" ภายใต้โครงการนั้น (ใช้ activityName เป็นชื่อรายการย่อย)
  List<MapEntry<String, List<Budget>>> get _groupedByProject {
    final order = <String>[];
    final map = <String, List<Budget>>{};
    for (final b in _filteredBudgets) {
      final key = b.projectName ?? '(ไม่มีชื่อโครงการ)';
      if (!map.containsKey(key)) {
        order.add(key);
        map[key] = [];
      }
      map[key]!.add(b);
    }
    return order.map((k) => MapEntry(k, map[k]!)).toList();
  }

  bool get _hasActiveFilter =>
      _searchQuery.isNotEmpty || _selectedDepartment != null || _selectedProject != null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildFilterBar(colors)),
                      const SizedBox(width: 12),
                      _buildViewToggle(colors),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _importing ? null : _importFromFile,
                        icon: _importing
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                              )
                            : const Icon(Icons.folder_open_outlined),
                        label: Text(_importing ? 'กำลังนำเข้า...' : '📂 Import จากไฟล์'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _budgets.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined, size: 64, color: colors.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text('ยังไม่มีแผนงบประมาณ\nกด "เพิ่มแผนงบ" เพื่อเริ่มต้น',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                                  ],
                                ),
                              )
                            : _filteredBudgets.isEmpty
                                ? Center(
                                    child: Text(
                                      _hasActiveFilter ? 'ไม่พบรายการที่ตรงกับตัวกรอง' : 'ยังไม่มีแผนงบประมาณ',
                                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                                    ),
                                  )
                                : _viewMode == _BudgetViewMode.card
                                    ? _buildCardView(colors)
                                    : _buildTableView(colors),
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
            label: const Text('เพิ่มแผนงบ'),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // แถบค้นหา + ตัวกรอง + สลับมุมมอง
  // ─────────────────────────────────────────

  Widget _buildFilterBar(ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'ค้นหาชื่อโครงการ/กิจกรรม',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            colors: colors,
            hint: 'ฝ่าย/แผนงาน (ทั้งหมด)',
            value: _selectedDepartment,
            options: _departmentOptions,
            onChanged: (v) => setState(() {
              _selectedDepartment = v;
              // ถ้าโครงการที่เลือกไว้ไม่อยู่ในฝ่ายใหม่ ให้เคลียร์ตัวกรองโครงการทิ้ง
              if (_selectedProject != null && !_projectOptions.contains(_selectedProject)) {
                _selectedProject = null;
              }
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            colors: colors,
            hint: 'โครงการ (ทั้งหมด)',
            value: _selectedProject,
            options: _projectOptions,
            onChanged: (v) => setState(() => _selectedProject = v),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required ColorScheme colors,
    required String hint,
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(isDense: true, hintText: hint),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(hint, overflow: TextOverflow.ellipsis)),
        ...options.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildViewToggle(ColorScheme colors) {
    return SegmentedButton<_BudgetViewMode>(
      segments: const [
        ButtonSegment(value: _BudgetViewMode.card, icon: Icon(Icons.view_agenda_outlined), label: Text('การ์ด')),
        ButtonSegment(value: _BudgetViewMode.table, icon: Icon(Icons.table_chart_outlined), label: Text('ตาราง')),
      ],
      selected: {_viewMode},
      onSelectionChanged: (s) => setState(() => _viewMode = s.first),
    );
  }

  // ─────────────────────────────────────────
  // มุมมองการ์ด — จัดกลุ่มตามโครงการ
  // ─────────────────────────────────────────

  Widget _buildCardView(ColorScheme colors) {
    final groups = _groupedByProject;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: groups.length,
      itemBuilder: (_, i) => _buildProjectGroup(colors, groups[i]),
    );
  }

  Widget _buildProjectGroup(ColorScheme colors, MapEntry<String, List<Budget>> group) {
    final rows = group.value;
    final totalAllocated = rows.fold<double>(0, (s, b) => s + (b.allocatedAmount ?? 0));
    final totalRemaining = rows.fold<double>(0, (s, b) => s + (b.remainingAmount ?? b.allocatedAmount ?? 0));
    final department = rows.first.groupName;
    final fiscalYear = rows.first.fiscalYear;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('ปี $fiscalYear',
                              style: TextStyle(fontSize: 11, color: colors.onPrimary, fontWeight: FontWeight.w600)),
                          ),
                          if (department != null) ...[
                            const SizedBox(width: 6),
                            Text(department,
                              style: TextStyle(fontSize: 11.5, color: colors.onPrimaryContainer)),
                          ],
                          if (rows.length > 1) ...[
                            const SizedBox(width: 6),
                            Text('· ${rows.length} รายการย่อย',
                              style: TextStyle(fontSize: 11.5, color: colors.onPrimaryContainer.withOpacity(0.7))),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(group.key,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.onPrimaryContainer),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('คงเหลือรวม', style: TextStyle(fontSize: 10.5, color: colors.onPrimaryContainer.withOpacity(0.8))),
                      Text('${totalRemaining.toStringAsFixed(2)} บาท',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onPrimaryContainer)),
                      Text('จาก ${totalAllocated.toStringAsFixed(2)} บาท',
                        style: TextStyle(fontSize: 10.5, color: colors.onPrimaryContainer.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
            ),
            for (final b in rows) _buildActivityRow(colors, b),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(ColorScheme colors, Budget b) {
    final remaining = b.remainingAmount ?? b.allocatedAmount ?? 0;
    final allocated = b.allocatedAmount ?? 0;
    final ratio = allocated > 0 ? (remaining / allocated).clamp(0.0, 1.0) : 1.0;
    final remainColor = ratio > 0.5 ? Colors.green : ratio > 0.2 ? Colors.orange : Colors.redAccent;

    return InkWell(
      onTap: () => _openForm(existing: b),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.outlineVariant))),
        child: Row(
          children: [
            Icon(Icons.subdirectory_arrow_right, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.activityName ?? '(ทั้งโครงการ)',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (b.egpNumber != null)
                    Text('e-GP: ${b.egpNumber}', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            Text('${remaining.toStringAsFixed(2)} บาท',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: remainColor)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'ลบ',
              onPressed: () => _confirmDelete(b),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // มุมมองตาราง — จัดกลุ่มตามโครงการเหมือนกัน แต่แสดงเป็นแถวตาราง
  // ─────────────────────────────────────────

  Widget _buildTableView(ColorScheme colors) {
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 1.5))),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text('ฝ่าย/แผนงาน', style: headerStyle)),
                  SizedBox(width: 60, child: Text('ปีงบ', style: headerStyle)),
                  Expanded(flex: 3, child: Text('โครงการ / รายการย่อย', style: headerStyle)),
                  SizedBox(width: 100, child: Text('เลข e-GP', style: headerStyle)),
                  SizedBox(width: 110, child: Text('วงเงิน', style: headerStyle, textAlign: TextAlign.right)),
                  SizedBox(width: 110, child: Text('คงเหลือ', style: headerStyle, textAlign: TextAlign.right)),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            for (final group in _groupedByProject) ..._buildTableGroupRows(colors, group),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTableGroupRows(ColorScheme colors, MapEntry<String, List<Budget>> group) {
    final rows = group.value;
    final department = rows.first.groupName ?? '-';
    final fiscalYear = rows.first.fiscalYear;
    final widgets = <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: colors.surfaceContainerHighest,
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(department, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant))),
            SizedBox(width: 60, child: Text(fiscalYear, style: const TextStyle(fontSize: 12.5))),
            Expanded(
              flex: 3,
              child: Text(group.key,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 100),
            const SizedBox(width: 110),
            const SizedBox(width: 110),
            const SizedBox(width: 40),
          ],
        ),
      ),
    ];
    for (final b in rows) {
      final remaining = b.remainingAmount ?? b.allocatedAmount ?? 0;
      final allocated = b.allocatedAmount ?? 0;
      final ratio = allocated > 0 ? (remaining / allocated).clamp(0.0, 1.0) : 1.0;
      final remainColor = ratio > 0.5 ? Colors.green : ratio > 0.2 ? Colors.orange : Colors.redAccent;
      widgets.add(
        InkWell(
          onTap: () => _openForm(existing: b),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                const SizedBox(width: 110),
                const SizedBox(width: 60),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(b.activityName ?? '(ทั้งโครงการ)',
                      style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                SizedBox(width: 100, child: Text(b.egpNumber ?? '-', style: const TextStyle(fontSize: 12.5))),
                SizedBox(width: 110, child: Text(allocated.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                SizedBox(
                  width: 110,
                  child: Text(remaining.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: remainColor)),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => _confirmDelete(b),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
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
    final colors = Theme.of(context).colorScheme;
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
                _field(_groupName, 'ฝ่าย/แผนงาน', hint: 'เช่น ฝ่ายบริหารงานทั่วไป'),
                _field(_projectName, 'ชื่อโครงการ (โครงการหลัก)'),
                _field(_activityName, 'กิจกรรม/โครงการย่อย'),
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
