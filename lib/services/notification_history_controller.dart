// notification_history_controller.dart
// ประวัติแจ้งเตือนแบบถาวร (ไม่หายเอง) แยกจาก toast ลอย (toast_service.dart)
// ที่หายไปเองใน 4-8 วินาที — งานเบื้องหลังที่ทำเสร็จแล้ว (import/export ฯลฯ)
// นอกจากจะขึ้น toast ชั่วคราวแล้ว ให้เก็บเข้าที่นี่ด้วย เพื่อให้ผู้ใช้กลับมาดู/
// กดย้อนหลังได้ ถ้าพลาดตอน toast หายไปแล้ว (คล้ายกระดิ่งแจ้งเตือนของเฟซบุ๊ก)

import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final IconData icon;
  final Color color;
  // mode string เดียวกับที่ NavigationRequestController ใช้ — กดแล้วพาไปหน้า
  // ที่เกี่ยวข้องได้เลย ถ้าไม่ระบุ กดแล้วแค่ปิดเมนู/mark อ่านแล้วเฉยๆ
  final String? navigateMode;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    this.navigateMode,
    this.read = false,
  });
}

class NotificationHistoryController extends ChangeNotifier {
  NotificationHistoryController._();
  static final NotificationHistoryController instance =
      NotificationHistoryController._();

  static const _maxItems = 30;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  void add({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String? navigateMode,
  }) {
    _items.insert(
      0,
      AppNotification(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        message: message,
        time: DateTime.now(),
        icon: icon,
        color: color,
        navigateMode: navigateMode,
      ),
    );
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1 || _items[idx].read) return;
    _items[idx].read = true;
    notifyListeners();
  }

  void markAllRead() {
    if (_items.every((n) => n.read)) return;
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
  }
}
