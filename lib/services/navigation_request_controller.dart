// navigation_request_controller.dart
// ขอสลับหน้าจากที่ไหนก็ได้นอก widget tree ของ AppShell (เช่น กด toast ลอยที่
// วางอยู่นอก AppShell ใน main.dart) — เก็บ mode string ที่ขอไว้ แล้วให้
// AppShell ฟังอยู่ผ่าน ChangeNotifier มาสลับหน้าจริงให้ (ผ่าน map เดียวกับที่
// ใช้กับ DashboardScreenV2.onNavigate อยู่แล้ว)

import 'package:flutter/material.dart';

class NavigationRequestController extends ChangeNotifier {
  NavigationRequestController._();
  static final NavigationRequestController instance =
      NavigationRequestController._();

  String? _pendingMode;

  void requestMode(String mode) {
    _pendingMode = mode;
    notifyListeners();
  }

  /// ดึง mode ที่ขอไว้มาใช้ครั้งเดียวแล้วล้างทิ้ง (กันสลับหน้าซ้ำถ้า listener
  /// ถูกเรียกมากกว่า 1 ครั้งจาก notifyListeners() เดียวกัน)
  String? consume() {
    final m = _pendingMode;
    _pendingMode = null;
    return m;
  }
}
