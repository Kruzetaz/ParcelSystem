// font_scale_controller.dart
// เก็บระดับขนาดตัวอักษรทั้งระบบที่ผู้ใช้เลือกไว้ล่าสุด (เพิ่ม/ลดได้จาก AppBar)
// บันทึกด้วย shared_preferences เพื่อให้จำค่าไว้ตอนเปิดแอปครั้งถัดไป — ทำตาม
// pattern เดียวกับ ThemeController (singleton ChangeNotifier)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefFontScale = 'font_scale_v1';
const double minFontScale = 0.5;
const double maxFontScale = 1.5;
const double _step = 0.1;

class FontScaleController extends ChangeNotifier {
  FontScaleController._();
  static final FontScaleController instance = FontScaleController._();

  double _scale = 1.0;
  double get scale => _scale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefFontScale);
    if (saved != null) _scale = saved.clamp(minFontScale, maxFontScale);
    notifyListeners();
  }

  Future<void> _set(double value) async {
    _scale = value.clamp(minFontScale, maxFontScale);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefFontScale, _scale);
  }

  Future<void> increase() => _set(_scale + _step);
  Future<void> decrease() => _set(_scale - _step);
  Future<void> reset() => _set(1.0);
}
