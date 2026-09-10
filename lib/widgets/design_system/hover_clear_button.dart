// hover_clear_button.dart
// ปุ่ม (x) ล้างค่าท้ายช่องกรอก/dropdown แบบวงกลมพื้นเทาจางๆ ขนาดเล็ก — โผล่
// เฉพาะตอนเอาเมาส์ไปชี้ที่ช่องนั้น "และ" ช่องมีข้อมูลอยู่แล้วเท่านั้น (ไม่โผล่ถ้า
// ช่องว่างเปล่า กันผู้ใช้งง ว่าจะกดล้างอะไร)

import 'package:flutter/material.dart';

/// ครอบ field ด้วย MouseRegion แล้วส่งสถานะ hover กลับผ่าน [builder] — ใช้แทน
/// การประกาศ bool state ของ hover ซ้ำๆ ทุกจุดที่มีปุ่ม (x)
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovering) builder;
  const HoverBuilder({super.key, required this.builder});

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: widget.builder(context, _hovering),
      );
}

/// ปุ่ม (x) วงกลมพื้นเทาจางๆ ขนาดเล็ก — ใส่เป็น suffixIcon ของ InputDecoration
/// โดยเงื่อนไข "โชว์เมื่อไหร่" (hover + มีค่า) ให้ผู้เรียกกำหนดเองก่อนส่งเข้ามา
/// (มักเป็น `hovering && value != null ? clearIconButton(...) : null`)
Widget clearIconButton(BuildContext context, VoidCallback onPressed) {
  final colors = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Material(
      color: colors.onSurfaceVariant.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.close, size: 14, color: colors.onSurfaceVariant),
        ),
      ),
    ),
  );
}
