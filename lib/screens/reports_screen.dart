// reports_screen.dart
// รายงานสรุปประจำปี/รายเดือน + ตรวจสอบ สตง. + Audit Trail (blueprint หน้าที่ 13)
//
// [หมายเหตุสำคัญ — ตรวจสอบ สตง.]: Ready Score ตรงนี้ตรวจแค่ "ข้อมูลกรอกครบไหม"
// (data completeness) เท่านั้น ไม่ใช่การรับรองความถูกต้องทางกฎหมาย ผู้ใช้ต้อง
// ตรวจสอบความถูกต้องตามระเบียบพัสดุจริงเองอีกครั้งก่อนใช้อ้างอิง — สอดคล้องกับ
// หลักการที่ตกลงกันไว้ว่าแอปนี้ไม่ทำหน้าที่รับรองความถูกต้องทางกฎหมายให้
//
// [หมายเหตุ — Audit Trail]: บันทึกเฉพาะ สร้าง/แก้ไข/ลบ ของตารางส่วนใหญ่ในแอป
// (แผนงบ, TOR, สัญญา, หลักประกัน, ตรวจรับ, ครุภัณฑ์, วัสดุ, ตรวจนับ, จำหน่าย,
// จัดซื้อจัดจ้าง, ข้อมูลโรงเรียน) — ไม่ครอบคลุมทุกตารางย่อยในระบบ (เช่น
// procurement_items แต่ละแถว, TOR template, ประวัติซ่อมแซมครุภัณฑ์)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/audit_log_entry.dart';
import '../models/procurement_order.dart';
import '../models/school_settings.dart';
import '../services/monthly_procurement_summary_export_service.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/progress_indicators.dart' show ProgressBar;
import '../widgets/design_system/status_badge.dart' show StatusBadge, BadgeVariant;

enum _ReportTab { monthly, readiness, auditTrail }

const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

int? _monthIndexFromThaiDate(String? text) {
  if (text == null) return null;
  final parts = text.trim().split(' ');
  if (parts.length != 3) return null;
  final idx = _thaiMonths.indexOf(parts[1]);
  return idx < 1 ? null : idx;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = ProcurementRepository();
  _ReportTab _tab = _ReportTab.monthly;
  bool _loading = true;

  List<Map<String, dynamic>> _monthlyRows = [];
  List<_ChecklistItem> _checklist = [];
  List<AuditLogEntry> _auditLog = [];
  List<ProcurementOrder> _orders = [];
  SchoolSettings? _school;
  // กันกดส่งออกซ้ำตอนกำลังสร้างไฟล์อยู่ — เก็บชื่อเดือนที่กำลังสร้าง
  String? _exportingMonth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repo.getAllOrders();
    final budgets = await _repo.getAllBudgets();
    final tors = await _repo.getAllTorDocuments();
    final contracts = await _repo.getAllContracts();
    final assets = await _repo.getAllFixedAssets();
    final auditLog = await _repo.getAuditLog();
    final school = await _repo.getSchoolSettings();

    // สรุปรายเดือน — รวมยอด usedBudget ตามเดือนของ dateOrderCreated
    final monthlyTotals = List<double>.filled(13, 0);
    final monthlyCounts = List<int>.filled(13, 0);
    for (final o in orders) {
      final m = _monthIndexFromThaiDate(o.dateOrderCreated);
      if (m == null) continue;
      monthlyTotals[m] += o.usedBudget ?? 0;
      monthlyCounts[m]++;
    }
    final monthlyRows = [
      for (var m = 1; m <= 12; m++)
        {'monthIndex': m, 'month': _thaiMonths[m], 'count': monthlyCounts[m], 'total': monthlyTotals[m]},
    ];

    // สตง. checklist — ตรวจแค่ข้อมูลครบไหม (data completeness) ไม่ใช่ความถูกต้องทางกฎหมาย
    final checklist = [
      _ChecklistItem(
        'แผนงบประมาณมีวงเงินระบุครบ',
        budgets.where((b) => b.allocatedAmount != null).length,
        budgets.length,
      ),
      _ChecklistItem(
        'เอกสารจัดซื้อจัดจ้างมีเลขที่เอกสารครบ',
        orders.where((o) => (o.procurementNumber ?? '').isNotEmpty).length,
        orders.length,
      ),
      _ChecklistItem(
        'เอกสารจัดซื้อจัดจ้างมีชื่อผู้ขาย/ผู้รับจ้างครบ',
        orders.where((o) => (o.vendorName ?? '').isNotEmpty).length,
        orders.length,
      ),
      _ChecklistItem(
        'TOR/คุณลักษณะเฉพาะมีรายละเอียดสเปกครบ',
        tors.where((t) => (t.specificationText ?? '').isNotEmpty).length,
        tors.length,
      ),
      _ChecklistItem(
        'สัญญามีวันที่เริ่ม-สิ้นสุดครบ',
        contracts.where((c) => c.startDate != null && c.endDate != null).length,
        contracts.length,
      ),
      _ChecklistItem(
        'ครุภัณฑ์มีเลขครุภัณฑ์ครบ',
        assets.where((a) => (a.assetNumber ?? '').isNotEmpty).length,
        assets.length,
      ),
    ];

    if (!mounted) return;
    setState(() {
      _monthlyRows = monthlyRows;
      _checklist = checklist;
      _auditLog = auditLog;
      _orders = orders;
      _school = school;
      _loading = false;
    });
  }

  /// ปุ่มส่งออก "แบบสรุปผลการจัดซื้อจัดจ้างรายเดือน" ต่อแถวเดือน — กรองเฉพาะ
  /// รายการที่ตรงเดือนนั้น (นับจาก dateOrderCreated) แล้วส่งออกเป็น Excel
  Future<void> _exportMonthlySummary(int monthIndex, String monthLabel) async {
    final ordersInMonth = _orders.where((o) => _monthIndexFromThaiDate(o.dateOrderCreated) == monthIndex).toList();
    if (ordersInMonth.isEmpty) return;
    final school = _school;
    if (school == null || (school.schoolName?.trim().isEmpty ?? true)) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    // หา พ.ศ. ที่พบบ่อยที่สุดในกลุ่มเดือนนี้ (เผื่อมีข้อมูลข้ามปีงบปนกัน)
    final yearCounts = <String, int>{};
    for (final o in ordersInMonth) {
      final parts = o.dateOrderCreated?.trim().split(' ');
      if (parts != null && parts.length == 3) {
        yearCounts[parts[2]] = (yearCounts[parts[2]] ?? 0) + 1;
      }
    }
    final year = yearCounts.isEmpty
        ? (DateTime.now().year + 543).toString()
        : (yearCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

    setState(() => _exportingMonth = monthLabel);
    try {
      await MonthlyProcurementSummaryExportService.exportAndOpen(
        orders: ordersInMonth,
        monthLabel: monthLabel,
        buddhistYearLabel: year,
        schoolName: school.schoolName!,
      );
      if (!mounted) return;
      showAppToast('ส่งออกแบบสรุปผลจัดซื้อจัดจ้างแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('ส่งออกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingMonth = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้ารายงาน/สตง.',
      icon: Icons.bar_chart_outlined,
      steps: const [
        '"รายงานรายเดือน" สรุปยอดใช้จ่ายตามกลุ่มงาน/หมวดหมู่ในแต่ละเดือนของปีงบประมาณ',
        'กดไอคอนดาวน์โหลดท้ายแถวเดือนที่มีรายการ เพื่อส่งออก "แบบสรุปผลการจัดซื้อจัดจ้างรายเดือน" (ตามแบบที่ส่งหน่วยงานกำกับ) เป็นไฟล์ Excel — "เหตุผลที่คัดเลือก" เติมข้อความมาตรฐานให้ก่อน แก้ไขในไฟล์ที่ได้เองได้ถ้ากรณีนั้นมีเหตุผลอื่น',
        '"ตรวจสอบ สตง." เช็คแค่ว่าข้อมูลกรอกครบตามที่จำเป็นหรือไม่ (data completeness) ไม่ใช่การรับรองความถูกต้องทางกฎหมาย ต้องตรวจสอบตามระเบียบพัสดุจริงอีกครั้งก่อนใช้อ้างอิง',
        '"Audit Trail" บันทึกประวัติการสร้าง/แก้ไข/ลบของข้อมูลส่วนใหญ่ในระบบ แต่ไม่ครอบคลุมทุกตารางย่อย (เช่น รายการพัสดุแต่ละแถวในคำสั่งซื้อ)',
        'สลับดูรายงานแต่ละแบบได้ที่แถบด้านบน',
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_outlined, color: BrandAccent.tealOn(context), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('รายงาน/สตง.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTabSelector(colors),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : switch (_tab) {
                      _ReportTab.monthly => _buildMonthlyReport(colors),
                      _ReportTab.readiness => _buildReadinessReport(context, colors),
                      _ReportTab.auditTrail => _buildAuditTrail(context, colors),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(ColorScheme colors) {
    return SegmentedButton<_ReportTab>(
      segments: const [
        ButtonSegment(value: _ReportTab.monthly, icon: Icon(Icons.bar_chart_outlined), label: Text('รายงานรายเดือน')),
        ButtonSegment(value: _ReportTab.readiness, icon: Icon(Icons.fact_check_outlined), label: Text('ตรวจสอบ สตง.')),
        ButtonSegment(value: _ReportTab.auditTrail, icon: Icon(Icons.history_outlined), label: Text('Audit Trail')),
      ],
      selected: {_tab},
      onSelectionChanged: (s) => setState(() => _tab = s.first),
    );
  }

  // ─────────────────────────────────────────
  // รายงานรายเดือน
  // ─────────────────────────────────────────

  Widget _buildMonthlyReport(ColorScheme colors) {
    final grandTotal = _monthlyRows.fold<double>(0, (s, r) => s + (r['total'] as double));
    final maxTotal = _monthlyRows.fold<double>(1, (m, r) => (r['total'] as double) > m ? r['total'] as double : m);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: BrandAccent.teal(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(RadiusSize.card),
              border: Border.all(color: BrandAccent.teal(context).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.summarize_outlined, color: BrandAccent.tealOn(context)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ยอดใช้จ่ายสะสมทั้งปี', style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                    Text('${formatBaht(grandTotal)} บาท',
                      style: TextStyle(fontSize: AppTypography.heading3, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(RadiusSize.card),
              boxShadow: AppShadows.light1,
            ),
            child: Column(
              children: [
                for (final row in _monthlyRows) _buildMonthRow(context, colors, row, maxTotal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthRow(BuildContext context, ColorScheme colors, Map<String, dynamic> row, double maxTotal) {
    final total = row['total'] as double;
    final count = row['count'] as int;
    final monthLabel = row['month'] as String;
    final ratio = maxTotal > 0 ? (total / maxTotal).clamp(0.0, 1.0) : 0.0;
    final isExporting = _exportingMonth == monthLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(monthLabel, style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface))),
          Expanded(child: ProgressBar(progress: ratio, height: 10)),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text('${formatBaht(total)} บาท', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface))),
          SizedBox(width: 60, child: Text('$count รายการ', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant))),
          const SizedBox(width: 4),
          isExporting
              ? Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(left: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RadiusSize.sm),
                    border: Border.all(color: colors.outline),
                  ),
                  child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    iconSize: IconSizes.md,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.sm),
                        side: BorderSide(color: count == 0 ? colors.outline.withValues(alpha: 0.5) : colors.outline),
                      ),
                      foregroundColor: BrandAccent.tealOn(context),
                      disabledForegroundColor: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    tooltip: 'ส่งออกแบบสรุปผลจัดซื้อจัดจ้าง (กวจ.)',
                    onPressed: count == 0 ? null : () => _exportMonthlySummary(row['monthIndex'] as int, monthLabel),
                  ),
                ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // ตรวจสอบ สตง.
  // ─────────────────────────────────────────

  Widget _buildReadinessReport(BuildContext context, ColorScheme colors) {
    final overallScore = _checklist.isEmpty
        ? 0.0
        : _checklist.map((c) => c.ratio).fold<double>(0, (a, b) => a + b) / _checklist.length;
    final scoreColor = overallScore > 0.8
        ? BrandAccent.green(context)
        : (overallScore > 0.5 ? BrandAccent.tertiary(context) : BrandAccent.red(context));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(RadiusSize.card),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircularProgressIndicator(value: overallScore, color: scoreColor, backgroundColor: scoreColor.withValues(alpha: 0.2), strokeWidth: 6),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${(overallScore * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: AppTypography.heading1, fontWeight: AppTypography.weightExtraBold, color: scoreColor)),
                      Text('Ready Score — ตรวจแค่ความครบถ้วนของข้อมูล', style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BrandAccent.tertiary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(RadiusSize.md),
              border: Border.all(color: BrandAccent.tertiary(context).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: BrandAccent.tertiary(context), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'คะแนนนี้ตรวจแค่ "ข้อมูลกรอกครบไหม" ไม่ใช่การรับรองความถูกต้องทางกฎหมาย โปรดตรวจสอบตามระเบียบพัสดุจริงอีกครั้งก่อนใช้อ้างอิง',
                    style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _checklist) _buildChecklistRow(context, colors, item),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(BuildContext context, ColorScheme colors, _ChecklistItem item) {
    final variant = item.ratio >= 1 ? BadgeVariant.success : (item.ratio > 0.5 ? BadgeVariant.warning : BadgeVariant.danger);
    final color = item.ratio >= 1 ? BrandAccent.green(context) : (item.ratio > 0.5 ? BrandAccent.tertiary(context) : BrandAccent.red(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(item.ratio >= 1 ? Icons.check_circle : Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(item.label, style: TextStyle(fontSize: AppTypography.body, color: colors.onSurface))),
          Text('${item.completed}/${item.total}', style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
          const SizedBox(width: 8),
          StatusBadge(label: '${(item.ratio * 100).toStringAsFixed(0)}%', variant: variant, compact: true),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Audit Trail
  // ─────────────────────────────────────────

  Widget _buildAuditTrail(BuildContext context, ColorScheme colors) {
    if (_auditLog.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_outlined, size: 64, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('ยังไม่มีประวัติการใช้งาน', style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4)),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: _auditLog.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: colors.outlineVariant),
        itemBuilder: (_, i) {
          final e = _auditLog[i];
          final variant = switch (e.action) {
            'สร้าง' => BadgeVariant.success,
            'ลบ' => BadgeVariant.danger,
            _ => BadgeVariant.warning,
          };
          return ListTile(
            dense: true,
            leading: StatusBadge(label: e.action, variant: variant, compact: true),
            title: Text('${e.tableLabel}: ${e.description}', style: TextStyle(fontSize: AppTypography.body, color: colors.onSurface),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${e.timestamp} · โดย ${e.userName ?? "-"}', style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
          );
        },
      ),
    );
  }
}

class _ChecklistItem {
  final String label;
  final int completed;
  final int total;
  _ChecklistItem(this.label, this.completed, this.total);
  double get ratio => total == 0 ? 1.0 : completed / total;
}
