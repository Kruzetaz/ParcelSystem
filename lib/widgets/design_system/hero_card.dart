// hero_card.dart
// Hero card — การ์ดแสดงข้อมูลสรุปหลักด้วย gradient background
// ตรงกับ .hcard ใน mockup พร้อม donut progress

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'progress_indicators.dart';

/// Hero card with gradient background
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.moneyItems,
    this.progressLabel,
    this.progressValue,
    this.progressTotal,
    this.progressPercentage,
    this.donutSegments,
    this.legendItems,
    this.donutCenterPercentage,
    this.donutCenterLabel = 'ใช้ไปแล้ว',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<MoneyItem> moneyItems;
  final String? progressLabel;
  final double? progressValue;
  final double? progressTotal;
  final double? progressPercentage;
  final List<DonutSegment>? donutSegments;
  final List<HeroDonutLegendItem>? legendItems;
  // ตรงกลาง donut กับแถบ mbar สื่อความหมายคนละอย่างกันได้ (เช่น mbar = สัดส่วน
  // การใช้งบรวมที่ผูกพันแล้ว, donut = เฉพาะส่วนที่เบิกจ่ายจริง) — ถ้าไม่ส่งมา
  // จะ fallback ไปใช้ progressPercentage ตัวเดียวกันเหมือนเดิม
  final double? donutCenterPercentage;
  final String donutCenterLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        // teal-dk คงที่ทั้งสองธีม (mockup ไม่ override ค่านี้ในโหมดมืด) แต่
        // teal ปลายไล่สีเปลี่ยนเป็นสีสว่างกว่าตอนโหมดมืด (#2DD4BF) ต้องดึงจาก
        // BrandAccent ไม่ใช้ค่าคงที่เดียวเหมือนเดิม
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.tealDark, BrandAccent.teal(context)],
        ),
        borderRadius: BorderRadius.circular(RadiusSize.hero),
        // mockup ปิดเงาการ์ดนี้ทิ้งเลยตอนโหมดมืด (html[data-theme="dark"]
        // .hcard{box-shadow:none}) — พื้นหลังมืดอยู่แล้ว เงาแทบไม่มีผลแถมดู
        // เป็นคราบทึบเกินจำเป็น
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : const [
                BoxShadow(
                  color: Color.fromRGBO(11, 84, 78, 0.3),
                  offset: Offset(0, 6),
                  blurRadius: 20,
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon + Title row
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(RadiusSize.xl),
                      ),
                      child: Icon(
                        icon,
                        size: AppTypography.heading2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTypography.heading3,
                              fontWeight: AppTypography.weightExtraBold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // mockup .hsub ไม่ได้กำหนด font-weight ไว้เลย (ตัว
                            // ธรรมดา) ของเดิมใส่ semiBold ผิดไปหนากว่าที่ควร
                            style: TextStyle(
                              fontSize: AppTypography.caption,
                              color: Colors.white.withValues(alpha: 0.62),
                              fontWeight: AppTypography.weightRegular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Money items
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: moneyItems.map((item) => _MoneyDisplay(item: item)).toList(),
                ),
                // Progress bar
                if (progressLabel != null &&
                    progressValue != null &&
                    progressTotal != null) ...[
                  const SizedBox(height: 12),
                  _ProgressSection(
                    label: progressLabel!,
                    value: progressValue!,
                    total: progressTotal!,
                    percentage: progressPercentage,
                  ),
                ],
              ],
            ),
          ),
          // Right donut + legend (.hdnt ใน mockup)
          if (donutSegments != null && progressPercentage != null) ...[
            const SizedBox(width: 24),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonutProgress(
                  percentage: progressPercentage!,
                  centerValue: '${(donutCenterPercentage ?? progressPercentage!).toInt()}%',
                  centerLabel: donutCenterLabel,
                  segments: donutSegments!,
                  size: 82,
                  strokeWidth: 10,
                ),
                if (legendItems != null && legendItems!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in legendItems!) _LegendRow(item: item),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MoneyItem {
  final String label;
  final String value;
  final String? unit;

  MoneyItem({required this.label, required this.value, this.unit});
}

/// รายการอธิบายสีของ donut (.dlg ใน mockup) — จุดสี + ป้ายชื่อ + ยอดเงิน
class HeroDonutLegendItem {
  final Color color;
  final String label;
  final String value;
  final bool outlined; // ขอบบาง — ใช้กับสีจางๆ ที่มองแทบไม่เห็นถ้าไม่มีขอบ

  HeroDonutLegendItem({
    required this.color,
    required this.label,
    required this.value,
    this.outlined = false,
  });
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.item});
  final HeroDonutLegendItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(2),
              border: item.outlined ? Border.all(color: Colors.white.withValues(alpha: 0.3)) : null,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppTypography.overline, color: Colors.white.withValues(alpha: 0.82)),
            ),
          ),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: AppTypography.overline,
              fontWeight: AppTypography.weightBold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyDisplay extends StatelessWidget {
  const _MoneyDisplay({required this.item});

  final MoneyItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          style: TextStyle(
            fontSize: AppTypography.micro,
            color: Colors.white.withValues(alpha: 0.62),
            fontWeight: AppTypography.weightSemiBold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.value,
              style: TextStyle(
                fontSize: AppTypography.heading1,
                fontWeight: AppTypography.weightExtraBold,
                letterSpacing: -0.7,
                color: Colors.white,
                height: 1,
              ),
            ),
            if (item.unit != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  item.unit!,
                  style: TextStyle(
                    fontSize: AppTypography.micro,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.label,
    required this.value,
    required this.total,
    this.percentage,
  });

  final String label;
  final double value;
  final double total;
  final double? percentage;

  @override
  Widget build(BuildContext context) {
    final percent = percentage ?? (value / total * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.overline,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: AppTypography.overline,
                fontWeight: AppTypography.weightBold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ProgressBar(
          progress: value / total,
          // มockup ใช้สีเหลืองทองสำหรับแถบนี้โดยเฉพาะ (ตัดกับพื้นเขียวเข้มชัดกว่า
          // teal-light) ต่างจากแถบ progress อื่นในระบบที่ใช้ teal ปกติ
          color: const Color(0xFFFDE047),
          backgroundColor: Colors.white.withValues(alpha: 0.18),
        ),
      ],
    );
  }
}
