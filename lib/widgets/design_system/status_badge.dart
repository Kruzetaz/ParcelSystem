// status_badge.dart
// Badge/Chip แสดงสถานะ — ใช้ใน table, alert, และจุดต่าง ๆ
// ตรงกับ .chip, .alt, badge ต่าง ๆ ใน mockup

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'glass_container.dart';

enum BadgeVariant {
  neutral,
  teal,
  success,
  warning,
  danger,
  info,
  purple,
  indigo,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final BadgeVariant variant;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = _getColors(context, variant, colorScheme);

    // pill (compact) ทุกอันใน mockup มีจุดกลมนำหน้าเสมอ (.pill i) พร้อม glow
    // สีเดียวกับตัวหนังสือ — ตัวเต็ม (ไม่ compact) ไม่มีจุดนี้
    final content = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(
          compact ? RadiusSize.xxl : RadiusSize.md,
        ),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact) ...[
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.text,
                boxShadow: [BoxShadow(color: colors.text.withValues(alpha: 0.6), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? AppTypography.mini : AppTypography.bodySmall,
              fontWeight: AppTypography.weightBold,
              color: colors.text,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          compact ? RadiusSize.xxl : RadiusSize.md,
        ),
        child: content,
      );
    }

    return content;
  }

  _BadgeColors _getColors(BuildContext context, BadgeVariant variant, ColorScheme colorScheme) {
    switch (variant) {
      case BadgeVariant.neutral:
        return _BadgeColors(
          background: colorScheme.surface,
          border: colorScheme.outline,
          text: colorScheme.onSurfaceVariant,
        );
      case BadgeVariant.teal:
        final teal = BrandAccent.teal(context);
        return _BadgeColors(background: teal, border: teal, text: Colors.white);
      case BadgeVariant.success:
        return _BadgeColors(
          background: BrandAccent.emeraldLight(context),
          border: BrandAccent.emerald(context).withValues(alpha: 0.3),
          text: BrandAccent.emeraldText(context),
        );
      case BadgeVariant.warning:
        final c = BrandAccent.tertiary(context);
        return _BadgeColors(
          background: c.withValues(alpha: 0.08),
          border: c.withValues(alpha: 0.28),
          text: c,
        );
      case BadgeVariant.danger:
        final c = BrandAccent.red(context);
        return _BadgeColors(
          background: c.withValues(alpha: 0.08),
          border: c.withValues(alpha: 0.3),
          text: c,
        );
      case BadgeVariant.info:
        final c = BrandAccent.blue(context);
        return _BadgeColors(
          background: c.withValues(alpha: 0.08),
          border: c.withValues(alpha: 0.25),
          text: c,
        );
      case BadgeVariant.purple:
        final c = BrandAccent.purple(context);
        return _BadgeColors(
          background: c.withValues(alpha: 0.08),
          border: c.withValues(alpha: 0.25),
          text: c,
        );
      case BadgeVariant.indigo:
        final c = BrandAccent.indigo(context);
        return _BadgeColors(
          background: c.withValues(alpha: 0.08),
          border: c.withValues(alpha: 0.25),
          text: c,
        );
    }
  }
}

class _BadgeColors {
  final Color background;
  final Color border;
  final Color text;

  _BadgeColors({
    required this.background,
    required this.border,
    required this.text,
  });
}

/// Filter chip — สำหรับ toolbar กรอง (.chip ใน mockup)
/// [isDanger]: สไตล์แดงถาวรแม้ยังไม่ถูกเลือก (ตรงกับ .chip.dgr เช่น "ไม่มีเลข e-GP")
class DSFilterChip extends StatelessWidget {
  const DSFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bg;
    Color border;
    Color text;
    if (isSelected) {
      final teal = BrandAccent.teal(context);
      bg = teal;
      border = teal;
      text = Colors.white;
    } else if (isDanger) {
      final red = BrandAccent.red(context);
      bg = red.withValues(alpha: 0.08);
      border = red.withValues(alpha: 0.25);
      text = red;
    } else {
      bg = colorScheme.surface;
      border = colorScheme.outline;
      text = colorScheme.onSurfaceVariant;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusSize.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(RadiusSize.md),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.caption,
            fontWeight: AppTypography.weightBold,
            color: text,
          ),
        ),
      ),
    );
  }
}

/// Alert tile — แถบแจ้งเตือนแบบเด่น (.alt ใน mockup)
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.icon,
    required this.count,
    required this.message,
    required this.variant,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String message;
  final BadgeVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = _getColors(context, variant, colorScheme);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusSize.pill),
      child: GlassContainer(
        blurSigma: 10,
        borderRadius: BorderRadius.circular(RadiusSize.pill),
        color: colors.background,
        border: Border.all(color: colors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IconSizes.sm, color: colors.text),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppTypography.weightExtraBold,
                letterSpacing: -0.5,
                color: colors.text,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  fontWeight: AppTypography.weightRegular,
                  color: colors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward,
              size: IconSizes.sm,
              color: colors.text.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  _BadgeColors _getColors(BuildContext context, BadgeVariant variant, ColorScheme colorScheme) {
    switch (variant) {
      case BadgeVariant.danger:
        final c = BrandAccent.red(context);
        return _BadgeColors(background: c.withValues(alpha: 0.08), border: c.withValues(alpha: 0.3), text: c);
      case BadgeVariant.warning:
        final c = BrandAccent.tertiary(context);
        return _BadgeColors(background: c.withValues(alpha: 0.08), border: c.withValues(alpha: 0.28), text: c);
      case BadgeVariant.info:
        final c = BrandAccent.blue(context);
        return _BadgeColors(background: c.withValues(alpha: 0.08), border: c.withValues(alpha: 0.25), text: c);
      default:
        return _BadgeColors(
          background: colorScheme.surface,
          border: colorScheme.outline,
          text: colorScheme.onSurfaceVariant,
        );
    }
  }
}
