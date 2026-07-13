// dashboard_screen.dart
// เนื้อหาหน้าแรกของแอป — แสดงรายการ procurement_orders ทั้งหมด ค้นหาได้
// [AppShell]: ไม่มี Scaffold/AppBar/FAB ของตัวเองแล้ว เพราะถูกวาดอยู่ในพื้นที่ขวา
// ของ AppShell เสมอ — AppBar ย้ายไปอยู่ระดับ shell แทน
// การสร้างใหม่/แก้ไขเอกสาร ใช้ callback ที่ shell ส่งมาให้ แทน Navigator.push เดิม
//
// [Dashboard v2/v3]: มี KPI 4 การ์ด, filter tabs (ทั้งหมด/ร่าง/เสร็จแล้ว),
// progress bar ในการ์ดแต่ละใบ, ธีมน้ำเงิน-ทอง-เทาอ่อน

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../models/budget.dart';
import '../models/school_settings.dart';
import 'app_sidebar.dart' show AppMode;
import '../services/toast_service.dart';

enum _OrderFilter { all, draft, completed }

class DashboardScreen extends StatefulWidget {
  final VoidCallback onCreateNew;
  final void Function(ProcurementOrder order) onEditOrder;
  // ให้ quick-action grid สลับไปหน้าแผนงบ/ตั้งค่าโรงเรียนได้ตรงๆ โดยไม่ต้องผ่าน sidebar
  final void Function(AppMode mode) onNavigate;

  const DashboardScreen({
    super.key,
    required this.onCreateNew,
    required this.onEditOrder,
    required this.onNavigate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ProcurementRepository();
  final _searchCtrl = TextEditingController();

  List<ProcurementOrder> _orders = [];
  List<Budget> _budgets = [];
  SchoolSettings? _school;
  bool _loading = true;
  String _query = '';
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders =
        _query.trim().isEmpty ? await _repo.getAllOrders() : await _repo.searchOrders(_query.trim());
    final budgets = await _repo.getAllBudgets();
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _budgets = budgets;
      _school = school;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(ProcurementOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'ต้องการลบเอกสาร "${order.procurementNumber ?? '(ไม่มีเลขที่)'} '
          '${order.projectName ?? ''}" ใช่หรือไม่?\nรายการพัสดุทั้งหมดในเอกสารนี้จะถูกลบไปด้วย',
        ),
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
    if (confirmed == true && order.id != null) {
      try {
        await _repo.deleteOrder(order.id!);
        if (!mounted) return;
        _load();
      } catch (e) {
        if (!mounted) return;
        showAppToast('ลบเอกสารไม่สำเร็จ: $e', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────
  // KPI คำนวณจาก _orders + _budgets ที่โหลดไว้แล้ว (ไม่ query ใหม่)
  // ─────────────────────────────────────────

  int get _draftCount => _orders.where((o) => o.currentStatus != 'COMPLETED').length;

  int get _completedCount => _orders.where((o) => o.currentStatus == 'COMPLETED').length;

  double get _totalSpent => _orders
      .where((o) => o.currentStatus == 'COMPLETED')
      .fold(0.0, (sum, o) => sum + (o.currentOrderPrice ?? 0));

  double get _totalRemainingBudget =>
      _budgets.fold(0.0, (sum, b) => sum + (b.remainingAmount ?? 0));

  /// ปีงบประมาณล่าสุด หา mode (ปีที่มีเอกสารเยอะสุด) ถ้าเสมอกันเลือกปีมากสุด
  String? get _currentFiscalYear {
    if (_orders.isEmpty) return null;
    final counts = <String, int>{};
    for (final o in _orders) {
      final y = o.fiscalYear;
      if (y == null || y.isEmpty) continue;
      counts[y] = (counts[y] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final topYears = counts.entries.where((e) => e.value == maxCount).map((e) => e.key).toList()
      ..sort();
    return topYears.last;
  }

  int get _currentFiscalYearCount {
    final year = _currentFiscalYear;
    if (year == null) return 0;
    return _orders.where((o) => o.fiscalYear == year).length;
  }

  List<ProcurementOrder> get _filteredOrders {
    switch (_filter) {
      case _OrderFilter.draft:
        return _orders.where((o) => o.currentStatus != 'COMPLETED').toList();
      case _OrderFilter.completed:
        return _orders.where((o) => o.currentStatus == 'COMPLETED').toList();
      case _OrderFilter.all:
        return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroBanner(colors),
                      const SizedBox(height: 20),
                      _buildKpiRow(colors),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFilterTabs(colors),
                                const SizedBox(height: 14),
                                _buildSearchBar(),
                                const SizedBox(height: 18),
                                _buildList(colors),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(width: 190, child: _buildQuickActionsPanel(colors)),
                        ],
                      ),
                      // เผื่อพื้นที่ด้านล่างไม่ให้ FAB ลอยทับรายการสุดท้าย
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: widget.onCreateNew,
            backgroundColor: colors.tertiary,
            foregroundColor: colors.onTertiary,
            icon: const Icon(Icons.add),
            label: const Text('สร้างใหม่', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // HERO BANNER — ชื่อโรงเรียน + ตัวเลขสรุปใหญ่ + วงกลม % ความคืบหน้ารวม
  // ─────────────────────────────────────────

  Widget _buildHeroBanner(ColorScheme colors) {
    final total = _orders.length;
    final ratio = total == 0 ? 0.0 : _completedCount / total;
    final schoolName = _school?.schoolName?.isNotEmpty == true
        ? _school!.schoolName!
        : 'ยังไม่ได้กรอกชื่อโรงเรียน';
    final fiscalYear = _currentFiscalYear;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(colors.primary, Colors.black, 0.35)!, colors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          final schoolBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, color: colors.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      schoolName,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fiscalYear == null ? 'ยังไม่มีข้อมูลปีงบประมาณ' : 'ปีงบประมาณ $fiscalYear',
                style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.6), fontSize: 12.5),
              ),
            ],
          );

          final statsRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _heroStat(colors, '$total', 'เอกสารทั้งหมด'),
              _heroStatDivider(colors),
              _heroStat(colors, '$_draftCount', 'ร่าง', valueColor: Colors.grey.shade300),
              _heroStatDivider(colors),
              _heroStat(colors, '$_completedCount', 'เสร็จแล้ว', valueColor: Colors.green.shade300),
              _heroStatDivider(colors),
              _heroStat(colors, _formatBaht(_totalSpent), 'ยอดใช้จ่าย', valueColor: Colors.amber.shade300),
            ],
          );

          final ring = _buildProgressRing(colors, ratio);

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: schoolBlock),
                    ring,
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: statsRow,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    schoolBlock,
                    const SizedBox(height: 20),
                    statsRow,
                  ],
                ),
              ),
              const SizedBox(width: 24),
              ring,
            ],
          );
        },
      ),
    );
  }

  Widget _heroStat(ColorScheme colors, String value, String label, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? colors.onPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.6), fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _heroStatDivider(ColorScheme colors) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: colors.onPrimary.withValues(alpha: 0.15),
    );
  }

  /// วงกลมแสดง % เอกสารที่เสร็จสมบูรณ์เทียบกับทั้งหมด วาดเองด้วย CustomPainter
  /// (ไม่ใช้ CircularProgressIndicator ตรงๆ เพราะต้องคุมความหนาเส้น/ปลายมน/
  /// สีพื้นหลังวงในให้ตรงกับดีไซน์ hero banner)
  Widget _buildProgressRing(ColorScheme colors, double ratio) {
    final pct = (ratio * 100).toStringAsFixed(0);
    return SizedBox(
      width: 84,
      height: 84,
      child: CustomPaint(
        painter: _ProgressRingPainter(ratio: ratio, trackColor: colors.onPrimary, progressColor: Colors.amber.shade300),
        child: Center(
          child: Text(
            '$pct%',
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // QUICK ACTIONS — ทางลัด 4 ปุ่ม (ทำหน้าที่เหมือนเมนูใน sidebar แต่เป็น
  // icon grid ให้กดถึงเร็วกว่าตอนอยู่หน้า dashboard)
  // ─────────────────────────────────────────

  Widget _buildQuickActionsPanel(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เมนูด่วน',
            style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _quickActionTile(
                colors: colors,
                icon: Icons.add_circle_outline,
                label: 'สร้างใหม่',
                onTap: widget.onCreateNew,
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.account_balance_wallet_outlined,
                label: 'แผนงบ',
                onTap: () => widget.onNavigate(AppMode.budgets),
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.settings_outlined,
                label: 'ตั้งค่า',
                onTap: () => widget.onNavigate(AppMode.settings),
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.auto_awesome_outlined,
                label: 'ตั้งค่า AI',
                onTap: () => widget.onNavigate(AppMode.aiSettings),
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.refresh,
                label: 'รีเฟรช',
                onTap: _load,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required ColorScheme colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: colors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // KPI ROW — 4 การ์ด
  // ─────────────────────────────────────────

  Widget _buildKpiRow(ColorScheme colors) {
    if (_loading && _orders.isEmpty) {
      return const SizedBox(height: 96);
    }

    final fiscalYear = _currentFiscalYear;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final cards = [
          _KpiCard(
            icon: Icons.description_outlined,
            iconColor: colors.primary,
            label: 'เอกสารทั้งหมด',
            value: '${_orders.length}',
            subLabel: 'ร่าง $_draftCount · เสร็จ $_completedCount',
          ),
          _KpiCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green.shade700,
            label: 'เสร็จสมบูรณ์',
            value: '$_completedCount',
            subLabel: _orders.isEmpty
                ? '-'
                : '${(_completedCount / _orders.length * 100).toStringAsFixed(0)}% ของทั้งหมด',
          ),
          _KpiCard(
            icon: Icons.payments_outlined,
            iconColor: colors.tertiary,
            label: 'ยอดใช้จ่ายรวม',
            value: _formatBaht(_totalSpent),
            subLabel: 'เฉพาะเอกสารที่เสร็จแล้ว',
            highlight: true,
          ),
          _KpiCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: colors.primary,
            label: 'งบประมาณคงเหลือ',
            value: _formatBaht(_totalRemainingBudget),
            subLabel: fiscalYear == null
                ? 'ปีงบฯ $_currentFiscalYearCount รายการ'
                : 'ปีงบฯ $fiscalYear · $_currentFiscalYearCount รายการ',
          ),
        ];

        if (isNarrow) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < cards.length ? 12 : 0),
                  child: Row(
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: 12),
                      if (i + 1 < cards.length) Expanded(child: cards[i + 1]) else const Spacer(),
                    ],
                  ),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  String _formatBaht(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$buf บาท';
  }

  // ─────────────────────────────────────────
  // FILTER TABS
  // ─────────────────────────────────────────

  Widget _buildFilterTabs(ColorScheme colors) {
    Widget chip(String label, _OrderFilter value) {
      final selected = _filter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        labelStyle: TextStyle(
          color: selected ? colors.onPrimary : colors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: selected ? 2 : 0,
        shadowColor: colors.primary.withValues(alpha: 0.3),
      );
    }

    return Row(
      children: [
        chip('ทั้งหมด', _OrderFilter.all),
        const SizedBox(width: 8),
        chip('ร่าง', _OrderFilter.draft),
        const SizedBox(width: 8),
        chip('เสร็จแล้ว', _OrderFilter.completed),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'ค้นหาเลขที่ / ชื่อโครงการ / ชื่อร้านค้า',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    _query = '';
                    _load();
                  },
                ),
        ),
        onSubmitted: (v) {
          _query = v;
          _load();
        },
        onChanged: (v) => _query = v,
      ),
    );
  }

  Widget _buildList(ColorScheme colors) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final filtered = _filteredOrders;

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? 'ไม่พบผลการค้นหา'
                    : _orders.isEmpty
                        ? 'ยังไม่มีเอกสารจัดซื้อจัดจ้าง'
                        : 'ไม่มีเอกสารในหมวดนี้',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // หน้าเลื่อนได้ทั้งหน้าแล้ว (SingleChildScrollView ใน build()) จึงไม่ต้อง
    // ใช้ ListView/RefreshIndicator ซ้อนตรงนี้อีกชั้น — ป้องกันปัญหา nested
    // scrollable ที่เคยทำให้ overflow ตอนหน้าต่างเตี้ย
    return Column(
      children: [
        for (int i = 0; i < filtered.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildOrderCard(colors, filtered[i]),
        ],
      ],
    );
  }

  Widget _buildOrderCard(ColorScheme colors, ProcurementOrder order) {
    final isCompleted = order.currentStatus == 'COMPLETED';
    final progress = order.progressPercent.clamp(0.0, 1.0);
    final progressPct = (progress * 100).toStringAsFixed(0);
    final isNearlyDone = !isCompleted && progress >= 0.7;

    final progressColor = isCompleted
        ? Colors.green.shade600
        : isNearlyDone
            ? colors.tertiary
            : colors.primary;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onEditOrder(order),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _statusBadge(colors, isCompleted),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.projectName?.isNotEmpty == true
                                ? order.projectName!
                                : '(ไม่มีชื่อโครงการ)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (order.procurementNumber?.isNotEmpty == true) order.procurementNumber,
                              if (order.vendorName?.isNotEmpty == true) order.vendorName,
                            ].join('  •  '),
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (order.currentOrderPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${order.currentOrderPrice!.toStringAsFixed(2)} บาท',
                          style: TextStyle(fontWeight: FontWeight.w600, color: colors.primary),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'ลบ',
                      onPressed: () => _confirmDelete(order),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: colors.outlineVariant,
                          color: progressColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$progressPct%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(ColorScheme colors, bool isCompleted) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? Colors.green : colors.tertiary,
      ),
    );
  }
}

// ─────────────────────────────────────────
// KPI CARD widget
// ─────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subLabel;
  final bool highlight;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subLabel,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: highlight ? Border.all(color: colors.tertiary.withValues(alpha: 0.4), width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subLabel,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// วงกลม % ความคืบหน้าบน hero banner — พื้นวงเป็นสีขาวจาง เส้น progress สีทอง
// ปลายมน วาดเริ่มจากตำแหน่ง 12 นาฬิกา ตามเข็มนาฬิกา
// ─────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double ratio;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({required this.ratio, required this.trackColor, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * ratio.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}