// collapsible_sidebar.dart
// แผงด้านข้างที่พับ/กางได้ — ใช้แทน colR ใน mockup
// รองรับ responsive และ animation
//
// [แยกการ์ดตาม mockup]: เดิม CollapsibleSidebar ห่อ children ทั้งหมดไว้ใน
// การ์ดใบเดียว (กรอบ/เงาเดียวคลุมทุก section) ต่างจาก mockup ที่แต่ละ section
// (.rcard) เป็นการ์ดแยกกันเอง มีกรอบ/เงาของตัวเอง เว้นช่องว่าง (gap:14px)
// ระหว่างกัน — ย้ายการห่อการ์ด (สี/ขอบ/มุมโค้ง/เงา) ไปไว้ที่ SidebarSection
// แทน ตัว CollapsibleSidebar เองเหลือแค่กรอบ animate ความกว้าง + ปุ่มพับ/กาง
// ปุ่มเดียวที่ยังคุมทุก section พร้อมกัน (ไม่ได้แยกปุ่มต่อการ์ด)

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import '../../theme/design_tokens.dart';

/// Collapsible sidebar — แผงด้านข้างพับได้
class CollapsibleSidebar extends StatefulWidget {
  const CollapsibleSidebar({
    super.key,
    required this.children,
    this.initiallyExpanded = true,
    this.width = 190,
  });

  final List<Widget> children;
  final bool initiallyExpanded;
  final double width;

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: 0,
      end: widget.width,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      // top ไม่ใช่ center — mockup ปักปุ่มพับ/กางไว้ที่บนสุด (align-self:
      // flex-start) เดิมใช้ค่า default (center) ทำให้ปุ่มลอยอยู่กลางความสูง
      // รวมของทุกการ์ด ดูเหมือนลอยไม่มีจุดยึดเวลามีหลาย section ซ้อนกัน
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button — ปุ่มเดียวคุมทุกการ์ดพร้อมกัน
        InkWell(
          onTap: _toggle,
          child: Container(
            width: Dimensions.sidebarCollapsedWidth,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(RadiusSize.lg),
                bottomLeft: Radius.circular(RadiusSize.lg),
              ),
              boxShadow: AppShadows.light1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.chevron_left,
                    size: IconSizes.xl,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sidebar content — Column ของการ์ดแยก (แต่ละ child ห่อการ์ดของตัวเองแล้ว
        // ใน SidebarSection) เว้นช่องว่างระหว่างกันตรงนี้แทนที่ผู้เรียกใช้จะต้อง
        // ใส่ SizedBox คั่นเองทุกครั้ง
        AnimatedBuilder(
          animation: _widthAnimation,
          builder: (context, child) {
            return SizedBox(
              width: _widthAnimation.value,
              child: _widthAnimation.value > 0
                  ? ClipRect(
                      // [แก้บั๊ก overflow ระหว่างอนิเมชัน]: SizedBox(width:
                      // widget.width) เดิมเข้าใจผิดว่าจะบังคับเนื้อหาข้างในให้
                      // กว้าง 190 เสมอ แต่ที่จริง constraint จากพ่อแม่ (SizedBox
                      // ด้านนอกที่ animate ความกว้างอยู่) รัดแน่นกว่าเสมอ —
                      // SizedBox ธรรมดาไม่มีทาง "ฝืน" ให้กว้างเกินกว่าที่พ่อแม่
                      // อนุญาต ผลคือช่วงกลางอนิเมชัน (เช่นความกว้างเหลือ ~69px)
                      // เนื้อหาข้างในถูกบีบตามจริง ทำให้ Row ในหัวการ์ด
                      // (SidebarSection) ล้น — OverflowBox คือ widget เดียวที่
                      // "เพิกเฉย" ต่อ constraint ของพ่อแม่แล้วบังคับขนาดลูกเองได้
                      // จริง ส่วนที่เกินขอบเขตให้ ClipRect ด้านนอกตัดทิ้งแทน
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: widget.width,
                        maxWidth: widget.width,
                        // fit เริ่มต้น (.max) จะพยายามบังคับขนาดของ OverflowBox
                        // เองให้เท่า maxWidth/maxHeight ที่ตั้งไว้ — maxHeight
                        // ไม่ได้กำหนดไว้ (null) เลยสืบทอด constraint สูงสุดจาก
                        // พ่อแม่ ซึ่งไม่จำกัด (infinity) เพราะทั้งหน้าอยู่ใน
                        // SingleChildScrollView แนวตั้งอีกที ผลคือ OverflowBox
                        // พยายามสูงเป็น infinity เกิด layout error ทำให้พื้นที่
                        // ทั้งหมดเรนเดอร์ไม่ออก (ว่างเปล่า) — deferToChild แก้
                        // โดยให้ OverflowBox รายงานขนาดของตัวเองตามลูกจริง แทนที่
                        // จะพยายามเท่า max constraint
                        fit: OverflowBoxFit.deferToChild,
                        child: SizedBox(
                          width: widget.width,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < widget.children.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 14),
                                  widget.children[i],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }
}

/// Sidebar section — การ์ดหนึ่งใบในแผงด้านข้าง (.rcard ใน mockup) — แต่ละ
/// section เป็นการ์ดแยกของตัวเอง มีกรอบ/เงา/มุมโค้งเอง
class SidebarSection extends StatelessWidget {
  const SidebarSection({
    super.key,
    required this.title,
    required this.child,
    this.padding,
    this.count,
    this.trailingIcon,
    this.onTrailingIconTap,
    this.trailingIconColor,
  });

  final String title;
  final Widget child;
  final EdgeInsets? padding;
  // ป้ายตัวเลขข้างหัวข้อ + ไอคอนขวาสุด — ตรงกับ .rch .nb ใน mockup
  final int? count;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingIconTap;
  // สีไอคอนขวาสุดต่างกันตามการ์ด — mockup ให้ "เมนูด่วน" (ไอคอนปรับแต่ง) เป็น
  // teal-on แต่ "ครบกำหนดเร็วๆ นี้" (ไอคอนปฏิทิน) เป็นสีเทาปกติ ไม่มีสีเดียว
  // ที่ใช้ได้กับทุกการ์ด — ปล่อย null ใช้สีเทา default เดิมไว้
  final Color? trailingIconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BrandAccent.surface3(context),
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    fontWeight: AppTypography.weightExtraBold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandAccent.surface2(context),
                      borderRadius: BorderRadius.circular(RadiusSize.xxl),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: AppTypography.mini,
                        fontWeight: AppTypography.weightBold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (trailingIcon != null)
                  InkWell(
                    onTap: onTrailingIconTap,
                    borderRadius: BorderRadius.circular(RadiusSize.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(trailingIcon, size: 14, color: trailingIconColor ?? colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}
