import 'screens/tab4_items_screen.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/database.dart';
import 'data/procurement_repository.dart';
import 'models/budget.dart';
import 'models/procurement_order.dart';
import 'models/procurement_item.dart';
import 'utils/calc_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await AppDatabase.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบจัดซื้อจัดจ้าง',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3A5C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Tab4TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _repo = ProcurementRepository();
  final _logs = <String>[];
  bool _running = false;

  Future<void> _runTest() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    void log(String msg) => setState(() => _logs.add(msg));

    try {
      // 1. สร้างแผนงบประมาณ (budgets) ก่อน — ตาม schema ใหม่
      final budgetId = await _repo.insertBudget(
        const Budget(
          fiscalYear: '2569',
          groupName: 'บริหารงานวิชาการ',
          projectName: 'จัดซื้อครุภัณฑ์ห้องเรียน',
          activityName: 'พัฒนาห้องเรียนดิจิทัล',
          egpNumber: 'EGP69000123',
          allocatedAmount: 50000,
          remainingAmount: 50000,
          responsiblePerson: 'ครูจริยา',
        ),
      );
      log('🏦 สร้างแผนงบประมาณ id=$budgetId');
      log('─────────────────────');

      // 2. สร้าง items ทดสอบ — quantity เป็นตัวเลขล้วนแล้ว (แก้บั๊กเดิม)
      final items = [
        ProcurementItem(
          itemName: 'โต๊ะนักเรียน',
          quantity: 5,
          unit: 'ตัว',
          unitPrice: 1200,
        ),
        ProcurementItem(
          itemName: 'เก้าอี้นักเรียน',
          quantity: 10,
          unit: 'ตัว',
          unitPrice: 450,
        ),
      ];

      // 3. คำนวณราคารวม — computedTotal คูณตรงจากตัวเลขแล้ว ไม่ parse ข้อความ
      final subtotal = items.fold<double>(0, (sum, i) => sum + i.computedTotal);
      final calc = CalcEngine.calcAll(subtotal);
      final bahtText = CalcEngine.bahtText(calc['current_order_price']!);

      log('📦 Items: ${items.length} รายการ');
      for (final i in items) {
        log('   • ${i.itemName}: ${i.quantityDisplay} × ${i.unitPrice} = ${i.computedTotal.toStringAsFixed(2)} บาท');
      }
      log('💰 ราคารวมก่อน VAT: ${subtotal.toStringAsFixed(2)} บาท');
      log('🧾 VAT 7%: ${calc['vat_amount']!.toStringAsFixed(2)} บาท');
      log('✂️  หัก ณ ที่จ่าย: ${calc['tax_withholding_amount']!.toStringAsFixed(2)} บาท');
      log('💵 ยอดสุทธิ: ${calc['net_payable_amount']!.toStringAsFixed(2)} บาท');
      log('🔤 ตัวอักษร: $bahtText');
      log('─────────────────────');

      // 4. บันทึก order + items พร้อมกัน — ผูกกับ budgetId ที่สร้างไว้
      final order = ProcurementOrder(
        budgetId: budgetId,
        fiscalYear: '2569',
        orderType: 'ซื้อ',
        procurementNumber: 'ซ.1/2569',
        projectName: 'จัดซื้อครุภัณฑ์ห้องเรียน',
        currentOrderPrice: calc['current_order_price'],
        totalPriceTh: bahtText,
        subtotalBeforeVat: calc['subtotal_before_vat'],
        vatAmount: calc['vat_amount'],
        taxWithholdingAmount: calc['tax_withholding_amount'],
        netPayableAmount: calc['net_payable_amount'],
      );

      final orderId = await _repo.saveOrderWithItems(order, items);
      log('✅ บันทึกลง SQLite สำเร็จ (order id=$orderId)');

      // 5. อ่านกลับมายืนยัน
      final loaded = await _repo.getOrder(orderId);
      final loadedItems = await _repo.getItems(orderId);
      log('📖 อ่านกลับ: ${loaded?.projectName}');
      log('📋 Items: ${loadedItems.length} รายการ');
      for (final i in loadedItems) {
        log('   • ${i.itemName} × ${i.quantityDisplay} = ${i.computedTotal.toStringAsFixed(2)} บาท');
      }
      log('─────────────────────');

      // 6. ทดสอบ search
      final results = await _repo.searchOrders('ห้องเรียน');
      log('🔍 Search "ห้องเรียน": พบ ${results.length} รายการ');

      // 7. ทดสอบ budgets query
      final budgets = await _repo.getAllBudgets(fiscalYear: '2569');
      log('🏦 แผนงบประมาณปี 2569: พบ ${budgets.length} รายการ');

      log('─────────────────────');
      log('🎉 ทุกอย่างผ่านหมด พร้อมทำ UI!');
    } catch (e, st) {
      log('❌ Error: $e');
      log('$st');
    }

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบระบบ DB + Calc (schema v2)'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _running ? null : _runTest,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_running ? 'กำลังทดสอบ...' : 'รันทดสอบ'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'กด "รันทดสอบ" เพื่อตรวจสอบระบบ',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[i],
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: _logs[i].startsWith('❌')
                              ? Colors.red
                              : _logs[i].startsWith('🎉')
                                  ? Colors.green
                                  : null,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}