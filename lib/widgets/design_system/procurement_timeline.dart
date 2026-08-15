// procurement_timeline.dart
// แถบขั้นตอนกระบวนการจัดซื้อ/จัดจ้างแบบ horizontal step tracker
// ตรงกับ .tl-steps ใน mockup — ใช้ตอนกางแถวในตารางรายการ (ProcurementTimeline)

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

enum TimelineStepState { done, current, pending }

class TimelineStep {
  final String label;
  final String? date;
  final TimelineStepState state;
  const TimelineStep({required this.label, this.date, this.state = TimelineStepState.pending});
}

/// Step tracker แนวนอน — จุดกลม + เส้นเชื่อม + ป้ายชื่อ/วันที่ใต้แต่ละจุด
class ProcurementTimeline extends StatelessWidget {
  const ProcurementTimeline({super.key, required this.steps});
  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // เดิมแต่ละ step วาดเส้นเชื่อมแค่ในกล่องของตัวเอง (0 ถึงขอบขวาของกล่อง)
    // ทำให้เส้นสั้นกว่าที่ควร ไปไม่ถึงจุดกึ่งกลางของวงกลมถัดไป (ขาดไปครึ่งกล่อง
    // เห็นเป็นช่องว่างระหว่างเส้น) — ต้อง LayoutBuilder หาความกว้างรวมจริงก่อน
    // แล้ววาดเส้นแยกเป็น "เลเยอร์" ทับใต้แถวจุดวงกลม โดยแต่ละเส้นพาดจากกึ่งกลาง
    // ช่อง i ไปกึ่งกลางช่อง i+1 พอดี ตรงกับ mockup (.tl-steps .s::after)
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / steps.length;
        const dotCenterY = 7.0; // ครึ่งความสูงของวงกลม 14px
        // 52 ไม่ใช่ 46 — ของเดิมตั้งตัวเลขแบบประมาณเอาจากผลรวม (จุด14+ช่องไฟ6+
        // ป้าย+ช่องไฟ2+วันที่) แต่ font metrics จริง (line-height เกินความสูง
        // ตัวอักษรที่ตั้งใจไว้เสมอ) ทำให้ล้นไป 1-3px ทุกจุด (6 จุด x ทุกแถวที่
        // กางไทม์ไลน์) เผื่อระยะเพิ่มให้พอจริง กันเหตุผลเดียวกันเกิดซ้ำถ้าฟอนต์
        // เปลี่ยนไปนิดหน่อยในอนาคต
        return SizedBox(
          height: 52,
          child: Stack(
            children: [
              for (int i = 0; i < steps.length - 1; i++)
                Positioned(
                  left: (i + 0.5) * segmentWidth,
                  width: segmentWidth,
                  top: dotCenterY - 1,
                  child: Container(
                    height: 2,
                    color: steps[i].state == TimelineStepState.done
                        ? BrandAccent.green(context)
                        : colorScheme.outline,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in steps)
                    Expanded(child: _StepWidget(step: step, colorScheme: colorScheme)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepWidget extends StatelessWidget {
  const _StepWidget({required this.step, required this.colorScheme});
  final TimelineStep step;
  final ColorScheme colorScheme;

  Color _dotColor(BuildContext context) {
    switch (step.state) {
      case TimelineStepState.done:
        return BrandAccent.green(context);
      case TimelineStepState.current:
        return BrandAccent.tertiary(context);
      case TimelineStepState.pending:
        return colorScheme.outline;
    }
  }

  Color _textColor(BuildContext context) {
    switch (step.state) {
      case TimelineStepState.done:
        return BrandAccent.green(context);
      case TimelineStepState.current:
        return BrandAccent.tertiary(context);
      case TimelineStepState.pending:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor(context);
    return Column(
      children: [
        SizedBox(
          height: 14,
          width: 14,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // ขั้นตอนที่ "ทำแล้ว" เท่านั้นที่ทึบสี — ทั้ง "กำลังทำ" (now) และ
              // "ยังไม่ถึง" (pending) พื้นวงกลมเป็นสีพื้นหลัง (ขาว) เหมือนกัน
              // ต่างกันแค่สีขอบ + วงแหวนเรืองแสงรอบขอบตอน "กำลังทำ" ตรงกับ
              // mockup (.tl-steps .s.now::before) ของเดิมเข้าใจผิดว่า "กำลังทำ"
              // ต้องทึบสีเหมือน "ทำแล้ว" เลยดูเหมือนไม่มีจุดขาวเป็นจุดเด่นเลย
              color: step.state == TimelineStepState.done ? dotColor : colorScheme.surface,
              border: Border.all(color: dotColor, width: 2),
              boxShadow: step.state == TimelineStepState.current
                  ? [BoxShadow(color: dotColor.withValues(alpha: 0.18), spreadRadius: 3)]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTypography.micro,
            fontWeight: step.state == TimelineStepState.current
                ? AppTypography.weightExtraBold
                : AppTypography.weightSemiBold,
            color: _textColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          step.date ?? '—',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTypography.nano,
            fontWeight: AppTypography.weightMedium,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
