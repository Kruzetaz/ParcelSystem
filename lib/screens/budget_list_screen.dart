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
import '../models/procurement_order.dart';
import '../models/work_group.dart';
import '../services/budget_export_service.dart';
import '../services/budget_import_service.dart';
import '../services/fiscal_year_controller.dart';
import '../services/toast_service.dart';
import '../widgets/budget_import_dialog.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/column_visibility_menu.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/data_table_shell.dart' show DsCheckbox, DsActionIconButtons, DsRowAction;
import '../widgets/design_system/kpi_card.dart';

/// คอลัมน์ที่ซ่อน/แสดงได้ในมุมมองตาราง — "ฝ่าย/ปีงบ/โครงการ/คงเหลือ" แสดงเสมอ
const _budgetTableOptionalColumns = ['เลข e-GP', 'ผู้รับผิดชอบ', 'วงเงิน'];

/// ค่าพิเศษในตัวกรอง "ฝ่าย/แผนงาน" สำหรับกรองเฉพาะแผนงบที่ยังไม่ได้เลือกฝ่ายไว้
/// (groupName ว่าง) — ไม่ใช่ชื่อฝ่ายจริง แค่ใช้เป็น sentinel ในตัวกรองเท่านั้น
const budgetUnassignedDepartmentFilter = '(ไม่ระบุฝ่าย/แผนงาน)';

enum _BudgetViewMode { card, table }

/// วิธีจัดการรายการที่ซ้ำกันตอน import จากไฟล์
enum _DuplicateResolution { replace, keepBoth, skip }

/// โหมด "กำหนดค่าหลายโครงการพร้อมกัน" — เลือกได้ว่าจะกำหนดฝ่าย/แผนงาน
/// หรือผู้รับผิดชอบ (none = ปิดโหมดนี้อยู่)
enum _BulkAssignField { none, department, responsiblePerson }

class BudgetListScreen extends StatefulWidget {
  // แจ้ง AppShell ว่า AI กำลังนำเข้าไฟล์แผนงบประมาณอยู่หรือไม่ — กันผู้ใช้
  // สลับหน้าออกไประหว่างรอ (สลับหน้า = ทำลาย state หน้านี้ทิ้ง ผลลัพธ์ที่ AI
  // กำลังจะได้จะหายไปเงียบๆ)
  final ValueChanged<bool>? onAiBusyChanged;

  const BudgetListScreen({super.key, this.onAiBusyChanged});
  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  // สไตล์กล่องยืนยัน (ลบ/ลบทั้งหมด/รายการซ้ำ) ใช้ร่วมกันทุกจุด — ธีมกลางของ
  // แอปตั้ง titleLarge/bodyMedium/labelLarge ไว้เล็ก (13.5/12.5/11px) เพราะ
  // ออกแบบมาให้ตารางข้อมูลหนาแน่นในหน้าหลักอ่านง่าย ไม่ได้ตั้งใจให้กล่องโต้ตอบ/
  // ปุ่มยืนยันที่คนต้องอ่านตัดสินใจจริงจังใช้ขนาดเดียวกัน จึงกำหนดสไตล์เอง
  // ตรงนี้แทนพึ่งพา default ของธีม
  static const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
  static const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
  static const _dialogButtonTextStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
  static const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  final _repo = ProcurementRepository();
  List<Budget> _budgets = [];
  List<WorkGroup> _workGroups = [];
  // โหลดมาคู่กับแผนงบ เพื่อคำนวณ "คงเหลือจริง" สดๆ จากยอดที่ใช้ไปแล้วจริง
  // (ดูหัวข้อ _usedByBudgetId ด้านล่าง) — ไม่ได้พึ่งพา Budget.remainingAmount
  // ในฐานข้อมูลอีกต่อไป เพราะคอลัมน์นั้นไม่เคยถูกหักลดตามการใช้จ่ายจริงเลย
  List<ProcurementOrder> _orders = [];
  bool _loading = true;
  bool _importing = false;
  bool _exporting = false;

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
    // สลับปีงบที่ AppBar ต้องทำให้หน้านี้โหลดใหม่ตามปีที่เลือกด้วยเช่นกัน
    FiscalYearController.instance.addListener(_onFiscalYearChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bulkPersonCtrl.dispose();
    FiscalYearController.instance.removeListener(_onFiscalYearChanged);
    super.dispose();
  }

  void _onFiscalYearChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final fiscalYear = FiscalYearController.instance.viewingYear;
    final list = await _repo.getAllBudgets(fiscalYear: fiscalYear);
    final groups = await _repo.getAllWorkGroups(activeOnly: true);
    final orders = await _repo.getAllOrders(fiscalYear: fiscalYear);
    if (!mounted) return;
    setState(() {
      _budgets = list;
      _workGroups = groups;
      _orders = orders;
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
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text(
          'ต้องการลบแผนงบ "${budget.projectName ?? "(ไม่มีชื่อโครงการ)"}" ใช่หรือไม่?',
          style: _dialogContentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: _dialogButtonPadding,
              textStyle: _dialogButtonTextStyle,
            ),
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

  /// คัดลอกแผนงบเป็นรายการใหม่ทั้งใบ — คัดลอกทุกช่องมาตรงๆ ไม่ล้างอะไรเลย
  /// เติมแค่ "(สำเนา)" ต่อชื่อโครงการ ให้ผู้ใช้แก้ไขเองว่าช่องไหนต้องเปลี่ยน
  /// (ไม่พาเข้าฟอร์มแก้ไขอัตโนมัติ — กดแก้เองตอนพร้อม)
  Future<void> _duplicateBudget(Budget budget) async {
    try {
      final map = budget.toMap();
      map.remove('id');
      map['project_name'] =
          '${(budget.projectName?.trim().isNotEmpty ?? false) ? budget.projectName! : "(ไม่มีชื่อโครงการ)"} (สำเนา)';
      await _repo.insertBudget(Budget.fromMap(map));
      if (!mounted) return;
      showAppToast('คัดลอกแผนงบแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกแผนงบไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบทั้งหมด', style: _dialogTitleStyle),
        content: Text(
          'ต้องการลบแผนงบประมาณทั้งหมด ${_budgets.length} รายการใช่หรือไม่?\nการลบนี้ไม่สามารถย้อนกลับได้',
          style: _dialogContentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: _dialogButtonPadding,
              textStyle: _dialogButtonTextStyle,
            ),
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

  Widget _buildBulkAssignBar(BuildContext context, ColorScheme colors) {
    final isDepartment = _bulkAssignField == _BulkAssignField.department;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BrandAccent.teal(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: BrandAccent.teal(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_outlined, color: BrandAccent.tealOn(context), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDepartment
                      ? (_selectedProjectKeys.isEmpty
                          ? 'เลือกโครงการที่ต้องการกำหนดฝ่าย/แผนงาน (ติ๊กที่หัวการ์ดแต่ละโครงการ)'
                          : 'เลือกแล้ว ${_selectedProjectKeys.length} โครงการ — ทุกกิจกรรมย่อยในโครงการนั้นจะได้ฝ่ายเดียวกัน')
                      : 'พิมพ์ชื่อผู้รับผิดชอบในช่องด้านล่าง แล้วติ๊กเลือกกิจกรรม/โครงการที่ต้องการกำหนด'
                          '${_selectedBudgetIds.isNotEmpty ? ' (เลือกแล้ว ${_selectedBudgetIds.length} รายการ)' : ''}',
                  style: TextStyle(
                    color: BrandAccent.tealOn(context),
                    fontSize: AppTypography.bodyMedium,
                    fontWeight: AppTypography.weightSemiBold,
                  ),
                ),
              ),
              if (isDepartment) ...[
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  enabled: _selectedProjectKeys.isNotEmpty && !_applyingBulkAssign,
                  onSelected: _applyBulkAssignDepartment,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    side: BorderSide(color: colors.outline),
                  ),
                  elevation: 6,
                  itemBuilder: (_) => _departmentNames
                      .map((g) => PopupMenuItem(
                            value: g,
                            child: Text(g, style: const TextStyle(fontSize: AppTypography.bodyMedium)),
                          ))
                      .toList(),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(RadiusSize.md)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_applyingBulkAssign)
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                        else
                          Icon(Icons.arrow_drop_down, color: colors.onPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'กำหนดฝ่าย/แผนงาน',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: AppTypography.bodyMedium,
                            fontWeight: AppTypography.weightBold,
                          ),
                        ),
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
                    style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'พิมพ์ชื่อผู้รับผิดชอบ เช่น นางสาวจริยา ยะคำป้อ',
                      hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _actionButton(
                  colors: colors,
                  onPressed: _applyingBulkAssign ? null : _applyBulkAssignResponsiblePerson,
                  icon: Icons.check,
                  loading: _applyingBulkAssign,
                  active: true,
                  label: 'กำหนด',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// ส่งออกเฉพาะแผนงบที่กรอง/ค้นหาอยู่ตอนนี้เป็นไฟล์ Excel (ตรงกับที่เห็นบนจอ
  /// จริงๆ ไม่ใช่ทั้งหมดในระบบเสมอ) แล้วเปิดไฟล์ให้อัตโนมัติ — ยอด "คงเหลือ"
  /// ในไฟล์ใช้ตัวเลขที่คำนวณสดจากออร์เดอร์ที่เสร็จสมบูรณ์แล้วเหมือนกับที่แสดงบนจอ
  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      final remainingById = <int, double>{
        for (final b in _filteredBudgets)
          if (b.id != null) b.id!: _actualRemaining(b),
      };
      await BudgetExportService.exportAndOpen(_filteredBudgets, remainingById);
      if (!mounted) return;
      showAppToast('ส่งออกไฟล์ Excel แล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('ส่งออกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
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
    widget.onAiBusyChanged?.call(true);
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
    } finally {
      widget.onAiBusyChanged?.call(false);
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
        title: const Text('พบรายการซ้ำ', style: _dialogTitleStyle),
        content: Text(
          'พบ $count รายการที่ปีงบประมาณ/ชื่อโครงการ/กิจกรรม ตรงกับที่มีอยู่แล้วในระบบ\n'
          'ต้องการจัดการรายการที่ซ้ำอย่างไร?',
          style: _dialogContentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิกทั้งหมด'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DuplicateResolution.skip),
            style: TextButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('ข้ามรายการซ้ำ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, _DuplicateResolution.keepBoth),
            style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
            child: const Text('เก็บไว้ทั้งคู่'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _DuplicateResolution.replace),
            style: FilledButton.styleFrom(padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
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

  bool get _hasUnassignedDepartmentBudgets =>
      _budgets.any((b) => !(b.groupName?.trim().isNotEmpty ?? false));

  List<String> get _departmentOptions {
    final legacy = _budgets
        .map((b) => b.groupName)
        .whereType<String>()
        .where((s) => s.isNotEmpty && !_departmentNames.contains(s))
        .toSet()
        .toList()
      ..sort();
    return [
      ..._departmentNames,
      ...legacy,
      if (_hasUnassignedDepartmentBudgets) budgetUnassignedDepartmentFilter,
    ];
  }

  bool _matchesDepartmentFilter(Budget b) {
    if (_selectedDepartment == null) return true;
    if (_selectedDepartment == budgetUnassignedDepartmentFilter) {
      return !(b.groupName?.trim().isNotEmpty ?? false);
    }
    return b.groupName == _selectedDepartment;
  }

  List<String> get _projectOptions => _budgets
      .where(_matchesDepartmentFilter)
      .map((b) => b.projectName)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<Budget> get _filteredBudgets => _budgets.where((b) {
        if (!_matchesDepartmentFilter(b)) return false;
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

  // ─────────────────────────────────────────
  // สรุปยอดรวม — ใช้กับแถบ KPI ด้านบน (คิดจากรายการที่ผ่านตัวกรองปัจจุบัน
  // เดียวกับที่แสดงในลิสต์ ไม่ใช่ทั้งหมดในระบบ ให้ตัวเลขสอดคล้องกับสิ่งที่เห็น)
  // ─────────────────────────────────────────

  double get _filteredTotalAllocated =>
      _filteredBudgets.fold<double>(0, (s, b) => s + (b.allocatedAmount ?? 0));

  double get _filteredTotalRemaining =>
      _filteredBudgets.fold<double>(0, (s, b) => s + _actualRemaining(b));

  int get _filteredProjectCount => _groupedByProject.length;

  int get _filteredUnassignedDepartmentCount =>
      _filteredBudgets.where((b) => !(b.groupName?.trim().isNotEmpty ?? false)).length;

  // ─────────────────────────────────────────
  // ผูกงบกับออร์เดอร์จริง — หักลด "คงเหลือ" อัตโนมัติจากยอดใช้จ่ายจริง (สดทุก
  // ครั้งที่โหลดข้อมูล ไม่ใช่ค่าที่บันทึกไว้ในคอลัมน์ remaining_amount ซึ่งไม่
  // เคยถูกหักลดเลย) — ใช้ตรรกะเดียวกับกราฟ "งบประมาณตามฝ่าย/กลุ่มงาน" ใน
  // หน้าหลัก (_getUsedByDepartment ใน dashboard_screen_v2.dart) แค่ทำในระดับ
  // รายแผนงบแต่ละใบแทนที่จะรวมทั้งฝ่าย — นับเฉพาะออร์เดอร์ที่ "เสร็จสมบูรณ์"
  // แล้วเท่านั้น (ออร์เดอร์ที่ยังร่าง/กำลังดำเนินการยังไม่ถือว่าใช้งบจริง)
  // ─────────────────────────────────────────

  Map<int, double> get _usedByBudgetId {
    final totals = <int, double>{};
    for (final o in _orders) {
      if (o.currentStatus != 'COMPLETED') continue;
      final budgetId = o.budgetId;
      if (budgetId == null) continue;
      totals[budgetId] = (totals[budgetId] ?? 0) + (o.currentOrderPrice ?? 0);
    }
    return totals;
  }

  double _actualUsed(Budget b) => b.id != null ? (_usedByBudgetId[b.id] ?? 0) : 0;

  /// คงเหลือจริง = วงเงินที่ได้รับจัดสรร − ยอดที่ออร์เดอร์เสร็จสมบูรณ์ใช้ไปแล้ว
  /// ติดลบได้ (แปลว่าใช้เกินงบที่ตั้งไว้จริง) — ไม่ clamp ทิ้ง เพราะเป็นสัญญาณ
  /// สำคัญที่อยากให้เห็นชัดว่าโครงการนี้ใช้เกินงบ ไม่ใช่ซ่อนไว้ให้ดูเหมือนพอดี
  double _actualRemaining(Budget b) => (b.allocatedAmount ?? 0) - _actualUsed(b);

  /// สีเตือนของยอด "คงเหลือ" ตามสัดส่วนที่เหลือเทียบกับวงเงินที่ได้รับจัดสรร —
  /// เดิมคำนวณซ้ำกันเป๊ะๆ ทั้งในมุมมองการ์ดและมุมมองตาราง (คนละจุดในไฟล์)
  /// รวมไว้ที่เดียวกันจุดเดียว กันแก้เกณฑ์แล้วลืมแก้อีกจุดให้ตรงกัน
  Color _remainColor(BuildContext context, double allocated, double remaining) {
    final ratio = allocated > 0 ? (remaining / allocated).clamp(0.0, 1.0) : 1.0;
    if (ratio > 0.5) return BrandAccent.green(context);
    if (ratio > 0.2) return BrandAccent.tertiary(context);
    return BrandAccent.red(context);
  }

  /// แบนเนอร์เตือนสั้นๆ ตอนกำลังดูปีงบเก่าอยู่ — ใช้ตัวย่อกว่า Dashboard เพราะ
  /// หน้านี้เข้าถึงได้ตรงจาก sidebar ไม่ได้ผ่าน Dashboard เสมอไป กันสับสน
  Widget _buildOldYearNotice(ColorScheme colors) {
    final fy = FiscalYearController.instance;
    // เดิม hardcode Colors.amber.shade50/300/800/900 ตรงๆ ถูกแค่โหมดสว่าง พอเป็น
    // โหมดมืดจะกลายเป็นกล่องสีขาวสว่างแปลกแยกจากพื้นหลังมืดทั้งหน้า (บั๊กแบบ
    // เดียวกับที่เจอใน kpi_card.dart/topbar amber pill) — ใช้ alphaBlend เคลือบ
    // ทับ surface ของธีมปัจจุบันแทน
    final amberBg = Color.alphaBlend(BrandColors.amber.withValues(alpha: 0.12), colors.surface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: amberBg,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: BrandColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            fy.isViewingFutureYear ? Icons.event_note_outlined : Icons.history_outlined,
            size: 18,
            color: BrandAccent.tertiary(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fy.isViewingFutureYear
                  ? 'กำลังวางแผนงบปีงบ ${fy.viewingYear} ล่วงหน้า (ยังไม่ถึงปีนี้จริง) — สลับกลับปีปัจจุบันได้ที่ป้ายปีงบมุมขวาบน'
                  : 'กำลังดูแผนงบปีงบ ${fy.viewingYear} (ปีเก่า) — สลับกลับปีปัจจุบันได้ที่ป้ายปีงบมุมขวาบน',
              style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าแผนงบประมาณ',
      icon: Icons.account_balance_wallet_outlined,
      // แถบตัวกรองด้านบนกว้างเต็มจอ ช่องดรอปดาวน์ "แหล่งงบ" ท้ายแถวไปชนมุม
      // ขวาบนพอดี (ค่า default) ย้ายปุ่มไกด์ไปมุมซ้ายล่างแทน — มุมขวาล่างมีปุ่ม
      // "เพิ่มแผนงบ" อยู่แล้ว
      corner: Alignment.bottomLeft,
      steps: const [
        'กด "เพิ่มแผนงบ" มุมขวาล่างเพื่อกรอกเอง ทีละโครงการ/กิจกรรม หรือกด "📂 Import จากไฟล์" เพื่อให้ AI อ่านจากไฟล์ PDF/Excel แล้วแยกรายการให้',
        'ตอน Import ถ้าพบรายการซ้ำกับที่มีอยู่แล้ว (ปีงบ+ชื่อโครงการ+กิจกรรมตรงกัน) ระบบจะถามว่าจะแทนที่ เก็บไว้ทั้งคู่ หรือข้ามรายการนั้น',
        'ใช้ปุ่ม "กำหนดฝ่ายหลายโครงการ" หรือ "กำหนดผู้รับผิดชอบหลายโครงการ" เมื่อต้องการตั้งค่าเดียวกันให้หลายโครงการ/กิจกรรมพร้อมกัน แทนการไล่แก้ทีละรายการ',
        'สลับมุมมอง "การ์ด"/"ตาราง" ได้ตามที่ถนัด ใช้ช่องค้นหา/ตัวกรองด้านบนเพื่อหาโครงการที่ต้องการเจอเร็วขึ้น',
        'ตัวเลข "คงเหลือ" คำนวณสดจากยอดออร์เดอร์ที่ "เสร็จสมบูรณ์" แล้วที่ผูกกับแผนงบนั้นๆ หักลบจากวงเงินที่ได้รับจัดสรรอัตโนมัติ — ออร์เดอร์ที่ยังร่าง/กำลังดำเนินการยังไม่นับว่าใช้งบ ถ้าติดลบแปลว่าใช้เกินงบที่ตั้งไว้จริง',
        'กดปุ่ม "ส่งออก Excel" ในแถบเครื่องมือเพื่อบันทึกแผนงบที่เห็นอยู่ตอนนี้ (ตามตัวกรอง/ค้นหาที่เลือกไว้) เป็นไฟล์ .xlsx',
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
                  if (!FiscalYearController.instance.isViewingCurrentYear) ...[
                    _buildOldYearNotice(colors),
                    const SizedBox(height: 12),
                  ],
                  if (!_loading && _budgets.isNotEmpty) ...[
                    _buildKpiSummary(colors),
                    const SizedBox(height: 16),
                  ],
                  _buildFilterBar(colors),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildViewToggle(colors),
                            _actionButton(
                              colors: colors,
                              onPressed: _importing ? null : _importFromFile,
                              icon: Icons.folder_open_outlined,
                              loading: _importing,
                              label: _importing ? 'กำลังนำเข้า...' : 'Import จากไฟล์',
                            ),
                            _actionButton(
                              colors: colors,
                              onPressed: _filteredBudgets.isEmpty || _exporting ? null : _exportToExcel,
                              icon: Icons.file_download_outlined,
                              loading: _exporting,
                              label: _exporting ? 'กำลังส่งออก...' : 'ส่งออก Excel',
                            ),
                          ],
                        ),
                      ),
                      // ปุ่ม "จัดการเพิ่มเติม" (กำหนดฝ่าย/กำหนดผู้รับผิดชอบ/ลบทั้งหมด) แยก
                      // ไปอยู่ขวาสุดต่างหาก ไม่ปนกับกลุ่มปุ่มการกระทำหลักฝั่งซ้าย — ตอนอยู่
                      // ในโหมดเลือกอยู่แล้ว โชว์ปุ่ม "ยกเลิกเลือก" แทนที่ตำแหน่งเดียวกัน
                      const SizedBox(width: 12),
                      if (_bulkAssignField != _BulkAssignField.none)
                        _actionButton(
                          colors: colors,
                          onPressed: () => _toggleBulkAssignMode(_bulkAssignField),
                          icon: Icons.close,
                          active: true,
                          label: 'ยกเลิกเลือก',
                        )
                      else
                        _buildMoreActionsMenu(colors),
                      // ปุ่มเลือกคอลัมน์ — ย้ายมาติดขวาสุดของแถบเครื่องมือ (เดิมลอย
                      // แทรกอยู่กลางแถวปนกับปุ่มอื่น ไม่มีกรอบ ดูหลุดจากกลุ่ม) มีเส้น
                      // บางๆ กั้นแยกไว้ให้เห็นชัดว่าเป็นคนละหมวด (ควบคุมการแสดงผล
                      // ตาราง ไม่ใช่การกระทำกับข้อมูลเหมือนปุ่มฝั่งซ้าย) และแสดงเฉพาะ
                      // ตอนอยู่มุมมองตารางเท่านั้น (โหมดการ์ดไม่มีคอลัมน์ให้เลือก)
                      if (_viewMode == _BudgetViewMode.table) ...[
                        const SizedBox(width: 12),
                        Container(width: 1, height: 28, color: colors.outlineVariant),
                        const SizedBox(width: 12),
                        ColumnVisibilityMenu(
                          allColumns: _budgetTableOptionalColumns,
                          visibleColumns: _visibleColumns,
                          onChanged: (v) => setState(() => _visibleColumns = v),
                        ),
                      ],
                    ],
                  ),
                  if (_bulkAssignField != _BulkAssignField.none) ...[
                    const SizedBox(height: 12),
                    _buildBulkAssignBar(context, colors),
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
            heroTag: 'budget_add_fab',
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
  // แถบสรุปยอด KPI — ใช้ component เดียวกับหน้าหลัก ให้หน้านี้รู้สึกเป็น
  // ชุดเดียวกับหน้าหลัก (ก่อนหน้านี้หน้านี้มีแค่รายการโครงการล้วนๆ ไม่มีสรุป
  // ภาพรวมให้เห็นเลยว่าทั้งปีงบใช้ไปเท่าไหร่แล้วในภาพรวม)
  // ─────────────────────────────────────────

  Widget _buildKpiSummary(ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'โครงการทั้งหมด',
            value: '$_filteredProjectCount',
            unit: 'โครงการ',
            icon: Icons.folder_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'วงเงินที่ได้รับจัดสรรรวม',
            value: formatBaht(_filteredTotalAllocated),
            unit: 'บาท',
            icon: Icons.account_balance_wallet_outlined,
            variant: KpiCardVariant.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'คงเหลือรวม',
            value: formatBaht(_filteredTotalRemaining),
            unit: 'บาท',
            icon: Icons.savings_outlined,
            variant: KpiCardVariant.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'ยังไม่ระบุฝ่าย/แผนงาน',
            value: '$_filteredUnassignedDepartmentCount',
            unit: 'รายการ',
            icon: Icons.warning_amber_outlined,
            variant: KpiCardVariant.amber,
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
          flex: 2,
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'ค้นหาชื่อโครงการ/กิจกรรม',
              hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RadiusSize.md),
                borderSide: BorderSide(color: colors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RadiusSize.md),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RadiusSize.md),
                borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
              ),
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
      borderRadius: BorderRadius.circular(RadiusSize.card),
      elevation: 6,
      style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
        ),
      ),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(hint, overflow: TextOverflow.ellipsis)),
        ...options.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildViewToggle(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BrandAccent.surface2(context),
        borderRadius: BorderRadius.circular(RadiusSize.md),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleSegment(colors, _BudgetViewMode.card, Icons.view_agenda_outlined, 'การ์ด'),
          const SizedBox(width: 2),
          _viewToggleSegment(colors, _BudgetViewMode.table, Icons.table_chart_outlined, 'ตาราง'),
        ],
      ),
    );
  }

  Widget _viewToggleSegment(ColorScheme colors, _BudgetViewMode mode, IconData icon, String label) {
    final active = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(RadiusSize.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(RadiusSize.sm),
          boxShadow: active ? AppShadows.light1 : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? BrandAccent.tealOn(context) : colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.bodySmall,
                fontWeight: AppTypography.weightBold,
                color: active ? BrandAccent.tealOn(context) : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มแถวเครื่องมือด้านบน (Import/กำหนดฝ่ายหลายโครงการ/ลบทั้งหมด ฯลฯ) — เดิม
  /// ใช้ OutlinedButton.icon ปกติของ Material ทั้งหมด ฟอนต์/สี/ขอบเป็น default
  /// ธีมกลาง ไม่ตรงกับชุดปุ่มที่ปรับแต่งไว้แล้วในหน้าหลัก รวมเป็น helper เดียว
  /// ให้ทุกปุ่มในแถวนี้มีขนาด/ฟอนต์/สถานะ active/danger ตรงกันหมด
  Widget _actionButton({
    required ColorScheme colors,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool active = false,
    bool danger = false,
    bool loading = false,
  }) {
    final disabled = onPressed == null;
    final Color bg;
    final Color border;
    final Color fg;
    if (active) {
      bg = BrandAccent.teal(context);
      border = BrandAccent.teal(context);
      fg = Colors.white;
    } else if (danger) {
      bg = BrandAccent.red(context).withValues(alpha: 0.08);
      border = BrandAccent.red(context).withValues(alpha: 0.3);
      fg = BrandAccent.red(context);
    } else {
      bg = colors.surface;
      border = colors.outline;
      fg = colors.onSurface;
    }
    final effectiveFg = disabled ? fg.withValues(alpha: 0.4) : fg;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(RadiusSize.md),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: disabled ? bg.withValues(alpha: active || danger ? 0.4 : 1) : bg,
            borderRadius: BorderRadius.circular(RadiusSize.md),
            border: Border.all(color: disabled ? border.withValues(alpha: 0.4) : border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: effectiveFg))
              else
                Icon(icon, size: 15, color: effectiveFg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightBold, color: effectiveFg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// รวมปุ่ม "กำหนดฝ่ายหลายโครงการ" / "กำหนดผู้รับผิดชอบหลายโครงการ" / "ลบแผนงบ
  /// ทั้งหมด" ไว้ในเมนูเดียว (ดู comment จุดที่เรียกใช้) — หน้าตากล่องเหมือน
  /// _actionButton เป๊ะ แต่ไม่มี InkWell ของตัวเอง (ให้ PopupMenuButton จัดการ
  /// splash/hit-test เองแทน กัน ripple ซ้อนกันสองชั้น)
  Widget _buildMoreActionsMenu(ColorScheme colors) {
    final disabled = _budgets.isEmpty;
    final fg = disabled ? colors.onSurface.withValues(alpha: 0.4) : colors.onSurface;
    return PopupMenuButton<String>(
      enabled: !disabled,
      tooltip: 'จัดการเพิ่มเติม',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md), side: BorderSide(color: colors.outline)),
      onSelected: (v) {
        switch (v) {
          case 'department':
            _toggleBulkAssignMode(_BulkAssignField.department);
            break;
          case 'responsible':
            _toggleBulkAssignMode(_BulkAssignField.responsiblePerson);
            break;
          case 'deleteAll':
            _confirmDeleteAll();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'department', child: Text('กำหนดฝ่ายหลายโครงการ')),
        const PopupMenuItem(value: 'responsible', child: Text('กำหนดผู้รับผิดชอบหลายโครงการ')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'deleteAll', child: Text('ลบแผนงบทั้งหมด', style: TextStyle(color: BrandAccent.red(context)))),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RadiusSize.md),
          border: Border.all(color: disabled ? colors.outline.withValues(alpha: 0.4) : colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 15, color: fg),
            const SizedBox(width: 6),
            Text('จัดการเพิ่มเติม', style: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.weightBold, color: fg)),
          ],
        ),
      ),
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
      itemBuilder: (context, i) => _buildProjectGroup(context, colors, groups[i]),
    );
  }

  Widget _buildProjectGroup(BuildContext context, ColorScheme colors, MapEntry<String, List<Budget>> group) {
    final rows = group.value;
    final totalAllocated = rows.fold<double>(0, (s, b) => s + (b.allocatedAmount ?? 0));
    final totalRemaining = rows.fold<double>(0, (s, b) => s + _actualRemaining(b));
    final department = rows.first.groupName;
    final fiscalYear = rows.first.fiscalYear;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(RadiusSize.card),
          boxShadow: AppShadows.light1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: BrandAccent.teal(context).withValues(alpha: 0.08),
                border: Border(bottom: BorderSide(color: colors.outline)),
              ),
              child: Row(
                children: [
                  if (_bulkAssignField == _BulkAssignField.department)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DsCheckbox(
                        value: _selectedProjectKeys.contains(group.key),
                        onChanged: (_) => _toggleProjectSelection(group.key),
                      ),
                    ),
                  if (_bulkAssignField == _BulkAssignField.responsiblePerson)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: 'เลือกทั้งโครงการ (ทุกกิจกรรมย่อย)',
                        child: DsCheckbox(
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
                              style: TextStyle(fontSize: AppTypography.caption, color: colors.onPrimary, fontWeight: AppTypography.weightSemiBold)),
                          ),
                          if (department != null) ...[
                            const SizedBox(width: 6),
                            Text(department,
                              style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
                          ],
                          if (rows.first.budgetSource == budgetSourceDistrict) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: BrandColors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('งบเขต (นอกแผน)',
                                style: TextStyle(fontSize: AppTypography.overline, color: Colors.white, fontWeight: AppTypography.weightSemiBold)),
                            ),
                          ],
                          if (rows.length > 1) ...[
                            const SizedBox(width: 6),
                            Text('· ${rows.length} รายการย่อย',
                              style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(group.key,
                          style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: 15, color: colors.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('คงเหลือรวม', style: TextStyle(fontSize: AppTypography.overline, color: colors.onSurfaceVariant)),
                      Text('${formatBaht(totalRemaining)} บาท',
                        style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: 14, color: colors.onSurface)),
                      Text('จาก ${formatBaht(totalAllocated)} บาท',
                        style: TextStyle(fontSize: AppTypography.overline, color: colors.onSurfaceVariant)),
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
    final remaining = _actualRemaining(b);
    final allocated = b.allocatedAmount ?? 0;
    final remainColor = _remainColor(context, allocated, remaining);

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
                child: DsCheckbox(
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
                    style: const TextStyle(fontSize: AppTypography.body, fontWeight: AppTypography.weightSemiBold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (b.egpNumber != null)
                    Text('e-GP: ${b.egpNumber}', style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
                  if (b.responsiblePerson != null && b.responsiblePerson!.isNotEmpty)
                    Text('ผู้รับผิดชอบ: ${b.responsiblePerson}',
                      style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            Text('${formatBaht(remaining)} บาท',
              style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body, color: remainColor)),
            const SizedBox(width: 8),
            DsActionIconButtons(
              actions: [
                DsRowAction(icon: Icons.copy_all_outlined, tooltip: 'คัดลอกแผนงบ', onTap: () => _duplicateBudget(b)),
                DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(b), danger: true),
              ],
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
    final headerStyle = TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant);
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
                  SizedBox(width: 170, child: Text('ฝ่าย/แผนงาน', style: headerStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 60, child: Text('ปีงบ', style: headerStyle)),
                  Expanded(flex: 3, child: Text('โครงการ / รายการย่อย', style: headerStyle)),
                  if (_visibleColumns.contains('เลข e-GP'))
                    SizedBox(width: 100, child: Text('เลข e-GP', style: headerStyle)),
                  if (_visibleColumns.contains('ผู้รับผิดชอบ'))
                    SizedBox(width: 110, child: Text('ผู้รับผิดชอบ', style: headerStyle)),
                  if (_visibleColumns.contains('วงเงิน')) ...[
                    SizedBox(width: 110, child: Text('วงเงิน', style: headerStyle, textAlign: TextAlign.right)),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 16, color: colors.outlineVariant),
                    const SizedBox(width: 10),
                  ],
                  SizedBox(width: 110, child: Text('คงเหลือ', style: headerStyle, textAlign: TextAlign.right)),
                  const SizedBox(width: 68),
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
            SizedBox(
              width: 170,
              child: Text(
                department,
                style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 60, child: Text(fiscalYear, style: const TextStyle(fontSize: AppTypography.bodyMedium))),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(group.key,
                      style: const TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (rows.first.budgetSource == budgetSourceDistrict) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: BrandColors.orange, borderRadius: BorderRadius.circular(4)),
                      child: const Text('งบเขต', style: TextStyle(fontSize: AppTypography.micro, color: Colors.white, fontWeight: AppTypography.weightSemiBold)),
                    ),
                  ],
                ],
              ),
            ),
            if (_visibleColumns.contains('เลข e-GP')) const SizedBox(width: 100),
            if (_visibleColumns.contains('ผู้รับผิดชอบ')) const SizedBox(width: 110),
            if (_visibleColumns.contains('วงเงิน')) const SizedBox(width: 131),
            const SizedBox(width: 110),
            const SizedBox(width: 68),
          ],
        ),
      ),
    ];
    for (final b in rows) {
      final remaining = _actualRemaining(b);
      final allocated = b.allocatedAmount ?? 0;
      final remainColor = _remainColor(context, allocated, remaining);
      widgets.add(
        InkWell(
          onTap: () => _openForm(existing: b),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                const SizedBox(width: 170),
                const SizedBox(width: 60),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(b.activityName ?? '(ทั้งโครงการ)',
                      style: const TextStyle(fontSize: AppTypography.body), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (_visibleColumns.contains('เลข e-GP'))
                  SizedBox(width: 100, child: Text(b.egpNumber ?? '-', style: const TextStyle(fontSize: AppTypography.bodyMedium))),
                if (_visibleColumns.contains('ผู้รับผิดชอบ'))
                  SizedBox(width: 110, child: Text(b.responsiblePerson ?? '-',
                    style: const TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (_visibleColumns.contains('วงเงิน')) ...[
                  SizedBox(width: 110, child: Text(formatBaht(allocated), textAlign: TextAlign.right, style: const TextStyle(fontSize: AppTypography.body))),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 16, color: colors.outlineVariant),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 110,
                  child: Text(formatBaht(remaining),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: AppTypography.body, fontWeight: AppTypography.weightSemiBold, color: remainColor)),
                ),
                SizedBox(
                  width: 68,
                  child: DsActionIconButtons(
                    actions: [
                      DsRowAction(icon: Icons.copy_all_outlined, tooltip: 'คัดลอกแผนงบ', onTap: () => _duplicateBudget(b)),
                      DsRowAction(icon: Icons.delete_outline, tooltip: 'ลบ', onTap: () => _confirmDelete(b), danger: true),
                    ],
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
    // เพิ่มใหม่ (ไม่มี existing) — เติมปีงบที่กำลังดูอยู่ให้เลย กันพิมพ์ผิด/ลืม
    // กรอก (เช่น ตอนสลับไปวางแผนปีงบถัดไปล่วงหน้าไว้แล้ว ก็ควรลงเป็นปีนั้นเลย)
    _fiscalYear = TextEditingController(text: b?.fiscalYear ?? FiscalYearController.instance.viewingYear);
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
    // ตัวหนังสือ/ป๊อปอัพเดิมเล็กไป (ใช้ isDense + ฟอนต์ default ของ Material ที่
    // ค่อนข้างเล็กเมื่อเทียบกับกล่องโต้ตอบขนาด 500px) — ขยายทั้งกล่อง (500→600)
    // และฟอนต์ทุกช่อง/ปุ่ม/หัวข้อ ให้อ่านง่ายขึ้นชัดเจน รองรับผู้ใช้ช่วงวัยกว้าง
    const labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    const inputStyle = TextStyle(fontSize: 17);
    return AlertDialog(
      title: Text(
        isEdit ? 'แก้ไขแผนงบประมาณ' : 'เพิ่มแผนงบประมาณ',
        style: const TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold),
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_fiscalYear, 'ปีงบประมาณ *', required: true, hint: 'เช่น 2568'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _groupName,
                    isExpanded: true,
                    style: inputStyle.copyWith(color: colors.onSurface),
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    decoration: InputDecoration(
                      labelText: 'ฝ่าย/แผนงาน', labelStyle: labelStyle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.45), width: 1.3),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.45), width: 1.3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.6),
                      ),
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
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _budgetSource,
                    isExpanded: true,
                    style: inputStyle.copyWith(color: colors.onSurface),
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    decoration: InputDecoration(
                      labelText: 'แหล่งงบประมาณ', labelStyle: labelStyle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.45), width: 1.3),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.45), width: 1.3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.6),
                      ),
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
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, TextInputType? keyboardType, String? hint}) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          hintStyle: const TextStyle(fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.3)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.3)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.6)),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null
            : null,
      ),
    );
  }
}
