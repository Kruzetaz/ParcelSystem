// learning_materials_screen.dart
// "ทะเบียนหนังสือเรียน/อุปกรณ์การเรียนทั้งโรงเรียน" — เทียบมาจากสมุดทะเบียน
// กระดาษเดิม (แยกหน้า "หนังสือเรียน"/"อุปกรณ์การเรียน" ตามสาขา) แต่เก็บเป็น
// ยอดสรุปต่อ (สาขา, หมวดหมู่, ชั้น) แทนการจด log การยืม-คืนแบบกระดาษ:
//   - จำนวนนักเรียน x ราคาต่อหัว = งบที่ต้องใช้ของชั้นนั้น
//   - เทียบกับจำนวนที่สั่งซื้อ/จำนวนเงินที่จัดซื้อจริง เพื่อเช็คว่าขาด/เกินไปเท่าไหร่
// สาขาของโรงเรียนจัดการเอง (เพิ่ม/แก้ไข/ลบ) ได้จากปุ่ม "จัดการสาขา" ในหน้านี้

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/school_branch.dart';
import '../models/learning_material_record.dart';
import '../models/learning_material_grade.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/design_system/status_badge.dart' show DSFilterChip;
import '../theme/design_tokens.dart';

class LearningMaterialsScreen extends StatefulWidget {
  const LearningMaterialsScreen({super.key});
  @override
  State<LearningMaterialsScreen> createState() => _LearningMaterialsScreenState();
}

class _LearningMaterialsScreenState extends State<LearningMaterialsScreen> {
  final _repo = ProcurementRepository();
  bool _loading = true;
  List<SchoolBranch> _branches = [];
  List<LearningMaterialGrade> _grades = [];
  int? _selectedBranchId;
  String _category = learningMaterialCategories.first;

  // ระเบียนของสาขาที่กำลังเลือกดู (สำหรับตาราง) — คีย์ด้วยชื่อชั้น
  Map<String, LearningMaterialRecord> _recordsByGrade = {};
  // ระเบียนทุกสาขารวมกันของหมวดหมู่ปัจจุบัน (สำหรับการ์ดสรุปภาพรวมทั้งโรงเรียน)
  List<LearningMaterialRecord> _allRecordsForCategory = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final branches = await _repo.getAllBranches();
    final grades = await _repo.getAllLearningMaterialGrades();
    if (!mounted) return;
    setState(() {
      _branches = branches;
      _grades = grades;
      _selectedBranchId ??= branches.isNotEmpty ? branches.first.id : null;
      _loading = false;
    });
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    final all = await _repo.getAllLearningMaterialRecords(_category);
    Map<String, LearningMaterialRecord> byGrade = {};
    if (_selectedBranchId != null) {
      for (final r in all.where((r) => r.branchId == _selectedBranchId)) {
        byGrade[r.gradeLevel] = r;
      }
    }
    if (!mounted) return;
    setState(() {
      _allRecordsForCategory = all;
      _recordsByGrade = byGrade;
    });
  }

  LearningMaterialRecord _recordFor(String grade) =>
      _recordsByGrade[grade] ??
      LearningMaterialRecord(branchId: _selectedBranchId!, category: _category, gradeLevel: grade);

  Future<void> _saveRecord(LearningMaterialRecord r) async {
    setState(() => _recordsByGrade[r.gradeLevel] = r);
    try {
      await _repo.upsertLearningMaterialRecord(r);
      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      showAppToast('บันทึกไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _manageBranches() async {
    await showDialog(context: context, builder: (_) => _BranchManagerDialog(repo: _repo, branches: _branches));
    final branches = await _repo.getAllBranches();
    if (!mounted) return;
    setState(() {
      _branches = branches;
      if (_selectedBranchId != null && !branches.any((b) => b.id == _selectedBranchId)) {
        _selectedBranchId = branches.isNotEmpty ? branches.first.id : null;
      }
      _selectedBranchId ??= branches.isNotEmpty ? branches.first.id : null;
    });
    await _loadRecords();
  }

  Future<void> _manageGrades() async {
    await showDialog(context: context, builder: (_) => _GradeManagerDialog(repo: _repo, grades: _grades));
    final grades = await _repo.getAllLearningMaterialGrades();
    if (!mounted) return;
    setState(() => _grades = grades);
    await _loadRecords();
  }

  Future<void> _editRow(String grade) async {
    final current = _recordFor(grade);
    final studentCtrl = TextEditingController(text: current.studentCount == 0 ? '' : '${current.studentCount}');
    final orderedCtrl = TextEditingController(text: current.orderedCount == 0 ? '' : '${current.orderedCount}');
    final unitPriceCtrl = TextEditingController(text: current.unitPrice == null ? '' : current.unitPrice!.toStringAsFixed(2));
    final actualAmountCtrl = TextEditingController(text: current.actualAmount == null ? '' : current.actualAmount!.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: current.note ?? '');

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('แก้ไขข้อมูลชั้น $grade'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: studentCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'จำนวนนักเรียน', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: orderedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'จำนวนที่สั่งซื้อ', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unitPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'ราคาต่อหัว (บาท)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: actualAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'จัดซื้อจริง (บาท)', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'หมายเหตุ', isDense: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );

    if (save == true) {
      await _saveRecord(current.copyWith(
        studentCount: int.tryParse(studentCtrl.text.trim()) ?? 0,
        orderedCount: int.tryParse(orderedCtrl.text.trim()) ?? 0,
        unitPrice: double.tryParse(unitPriceCtrl.text.trim()),
        actualAmount: double.tryParse(actualAmountCtrl.text.trim()),
        note: noteCtrl.text.trim(),
      ));
    }
    studentCtrl.dispose();
    orderedCtrl.dispose();
    unitPriceCtrl.dispose();
    actualAmountCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return GuideFabOverlay(
      title: 'วิธีใช้ทะเบียนหนังสือเรียน/อุปกรณ์การเรียน',
      icon: Icons.menu_book_outlined,
      steps: const [
        'กด "จัดการสาขา" เพื่อเพิ่มสาขาของโรงเรียนก่อนครั้งแรก (เช่น โรงเรียนหลัก + สาขาย่อย)',
        'กด "จัดการชั้นเรียน" เพื่อเพิ่ม/แก้ไข/ลบรายชื่อชั้น — ค่าเริ่มต้นมีให้ครบ อ.2-ม.3 แล้ว ปรับได้ตามจริงถ้าโรงเรียนไม่มีบางชั้น',
        'สลับดู "หนังสือเรียน"/"อุปกรณ์การเรียน" ด้วยปุ่มด้านบน แล้วเลือกสาขาที่จะกรอกจากแท็บสาขา',
        'กดไอคอนดินสอในแต่ละแถวชั้นเพื่อกรอกจำนวนนักเรียน จำนวนที่สั่งซื้อ ราคาต่อหัว และจำนวนเงินที่จัดซื้อจริง',
        'ระบบคำนวณ "งบที่ต้องใช้" ให้อัตโนมัติจาก ราคาต่อหัว x จำนวนนักเรียน แล้วเทียบกับเงินที่จัดซื้อจริง เพื่อบอกว่าขาด/เกินงบไปเท่าไหร่',
        'การ์ดสรุปด้านบนรวมยอดทุกสาขาของหมวดหมู่ที่กำลังดูอยู่ ให้เห็นภาพรวมทั้งโรงเรียนโดยไม่ต้องสลับไปดูทีละสาขา',
      ],
      corner: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, color: BrandAccent.tealOn(context), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('ทะเบียนหนังสือเรียน/อุปกรณ์การเรียน',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                ),
                SegmentedButton<String>(
                  segments: learningMaterialCategories.map((c) => ButtonSegment(value: c, label: Text(c))).toList(),
                  selected: {_category},
                  onSelectionChanged: (s) {
                    setState(() => _category = s.first);
                    _loadRecords();
                  },
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _manageBranches,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: const Text('จัดการสาขา'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _manageGrades,
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('จัดการชั้นเรียน'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('จำนวนนักเรียน x ราคาต่อหัว = งบที่ต้องใช้ เทียบกับเงินที่จัดซื้อจริง เพื่อเช็คว่าขาด/เกินงบไปเท่าไหร่',
                style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
            const SizedBox(height: 16),
            _buildOverviewCard(colors),
            if (_branches.length > 1) ...[
              const SizedBox(height: 10),
              _buildBranchSummaryTable(colors),
            ],
            const SizedBox(height: 16),
            if (_branches.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off_outlined, size: 64, color: colors.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('ยังไม่มีสาขาในระบบ กด "จัดการสาขา" เพื่อเพิ่มสาขาแรก',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
                    ],
                  ),
                ),
              )
            else ...[
              _buildBranchTabs(colors),
              const SizedBox(height: 12),
              Expanded(child: _buildTable(colors)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(ColorScheme colors) {
    final totalRequired = _allRecordsForCategory.fold<double>(0, (s, r) => s + r.requiredBudget);
    final totalActual = _allRecordsForCategory.fold<double>(0, (s, r) => s + (r.actualAmount ?? 0));
    final totalDiff = totalActual - totalRequired;
    final shortageGrades = _allRecordsForCategory.where((r) => r.diff < 0).length;
    final overBudget = totalDiff < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      child: Row(
        children: [
          Expanded(child: _overviewStat('ภาพรวมทั้งโรงเรียน ($_category)', '${_branches.length} สาขา', colors.onSurfaceVariant, colors)),
          Container(width: 1, height: 34, color: colors.outlineVariant),
          Expanded(child: _overviewStat('งบที่ต้องใช้รวม', '${formatBaht(totalRequired)} บาท', colors.onSurface, colors)),
          Container(width: 1, height: 34, color: colors.outlineVariant),
          Expanded(child: _overviewStat('จัดซื้อจริงรวม', '${formatBaht(totalActual)} บาท', colors.onSurface, colors)),
          Container(width: 1, height: 34, color: colors.outlineVariant),
          Expanded(
            child: _overviewStat(
              overBudget ? 'เกินงบรวม' : 'ขาดงบรวม',
              '${formatBaht(totalDiff.abs())} บาท',
              overBudget ? Colors.orange : BrandAccent.green(context),
              colors,
            ),
          ),
          Container(width: 1, height: 34, color: colors.outlineVariant),
          Expanded(child: _overviewStat('ชั้นที่จำนวนขาด', '$shortageGrades ชั้น', shortageGrades > 0 ? Colors.orange : BrandAccent.green(context), colors)),
        ],
      ),
    );
  }

  Widget _overviewStat(String label, String value, Color valueColor, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }

  /// สรุปแยกตามสาขา (ของหมวดหมู่ที่กำลังดูอยู่) — แถวละสาขา กดแล้วสลับไปดู/
  /// แก้ไขตารางของสาขานั้นได้ทันที
  Widget _buildBranchSummaryTable(ColorScheme colors) {
    final headerStyle = TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.caption, color: colors.onSurfaceVariant);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text('สรุปแยกตามสาขา ($_category)', style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodySmall, color: colors.onSurface)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('สาขา', style: headerStyle)),
                Expanded(child: Text('งบที่ต้องใช้', style: headerStyle, textAlign: TextAlign.right)),
                Expanded(child: Text('จัดซื้อจริง', style: headerStyle, textAlign: TextAlign.right)),
                Expanded(child: Text('ส่วนต่างงบ', style: headerStyle, textAlign: TextAlign.right)),
                Expanded(child: Text('ชั้นที่ขาด', style: headerStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 8),
          ..._branches.map((b) {
            final recs = _allRecordsForCategory.where((r) => r.branchId == b.id);
            final required = recs.fold<double>(0, (s, r) => s + r.requiredBudget);
            final actual = recs.fold<double>(0, (s, r) => s + (r.actualAmount ?? 0));
            final diff = actual - required;
            final shortage = recs.where((r) => r.diff < 0).length;
            final over = diff < 0;
            final selected = b.id == _selectedBranchId;
            return InkWell(
              onTap: () {
                setState(() => _selectedBranchId = b.id);
                _loadRecords();
              },
              child: Container(
                color: selected ? BrandAccent.teal(context).withValues(alpha: 0.06) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: selected ? FontWeight.w800 : FontWeight.w500))),
                    Expanded(child: Text(formatBaht(required), textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodySmall))),
                    Expanded(child: Text(formatBaht(actual), textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodySmall))),
                    Expanded(
                      child: Text(formatBaht(diff.abs()),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: FontWeight.w700, color: over ? Colors.orange : BrandAccent.green(context))),
                    ),
                    Expanded(
                      child: Text('$shortage ชั้น',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: FontWeight.w700, color: shortage > 0 ? Colors.orange : BrandAccent.green(context))),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBranchTabs(ColorScheme colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _branches.map((b) {
        final selected = b.id == _selectedBranchId;
        return DSFilterChip(
          label: b.name,
          isSelected: selected,
          onTap: () {
            setState(() => _selectedBranchId = b.id);
            _loadRecords();
          },
        );
      }).toList(),
    );
  }

  Widget _buildTable(ColorScheme colors) {
    final headerStyle = TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant);
    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 1.5))),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text('ชั้น', style: headerStyle)),
                SizedBox(width: 90, child: Text('นักเรียน', style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(width: 90, child: Text('สั่งซื้อ', style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(width: 90, child: Text('ส่วนต่าง', style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(width: 100, child: Text('ราคา/หัว', style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(width: 120, child: Text('งบที่ต้องใช้', style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(width: 120, child: Text('จัดซื้อจริง', style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(width: 110, child: Text('ส่วนต่างงบ', style: headerStyle, textAlign: TextAlign.right)),
                const Expanded(child: Text('')),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: _grades.isEmpty
                ? Center(
                    child: Text('ยังไม่มีชั้นเรียนในระบบ กด "จัดการชั้นเรียน" เพื่อเพิ่ม',
                        style: TextStyle(color: colors.onSurfaceVariant)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 6),
                    itemCount: _grades.length,
                    itemBuilder: (_, i) => _buildRow(colors, _grades[i].name),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, String grade) {
    final r = _recordFor(grade);
    final qtyShort = r.diff < 0;
    final overBudget = r.budgetDiff < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(grade, style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: FontWeight.w700))),
          SizedBox(width: 90, child: Text('${r.studentCount}', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
          SizedBox(width: 90, child: Text('${r.orderedCount}', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
          SizedBox(
            width: 90,
            child: Text(
              r.diff == 0 ? '0' : (r.diff > 0 ? '+${r.diff}' : '${r.diff}'),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: FontWeight.w700, color: qtyShort ? Colors.orange : BrandAccent.green(context)),
            ),
          ),
          SizedBox(width: 100, child: Text(r.unitPrice != null ? formatBaht(r.unitPrice) : '-', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
          SizedBox(width: 120, child: Text(formatBaht(r.requiredBudget), textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
          SizedBox(width: 120, child: Text(r.actualAmount != null ? formatBaht(r.actualAmount) : '-', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
          SizedBox(
            width: 110,
            child: Text(
              formatBaht(r.budgetDiff.abs()),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: FontWeight.w700, color: overBudget ? Colors.orange : BrandAccent.green(context)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(r.note?.isNotEmpty == true ? r.note! : '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'แก้ไข',
              onPressed: () => _editRow(grade),
            ),
          ),
        ],
      ),
    );
  }
}

/// กล่องโต้ตอบจัดการสาขาของโรงเรียน — เพิ่ม/แก้ไขชื่อ/ลบ
class _BranchManagerDialog extends StatefulWidget {
  final ProcurementRepository repo;
  final List<SchoolBranch> branches;
  const _BranchManagerDialog({required this.repo, required this.branches});

  @override
  State<_BranchManagerDialog> createState() => _BranchManagerDialogState();
}

class _BranchManagerDialogState extends State<_BranchManagerDialog> {
  late List<SchoolBranch> _branches;
  final _newBranchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _branches = List.of(widget.branches);
  }

  @override
  void dispose() {
    _newBranchCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _newBranchCtrl.text.trim();
    if (name.isEmpty) return;
    final id = await widget.repo.insertBranch(SchoolBranch(name: name, sortOrder: _branches.length));
    setState(() {
      _branches.add(SchoolBranch(id: id, name: name, sortOrder: _branches.length));
      _newBranchCtrl.clear();
    });
  }

  Future<void> _rename(SchoolBranch b) async {
    final ctrl = TextEditingController(text: b.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อสาขา'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty) return;
    final updated = b.copyWith(name: newName);
    await widget.repo.updateBranch(updated);
    setState(() {
      final idx = _branches.indexWhere((x) => x.id == b.id);
      if (idx != -1) _branches[idx] = updated;
    });
  }

  Future<void> _delete(SchoolBranch b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบสาขานี้?'),
        content: Text('ลบสาขา "${b.name}" — ข้อมูลหนังสือเรียน/อุปกรณ์การเรียนของสาขานี้ทั้งหมดจะถูกลบไปด้วย'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true || b.id == null) return;
    await widget.repo.deleteBranch(b.id!);
    setState(() => _branches.removeWhere((x) => x.id == b.id));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('จัดการสาขาโรงเรียน'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 260,
              child: _branches.isEmpty
                  ? const Center(child: Text('ยังไม่มีสาขา'))
                  : ListView.builder(
                      itemCount: _branches.length,
                      itemBuilder: (_, i) {
                        final b = _branches[i];
                        return ListTile(
                          dense: true,
                          title: Text(b.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _rename(b)),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(b)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newBranchCtrl,
                    decoration: const InputDecoration(hintText: 'ชื่อสาขาใหม่', isDense: true),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('เพิ่ม')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
      ],
    );
  }
}

/// กล่องโต้ตอบจัดการชั้นเรียน — เพิ่ม/แก้ไขชื่อ/ลบ (เดิม fix ตายตัว อ.2-ม.3
/// ในโค้ด ย้ายมาให้ผู้ใช้ปรับเองได้ เผื่อบางโรงเรียนไม่มีบางชั้น)
class _GradeManagerDialog extends StatefulWidget {
  final ProcurementRepository repo;
  final List<LearningMaterialGrade> grades;
  const _GradeManagerDialog({required this.repo, required this.grades});

  @override
  State<_GradeManagerDialog> createState() => _GradeManagerDialogState();
}

class _GradeManagerDialogState extends State<_GradeManagerDialog> {
  late List<LearningMaterialGrade> _grades;
  final _newGradeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _grades = List.of(widget.grades);
  }

  @override
  void dispose() {
    _newGradeCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _newGradeCtrl.text.trim();
    if (name.isEmpty) return;
    final id = await widget.repo.insertLearningMaterialGrade(LearningMaterialGrade(name: name, sortOrder: _grades.length));
    setState(() {
      _grades.add(LearningMaterialGrade(id: id, name: name, sortOrder: _grades.length));
      _newGradeCtrl.clear();
    });
  }

  Future<void> _rename(LearningMaterialGrade g) async {
    final ctrl = TextEditingController(text: g.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อชั้น'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty || newName == g.name) return;
    await widget.repo.renameLearningMaterialGrade(g, newName);
    setState(() {
      final idx = _grades.indexWhere((x) => x.id == g.id);
      if (idx != -1) _grades[idx] = g.copyWith(name: newName);
    });
  }

  Future<void> _delete(LearningMaterialGrade g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบชั้นนี้?'),
        content: Text('ลบชั้น "${g.name}" — ข้อมูลหนังสือเรียน/อุปกรณ์การเรียนของชั้นนี้ทุกสาขาจะถูกลบไปด้วย'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true || g.id == null) return;
    await widget.repo.deleteLearningMaterialGrade(g);
    setState(() => _grades.removeWhere((x) => x.id == g.id));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('จัดการชั้นเรียน'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 260,
              child: _grades.isEmpty
                  ? const Center(child: Text('ยังไม่มีชั้นเรียน'))
                  : ListView.builder(
                      itemCount: _grades.length,
                      itemBuilder: (_, i) {
                        final g = _grades[i];
                        return ListTile(
                          dense: true,
                          title: Text(g.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _rename(g)),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(g)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newGradeCtrl,
                    decoration: const InputDecoration(hintText: 'ชื่อชั้นใหม่ เช่น ป.7', isDense: true),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('เพิ่ม')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
      ],
    );
  }
}
