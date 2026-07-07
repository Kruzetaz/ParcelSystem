// dashboard_screen.dart
// หน้าแรกของแอป — แสดงรายการ procurement_orders ทั้งหมด ค้นหาได้ กดสร้างใหม่
// หรือกดที่แถวเพื่อแก้ไขของเดิม (เชื่อมกับ OrderWizardScreen)
//
// [Dashboard v2 - กรกฎาคม 2569]: เพิ่ม KPI 4 การ์ด, filter tabs (ทั้งหมด/ร่าง/เสร็จแล้ว),
// progress bar ในการ์ดแต่ละใบ, ปรับ theme เล็กน้อย
// [Dashboard v3 - กรกฎาคม 2569]: ปรับโทนสีเป็นน้ำเงิน-ทอง-เทาอ่อน เพิ่มเงาให้การ์ด
// แทนเส้นขอบเรียบ ปรับ spacing ให้อ่านง่ายขึ้น, progress bar ใช้สีทองตอนใกล้เสร็จ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../models/budget.dart';
import 'order_wizard_screen.dart';
import 'settings_screen.dart';
import 'budget_list_screen.dart';

const _brandColor = Color(0xFF1A3A5C); // น้ำเงินหลัก
const _goldAccent = Color(0xFFC9A227); // ทอง — ใช้เน้นจุดสำคัญ/ใกล้เสร็จ
const _bgColor = Color(0xFFF5F6F8); // เทาอ่อน — พื้นหลังหลัก

enum _OrderFilter { all, draft, completed }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ProcurementRepository();
  final _searchCtrl = TextEditingController();

  List<ProcurementOrder> _orders = [];
  List<Budget> _budgets = [];
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
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _budgets = budgets;
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
      await _repo.deleteOrder(order.id!);
      _load();
    }
  }

  Future<void> _openWizard({ProcurementOrder? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OrderWizardScreen(existingOrder: existing)),
    );
    if (saved == true) _load();
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
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('ระบบจัดซื้อจัดจ้าง'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _appBarIconButton(
            tooltip: 'แผนงบประมาณ',
            icon: Icons.account_balance_wallet_outlined,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetListScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
          _appBarIconButton(
            tooltip: 'ข้อมูลโรงเรียน',
            icon: Icons.settings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(),
        backgroundColor: _goldAccent,
        foregroundColor: _brandColor,
        icon: const Icon(Icons.add),
        label: const Text('สร้างใหม่', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKpiRow(),
                const SizedBox(height: 24),
                _buildFilterTabs(),
                const SizedBox(height: 14),
                _buildSearchBar(),
                const SizedBox(height: 18),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่มไอคอนมุมขวาบน — พื้นหลังวงกลมจางๆ ให้ดูเป็นกลุ่มปุ่มมากกว่าไอคอนลอยเดี่ยวๆ
  Widget _appBarIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // KPI ROW — 4 การ์ด
  // ─────────────────────────────────────────

  Widget _buildKpiRow() {
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
            iconColor: _brandColor,
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
            iconColor: _goldAccent,
            label: 'ยอดใช้จ่ายรวม',
            value: _formatBaht(_totalSpent),
            subLabel: 'เฉพาะเอกสารที่เสร็จแล้ว',
            highlight: true,
          ),
          _KpiCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: Colors.teal.shade700,
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

  Widget _buildFilterTabs() {
    Widget chip(String label, _OrderFilter value) {
      final selected = _filter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: _brandColor,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(color: selected ? _brandColor : Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: selected ? 2 : 0,
        shadowColor: _brandColor.withOpacity(0.3),
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
            color: Colors.black.withOpacity(0.04),
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
          filled: true,
          fillColor: Colors.white,
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

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredOrders;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty
                  ? 'ไม่พบผลการค้นหา'
                  : _orders.isEmpty
                      ? 'ยังไม่มีเอกสารจัดซื้อจัดจ้าง'
                      : 'ไม่มีเอกสารในหมวดนี้',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildOrderCard(filtered[index]),
      ),
    );
  }

  Widget _buildOrderCard(ProcurementOrder order) {
    final isCompleted = order.currentStatus == 'COMPLETED';
    final progress = order.progressPercent.clamp(0.0, 1.0);
    final progressPct = (progress * 100).toStringAsFixed(0);
    final isNearlyDone = !isCompleted && progress >= 0.7;

    final progressColor = isCompleted
        ? Colors.green.shade600
        : isNearlyDone
            ? _goldAccent
            : _brandColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openWizard(existing: order),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _statusBadge(isCompleted),
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
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                          style: const TextStyle(fontWeight: FontWeight.w600, color: _brandColor),
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
                          backgroundColor: Colors.grey.shade200,
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
                          color: Colors.grey.shade600,
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

  Widget _statusBadge(bool isCompleted) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? Colors.green : _goldAccent,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: highlight ? Border.all(color: _goldAccent.withOpacity(0.4), width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _brandColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}