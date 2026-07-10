// app_theme.dart
// จุดเดียวที่กำหนดสีของทั้งแอป — สีหลักคือ "เขียวหัวเป็ด" (teal)
// มี 2 ธีม: light() และ dark() ตามที่ตกลงกันไว้ (โหมดสว่าง/มืด สลับได้)

import 'package:flutter/material.dart';

/// สีแบรนด์หลักของแอป — ใช้เป็น "เมล็ดพันธุ์" (seed) ให้ Flutter
/// สร้างชุดสีทั้งหมด (ปุ่ม, ไฮไลต์, ฯลฯ) ให้เข้ากันโดยอัตโนมัติ
const Color kTealAccent = Color(0xFF0F766E);

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kTealAccent,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kTealAccent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      // ใช้ primary/onPrimary เหมือนกับโหมดสว่าง (ไม่ใช้ surface/onSurface)
      // เพราะโค้ดในแถบบนสุด (app_shell.dart) อ้างอิงสี onPrimary ตรงๆ
      // ถ้าพื้นหลังแถบบนใช้สีอื่น ตัวหนังสือจะกลายเป็นสีจางมองไม่เห็น
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
    );
  }

  // ช่องกรอกข้อมูลทั้งแอปใช้ค่าจากตรงนี้เป็นค่าเริ่มต้น — ทำให้ตัวหนังสือ/เส้นขอบ
  // ปรับสีตามโหมดสว่าง-มืดเองอัตโนมัติ ไม่ต้องไปกำหนดสีทีละช่องในแต่ละหน้า
  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    );
  }
}
