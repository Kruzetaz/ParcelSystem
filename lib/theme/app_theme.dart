// app_theme.dart
// Theme กลางของแอป — สร้างจาก design_tokens.dart พร้อม typography และ component defaults
// มี 2 ธีม: light() และ dark() ตามที่ตกลงกันไว้ (โหมดสว่าง/มืด สลับได้)

import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// สีแบรนด์หลักของแอป (รักษาไว้เพื่อ backward compatibility)
const Color kTealAccent = Color(0xFF0F766E);

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BrandColors.teal,
      brightness: Brightness.light,
      // Override ค่าที่ต้องการควบคุมเองตาม mockup
      primary: BrandColors.teal,
      // ไม่ override ไว้เดิม ทำให้ fromSeed คำนวณ onPrimary จาก primary โทน
      // อ่อนที่มันตั้งใจสร้างเอง (ไม่ใช่ teal เข้มที่เรา override ทับ) — ในโหมด
      // มืดยิ่งชัด เพราะ fromSeed(dark) คาดหวัง primary โทนอ่อน คู่กับ onPrimary
      // โทนเข้ม พอเราจับ primary เป็น teal เข้มแทน onPrimary (เข้มเหมือนกัน) เลย
      // แทบกลืนกับพื้นบาร์ ล็อกเป็นขาวเสมอให้ตรงกับ topbar ที่เป็น teal เข้มทุกโหมด
      onPrimary: Colors.white,
      primaryContainer: BrandColors.primaryContainer,
      onPrimaryContainer: BrandColors.onPrimaryContainer,
      secondary: BrandColors.emerald,
      tertiary: BrandColors.amber,
      error: BrandColors.red,
      surface: BrandColors.surfaceLight,
      onSurface: BrandColors.onLight,
      onSurfaceVariant: BrandColors.onVarLight,
      outline: BrandColors.outlineLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.bgLight,
      textTheme: _textTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: AppTypography.heading4,
          fontWeight: AppTypography.weightExtraBold,
          color: Colors.white,
          fontFamily: 'NotoSansThai',
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shadowColor: AppShadows.light1.first.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.card),
          side: BorderSide(color: colorScheme.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: BrandColors.teal,
        labelStyle: TextStyle(
          fontSize: AppTypography.bodySmall,
          fontWeight: AppTypography.weightBold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.teal,
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontSize: AppTypography.body,
            fontWeight: AppTypography.weightExtraBold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusSize.card),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      switchTheme: _switchTheme(colorScheme),
      popupMenuTheme: _popupMenuTheme(colorScheme),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BrandColors.teal,
      brightness: Brightness.dark,
      // Override ค่าที่ต้องการควบคุมเองตาม mockup dark theme
      primary: BrandColors.teal,
      onPrimary: Colors.white,
      secondary: BrandColors.emerald,
      tertiary: BrandColors.amber,
      error: BrandColors.red,
      surface: BrandColors.surfaceDark,
      onSurface: BrandColors.onDark,
      onSurfaceVariant: BrandColors.onVarDark,
      outline: BrandColors.outlineDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.bgDark,
      textTheme: _textTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: AppTypography.heading4,
          fontWeight: AppTypography.weightExtraBold,
          color: Colors.white,
          fontFamily: 'NotoSansThai',
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shadowColor: AppShadows.dark1.first.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.card),
          side: BorderSide(color: colorScheme.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: BrandColors.teal,
        labelStyle: TextStyle(
          fontSize: AppTypography.bodySmall,
          fontWeight: AppTypography.weightBold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.teal,
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontSize: AppTypography.body,
            fontWeight: AppTypography.weightExtraBold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusSize.card),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      switchTheme: _switchTheme(colorScheme),
      popupMenuTheme: _popupMenuTheme(colorScheme),
    );
  }

  /// PopupMenuItem ค่าเริ่มต้นของ Flutter ใช้ TextTheme.labelLarge เป็นสไตล์
  /// ข้อความ — แต่ labelLarge ในธีมนี้ตั้งใจให้เป็นตัวหนา (ใช้กับป้าย/badge
  /// เล็กๆ ที่อื่น) พอมาเป็นค่าเริ่มต้นของเมนูป๊อปอัพ (เช่นเมนู "จัดการเพิ่มเติม",
  /// เมนูเลือกจากทำเนียบบุคลากร, เมนูสร้างเอกสาร) เลยทำให้ตัวหนังสือในเมนู
  /// หนาเกินไปทั้งที่ควรเป็นข้อความปกติ — กำหนดสไตล์ให้เมนูป๊อปอัพโดยเฉพาะแทน
  /// ไม่แตะ labelLarge ตรงๆ กันกระทบ badge/chip ที่อื่นที่ตั้งใจให้หนาอยู่แล้ว
  static PopupMenuThemeData _popupMenuTheme(ColorScheme colorScheme) {
    // ธีมนี้เปิด useMaterial3 ไว้ — PopupMenuItem อ่านสไตล์จาก labelTextStyle
    // (WidgetStateProperty) เท่านั้นตอน Material3 ไม่ใช่ textStyle ตัวเก่า
    // (M2) ถ้าตั้งแค่ textStyle เฉยๆ จะไม่มีผลอะไรเลย
    final style = TextStyle(
      fontSize: AppTypography.body,
      fontWeight: AppTypography.weightRegular,
      color: colorScheme.onSurface,
      fontFamily: 'NotoSansThai',
    );
    return PopupMenuThemeData(labelTextStyle: WidgetStatePropertyAll(style));
  }

  /// สถานะปิด (off) ของ Switch ค่าเริ่มต้นของ Flutter ใช้ colorScheme.outline
  /// เป็นเส้นขอบราง ซึ่งในธีมนี้จางมาก (เหตุผลเดียวกับที่เคยเจอกับเส้นขอบช่อง
  /// กรอกในไดอะล็อก) ทำให้สวิตช์ตอนปิดดูเหมือนกล่องเทาแบนๆ ไม่รู้ว่ากดได้ —
  /// บังคับให้รางตอนปิดใช้สี onSurfaceVariant (เข้มกว่า) แทน ให้เห็นชัดว่าเป็น
  /// ปุ่มเปิด/ปิด ไม่ใช่แค่ตกแต่ง
  static SwitchThemeData _switchTheme(ColorScheme colorScheme) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return colorScheme.onSurfaceVariant;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return BrandColors.teal;
        return colorScheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
      }),
      trackOutlineWidth: const WidgetStatePropertyAll(1.5),
    );
  }

  /// Typography theme — ใช้ Noto Sans Thai เป็นฟอนต์หลักตรงกับ mockup
  static TextTheme _textTheme(ColorScheme colorScheme) {
    const fontFamily = 'NotoSansThai';
    return TextTheme(
      // Display & Headings
      displayLarge: TextStyle(
        fontSize: AppTypography.display1,
        fontWeight: AppTypography.weightExtraBold,
        letterSpacing: -1.1,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      headlineLarge: TextStyle(
        fontSize: AppTypography.heading1,
        fontWeight: AppTypography.weightExtraBold,
        letterSpacing: -0.7,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      headlineMedium: TextStyle(
        fontSize: AppTypography.heading2,
        fontWeight: AppTypography.weightExtraBold,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      headlineSmall: TextStyle(
        fontSize: AppTypography.heading3,
        fontWeight: AppTypography.weightExtraBold,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      titleLarge: TextStyle(
        fontSize: AppTypography.heading4,
        fontWeight: AppTypography.weightExtraBold,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      // titleMedium/titleSmall ไม่เคยกำหนดไว้มาก่อน — ตกไปใช้ค่า default ของ
      // Material Typography (คนละฟอนต์กับ NotoSansThai ที่ตั้งไว้ทุกสไตล์อื่น
      // ในนี้ + น้ำหนัก w500) ซึ่งเป็นสไตล์ที่ TextField/DropdownButtonFormField
      // ใช้แสดงค่าที่กรอก/เลือกไว้จริงๆ (ไม่ใช่ label ลอย) ทำให้ตัวหนังสือใน
      // ช่องกรอกทั้งแอปดู "หนา/แปลกฟอนต์" กว่าจุดอื่นโดยไม่ได้ตั้งใจ — กำหนด
      // ให้ชัดเจนเป็นน้ำหนักปกติ (w400) เหมือน bodyLarge แทน
      titleMedium: TextStyle(
        fontSize: AppTypography.body,
        fontWeight: AppTypography.weightRegular,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      titleSmall: TextStyle(
        fontSize: AppTypography.bodyMedium,
        fontWeight: AppTypography.weightRegular,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      // Body text
      bodyLarge: TextStyle(
        fontSize: AppTypography.body,
        fontWeight: AppTypography.weightRegular,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: AppTypography.bodyMedium,
        fontWeight: AppTypography.weightRegular,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: AppTypography.bodySmall,
        fontWeight: AppTypography.weightRegular,
        color: colorScheme.onSurfaceVariant,
        fontFamily: fontFamily,
      ),
      // Labels
      labelLarge: TextStyle(
        fontSize: AppTypography.caption,
        fontWeight: AppTypography.weightBold,
        color: colorScheme.onSurfaceVariant,
        fontFamily: fontFamily,
      ),
      labelMedium: TextStyle(
        fontSize: AppTypography.micro,
        fontWeight: AppTypography.weightBold,
        color: colorScheme.onSurfaceVariant,
        fontFamily: fontFamily,
      ),
      labelSmall: TextStyle(
        fontSize: AppTypography.tiny,
        fontWeight: AppTypography.weightMedium,
        color: colorScheme.onSurfaceVariant,
        fontFamily: fontFamily,
      ),
    );
  }

  // ช่องกรอกข้อมูลทั้งแอปใช้ค่าจากตรงนี้เป็นค่าเริ่มต้น — ทำให้ตัวหนังสือ/เส้นขอบ
  // ปรับสีตามโหมดสว่าง-มืดเองอัตโนมัติ ไม่ต้องไปกำหนดสีทีละช่องในแต่ละหน้า
  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.lg),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.lg),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.lg),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.lg),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      hintStyle: TextStyle(
        fontSize: AppTypography.bodyMedium,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      labelStyle: TextStyle(
        fontSize: AppTypography.caption,
        color: colorScheme.onSurfaceVariant,
        fontWeight: AppTypography.weightSemiBold,
      ),
    );
  }
}
