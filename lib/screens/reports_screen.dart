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
        {'month': _thaiMonths[m], 'count': monthlyCounts[m], 'total': monthlyTotals[m]},
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
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabSelector(colors),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : switch (_tab) {
                    _ReportTab.monthly => _buildMonthlyReport(colors),
                    _ReportTab.readiness => _buildReadinessReport(colors),
                    _ReportTab.auditTrail => _buildAuditTrail(colors),
                  },
          ),
        ],
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
            decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.summarize_outlined, color: colors.onPrimaryContainer),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ยอดใช้จ่ายสะสมทั้งปี', style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer)),
                    Text('${grandTotal.toStringAsFixed(2)} บาท',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onPrimaryContainer)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                for (final row in _monthlyRows) _buildMonthRow(colors, row, maxTotal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthRow(ColorScheme colors, Map<String, dynamic> row, double maxTotal) {
    final total = row['total'] as double;
    final ratio = maxTotal > 0 ? (total / maxTotal).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(row['month'] as String, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Stack(
              children: [
                Container(height: 18, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(height: 18, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text('${total.toStringAsFixed(2)} บาท', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
          SizedBox(width: 60, child: Text('${row['count']} รายการ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // ตรวจสอบ สตง.
  // ─────────────────────────────────────────

  Widget _buildReadinessReport(ColorScheme colors) {
    final overallScore = _checklist.isEmpty
        ? 0.0
        : _checklist.map((c) => c.ratio).fold<double>(0, (a, b) => a + b) / _checklist.length;
    final scoreColor = overallScore > 0.8 ? Colors.green : (overallScore > 0.5 ? Colors.orange : Colors.redAccent);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                CircularProgressIndicator(value: overallScore, color: scoreColor, backgroundColor: scoreColor.withValues(alpha: 0.2), strokeWidth: 6),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${(overallScore * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scoreColor)),
                      Text('Ready Score — ตรวจแค่ความครบถ้วนของข้อมูล', style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade700)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'คะแนนนี้ตรวจแค่ "ข้อมูลกรอกครบไหม" ไม่ใช่การรับรองความถูกต้องทางกฎหมาย โปรดตรวจสอบตามระเบียบพัสดุจริงอีกครั้งก่อนใช้อ้างอิง',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _checklist) _buildChecklistRow(colors, item),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(ColorScheme colors, _ChecklistItem item) {
    final color = item.ratio >= 1 ? Colors.green : (item.ratio > 0.5 ? Colors.orange : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(item.ratio >= 1 ? Icons.check_circle : Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13.5))),
          Text('${item.completed}/${item.total}', style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text('${(item.ratio * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Audit Trail
  // ─────────────────────────────────────────

  Widget _buildAuditTrail(ColorScheme colors) {
    if (_auditLog.isEmpty) {
      return Center(child: Text('ยังไม่มีประวัติการใช้งาน', style: TextStyle(color: colors.onSurfaceVariant)));
    }
    return ListView.separated(
      itemCount: _auditLog.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = _auditLog[i];
        final color = switch (e.action) {
          'สร้าง' => Colors.green,
          'ลบ' => Colors.redAccent,
          _ => Colors.orange,
        };
        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(e.action, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
          ),
          title: Text('${e.tableLabel}: ${e.description}', style: const TextStyle(fontSize: 13.5)),
          subtitle: Text('${e.timestamp} · โดย ${e.userName ?? "-"}', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
        );
      },
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
