// deadline_list_item.dart
// รายการที่ใกล้ครบกำหนด — ใช้ในแผงด้านข้าง
// ตรงกับ .dli ใน mockup — โครงจริงมีแค่ "กล่องวันที่ + ข้อความ 2 บรรทัด"
// (ไม่มีคอลัมน์ขวาแยกสำหรับนับวันเหมือนที่เคยออกแบบไว้ก่อนหน้า) เลขวันคงเหลือ/
// เกินกำหนดถูกผสมเป็นส่วนหนึ่งของบรรทัดที่สอง (subtitle) แทน — ผู้เรียกใช้เป็น
// คนคำนวณ/ประกอบข้อความเอง ตัว widget นี้แค่จัดวางกับใส่สีแดงตอน isUrgent

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Deadline list item — แสดงรายการที่ใกล้ครบกำหนด
class DeadlineListItem extends StatelessWidget {
  const DeadlineListItem({
    super.key,
    required this.date,
    required this.month,
    required this.title,
    required this.subtitle,
    this.isUrgent = false,
    this.onTap,
  });

  final String date; // "17"
  final String month; // "ส.ค."
  final String title; // เช่น "ส่งมอบงาน · จ้างปรับปรุงห้องสมุด"
  final String subtitle; // เช่น "w.007/2569 · เกินกำหนด 6 วัน"
  final bool isUrgent; // true = เกินกำหนด/ครบกำหนดวันนี้ (แต้มสีแดงที่กล่องวันที่)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // กล่องวันที่ — เปลี่ยนเป็นสีแดงตอนเกินกำหนด (.dli.urg .dt2)
            Container(
              width: 34,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isUrgent ? BrandAccent.red(context).withValues(alpha: 0.1) : BrandAccent.surface2(context),
                borderRadius: BorderRadius.circular(RadiusSize.md),
                border: Border.all(
                  color: isUrgent ? BrandAccent.red(context).withValues(alpha: 0.2) : colorScheme.outline,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppTypography.weightExtraBold,
                      color: isUrgent ? BrandAccent.red(context) : colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: AppTypography.nano,
                      fontWeight: AppTypography.weightBold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      fontWeight: AppTypography.weightBold,
                      color: colorScheme.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // mockup ให้แค่กล่องวันที่เปลี่ยนแดงตอนเกินกำหนด (.dli.urg .dt2)
                    // ส่วนบรรทัดนี้ (.dli .tx .b) เป็นสีเทาเดิมเสมอ ไม่มี .urg override
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.tiny,
                      fontWeight: AppTypography.weightMedium,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
