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
import '../models/work_group.dart';
import '../services/budget_import_service.dart';
import '../services/toast_service.dart';
import '../widgets/budget_import_dialog.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/column_visibility_menu.dart';

/// คอลัมน์ที่ซ่อน/แสดงได้ในมุมมองตาราง — "ฝ่าย/ปีงบ/โครงการ/คงเหลือ" แสดงเสมอ
const _budgetTableOptionalColumns = ['เลข e-GP', 'ผู้รับผิดชอบ', 'วงเงิน'];

enum _BudgetViewMode { card, table }

/// วิธีจัดการรายการที่ซ้ำกันตอน import จากไฟล์
enum _DuplicateResolution { replace, keepBoth, skip }

/// โหมด "กำหนดค่าหลายโครงการพร้อมกัน" — เลือกได้ว่าจะกำหนดฝ่าย/แผนงาน
/// หรือผู้รับผิดชอบ (none = ปิดโหมดนี้อยู่)
enum _BulkAssignField { none, department, responsiblePerson }

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});
  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  final _repo = ProcurementRepository();
  List<Budget> _budgets = [];
  List<WorkGroup> _workGroups = [];
  bool _loading = true;
  bool _importing = false;

  _BudgetViewMode _viewMode = _BudgetViewMode.card;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment; // null = ทั้งหมด — ใช้ค่าจาก groupName
  String? _selectedProject; // null = ทั้งหมด — ใช้ค่าจาก projectName
  String? _selectedSource; // null = ทั้งหมด — ใช้ค่าจาก budgetSource
  Set<String> _visibleColumns = _budgetTableOptionalColumns.toSet();

  // โหมด "กำหนดค่าหลายโครงการพร้อมกัน" — ใช้ enum เดียวสลับระหว่างกำหนด
  // "ฝ่าย/แผนงาน" (เลือกได้แค่ระดับโครงการ — ทุกกิจกรรมย่อยได้ค่าเดียวกันเสมอ)
  // กับ "ผู้รับผิดชอบ" (เลือกได้ละเอียดถึงระดับกิจกรรมย่อยแต่ละรายการ เพราะ
  // แต่ละกิจกรรมในโครงการเดียวกันอาจมีคนรับผิดชอบคนละคน)
  _BulkAssignField _bulkAssignField = _BulkAssignField.none;
  final Set<String> _selectedProjectKeys = {}; // ใช้กับโหมดฝ่าย/แผนงาน
  final Set<int> _selectedBudgetIds = {}; // ใช้กับโหมดผู้รับผิดชอบ (รายกิจกรรม)
  final _bulkPersonCtrl = TextEditingController();
  bool _applyingBulkAssign = false;

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
    _bulkPersonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllBudgets();
    final groups = await _repo.getAllWorkGroups(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _budgets = list;
      _workGroups = groups;
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
      try {
        await _repo.deleteBudget(budget.id!);
        if (!mounted) return;
        _load();
      } catch (e) {
        if (!mounted) return;
        showAppToast('ลบแผนงบไม่สำเร็จ: $e', isError: true);
      }
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบทั้งหมด'),
        content: Text('ต้องการลบแผนงบประมาณทั้งหมด ${_budgets.length} รายการใช่หรือไม่?\nการลบนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteAllBudgets();
      if (!mounted) return;
      showAppToast('ลบแผนงบประมาณทั้งหมดแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('ลบแผนงบไม่สำเร็จ: $e', isError: true);
    }
  }

  void _toggleBulkAssignMode(_BulkAssignField field) {
    setState(() {
      _bulkAssignField = _bulkAssignField == field ? _BulkAssignField.none : field;
      _selectedProjectKeys.clear();
      _selectedBudgetIds.clear();
      _bulkPersonCtrl.clear();
    });
  }

  /// ใช้กับโหมด "ฝ่าย/แผนงาน" — เลือกได้แค่ระดับทั้งโครงการ
  void _toggleProjectSelection(String projectKey) {
    setState(() {
      if (_selectedProjectKeys.contains(projectKey)) {
        _selectedProjectKeys.remove(projectKey);
      } else {
        _selectedProjectKeys.add(projectKey);
      }
    });
  }

  /// ใช้กับโหมด "ผู้รับผิดชอบ" — ติ๊กที่หัวการ์ด = เลือก/ยกเลิกทุกกิจกรรมย่อยในโครงการนั้นพร้อมกัน
  void _toggleProjectAllBudgets(List<Budget> rows) {
    final ids = rows.map((b) => b.id).whereType<int>().toSet();
    final allSelected = ids.every(_selectedBudgetIds.contains);
    setState(() {
      if (allSelected) {
        _selectedBudgetIds.removeAll(ids);
      } else {
        _selectedBudgetIds.addAll(ids);
      }
    });
  }

  /// ใช้กับโหมด "ผู้รับผิดชอบ" — ติ๊กแต่ละกิจกรรมย่อยแยกทีละรายการ
  void _toggleBudgetSelection(int id) {
    setState(() {
      if (_selectedBudgetIds.contains(id)) {
        _selectedBudgetIds.remove(id);
      } else {
        _selectedBudgetIds.add(id);
      }
    });
  }

  /// กำหนดฝ่าย/แผนงาน (จากรายการคงที่) ให้ทุกโครงการที่เลือกไว้ (ระดับทั้งโครงการ)
  Future<void> _applyBulkAssignDepartment(String group) async {
    setState(() => _applyingBulkAssign = true);
    try {
      var updatedCount = 0;
      for (final entry in _groupedByProject) {
        if (!_selectedProjectKeys.contains(entry.key)) continue;
        for (final b in entry.value) {
          if (b.id == null || b.groupName == group) continue;
          await _repo.updateBudget(b.copyWith(groupName: group));
          updatedCount++;
        }
      }
      if (!mounted) return;
      showAppToast('กำหนดฝ่าย/แผนงานให้ $updatedCount รายการแล้ว');
      setState(() {
        _bulkAssignField = _BulkAssignField.none;
        _selectedProjectKeys.clear();
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('กำหนดฝ่าย/แผนงานไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _applyingBulkAssign = false);
    }
  }

  /// กำหนดผู้รับผิดชอบ (ชื่อที่พิมพ์ไว้ในช่องของแถบด้านบน) ให้ทุกกิจกรรมย่อยที่ติ๊กเลือกไว้
  Future<void> _applyBulkAssignResponsiblePerson() async {
    final person = _bulkPersonCtrl.text.trim();
    if (person.isEmpty) {
      showAppToast('กรุณากรอกชื่อผู้รับผิดชอบก่อน', isError: true);
      return;
    }
    if (_selectedBudgetIds.isEmpty) {
      showAppToast('กรุณาติ๊กเลือกอย่างน้อย 1 กิจกรรม', isError: true);
      return;
    }
    setState(() => _applyingBulkAssign = true);
    try {
      var updatedCount = 0;
      for (final b in _budgets) {
        if (b.id == null || !_selectedBudgetIds.contains(b.id) || b.responsiblePerson == person) continue;
        await _repo.updateBudget(b.copyWith(responsiblePerson: person));
        updatedCount++;
      }
      if (!mounted) return;
      showAppToast('กำหนดผู้รับผิดชอบให้ $updatedCount รายการแล้ว');
      setState(() {
        _bulkAssignField = _BulkAssignField.none;
        _selectedBudgetIds.clear();
        _bulkPersonCtrl.clear();
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('กำหนดผู้รับผิดชอบไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _applyingBulkAssign = false);
    }
  }

  Widget _buildBulkAssignBar(ColorScheme colors) {
    final isDepartment = _bulkAssignField == _BulkAssignField.department;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_outlined, color: colors.onPrimaryContainer, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDepartment
                      ? (_selectedProjectKeys.isEmpty
                          ? 'เลือกโครงการที่ต้องการกำหนดฝ่าย/แผนงาน (ติ๊กที่หัวการ์ดแต่ละโครงการ)'
                          : 'เลือกแล้ว ${_selectedProjectKeys.length} โครงการ — ทุกกิจกรรมย่อยในโครงการนั้นจะได้ฝ่ายเดียวกัน')
                      : 'พิมพ์ชื่อผู้รับผิดชอบในช่องด้านล่าง แล้วติ๊กเลือกกิจกรรม/โครงการที่ต้องการกำหนด'
                          '${_selectedBudgetIds.isNotEmpty ? ' (เลือกแล้ว ${_selectedBudgetIds.length} รายการ)' : ''}',
                  style: TextStyle(color: colors.onPrimaryContainer, fontSize: 13),
                ),
              ),
              if (isDepartment) ...[
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  enabled: _selectedProjectKeys.isNotEmpty && !_applyingBulkAssign,
                  onSelected: _applyBulkAssignDepartment,
                  itemBuilder: (_) => _departmentNames
                      .map((g) => PopupMenuItem(value: g, child: Text(g)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_applyingBulkAssign)
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                        else
                          Icon(Icons.arrow_drop_down, color: colors.onPrimary),
                        const SizedBox(width: 6),
                        Text('กำหนดฝ่าย/แผนงาน', style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isDepartment) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bulkPersonCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'พิมพ์ชื่อผู้รับผิดชอบ เช่น นางสาวจริยา ยะคำป้อ',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _applyingBulkAssign ? null : _applyBulkAssignResponsiblePerson,
                  icon: _applyingBulkAssign
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                      : const Icon(Icons.check),
                  label: const Text('กำหนด'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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

      final confirmed = await showBudgetImportPreviewDialog(context, parsed, _departmentNames);
      if (confirmed != null && confirmed.isNotEmpty) {
        await _saveImportedBudgets(confirmed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      showAppToast('นำเข้าไฟล์ไม่สำเร็จ: $e', isError: true);
    }
  }

  /// ถือว่าซ้ำกันถ้าปีงบประมาณ + ชื่อโครงการ + กิจกรรม ตรงกันเป๊ะ (ตัดช่องว่างหัวท้าย)
  Budget? _findDuplicate(Budget b) {
    for (final existing in _budgets) {
      if (existing.fiscalYear.trim() == b.fiscalYear.trim() &&
          (existing.projectName ?? '').trim() == (b.projectName ?? '').trim() &&
          (existing.activityName ?? '').trim() == (b.activityName ?? '').trim()) {
        return existing;
      }
    }
    return null;
  }

  Future<void> _saveImportedBudgets(List<Budget> incoming) async {
    final duplicates = <MapEntry<Budget, Budget>>[]; // (ของใหม่, ของเดิมที่ซ้ำ)
    final freshOnes = <Budget>[];
    for (final b in incoming) {
      final existing = _findDuplicate(b);
      if (existing != null) {
        duplicates.add(MapEntry(b, existing));
      } else {
        freshOnes.add(b);
      }
    }

    var resolution = _DuplicateResolution.keepBoth;
    if (duplicates.isNotEmpty) {
      if (!mounted) return;
      final chosen = await _askDuplicateResolution(duplicates.length);
      if (chosen == null) return; // ผู้ใช้กดยกเลิก — ไม่บันทึกอะไรเลย
      resolution = chosen;
    }

    var savedCount = 0;
    for (final b in freshOnes) {
      await _repo.insertBudget(b);
      savedCount++;
    }
    for (final entry in duplicates) {
      switch (resolution) {
        case _DuplicateResolution.replace:
          await _repo.updateBudget(entry.key.copyWith(id: entry.value.id));
          savedCount++;
        case _DuplicateResolution.keepBoth:
          await _repo.insertBudget(entry.key);
          savedCount++;
        case _DuplicateResolution.skip:
          break;
      }
    }

    if (!mounted) return;
    showAppToast('นำเข้า $savedCount แผนงบประมาณแล้ว'
        '${duplicates.isNotEmpty && resolution == _DuplicateResolution.skip ? ' (ข้ามรายการซ้ำ ${duplicates.length} รายการ)' : ''}');
    _load();
  }

  Future<_DuplicateResolution?> _askDuplicateResolution(int count) {
    return showDialog<_DuplicateResolution>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('พบรายการซ้ำ'),
        content: Text(
          'พบ $count รายการที่ปีงบประมาณ/ชื่อโครงการ/กิจกรรม ตรงกับที่มีอยู่แล้วในระบบ\n'
          'ต้องการจัดการรายการที่ซ้ำอย่างไร?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('ยกเลิกทั้งหมด'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DuplicateResolution.skip),
            child: const Text('ข้ามรายการซ้ำ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, _DuplicateResolution.keepBoth),
            child: const Text('เก็บไว้ทั้งคู่'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _DuplicateResolution.replace),
            child: const Text('แทนที่ของเดิม'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // การกรอง + จัดกลุ่ม
  // ─────────────────────────────────────────

  /// ตัวเลือกฝ่าย/แผนงาน — ใช้กลุ่มงานที่จัดการไว้ในตั้งค่า (แท็บ "กลุ่มงาน") เป็นหลัก
  /// + รวมค่าเก่าที่เคยกรอกไว้แบบข้อความอิสระ (กันไม่ให้ข้อมูลเก่าหายไปจากตัวกรอง)
  List<String> get _departmentNames => _workGroups.map((g) => g.name).toList();

  List<String> get _departmentOptions {
    final legacy = _budgets
        .map((b) => b.groupName)
        .whereType<String>()
        .where((s) => s.isNotEmpty && !_departmentNames.contains(s))
        .toSet()
        .toList()
      ..sort();
    return [..._departmentNames, ...legacy];
  }

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
        if (_selectedSource != null && b.budgetSource != _selectedSource) return false;
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
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าแผนงบประมาณ',
      icon: Icons.account_balance_wallet_outlined,
      steps: const [
        'กด "เพิ่มแผนงบ" มุมขวาล่างเพื่อกรอกเอง ทีละโครงการ/กิจกรรม หรือกด "📂 Import จากไฟล์" เพื่อให้ AI อ่านจากไฟล์ PDF/Excel แล้วแยกรายการให้',
        'ตอน Import ถ้าพบรายการซ้ำกับที่มีอยู่แล้ว (ปีงบ+ชื่อโครงการ+กิจกรรมตรงกัน) ระบบจะถามว่าจะแทนที่ เก็บไว้ทั้งคู่ หรือข้ามรายการนั้น',
        'ใช้ปุ่ม "กำหนดฝ่ายหลายโครงการ" หรือ "กำหนดผู้รับผิดชอบหลายโครงการ" เมื่อต้องการตั้งค่าเดียวกันให้หลายโครงการ/กิจกรรมพร้อมกัน แทนการไล่แก้ทีละรายการ',
        'สลับมุมมอง "การ์ด"/"ตาราง" ได้ตามที่ถนัด ใช้ช่องค้นหา/ตัวกรองด้านบนเพื่อหาโครงการที่ต้องการเจอเร็วขึ้น',
        'ตัวเลข "คงเหลือ" จะเท่ากับ "วงเงินที่ได้รับจัดสรร" เสมอ เพราะระบบยังไม่มีฟีเจอร์หักลดอัตโนมัติตามการใช้จ่ายจริง',
      ],
      child: Stack(
        children: [
          Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterBar(colors),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildViewToggle(colors),
                      if (_viewMode == _BudgetViewMode.table)
                        ColumnVisibilityMenu(
                          allColumns: _budgetTableOptionalColumns,
                          visibleColumns: _visibleColumns,
                          onChanged: (v) => setState(() => _visibleColumns = v),
                        ),
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
                      OutlinedButton.icon(
                        onPressed: _budgets.isEmpty
                            ? null
                            : () => _toggleBulkAssignMode(_BulkAssignField.department),
                        icon: Icon(_bulkAssignField == _BulkAssignField.department
                            ? Icons.close
                            : Icons.edit_note_outlined),
                        label: Text(_bulkAssignField == _BulkAssignField.department
                            ? 'ยกเลิกเลือก'
                            : 'กำหนดฝ่ายหลายโครงการ'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _budgets.isEmpty
                            ? null
                            : () => _toggleBulkAssignMode(_BulkAssignField.responsiblePerson),
                        icon: Icon(_bulkAssignField == _BulkAssignField.responsiblePerson
                            ? Icons.close
                            : Icons.person_search_outlined),
                        label: Text(_bulkAssignField == _BulkAssignField.responsiblePerson
                            ? 'ยกเลิกเลือก'
                            : 'กำหนดผู้รับผิดชอบหลายโครงการ'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _budgets.isEmpty ? null : _confirmDeleteAll,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('ลบแผนงบทั้งหมด'),
                      ),
                    ],
                  ),
                  if (_bulkAssignField != _BulkAssignField.none) ...[
                    const SizedBox(height: 12),
                    _buildBulkAssignBar(colors),
                  ],
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
      ),
    );
  }

  // ─────────────────────────────────────────
  // แถบค้นหา + ตัวกรอง + สลับมุมมอง
  // ─────────────────────────────────────────

  Widget _buildFilterBar(ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          flex: 2,
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
          flex: 4,
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
          flex: 3,
          child: _buildDropdown(
            colors: colors,
            hint: 'โครงการ (ทั้งหมด)',
            value: _selectedProject,
            options: _projectOptions,
            onChanged: (v) => setState(() => _selectedProject = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _buildDropdown(
            colors: colors,
            hint: 'แหล่งงบ (ทั้งหมด)',
            value: _selectedSource,
            options: budgetSources,
            onChanged: (v) => setState(() => _selectedSource = v),
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
                  if (_bulkAssignField == _BulkAssignField.department)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(
                        value: _selectedProjectKeys.contains(group.key),
                        onChanged: (_) => _toggleProjectSelection(group.key),
                      ),
                    ),
                  if (_bulkAssignField == _BulkAssignField.responsiblePerson)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: 'เลือกทั้งโครงการ (ทุกกิจกรรมย่อย)',
                        child: Checkbox(
                          value: rows.map((b) => b.id).whereType<int>().every(_selectedBudgetIds.contains),
                          onChanged: (_) => _toggleProjectAllBudgets(rows),
                        ),
                      ),
                    ),
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
                          if (rows.first.budgetSource == budgetSourceDistrict) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('งบเขต (นอกแผน)',
                                style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                          if (rows.length > 1) ...[
                            const SizedBox(width: 6),
                            Text('· ${rows.length} รายการย่อย',
                              style: TextStyle(fontSize: 11.5, color: colors.onPrimaryContainer.withValues(alpha: 0.7))),
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
                      Text('คงเหลือรวม', style: TextStyle(fontSize: 10.5, color: colors.onPrimaryContainer.withValues(alpha: 0.8))),
                      Text('${formatBaht(totalRemaining)} บาท',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onPrimaryContainer)),
                      Text('จาก ${formatBaht(totalAllocated)} บาท',
                        style: TextStyle(fontSize: 10.5, color: colors.onPrimaryContainer.withValues(alpha: 0.8))),
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
            if (_bulkAssignField == _BulkAssignField.responsiblePerson && b.id != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Checkbox(
                  value: _selectedBudgetIds.contains(b.id),
                  onChanged: (_) => _toggleBudgetSelection(b.id!),
                ),
              ),
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
                  if (b.responsiblePerson != null && b.responsiblePerson!.isNotEmpty)
                    Text('ผู้รับผิดชอบ: ${b.responsiblePerson}',
                      style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            Text('${formatBaht(remaining)} บาท',
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
        constraints: const BoxConstraints(minWidth: 1010),
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
                  if (_visibleColumns.contains('เลข e-GP'))
                    SizedBox(width: 100, child: Text('เลข e-GP', style: headerStyle)),
                  if (_visibleColumns.contains('ผู้รับผิดชอบ'))
                    SizedBox(width: 110, child: Text('ผู้รับผิดชอบ', style: headerStyle)),
                  if (_visibleColumns.contains('วงเงิน'))
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
              child: Row(
                children: [
                  Flexible(
                    child: Text(group.key,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (rows.first.budgetSource == budgetSourceDistrict) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                      child: const Text('งบเขต', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            if (_visibleColumns.contains('เลข e-GP')) const SizedBox(width: 100),
            if (_visibleColumns.contains('ผู้รับผิดชอบ')) const SizedBox(width: 110),
            if (_visibleColumns.contains('วงเงิน')) const SizedBox(width: 110),
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
                if (_visibleColumns.contains('เลข e-GP'))
                  SizedBox(width: 100, child: Text(b.egpNumber ?? '-', style: const TextStyle(fontSize: 12.5))),
                if (_visibleColumns.contains('ผู้รับผิดชอบ'))
                  SizedBox(width: 110, child: Text(b.responsiblePerson ?? '-',
                    style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (_visibleColumns.contains('วงเงิน'))
                  SizedBox(width: 110, child: Text(formatBaht(allocated), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                SizedBox(
                  width: 110,
                  child: Text(formatBaht(remaining),
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
  String? _groupName;
  late final TextEditingController _projectName;
  late final TextEditingController _activityName;
  late final TextEditingController _egpNumber;
  late final TextEditingController _allocatedAmount;
  late final TextEditingController _responsiblePerson;
  late String _budgetSource;
  bool _saving = false;
  List<WorkGroup> _workGroups = [];

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _fiscalYear = TextEditingController(text: b?.fiscalYear ?? '');
    _groupName = (b?.groupName != null && b!.groupName!.isNotEmpty) ? b.groupName : null;
    _projectName = TextEditingController(text: b?.projectName ?? '');
    _activityName = TextEditingController(text: b?.activityName ?? '');
    _egpNumber = TextEditingController(text: b?.egpNumber ?? '');
    _allocatedAmount = TextEditingController(text: b?.allocatedAmount?.toStringAsFixed(2) ?? '');
    _responsiblePerson = TextEditingController(text: b?.responsiblePerson ?? '');
    _budgetSource = b?.budgetSource ?? budgetSourceSchool;
    _loadWorkGroups();
  }

  Future<void> _loadWorkGroups() async {
    final groups = await _repo.getAllWorkGroups(activeOnly: true);
    if (!mounted) return;
    setState(() => _workGroups = groups);
  }

  @override
  void dispose() {
    for (final c in [_fiscalYear, _projectName, _activityName, _egpNumber, _allocatedAmount, _responsiblePerson]) {
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
      groupName: _groupName,
      projectName: _projectName.text.trim().isEmpty ? null : _projectName.text.trim(),
      activityName: _activityName.text.trim().isEmpty ? null : _activityName.text.trim(),
      egpNumber: _egpNumber.text.trim().isEmpty ? null : _egpNumber.text.trim(),
      allocatedAmount: allocated,
      // เดิมตอนแก้ไขจะคงค่า remainingAmount เก่าไว้เสมอ ไม่ว่าจะแก้วงเงินที่ได้รับ
      // จัดสรรเป็นเท่าไหร่ก็ตาม ทำให้ "คงเหลือรวม" ในตารางไม่ตรงกับยอดที่เพิ่งแก้ —
      // ทั้งระบบไม่มีจุดไหนหักลด remainingAmount ตามการใช้จ่ายจริงเลย (ไม่มีฟีเจอร์
      // ผูกงบกับออร์เดอร์แล้วหักอัตโนมัติ) จึงให้ remainingAmount = allocatedAmount
      // เสมอทุกครั้งที่บันทึก กันไม่ให้สองค่านี้เพี้ยนไปจากกัน
      remainingAmount: allocated,
      responsiblePerson: _responsiblePerson.text.trim().isEmpty ? null : _responsiblePerson.text.trim(),
      budgetSource: _budgetSource,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _groupName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'ฝ่าย/แผนงาน', border: OutlineInputBorder(), isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ..._workGroups.map((g) => g.name).followedBy(
                        (_groupName != null && !_workGroups.any((g) => g.name == _groupName)) ? [_groupName!] : const [],
                      ).map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _groupName = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _budgetSource,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'แหล่งงบประมาณ', border: OutlineInputBorder(), isDense: true,
                    ),
                    items: budgetSources
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _budgetSource = v ?? budgetSourceSchool),
                  ),
                ),
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
