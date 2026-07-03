// order_wizard_screen.dart
// STUB ชั่วคราว — ยังไม่ใช่ wizard เต็ม แค่ให้ Dashboard เรียกแล้ว compile ผ่าน
// ขั้นต่อไปจะเติม Tab 1-5 จริงเข้ามาแทนที่เนื้อหาในนี้
// (Tab 4 ที่ทำไว้แล้ว — ItemsTableEditor — จะถูกเอามาฝังในนี้ตอนนั้น)

import 'package:flutter/material.dart';
import '../models/procurement_order.dart';

class OrderWizardScreen extends StatelessWidget {
  final ProcurementOrder? existingOrder;

  const OrderWizardScreen({super.key, this.existingOrder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(existingOrder == null ? 'สร้างเอกสารใหม่' : 'แก้ไขเอกสาร'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              existingOrder == null
                  ? 'Wizard สร้างเอกสารใหม่ (Tab 1-5)\nยังไม่ได้สร้าง — ขั้นตอนถัดไป'
                  : 'แก้ไขเอกสาร id=${existingOrder!.id}\nWizard ยังไม่ได้สร้าง — ขั้นตอนถัดไป',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('กลับไป Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}