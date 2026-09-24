// toast_service.dart
// การแจ้งเตือนแบบ "ซ้อนกันได้หลายอัน" — ต่างจาก ScaffoldMessenger.showSnackBar
// เดิมที่ต้องรอให้อันก่อนหน้าหายไปก่อนถึงจะขึ้นอันถัดไป ถ้ากดรัวๆ (เช่นกดปุ่ม
// ทดสอบการเชื่อมต่อหลายครั้งติดกัน) ข้อความจะเรียงต่อคิวกันยาว ใช้ตัวนี้แทนเพื่อ
// ให้ทุกข้อความขึ้นพร้อมกันได้ แต่ละอันหายไปเองตามเวลาของตัวเอง
//
// จำกัดไว้ไม่เกิน [maxVisible] อันพร้อมกัน — ถ้ามีเกิน อันเก่าสุดจะค่อยๆ จางหาย
// (ไม่ใช่หายวับทันที) ก่อนถูกลบออกจริง กันไม่ให้เต็มจอเวลากดรัวๆ
//
// [เพิ่ม toast แบบ "กำลังทำงาน"]: งานเบื้องหลังบางอย่าง (import/export,
// ให้ AI อ่านไฟล์ ฯลฯ) ใช้เวลานานและห้ามผู้ใช้สลับหน้าจอไปทำอย่างอื่นระหว่างรอ
// (เช่น ฟอร์มที่ยังกรอกค้างอยู่จะหาย) — toast ปกติหายเองตามเวลาคงที่ ไม่พอสำหรับ
// เคสนี้ จึงเพิ่ม showLoading()/complete()/dismiss() ให้เรียกเป็นคู่ได้:
// เริ่มงานเรียก showLoading() เก็บ id ไว้ พองานเสร็จเรียก complete(id, ...)
// เพื่อเปลี่ยนเป็นผลสำเร็จ/ล้มเหลวแล้วค่อยหายเองตามปกติ

import 'package:flutter/material.dart';
import 'notification_history_controller.dart';

enum ToastType { success, error, warning, info, loading }

class ToastItem {
  final String id;
  String title;
  String message;
  ToastType type;
  // toast แบบ loading ไม่มีตัวจับเวลาหายเอง ต้องเรียก complete()/dismiss() เอง
  bool persistent;
  bool removing;
  // กดที่ตัว toast แล้วพาไปหน้าที่เกี่ยวข้องได้ (เช่น toast "กำลังนำเข้าโครงการ
  // เก่า" กดแล้วพาไปหน้าทะเบียนคุมเลขที่ที่ผลลัพธ์จะไปโผล่) — ไม่บังคับมี
  final VoidCallback? onTap;

  ToastItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.persistent = false,
    this.removing = false,
    this.onTap,
  });

  bool get isError => type == ToastType.error;
}

class ToastController extends ChangeNotifier {
  ToastController._();
  static final ToastController instance = ToastController._();

  static const maxVisible = 3;
  static const _fadeDuration = Duration(milliseconds: 250);

  final List<ToastItem> _items = [];
  List<ToastItem> get items => List.unmodifiable(_items);

  /// เดิม: ใช้ข้อความล้วนๆ ไม่มีหัวข้อ — คงไว้เพื่อความเข้ากันได้กับจุดเรียกใช้
  /// เดิมทั้งหมดในแอป (showAppToast) ที่ยังส่งมาแค่ message/isError
  String show(String message, {bool isError = false}) {
    final type = isError ? ToastType.error : ToastType.success;
    final title = isError ? 'เกิดข้อผิดพลาด' : 'สำเร็จ';
    return _add(title: title, message: message, type: type);
  }

  /// เริ่ม toast แบบ "กำลังทำงาน" — ไม่หายเอง ต้องเรียก complete()/dismiss()
  /// เองเมื่องานเสร็จ คืนค่า id ไว้ใช้เรียกปิด/เปลี่ยนสถานะภายหลัง
  String showLoading(String title,
      {String message = 'กรุณารอสักครู่...', VoidCallback? onTap}) {
    return _add(
        title: title,
        message: message,
        type: ToastType.loading,
        persistent: true,
        onTap: onTap);
  }

  /// อัปเดตข้อความของ toast ที่ยังลอยค้างอยู่ (เช่น รายงานความคืบหน้า
  /// "5/28 ไฟล์") โดยไม่เปลี่ยนสถานะ/ไม่ปิด — ถ้าหา id ไม่เจอแล้วจะไม่ทำอะไร
  void updateMessage(String id, String message) {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _items[idx].message = message;
    notifyListeners();
  }

  /// เปลี่ยน toast แบบ loading (ตาม id) ให้กลายเป็นผลสำเร็จ/ล้มเหลว แล้วค่อยหาย
  /// เองตามเวลาปกติ — ถ้าหา id ไม่เจอแล้ว (เช่นผู้ใช้กดปิดเองไปก่อน) จะไม่ทำอะไร
  /// [navigateMode] เก็บลงประวัติแจ้งเตือนถาวรด้วยเสมอ (กระดิ่งบนแถบบน) เผื่อ
  /// toast ลอยหายไปก่อนผู้ใช้ทันเห็น/ทันกด — กดรายการในกระดิ่งย้อนหลังได้
  void complete(String id,
      {required bool success,
      String? title,
      String? message,
      String? navigateMode}) {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final item = _items[idx];
    item.type = success ? ToastType.success : ToastType.error;
    item.title = title ?? (success ? 'สำเร็จ' : 'เกิดข้อผิดพลาด');
    item.message = message ?? item.message;
    item.persistent = false;
    notifyListeners();
    NotificationHistoryController.instance.add(
      title: item.title,
      message: item.message,
      icon: success ? Icons.check_circle_outline : Icons.error_outline,
      color: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      navigateMode: navigateMode,
    );
    final duration =
        success ? const Duration(seconds: 4) : const Duration(seconds: 8);
    Future.delayed(duration, () => dismiss(id));
  }

  String _add(
      {required String title,
      required String message,
      required ToastType type,
      bool persistent = false,
      VoidCallback? onTap}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _items.add(ToastItem(
        id: id,
        title: title,
        message: message,
        type: type,
        persistent: persistent,
        onTap: onTap));
    _enforceLimit();
    notifyListeners();
    if (!persistent) {
      final duration = type == ToastType.error
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4);
      Future.delayed(duration, () => dismiss(id));
    }
    return id;
  }

  /// เกิน maxVisible แล้ว → ให้อันเก่าสุด (ที่ยังไม่ได้เริ่มจางอยู่) เริ่มจางหายทีละอัน
  /// ข้าม toast แบบ persistent (loading) ไม่ให้ถูกเบียดออกระหว่างรองานเสร็จ
  void _enforceLimit() {
    final stillVisible =
        _items.where((t) => !t.removing && !t.persistent).toList();
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

/// เริ่มแจ้งเตือน "กำลังทำงาน" ที่ลอยค้างไว้จนกว่าจะเรียก [completeAppToast] —
/// ใช้กับงานเบื้องหลังที่ใช้เวลานานและห้ามสลับหน้าจอระหว่างรอ (import/export,
/// ให้ AI อ่านไฟล์ ฯลฯ) คืนค่า id ไว้ใช้เรียกปิด/เปลี่ยนสถานะภายหลัง
String showAppLoadingToast(String title,
    {String message = 'กรุณารอสักครู่...', VoidCallback? onTap}) {
  return ToastController.instance
      .showLoading(title, message: message, onTap: onTap);
}

/// อัปเดตข้อความความคืบหน้าของ toast ที่เริ่มด้วย [showAppLoadingToast]
void updateAppLoadingToast(String id, String message) =>
    ToastController.instance.updateMessage(id, message);

/// เปลี่ยน toast ที่เริ่มด้วย [showAppLoadingToast] ให้เป็นผลสำเร็จ/ล้มเหลว
void completeAppToast(String id,
    {required bool success,
    String? title,
    String? message,
    String? navigateMode}) {
  ToastController.instance.complete(id,
      success: success,
      title: title,
      message: message,
      navigateMode: navigateMode);
}

/// ปิด toast ทันที (ใช้กับ id ที่ได้จาก [showAppLoadingToast] ถ้าต้องการปิดโดย
/// ไม่ต้องเปลี่ยนเป็นผลสำเร็จ/ล้มเหลว)
void dismissAppToast(String id) => ToastController.instance.dismiss(id);
