// glass_container.dart
// กล่องพื้นผิว "กระจกฝ้า" (frosted glass) — เลียนแบบ backdrop-filter:blur() ของ
// CSS ที่ mockup ใช้เยอะมาก (.omni, .alt, .gbt, .pg, .selbar .bs ฯลฯ)
//
// [ตั้งใจใช้แบบเลือกจุด ไม่ใช่ทุกที่]: BackdropFilter ของ Flutter แพงกว่า CSS
// backdrop-filter มาก (ทุกจุดที่ใช้คือ saveLayer + อ่าน pixel พื้นหลังมา blur
// ใหม่ทุกเฟรม) ถ้าใช้ซ้ำเป็นสิบๆ ครั้งใน widget ที่ rebuild บ่อย (เช่น ปุ่ม
// ดำเนินการต่อแถวในตารางที่มีเป็นสิบแถว) จะกินพลังเครื่องเกินจำเป็นจนหน้าจอ
// กระตุกตอนเลื่อน — ใช้ widget นี้เฉพาะจุดที่ปรากฏครั้งเดียว/ไม่กี่ครั้งต่อหน้า
// (เช่น search bar บน topbar, alert pill 2-3 อัน, ปุ่มหัวการ์ด) ส่วนจุดที่
// ซ้ำเยอะ (ปุ่มไอคอนต่อแถวในตาราง) จงใจใช้สีโปร่งแสงธรรมดาแทนเพื่อประสิทธิภาพ

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.color,
    this.blurSigma = 8,
    this.borderRadius,
    this.border,
    this.padding,
  });

  final Widget child;
  final Color? color;
  final double blurSigma;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(RadiusSize.lg);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: color, borderRadius: radius, border: border),
          child: child,
        ),
      ),
    );
  }
}
