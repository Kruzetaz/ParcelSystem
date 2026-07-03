// dashboard_screen.dart
// หน้าแรกของแอป — แสดงรายการ procurement_orders ทั้งหมด ค้นหาได้ กดสร้างใหม่
// หรือกดที่แถวเพื่อแก้ไขของเดิม (เชื่อมกับ OrderWizardScreen ที่จะทำต่อไป)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import 'order_wizard_screen.dart';
import 'settings_screen.dart';
import 'budget_list_screen.dart';

const _brandColor = Color(0xFF1A3A5C);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ProcurementRepository();
  final _searchCtrl = TextEditingController();

  List<ProcurementOrder> _orders = [];
  bool _loading = true;
  String _query = '';

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
    if (!mounted) return;
    setState(() {
      _orders = orders;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('ระบบจัดซื้อจัดจ้าง'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'แผนงบประมาณ',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetListScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'ข้อมูลโรงเรียน',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('สร้างใหม่'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'ค้นหาเลขที่ / ชื่อโครงการ / ชื่อร้านค้า',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty ? 'ยังไม่มีเอกสารจัดซื้อจัดจ้าง' : 'ไม่พบผลการค้นหา',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(ProcurementOrder order) {
    final isCompleted = order.currentStatus == 'COMPLETED';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openWizard(existing: order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _statusBadge(isCompleted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.projectName?.isNotEmpty == true ? order.projectName! : '(ไม่มีชื่อโครงการ)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                  padding: const EdgeInsets.only(right: 16),
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
        color: isCompleted ? Colors.green : Colors.orange,
      ),
    );
  }
}