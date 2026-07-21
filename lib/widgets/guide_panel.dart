// guide_panel.dart
// ไกด์/วิธีใช้งานแบบสั้น กระชับ — แสดงผ่านปุ่มลอยสี่เหลี่ยมมุมจอ (GuideFabOverlay)
// กดแล้วเปิดกล่องไกด์ขึ้นมา ไม่ค้างกินพื้นที่จอตลอดเวลาเหมือนแบบ panel ข้างเดิม

import 'package:flutter/material.dart';

/// เนื้อหาไกด์ (หัวข้อ + รายการขั้นตอนแบบมีเลขกำกับ) — ใช้แสดงในกล่องโต้ตอบ
class GuidePanel extends StatelessWidget {
  final String title;
  final List<String> steps;
  final IconData icon;

  const GuidePanel({
    super.key,
    required this.title,
    required this.steps,
    this.icon = Icons.lightbulb_outline,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: colors.primary,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 10, color: colors.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(steps[i], style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// วางปุ่มลอยสี่เหลี่ยม (มุมจอตามที่กำหนด) ทับบนเนื้อหาหลักของหน้า
/// กดแล้วเปิดกล่องไกด์การใช้งานของหน้านั้นขึ้นมา
class GuideFabOverlay extends StatelessWidget {
  final Widget child;
  final String title;
  final List<String> steps;
  final IconData icon;
  final Alignment corner;

  const GuideFabOverlay({
    super.key,
    required this.child,
    required this.title,
    required this.steps,
    this.icon = Icons.lightbulb_outline,
    this.corner = Alignment.topRight,
  });

  void _openGuide(BuildContext context) {
    // เปิด dialog ใน microtask ถัดไปแทนที่จะเปิดทันทีตอน onTap (ซึ่งยังอยู่
    // ระหว่าง pointer event เดิม) — ป้องกันบั๊กของ Flutter mouse_tracker บน
    // desktop ที่ชน assertion "_debugDuringDeviceUpdate" เวลามีการ mount
    // widget/overlay ใหม่ (เช่น dialog) ขึ้นมาซ้อนระหว่างที่ตัว mouse tracker
    // กำลังประมวลผล pointer event ของปุ่มเดิมอยู่พอดี ทำให้แอปค้าง กดอะไรไม่ได้
    // ทั้งแอป — ใช้ Future.microtask แทน addPostFrameCallback เพราะ
    // addPostFrameCallback ต้องรอ "เฟรมจอถัดไปจริงๆ" ซึ่งถ้าตอนนั้นแอปนิ่งๆ
    // Flutter อาจไม่รีบวาดเฟรมใหม่ให้ ทำให้ผู้ใช้รู้สึกว่าปุ่มหน่วง/กดแล้วช้า
    Future.microtask(() {
      if (!context.mounted) return;
      _showGuideDialog(context);
    });
  }

  void _showGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GuidePanel(title: title, steps: steps, icon: icon),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ปิด'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTop = corner.y < 0;
    final isLeft = corner.x < 0;
    return Stack(
      children: [
        child,
        Positioned(
          top: isTop ? 16 : null,
          bottom: isTop ? null : 16,
          left: isLeft ? 16 : null,
          right: isLeft ? null : 16,
          child: Material(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            // หมายเหตุ: ใช้ GestureDetector แทน InkWell โดยตั้งใจ — InkWell ผูก
            // MouseRegion ของตัวเองไว้เพื่อ hover/splash effect ซึ่งพอวางอยู่ใน
            // Positioned/Stack ที่เนื้อหาหน้ารีบิลด์บ่อยๆ ทำให้ Flutter mouse
            // tracker บน desktop ชน assertion "_debugDuringDeviceUpdate" แล้ว
            // ทำให้ทั้งแอปกดอะไรไม่ได้เลย (บั๊กที่รู้จักกันของ Flutter บน desktop)
            // GestureDetector ไม่ผูก MouseRegion เพิ่ม จึงไม่ชนปัญหานี้
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openGuide(context),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.help_outline, color: colors.onPrimary, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
