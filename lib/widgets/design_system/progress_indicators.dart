// progress_indicators.dart
// แถบความคืบหน้าแบบต่าง ๆ — bar, ring, stacked bar
// ตรงกับ .mbar, .dring, .brow ใน mockup

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/design_tokens.dart';

/// แถบความคืบหน้าแบบธรรมดา (.mbar.tk ใน mockup)
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.backgroundColor,
    this.height = 7,
  });

  final double progress; // 0.0-1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fillColor = color ?? BrandAccent.tealLight(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(RadiusSize.tiny),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor ?? BrandAccent.surface2(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(RadiusSize.tiny),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          // glow เงาสีเดียวกับแถบ ตรงกับ .prg .tk i ใน mockup ที่มี box-shadow
          // เรืองแสงตามสถานะเสมอ (ไม่ใช่แค่ตอน default teal)
          child: Container(
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(RadiusSize.tiny),
              boxShadow: [BoxShadow(color: fillColor.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Donut ring progress (.dring ใน mockup) — วงกลมความคืบหน้าแบบ hero
class DonutProgress extends StatelessWidget {
  const DonutProgress({
    super.key,
    required this.percentage,
    required this.centerValue,
    required this.centerLabel,
    this.size = 100,
    this.strokeWidth = 13,
    this.segments = const [],
  });

  final double percentage; // 0-100
  final String centerValue;
  final String centerLabel;
  final double size;
  final double strokeWidth;
  final List<DonutSegment> segments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              segments: segments,
              strokeWidth: strokeWidth,
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                // สเกลตามขนาดวงแหวนจริง (มockup ใช้อัตราส่วนราว 21/100) กันตัวเลข
                // ดูใหญ่เทอะทะเกินสัดส่วนเมื่อ hero card ถูกย่อวงแหวนให้เล็กลง
                style: TextStyle(
                  fontSize: size * 0.21,
                  fontWeight: AppTypography.weightExtraBold,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerLabel,
                style: TextStyle(
                  fontSize: AppTypography.mini,
                  fontWeight: AppTypography.weightSemiBold,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutSegment {
  final double value; // 0-100
  final Color color;

  DonutSegment(this.value, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;

  _DonutPainter({required this.segments, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2; // เริ่มจากบน

    for (final segment in segments) {
      final sweepAngle = (segment.value / 100) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Stacked horizontal bar — แถบแนวนอนหลายสีซ้อนกัน (.brow ใน mockup)
class StackedBar extends StatelessWidget {
  const StackedBar({
    super.key,
    required this.label,
    required this.segments,
    required this.total,
    this.showPercentage = true,
    this.showValue = true,
    this.height = 15,
  });

  final String label;
  final List<BarSegment> segments;
  final double total;
  final bool showPercentage;
  final bool showValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final percentage = total > 0
        ? (segments.fold<double>(0, (sum, s) => sum + s.value) / total * 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Label
          SizedBox(
            width: 196,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.caption,
                fontWeight: AppTypography.weightSemiBold,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: BrandAccent.surface2(context),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Stack(
                  children: [
                    for (int i = 0; i < segments.length; i++)
                      _buildSegment(segments[i], i),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Percentage
          if (showPercentage)
            SizedBox(
              width: 30,
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: AppTypography.micro,
                  fontWeight: AppTypography.weightBold,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          const SizedBox(width: 12),
          // Value
          if (showValue)
            SizedBox(
              width: 112,
              child: Text(
                _formatNumber(segments.fold<double>(0, (sum, s) => sum + s.value)),
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  fontWeight: AppTypography.weightBold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegment(BarSegment segment, int index) {
    double leftOffset = 0;
    for (int i = 0; i < index; i++) {
      leftOffset += (segments[i].value / total);
    }

    return Positioned(
      left: leftOffset * double.infinity,
      child: FractionallySizedBox(
        widthFactor: segment.value / total,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: segment.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} ล้าน';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)},${(value % 1000).toStringAsFixed(0).padLeft(3, '0')}';
    }
    return value.toStringAsFixed(2);
  }
}

class BarSegment {
  final double value;
  final Color color;
  final String? label;

  BarSegment({required this.value, required this.color, this.label});
}

