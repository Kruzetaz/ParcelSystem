import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/database.dart';
import 'data/procurement_repository.dart';
import 'models/procurement_form.dart';
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
      home: const TestScreen(),
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
    setState(() { _running = true; _logs.clear(); });

    void log(String msg) => setState(() => _logs.add(msg));

    try {
      // 1. สร้าง items ทดสอบ
      final items = [
        ProcurementItem(
          procurementNumber: 'ซ.1/2568',
          itemName: 'โต๊ะนักเรียน',
          quantity: '5',
          unitPrice: 1200,
        ),
        ProcurementItem(
          procurementNumber: 'ซ.1/2568',
          itemName: 'เก้าอี้นักเรียน',
          quantity: '10',
          unitPrice: 450,
        ),
      ];

      // 2. คำนวณราคารวม
      final subtotal = items.fold<double>(
        0, (sum, i) => sum + i.computedTotal,
      );
      final calc = CalcEngine.calcAll(subtotal);
      final bahtText = CalcEngine.bahtText(calc['current_order_price']!);

      log('📦 Items: ${items.length} รายการ');
      log('💰 ราคารวมก่อน VAT: ${subtotal.toStringAsFixed(2)} บาท');
      log('🧾 VAT 7%: ${calc['vat_amount']!.toStringAsFixed(2)} บาท');
      log('✂️  หัก ณ ที่จ่าย 3%: ${calc['tax_withholding_amount']!.toStringAsFixed(2)} บาท');
      log('💵 ยอดสุทธิ: ${calc['net_payable_amount']!.toStringAsFixed(2)} บาท');
      log('🔤 ตัวอักษร: $bahtText');
      log('─────────────────────');

      // 3. บันทึกลง SQLite
      final form = ProcurementForm(
        procurementNumber: 'ซ.1/2568',
        schoolName: 'โรงเรียนบ้านป่าลาน',
        projectName: 'จัดซื้อครุภัณฑ์ห้องเรียน',
        currentOrderPrice: calc['current_order_price'],
        totalPriceTh: bahtText,
        subtotalBeforeVat: calc['subtotal_before_vat'],
        vatAmount: calc['vat_amount'],
        taxWithholdingAmount: calc['tax_withholding_amount'],
        netPayableAmount: calc['net_payable_amount'],
      );

      await _repo.saveFormWithItems(form, items);
      log('✅ บันทึกลง SQLite สำเร็จ');

      // 4. อ่านกลับมายืนยัน
      final loaded = await _repo.getForm('ซ.1/2568');
      final loadedItems = await _repo.getItems('ซ.1/2568');
      log('📖 อ่านกลับ: ${loaded?.projectName}');
      log('📋 Items: ${loadedItems.length} รายการ');
      for (final i in loadedItems) {
        log('   • ${i.itemName} × ${i.quantity} = ${i.computedTotal.toStringAsFixed(2)} บาท');
      }
      log('─────────────────────');

      // 5. ทดสอบ search
      final results = await _repo.searchForms('ห้องเรียน');
      log('🔍 Search "ห้องเรียน": พบ ${results.length} รายการ');

      // 6. ทดสอบ bahtText เพิ่มเติม
      log('─────────────────────');
      log('🔤 ทดสอบ bahtText:');
      for (final n in [0, 1, 11, 21, 100, 1001, 5250.75, 1000000]) {
        log('   ${n} → ${CalcEngine.bahtText(n.toDouble())}');
      }

      log('─────────────────────');
      log('🎉 ทุกอย่างผ่านหมด พร้อมทำ UI!');
    } catch (e) {
      log('❌ Error: $e');
    }

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบระบบ DB + Calc'),
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
                        width: 16, height: 16,
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
