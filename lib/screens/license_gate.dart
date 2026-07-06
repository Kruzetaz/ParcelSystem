// license_gate.dart
// Widget ที่นั่งอยู่หน้า DashboardScreen — ตรวจ license ตอนเปิดแอป
// ถ้า valid → ไป Dashboard, ถ้าไม่ valid → ไป ActivationScreen

import 'package:flutter/material.dart';
import '../services/license_service.dart';
import 'activation_screen.dart';
import 'dashboard_screen.dart';

class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final result = await LicenseService.instance.checkOnStartup();
    if (!mounted) return;

    if (result.isValid) {
      _goToDashboard();
    } else {
      _goToActivation(reason: result.errorReason);
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _goToActivation({String? reason}) async {
    final result = await Navigator.of(context).push<LicenseResult>(
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
    );

    if (!mounted) return;

    if (result != null && result.isValid) {
      _goToDashboard();
    } else {
      // ถ้ากด back หรือ activate ไม่สำเร็จ → แสดงหน้า activation ซ้ำ
      // (ปิดแอปได้อย่างเดียว)
      _goToActivation();
    }
  }

  @override
  Widget build(BuildContext context) {
    // แสดง loading ระหว่างเช็ก license
    return const Scaffold(
      backgroundColor: Color(0xFF1A3A5C),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 24),
            Text(
              'กำลังตรวจสอบ License...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}