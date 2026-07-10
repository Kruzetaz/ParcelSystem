// theme_controller.dart
// เก็บว่าผู้ใช้เลือกโหมดสว่าง (light) หรือมืด (dark) ไว้ล่าสุด
// บันทึกด้วย shared_preferences เพื่อให้จำค่าไว้ตอนเปิดแอปครั้งถัดไป

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefThemeMode = 'theme_mode'; // เก็บค่าเป็น 'light' หรือ 'dark'

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// เรียกครั้งเดียวตอนแอปเริ่มทำงาน (ใน main.dart) เพื่อโหลดค่าที่เคยบันทึกไว้
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefThemeMode);
    _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// สลับโหมด — เรียกจากปุ่มสลับธีมใน AppBar
  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeMode, _mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
