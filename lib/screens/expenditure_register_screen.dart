// expenditure_register_screen.dart
// "ทะเบียนคุมรายจ่ายโครงการ" — รวมแผนงบประมาณทุกใบ เทียบวงเงินที่ได้รับจัดสรร
// กับยอดที่เบิกจ่ายไปแล้วจริง (นับเฉพาะออร์เดอร์ที่ผูกแผนงบและเสร็จสมบูรณ์แล้ว)
// ไม่ใช่ตารางแยก — ดึงจาก budgets + procurement_orders ที่มีอยู่แล้วโดยตรง

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget_spending.dart';
import '../services/expenditure_register_export_service.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../utils/thai_date.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';

class ExpenditureRegisterScreen extends StatefulWidget {
  const ExpenditureRegisterScreen({super.key});
  @override
  State<ExpenditureRegisterScreen> createState() =>
      _ExpenditureRegisterScreenState();
}

class _ExpenditureRegisterScreenState extends State<ExpenditureRegisterScreen> {
  final _repo = ProcurementRepository();
  List<BudgetSpending> _rows = [];
  bool _loading = true;
  bool _exporting = false;
  String? _fiscalYearFilter;
  final _scrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.getBudgetSpendingSummaries();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  List<String> get _fiscalYears =>
      _rows.map((r) => r.budget.fiscalYear).toSet().toList()..sort();

  List<BudgetSpending> get _filtered => _fiscalYearFilter == null
      ? _rows
      : _rows.where((r) => r.budget.fiscalYear == _fiscalYearFilter).toList();

  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await ExpenditureRegisterExportService.exportAndOpen(_filtered);
      if (!mounted) return;
      showAppToast('ส่งออก Excel สำเร็จ กำลังเปิดไฟล์...');
    } catch (e) {
      if (!mounted) return;
      showAppToast('ส่งออกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showDetails(BudgetSpending r) {
    showDialog(
      context: context,
      builder: (ctx) => _ExpenditureDetailDialog(row: r),
    );
  }

  Color _remainColor(BuildContext context, double allocated, double remaining) {
    final ratio = allocated > 0 ? (remaining / allocated).clamp(0.0, 1.0) : 1.0;
    if (ratio > 0.5) return BrandAccent.green(context);
    if (ratio > 0.2) return BrandAccent.tertiary(context);
    return BrandAccent.red(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้ทะเบียนคุมรายจ่ายโครงการ',
      icon: Icons.payments_outlined,
      corner: Alignment.bottomRight,
      steps: const [
        'หน้านี้รวมแผนงบประมาณทุกใบมาเทียบวงเงินที่ได้รับจัดสรรกับยอดที่เบิกจ่ายไปแล้วจริง',
        '"จ่ายไปแล้ว" นับเฉพาะโครงการที่ผูกกับแผนงบนี้และมีสถานะ "เสร็จสมบูรณ์" แล้วเท่านั้น โครงการที่ยังร่าง/กำลังดำเนินการยังไม่ถือว่าใช้งบจริง',
        'กดที่แถวเพื่อดูรายการโครงการที่เบิกจ่ายไปแล้วภายใต้แผนงบนั้น',
        'กรองตามปีงบ แล้วกด "ส่งออก Excel" เพื่อพิมพ์ทะเบียนเป็นไฟล์',
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        color: BrandAccent.tealOn(context), size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text('ทะเบียนคุมรายจ่ายโครงการ',
                          style: TextStyle(
                              fontWeight: AppTypography.weightExtraBold,
                              fontSize: AppTypography.heading2,
                              color: colors.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _fiscalYearFilter,
                        isDense: true,
                        isExpanded: true,
                        style: TextStyle(
                            fontSize: AppTypography.bodyMedium,
                            color: colors.onSurface),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'ปีงบ (ทั้งหมด)',
                          hintStyle: TextStyle(
                              fontSize: AppTypography.bodyMedium,
                              color: colors.onSurfaceVariant),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
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
                            borderSide: BorderSide(
                                color: BrandAccent.teal(context), width: 1.5),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('ปีงบ (ทั้งหมด)',
                                  overflow: TextOverflow.ellipsis)),
                          ..._fiscalYears.map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('ปี $y',
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() => _fiscalYearFilter = v),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _rows.isEmpty || _exporting ? null : _exportToExcel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        side: BorderSide(color: colors.outline),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RadiusSize.md)),
                        textStyle: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      icon: _exporting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onSurfaceVariant))
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label:
                          Text(_exporting ? 'กำลังส่งออก...' : 'ส่งออก Excel'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.payments_outlined,
                                      size: 64, color: colors.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                      _rows.isEmpty
                                          ? 'ยังไม่มีแผนงบประมาณในระบบ\nไปเพิ่มที่หน้า "แผนงบประมาณ" ก่อน'
                                          : 'ไม่พบรายการที่ตรงกับตัวกรอง',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: AppTypography.heading4)),
                                ],
                              ),
                            )
                          : _buildTable(colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(ColorScheme colors) {
    final headerStyle = TextStyle(
        fontWeight: AppTypography.weightBold,
        fontSize: AppTypography.bodySmall,
        color: colors.onSurfaceVariant);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: BrandAccent.surface2(context),
                      border:
                          Border(bottom: BorderSide(color: colors.outline))),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 40, child: Text('ที่', style: headerStyle)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 150,
                          child: Text('หน่วยงาน/กลุ่มงาน', style: headerStyle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('โครงการ/กิจกรรม', style: headerStyle)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 130,
                          child: Text('วงเงินที่ได้รับจัดสรร',
                              style: headerStyle, textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 120,
                          child: Text('จ่ายไปแล้ว',
                              style: headerStyle, textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 120,
                          child: Text('คงเหลือ',
                              style: headerStyle, textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 90,
                          child: Text('รายการ',
                              style: headerStyle, textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vScrollCtrl,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _vScrollCtrl,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildRow(colors, i, _filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, int index, BudgetSpending r) {
    final b = r.budget;
    final allocated = b.allocatedAmount ?? 0;
    final remainColor = _remainColor(context, allocated, r.remainingAmount);
    return InkWell(
      onTap: () => _showDetails(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant))),
        child: Row(
          children: [
            SizedBox(
                width: 40,
                child: Text('${index + 1}',
                    style: TextStyle(fontSize: AppTypography.bodyMedium))),
            const SizedBox(width: 8),
            SizedBox(
                width: 150,
                child: Text(b.groupName ?? '-',
                    style: TextStyle(fontSize: AppTypography.bodyMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  [b.projectName, b.activityName]
                      .where((s) => s != null && s.trim().isNotEmpty)
                      .join(' › '),
                  style: TextStyle(
                      fontSize: AppTypography.bodyMedium,
                      fontWeight: AppTypography.weightSemiBold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            SizedBox(
                width: 130,
                child: Text(formatBaht(allocated),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: AppTypography.bodyMedium))),
            const SizedBox(width: 8),
            SizedBox(
                width: 120,
                child: Text(formatBaht(r.spentAmount),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: AppTypography.bodyMedium))),
            const SizedBox(width: 8),
            SizedBox(
                width: 120,
                child: Text(formatBaht(r.remainingAmount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: AppTypography.bodyMedium,
                        fontWeight: AppTypography.weightSemiBold,
                        color: remainColor))),
            const SizedBox(width: 8),
            SizedBox(
                width: 90,
                child: Text('${r.orderCount}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppTypography.bodyMedium))),
          ],
        ),
      ),
    );
  }
}

class _ExpenditureDetailDialog extends StatelessWidget {
  final BudgetSpending row;
  const _ExpenditureDetailDialog({required this.row});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final b = row.budget;
    return AlertDialog(
      title: Text(
          [b.projectName, b.activityName]
              .where((s) => s != null && s.trim().isNotEmpty)
              .join(' › '),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 560,
        child: row.orders.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'ยังไม่มีโครงการที่เบิกจ่ายเสร็จสมบูรณ์ภายใต้แผนงบนี้',
                    style: TextStyle(color: colors.onSurfaceVariant)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final o in row.orders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      o.orderNumber ??
                                          o.procurementSubject ??
                                          '(ไม่มีเลขที่)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(o.procurementSubject ?? '',
                                      style: TextStyle(
                                          fontSize: AppTypography.bodySmall,
                                          color: colors.onSurfaceVariant),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  if (o.dateDisbursement != null)
                                    Text(
                                        'เบิกจ่าย ${formatThaiDateShort(o.dateDisbursement)}',
                                        style: TextStyle(
                                            fontSize: AppTypography.caption,
                                            color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Text(formatBaht(o.currentOrderPrice ?? 0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}
