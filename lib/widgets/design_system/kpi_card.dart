// kpi_card.dart
// KPI card component — แสดงตัวเลขสถิติพร้อมไอคอน, แถบความคืบหน้า
// ตรงกับ .kp ใน mockup

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

enum KpiCardVariant {
  navy, // k1
  green, // k2
  amber, // k3
  teal, // k4
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.subtitle,
    this.progress,
    required this.icon,
    this.variant = KpiCardVariant.teal,
  });

  final String label;
  final String value;
  final String? unit;
  final String? subtitle;
  final double? progress; // 0.0-1.0
  final IconData icon;
  final KpiCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final colors = _getColors(context, variant);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // mockup .kp.k3 คือ amber 5% เคลือบทับสี surface ปกติ (ไม่ใช่พื้นขาว
        // ครีมค่าคงที่) ของเดิม hardcode สีขาวอมเหลืองไว้ตรงๆ ถูกเฉพาะโหมดสว่าง
        // พอเป็นโหมดมืดพื้นการ์ดจะกลายเป็นกล่องสีขาวสว่างแปลกแยกจากการ์ดอื่น
        // ที่มืดหมด — ใช้ alphaBlend เคลือบทับ surface ของธีมปัจจุบันแทน
        color: variant == KpiCardVariant.amber
            ? Color.alphaBlend(
                BrandColors.amber.withValues(alpha: 0.05), colorScheme.surface)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(
          color: variant == KpiCardVariant.amber
              ? BrandColors.amber.withValues(alpha: 0.35)
              : colorScheme.outline,
        ),
        boxShadow: AppShadows.light1,
      ),
      // แถบสีบนสุดใช้ Positioned ลอยทับ (ตรงกับ mockup ที่ใช้ ::before แบบ
      // position:absolute ไม่กินพื้นที่ใน flow) — ของเดิมเป็น Container จริง
      // ใน Column กิน margin-bottom 14px เพิ่มเข้าไปทำให้การ์ดสูงเกิน mockup
      // ไปเปล่าๆ 17px ทุกใบ
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: colors.accent,
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.7),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: _buildContent(context, colorScheme, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ColorScheme colorScheme, _KpiColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon + Label row
        Row(
          children: [
            Container(
              width: Dimensions.kpiIconSize,
              height: Dimensions.kpiIconSize,
              decoration: BoxDecoration(
                color: colors.iconBg,
                borderRadius: BorderRadius.circular(RadiusSize.md),
              ),
              child: Icon(
                icon,
                size: IconSizes.md,
                color: colors.iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  fontWeight: AppTypography.weightBold,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Value
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTypography.display1,
                  fontWeight: AppTypography.weightExtraBold,
                  letterSpacing: -1.1,
                  height: 1,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit!,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    fontWeight: AppTypography.weightBold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: AppTypography.micro,
              fontWeight: AppTypography.weightSemiBold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: BrandAccent.surface2(context),
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ],
      ],
    );
  }

  _KpiColors _getColors(BuildContext context, KpiCardVariant variant) {
    switch (variant) {
      case KpiCardVariant.navy:
        final c = BrandAccent.navy(context);
        return _KpiColors(
            accent: c, iconBg: c.withValues(alpha: 0.1), iconColor: c);
      case KpiCardVariant.green:
        // ไม่มีในชุดโทเค็น mockup (สีเสริมเฉพาะ KPI นี้) — คงค่าเดียวไว้ทั้ง
        // สองธีมได้ตามเดิม ไม่กระทบคอนทราสต์มากนักเพราะใช้แค่พื้นหลังจางๆ
        return _KpiColors(
          accent: const Color(0xFF10B981),
          iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
          iconColor: const Color(0xFF10B981),
        );
      case KpiCardVariant.amber:
        final c = BrandAccent.tertiary(context);
        return _KpiColors(
            accent: c, iconBg: c.withValues(alpha: 0.1), iconColor: c);
      case KpiCardVariant.teal:
        final c = BrandAccent.teal(context);
        return _KpiColors(
            accent: c, iconBg: c.withValues(alpha: 0.1), iconColor: c);
    }
  }
}

class _KpiColors {
  final Color accent;
  final Color iconBg;
  final Color iconColor;

  _KpiColors({
    required this.accent,
    required this.iconBg,
    required this.iconColor,
  });
}
