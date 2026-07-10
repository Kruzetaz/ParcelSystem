// tab4_items_screen.dart
// หน้าจอสำหรับทดสอบ ItemsTableEditor แบบเดี่ยวๆ ก่อนเอาไปฝังใน Wizard จริง
// สลับ home: ใน main.dart มาเป็น Tab4TestScreen() ชั่วคราวเพื่อทดสอบได้เลย

import 'package:flutter/material.dart';
import '../models/procurement_item.dart';
import '../widgets/items_table_editor.dart';

class Tab4TestScreen extends StatefulWidget {
  const Tab4TestScreen({super.key});

  @override
  State<Tab4TestScreen> createState() => _Tab4TestScreenState();
}

class _Tab4TestScreenState extends State<Tab4TestScreen> {
  List<ProcurementItem> _items = [];
  double _subtotal = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tab 4 — รายการพัสดุ'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ItemsTableEditor(
                      onChanged: (items, subtotal) {
                        setState(() {
                          _items = items;
                          _subtotal = subtotal;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // แผงตรวจสอบผลลัพธ์ real-time ที่ parent ได้รับจาก callback
                // (เอาไว้ debug ตอนนี้ — ตอนต่อ wizard จริงค่อยเอาออก)
                Card(
                  color: colors.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ข้อมูลที่ parent ได้รับ (debug)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text('จำนวนรายการที่ valid: ${_items.length}'),
                        Text('Subtotal: ${_subtotal.toStringAsFixed(2)} บาท'),
                        const SizedBox(height: 8),
                        for (final item in _items)
                          Text(
                            '• ${item.itemName}: ${item.quantityDisplay} × '
                            '${item.unitPrice.toStringAsFixed(2)} = '
                            '${item.computedTotal.toStringAsFixed(2)} บาท',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          ),
                      ],
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
}