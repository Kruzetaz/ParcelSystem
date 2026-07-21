// order_register_screen.dart
// "ทะเบียนคุมเลขที่จัดซื้อจัดจ้าง" — รวมรายการที่บันทึกไว้แล้วทั้งหมดในระบบ
// (ไม่ใช่ตารางแยกต่างหาก) มาแสดงเป็นทะเบียนคุม 2 ตาราง (จัดซื้อ/จัดจ้าง)
// ตามแบบฟอร์มราชการ — ดึงข้อมูลจาก procurement_orders โดยตรง ไม่ต้องกรอกซ้ำ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget.dart';
import '../models/procurement_order.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';

class OrderRegisterScreen extends StatefulWidget {
  const OrderRegisterScreen({super.key});
  @override
  State<OrderRegisterScreen> createState() => _OrderRegisterScreenState();
}

class _OrderRegisterScreenState extends State<OrderRegisterScreen> {
  final _repo = ProcurementRepository();
  List<ProcurementOrder> _orders = [];
  Map<int, Budget> _budgetsById = {};
  bool _loading = true;
  String? _fiscalYearFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repo.getAllOrders();
    final budgets = await _repo.getAllBudgets();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _budgetsById = {for (final b in budgets) if (b.id != null) b.id!: b};
      _loading = false;
    });
  }

  List<String> get _fiscalYears =>
      _orders.map((o) => o.fiscalYear).whereType<String>().where((s) => s.isNotEmpty).toSet().toList()..sort();

  List<ProcurementOrder> get _filtered =>
      _fiscalYearFilter == null ? _orders : _orders.where((o) => o.fiscalYear == _fiscalYearFilter).toList();

  List<ProcurementOrder> get _purchases => _filtered.where((o) => o.orderType != 'จ้าง').toList();
  List<ProcurementOrder> get _hires => _filtered.where((o) => o.orderType == 'จ้าง').toList();

  String? _projectLabel(ProcurementOrder o) {
    final budget = o.budgetId != null ? _budgetsById[o.budgetId] : null;
    if (budget?.projectName != null) return budget!.projectName;
    return o.projectName;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้ทะเบียนคุมเลขที่จัดซื้อจัดจ้าง',
      icon: Icons.numbers_outlined,
      steps: const [
        'หน้านี้ไม่ต้องกรอกข้อมูลซ้ำ — ดึงรายการที่บันทึกไว้แล้วในหน้า "สร้างใหม่"/"Easy Wizard" มาจัดเรียงเป็นทะเบียนคุมให้อัตโนมัติ',
        'แยกเป็น 2 ตารางตามแบบฟอร์มราชการ: "ทะเบียนคุมการจัดซื้อ" กับ "ทะเบียนคุมการจัดจ้าง" (แยกตามช่อง "ประเภท" ที่เลือกไว้ตอนสร้างรายการ)',
        'ใช้ตัวกรองปีงบประมาณด้านบนเพื่อดูเฉพาะปีที่ต้องการ',
        'ถ้ารายการไหนไม่มีเลขที่/วันที่บางช่อง แสดงว่ายังกรอกข้อมูลนั้นไม่ครบในหน้ารายการต้นทาง ให้ไปเติมที่นั่น ไม่ต้องแก้ในหน้านี้',
      ],
      corner: Alignment.bottomRight,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('ทะเบียนคุมเลขที่จัดซื้อจัดจ้าง',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.onSurface)),
                      const Spacer(),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _fiscalYearFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true, labelText: 'ปีงบประมาณ'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('ทั้งหมด')),
                            ..._fiscalYears.map((y) => DropdownMenuItem(value: y, child: Text('ปี $y'))),
                          ],
                          onChanged: (v) => setState(() => _fiscalYearFilter = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _orders.isEmpty
                        ? Center(
                            child: Text('ยังไม่มีรายการจัดซื้อจัดจ้างในระบบ',
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15)),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSection(colors, 'ทะเบียนคุมการจัดซื้อ', _purchases),
                                const SizedBox(height: 24),
                                _buildSection(colors, 'ทะเบียนคุมการจัดจ้าง', _hires),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(ColorScheme colors, String title, List<ProcurementOrder> orders) {
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant);
    final total = orders.fold<double>(0, (s, o) => s + (o.currentOrderPrice ?? 0));
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(10)),
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
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: colors.onPrimaryContainer)),
                const Spacer(),
                Text('${orders.length} รายการ · รวม ${formatBaht(total)} บาท',
                  style: TextStyle(fontSize: 12.5, color: colors.onPrimaryContainer)),
              ],
            ),
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('ไม่มีรายการ', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 1.5))),
                      child: Row(
                        children: [
                          SizedBox(width: 36, child: Text('ที่', style: headerStyle)),
                          SizedBox(width: 130, child: Text('เลขที่เอกสาร', style: headerStyle)),
                          Expanded(flex: 3, child: Text('รายการ/โครงการ', style: headerStyle)),
                          SizedBox(width: 150, child: Text('ผู้ขาย/ผู้รับจ้าง', style: headerStyle)),
                          SizedBox(width: 110, child: Text('จำนวนเงิน', style: headerStyle, textAlign: TextAlign.right)),
                          SizedBox(width: 100, child: Text('วันที่', style: headerStyle)),
                          SizedBox(width: 110, child: Text('ครบกำหนดส่งมอบ', style: headerStyle)),
                          SizedBox(width: 100, child: Text('วันตรวจรับ', style: headerStyle)),
                          SizedBox(width: 100, child: Text('วันส่งเบิกเงิน', style: headerStyle)),
                        ],
                      ),
                    ),
                    for (var i = 0; i < orders.length; i++) _buildRow(colors, i + 1, orders[i]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, int index, ProcurementOrder o) {
    final docNumber = o.orderNumber ?? o.procurementNumber ?? '-';
    final itemLabel = _projectLabel(o) ?? o.procurementSubject ?? '(ไม่มีชื่อรายการ)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('$index', style: const TextStyle(fontSize: 12.5))),
          SizedBox(width: 130, child: Text(docNumber, style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(itemLabel, style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 150, child: Text(o.vendorName ?? '-', style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 110, child: Text(o.currentOrderPrice != null ? formatBaht(o.currentOrderPrice) : '-', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
          SizedBox(width: 100, child: Text(o.dateOrderCreated ?? '-', style: const TextStyle(fontSize: 12))),
          SizedBox(width: 110, child: Text(o.dateDeadline ?? '-', style: const TextStyle(fontSize: 12))),
          SizedBox(width: 100, child: Text(o.dateInspection ?? '-', style: const TextStyle(fontSize: 12))),
          SizedBox(width: 100, child: Text(o.dateDisbursement ?? '-', style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
