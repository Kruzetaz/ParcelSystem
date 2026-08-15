// app_card.dart
// การ์ดพื้นฐาน — ใช้ครอบเนื้อหาทั่วไป พร้อมหัวข้อและการพับ/กางได้
// ตรงกับ .card ใน mockup

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// การ์ดพื้นฐานที่ใช้ทั่วทั้งระบบ
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.title,
    this.titleWidget,
    this.titleAction,
    required this.child,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final String? title;
  // ใช้แทน title (String ธรรมดา) เมื่อต้องการแปะอะไรเพิ่มติดกับหัวข้อเลย
  // (เช่น badge ตัวเลขนับรายการ) โดยไม่ให้มันไปแยกไกลกับปุ่ม/ช่องค้นหาอื่นๆ
  // ใน titleAction ที่ถูกดันไปสุดขวาด้วย WrapAlignment.spaceBetween
  final Widget? titleWidget;
  final Widget? titleAction;
  final Widget child;
  final EdgeInsets? padding;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (collapsible) {
      return _CollapsibleCard(
        title: title,
        titleWidget: titleWidget,
        titleAction: titleAction,
        initiallyExpanded: initiallyExpanded,
        padding: padding,
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colorScheme.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || titleWidget != null)
            _CardHeader(
              title: title,
              titleWidget: titleWidget,
              action: titleAction,
            ),
          Padding(
            padding: padding ?? const EdgeInsets.all(Dimensions.cardPadding),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    this.title,
    this.titleWidget,
    this.action,
    this.onTap,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.cardPadding,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outline),
        ),
      ),
      // Wrap แทน Row — กัน RenderFlex overflow ตอนหน้าต่างแคบ/action row ยาว
      // (เช่นการ์ดตารางที่มีหลายปุ่มในหัว) ถ้าที่ไม่พอจะเลื่อน action ไปอยู่
      // บรรทัดถัดไปแทนที่จะล้นจอ — title เองก็ครอบความกว้างไว้ + ตัดคำด้วย
      // ellipsis กันชื่อยาวๆ ทำ layout พังเหมือนกัน
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: titleWidget ??
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // mockup .ch h3 คือ 13.5px (heading4) ของเดิมใช้ caption(11px)
                  // เล็กไปมาก หัวข้อการ์ดเลยดูจมกับข้อความอื่นรอบๆ
                  style: TextStyle(
                    fontSize: AppTypography.heading4,
                    fontWeight: AppTypography.weightExtraBold,
                    color: colorScheme.onSurface,
                  ),
                ),
          ),
          if (action != null) action!,
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

class _CollapsibleCard extends StatefulWidget {
  const _CollapsibleCard({
    this.title,
    this.titleWidget,
    this.titleAction,
    required this.initiallyExpanded,
    this.padding,
    required this.child,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? titleAction;
  final bool initiallyExpanded;
  final EdgeInsets? padding;
  final Widget child;

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colorScheme.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null || widget.titleWidget != null)
            _CardHeader(
              title: widget.title,
              titleWidget: widget.titleWidget,
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.titleAction != null) ...[
                    widget.titleAction!,
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: IconSizes.md,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: _toggle,
            ),
          if (_isExpanded)
            Padding(
              padding: widget.padding ?? const EdgeInsets.all(Dimensions.cardPadding),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
