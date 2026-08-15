// design_tokens.dart
// ค่า token ทั้งหมดถอดจาก dashboard-finalv2.html mockup
// ใช้เป็นจุดเดียวที่กำหนดสี spacing typography radius shadow ของทั้งแอป

import 'package:flutter/material.dart';

/// สีหลัก — ใช้เป็นฐานสร้าง ColorScheme และอ้างอิงโดยตรงในบางจุด
class BrandColors {
  BrandColors._();

  // Teal (สีหลักของแอป)
  static const teal = Color(0xFF0F766E);           // --teal
  static const tealDark = Color(0xFF0B544E);       // --teal-dk (rail bg)
  static const tealLight = Color(0xFF14938A);      // --teal-lt

  // Semantic colors
  static const amber = Color(0xFFF59E0B);
  static const tertiary = Color(0xFFB45309);
  static const green = Color(0xFF15803D);
  static const red = Color(0xFFDC2626);
  static const indigo = Color(0xFF4338CA);
  static const purple = Color(0xFF7E22CE);
  static const blue = Color(0xFF1D4ED8);
  static const orange = Color(0xFFEA580C);  // ใช้เฉพาะแถบกราฟงบตามฝ่าย (.brow) ลำดับที่ 3
  static const navy = Color(0xFF1E3A8A);

  // Emerald (เน้นจุดสำคัญ)
  static const emerald = Color(0xFF047857);
  static const emeraldLight = Color(0xFFECFDF5);
  static const emeraldText = Color(0xFF065F46);

  // Light theme surfaces
  static const background = Color(0xFFF1F4F6);  // เพิ่ม background alias
  static const bgLight = Color(0xFFF1F4F6);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFEDF1F3);
  static const surface3Light = Color(0xFFF7F9FA);
  static const onLight = Color(0xFF0B1220);
  static const onVarLight = Color(0xFF57636F);
  static const outlineLight = Color(0xFFE1E7EB);

  // Dark theme surfaces
  static const bgDark = Color(0xFF0B0F14);
  static const surfaceDark = Color(0xFF151B22);
  static const surface2Dark = Color(0xFF1E262F);
  static const surface3Dark = Color(0xFF11171D);
  static const onDark = Color(0xFFE9EEF3);
  static const onVarDark = Color(0xFF94A3B0);
  static const outlineDark = Color(0xFF28323C);

  // Container tints (ใช้ใน card, chip)
  static const primaryContainer = Color(0xFFD3EBE8);
  static const onPrimaryContainer = Color(0xFF06403B);
}

/// สีเน้น (accent) ที่ mockup "สลับค่า" ตามธีมสว่าง/มืด (--teal, --red, --green
/// ฯลฯ เป็น CSS custom property ที่ html[data-theme="dark"] ทับค่าใหม่ทั้งชุด
/// ให้สว่าง/จัดจ้านขึ้นเพื่อคอนทราสต์กับพื้นมืด) — BrandColors ด้านบนมีแค่ค่า
/// เดียว (โทนสว่าง) คงที่ทุกจุด ไม่มีคู่โหมดมืด ใช้ตัวนี้แทนตรงจุดที่ต้องขึ้นกับ
/// ธีมจริงๆ (ป้ายสถานะ, กราฟ, หลอดความคืบหน้า ฯลฯ) — เมธอดรับ BuildContext
/// เพื่ออ่าน Theme.of(context).brightness ตัดสินใจว่าจะคืนค่าคู่ไหน
class BrandAccent {
  BrandAccent._();

  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color teal(BuildContext context) => _isDark(context) ? const Color(0xFF2DD4BF) : BrandColors.teal;
  // --teal-on: โทเค็นแยกจาก --teal โดยเฉพาะ ใช้กับ "ตัวหนังสือ/ไอคอนสีเขียว
  // บนพื้นผิวปกติ" (ไม่ใช่พื้นทึบสีเขียว) — โหมดสว่างค่าเท่า --teal พอดี แต่
  // โหมดมืด mockup ตั้งใจให้ "สว่างกว่า" --teal ปกติ (เท่า teal-lt) เพื่อให้
  // อ่านง่ายขึ้นบนพื้นมืด ถ้าใช้ teal() เฉยๆ แทนจุดที่ควรเป็น teal-on ตัวหนังสือ
  // จะดู "หม่น" กว่าที่ตั้งใจไว้ในโหมดมืด (สาเหตุที่บางจุดดูกลืนไปกับพื้นหลัง)
  static Color tealOn(BuildContext context) => _isDark(context) ? const Color(0xFF5EEAD4) : BrandColors.teal;
  static Color tealLight(BuildContext context) => _isDark(context) ? const Color(0xFF5EEAD4) : BrandColors.tealLight;
  static Color tertiary(BuildContext context) => _isDark(context) ? const Color(0xFFFBBF24) : BrandColors.tertiary;
  static Color green(BuildContext context) => _isDark(context) ? const Color(0xFF4ADE80) : BrandColors.green;
  static Color red(BuildContext context) => _isDark(context) ? const Color(0xFFF87171) : BrandColors.red;
  static Color indigo(BuildContext context) => _isDark(context) ? const Color(0xFFA5B4FC) : BrandColors.indigo;
  static Color purple(BuildContext context) => _isDark(context) ? const Color(0xFFD8B4FE) : BrandColors.purple;
  static Color blue(BuildContext context) => _isDark(context) ? const Color(0xFF93C5FD) : BrandColors.blue;
  static Color navy(BuildContext context) => _isDark(context) ? const Color(0xFF3B5FD4) : BrandColors.navy;
  static Color emerald(BuildContext context) => _isDark(context) ? const Color(0xFF34D399) : BrandColors.emerald;
  static Color emeraldLight(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0D3327) : BrandColors.emeraldLight;
  static Color emeraldText(BuildContext context) =>
      _isDark(context) ? const Color(0xFF6EE7B7) : BrandColors.emeraldText;
  static Color primaryContainer(BuildContext context) =>
      _isDark(context) ? const Color(0xFF12403C) : BrandColors.primaryContainer;
  static Color onPrimaryContainer(BuildContext context) =>
      _isDark(context) ? const Color(0xFF7FE0D5) : BrandColors.onPrimaryContainer;
  static Color surface2(BuildContext context) =>
      _isDark(context) ? BrandColors.surface2Dark : BrandColors.surface2Light;
  static Color surface3(BuildContext context) =>
      _isDark(context) ? BrandColors.surface3Dark : BrandColors.surface3Light;
  static Color background(BuildContext context) => _isDark(context) ? BrandColors.bgDark : BrandColors.background;
}

/// Typography scale — ฟอนต์ขนาดต่าง ๆ ที่ใช้ซ้ำในระบบ
/// mockup ใช้ 9-26px แนวคิดคือยกขึ้น 1-2px ให้อ่านง่ายขึ้นเล็กน้อยตามคำแนะนำ
class AppTypography {
  AppTypography._();

  // Display & Heading
  static const display1 = 26.0;  // mockup: 26px (KPI value)
  static const heading1 = 22.0;  // mockup: 22px (hero money)
  static const heading2 = 19.0;  // mockup: 19px (hero icon)
  static const heading3 = 17.0;  // mockup: 17px (hero title)
  static const heading4 = 13.5;  // mockup: 13.5px (card title, body base)

  // Body & UI
  static const body = 13.5;      // mockup: 13.5px (ฟอนต์พื้นฐาน)
  static const bodyMedium = 12.5; // mockup: 12.5px (search, amount col)
  static const bodySmall = 11.5;  // mockup: 11.5px (chip, alt, link)
  static const caption = 11.0;    // mockup: 11px (labels, dno, dli.a)
  static const overline = 10.5;   // mockup: 10.5px (dlg, mbar.r1)
  static const micro = 10.0;      // mockup: 10px (nb badge, sl, mbar.lg)
  static const tiny = 9.5;        // mockup: 9.5px (it.cnt, dli.b, dno s)
  static const mini = 9.0;        // mockup: 9px (sec uppercase, dring.in s)
  static const nano = 8.0;        // mockup: 8px (dli.dt2 s)

  // Font weights
  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemiBold = FontWeight.w600;
  static const weightBold = FontWeight.w700;
  static const weightExtraBold = FontWeight.w800;
}

/// Spacing scale — ระยะห่างมาตรฐาน (gap, padding)
class Spacing {
  Spacing._();

  static const xs = 4.0;   // mockup: 4-5px
  static const sm = 6.0;   // mockup: 6-7px
  static const md = 8.0;   // mockup: 8px
  static const lg = 10.0;  // mockup: 10-12px
  static const xl = 14.0;  // mockup: 14-15px
  static const xxl = 16.0; // mockup: 16px (gap หลัก content)
  static const xxxl = 18.0; // mockup: 18px (scroll padding)
  static const huge = 22.0; // mockup: 22px (hcard padding)
  static const giant = 24.0; // mockup: 24px (hero gap, fab position)
}

/// Border radius scale
class RadiusSize {
  RadiusSize._();

  static const tiny = 4.0;   // mockup: 4px (mbar.tk, ck)
  static const sm = 6.0;     // mockup: 6px (grp span, acts b)
  static const md = 7.0;     // mockup: 7px (chip, kp.ib, dli.dt2)
  static const lg = 8.0;     // mockup: 8px (rail.it, tb-ic, sbox)
  static const xl = 9.0;     // mockup: 9px (omni, hcard.sc)
  static const xxl = 11.0;   // mockup: 11px (ch.nb badge)
  static const card = 13.0;  // mockup: 13px (card, kp, chart-card, fab)
  static const hero = 16.0;  // mockup: 16px (hcard)
  static const pill = 20.0;  // mockup: 20px (alt alert pill)
  static const full = 999.0; // ปุ่ม/badge ที่ต้องการมนเต็ม
}

/// Shadows — เงามาตรฐาน 2 ระดับ
class AppShadows {
  AppShadows._();

  // --sh-1: subtle shadow for cards
  static const light1 = [
    BoxShadow(
      color: Color.fromRGBO(11, 18, 32, 0.05),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(11, 18, 32, 0.04),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  // --sh-2: elevated shadow for chart
  static const light2 = [
    BoxShadow(
      color: Color.fromRGBO(11, 18, 32, 0.06),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(11, 18, 32, 0.07),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  // Dark theme shadows
  static const dark1 = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.4),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const dark2 = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.5),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];
}

/// Icon sizes — ขนาดไอคอนมาตรฐาน
class IconSizes {
  IconSizes._();

  static const tiny = 11.0;   // ck checkbox icon
  static const sm = 15.0;     // grp span, alt.ic, alt.ar
  static const md = 16.0;     // acts b, school.av, kp.ib
  static const lg = 17.0;     // rail.it.ico
  static const xl = 18.0;     // tb-ic, colR-tab
  static const xxl = 19.0;    // hcard.sc, fab
}

/// Dimensions — ความสูง/กว้างที่ใช้ซ้ำ
class Dimensions {
  Dimensions._();

  // Layout
  static const pageMargin = 20.0;
  static const sectionGap = 16.0;
  static const topBarHeight = 64.0;
  static const cardPadding = 16.0;

  static const topbarHeight = 64.0;
  static const railWidth = 212.0;
  static const sidebarCollapsedWidth = 26.0; // colR-tab
  static const sidebarOpenWidth = 190.0;     // colR
  static const fabHeight = 48.0;
  static const chipHeight = 34.0;
  static const buttonHeightSm = 32.0;        // tb-pill
  static const buttonHeightMd = 34.0;        // gbt, sbox
  static const buttonHeightLg = 38.0;        // omni
  static const iconButtonSize = 32.0;        // tb-ic
  static const kpiIconSize = 28.0;           // kp.ib
  static const checkboxSize = 15.0;          // ck

  // Content constraints
  static const maxContentWidth = 1150.0;     // wrap max-width
  static const appWidth = 1440.0;            // mockup app width (แต่เราจะทำ responsive)
}
