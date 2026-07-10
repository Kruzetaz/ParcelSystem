// toast_service.dart
// การแจ้งเตือนแบบ "ซ้อนกันได้หลายอัน" — ต่างจาก ScaffoldMessenger.showSnackBar
// เดิมที่ต้องรอให้อันก่อนหน้าหายไปก่อนถึงจะขึ้นอันถัดไป ถ้ากดรัวๆ (เช่นกดปุ่ม
// ทดสอบการเชื่อมต่อหลายครั้งติดกัน) ข้อความจะเรียงต่อคิวกันยาว ใช้ตัวนี้แทนเพื่อ
// ให้ทุกข้อความขึ้นพร้อมกันได้ แต่ละอันหายไปเองตามเวลาของตัวเอง
//
// จำกัดไว้ไม่เกิน [maxVisible] อันพร้อมกัน — ถ้ามีเกิน อันเก่าสุดจะค่อยๆ จางหาย
// (ไม่ใช่หายวับทันที) ก่อนถูกลบออกจริง กันไม่ให้เต็มจอเวลากดรัวๆ

import 'package:flutter/material.dart';

class ToastItem {
  final String id;
  final String message;
  final bool isError;
  bool removing;
  ToastItem({
    required this.id,
    required this.message,
    required this.isError,
    this.removing = false,
  });
}

class ToastController extends ChangeNotifier {
  ToastController._();
  static final ToastController instance = ToastController._();

  static const maxVisible = 2;
  static const _fadeDuration = Duration(milliseconds: 250);

  final List<ToastItem> _items = [];
  List<ToastItem> get items => List.unmodifiable(_items);

  void show(String message, {bool isError = false}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _items.add(ToastItem(id: id, message: message, isError: isError));
    _enforceLimit();
    notifyListeners();
    final duration = isError ? const Duration(seconds: 8) : const Duration(seconds: 4);
    Future.delayed(duration, () => dismiss(id));
  }

  /// เกิน maxVisible แล้ว → ให้อันเก่าสุด (ที่ยังไม่ได้เริ่มจางอยู่) เริ่มจางหายทีละอัน
  void _enforceLimit() {
    final stillVisible = _items.where((t) => !t.removing).toList();
    final overflow = stillVisible.length - maxVisible;
    for (var i = 0; i < overflow; i++) {
      _fadeOutAndRemove(stillVisible[i].id);
    }
  }

  void dismiss(String id) => _fadeOutAndRemove(id);

  void _fadeOutAndRemove(String id) {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1 || _items[idx].removing) return;
    _items[idx].removing = true;
    notifyListeners();
    Future.delayed(_fadeDuration, () {
      _items.removeWhere((t) => t.id == id);
      notifyListeners();
    });
  }
}

/// เรียกจากที่ไหนก็ได้ในแอป แทน ScaffoldMessenger.of(context).showSnackBar(...)
void showAppToast(String message, {bool isError = false}) {
  ToastController.instance.show(message, isError: isError);
}
