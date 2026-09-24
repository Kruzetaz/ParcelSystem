// hover_marquee_text.dart
// ข้อความบรรทัดเดียวที่ถูกตัด (ellipsis) เพราะพื้นที่ไม่พอ — ตอนเอาเมาส์ไปชี้ค้าง
// จะเลื่อน (ไหล) ไปทางซ้ายให้อ่านส่วนที่ถูกตัดจนจบ แล้วเลื่อนกลับ วนซ้ำไปมาตราบ
// ที่เมาส์ยังชี้อยู่ — ถ้าข้อความสั้นพอไม่ล้นพื้นที่อยู่แล้ว จะไม่ขยับเลย (เช็คด้วย
// TextPainter วัดความกว้างจริงของข้อความเทียบกับพื้นที่ที่มี)

import 'package:flutter/material.dart';

class HoverMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const HoverMarqueeText({super.key, required this.text, required this.style});

  @override
  State<HoverMarqueeText> createState() => _HoverMarqueeTextState();
}

class _HoverMarqueeTextState extends State<HoverMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _textWidth() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  void _onEnter(double overflow) {
    if (overflow <= 0) return;
    // ยิ่งข้อความล้นเยอะ ยิ่งใช้เวลาเลื่อนนานขึ้น กันเลื่อนเร็วจนอ่านไม่ทัน
    _controller
      ..duration = Duration(milliseconds: 700 + (overflow * 20).round())
      ..repeat(reverse: true);
  }

  void _onExit() {
    _controller.stop();
    _controller.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final overflow =
          (_textWidth() - constraints.maxWidth).clamp(0.0, double.infinity);
      return MouseRegion(
        onEnter: (_) => _onEnter(overflow),
        onExit: (_) => _onExit(),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-overflow * _controller.value, 0),
              child: child,
            ),
            child: Text(widget.text,
                maxLines: 1, softWrap: false, style: widget.style),
          ),
        ),
      );
    });
  }
}
