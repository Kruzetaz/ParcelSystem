// quick_action_tile.dart
// ปุ่มเมนูด่วน — ใช้ในแผงด้านข้าง
// ตรงกับ .acts b ใน mockup

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Quick action tile — ปุ่มไอคอนพร้อมป้ายกำกับ
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ตรงกับ .qt ใน mockup — พื้นเขียวอ่อนโปร่งแสง ไอคอนสีเขียวเข้ม (ไม่ใช่การ์ด
    // สีขาว/เทาแบบปุ่มไอคอนอื่นในระบบ) เพราะปุ่มเมนูด่วนตั้งใจให้เด่นกว่าปุ่มธรรมดา
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusSize.xl),
        hoverColor: BrandAccent.teal(context).withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            // เพิ่มความเข้มจาก .06 เป็น .09 ให้เห็นสีเขียวชัดขึ้น (ของเดิมจาง
            // จนดูเหมือนกล่องขาวเปล่าๆ ในสกรีนช็อตจริง)
            color: BrandAccent.teal(context).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(RadiusSize.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: BrandAccent.tealOn(context)),
              const SizedBox(height: 3),
              // maxLines:1 (ไม่ใช่ 2) — บังคับความสูงให้คงที่ทุกปุ่มเสมอ กัน
              // ปุ่มที่ป้ายยาวกว่า (เช่น "ตั้งค่า AI") พองตัวสูงกว่าปุ่มอื่นในแถว
              // เดียวกัน ซึ่งเป็นสาเหตุหลักที่ทำให้ดูเป็นกล่องสี่เหลี่ยมใหญ่ไม่เท่ากัน
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  fontWeight: AppTypography.weightBold,
                  color: colorScheme.onSurface,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick actions grid — กริดของปุ่มเมนูด่วน
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.actions,
    this.crossAxisCount = 3,
  });

  final List<QuickAction> actions;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    // ไม่ใช้ GridView+childAspectRatio:1 อีกต่อไป — สี่เหลี่ยมจัตุรัสบังคับให้
    // ทุกช่องสูงเท่าความกว้าง ซึ่งกว้างกว่าที่เนื้อหา (ไอคอน 18px + ป้ายชื่อ)
    // ต้องการมาก ทำให้ปุ่มดูอ้วน/สูงเทอะทะกว่า mockup มาก (mockup ไม่ได้บังคับ
    // อัตราส่วนเลย ปล่อยให้สูงตามเนื้อหาจริง) เปลี่ยนมาต่อแถวเองแทน ความสูงจะ
    // ยึดตามเนื้อหาของ QuickActionTile เอง ไม่ใช่ความกว้างของช่อง
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += crossAxisCount) {
      final rowActions = actions.skip(i).take(crossAxisCount).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < crossAxisCount; j++) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(
                child: j < rowActions.length
                    ? QuickActionTile(
                        icon: rowActions[j].icon,
                        label: rowActions[j].label,
                        onTap: rowActions[j].onTap,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
