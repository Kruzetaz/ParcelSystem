// data_table_shell.dart
// โครงตารางข้อมูลหนาแน่น (dense data table) — ตรงกับ table.dt ใน mockup
// กำหนดคอลัมน์เป็น flex/fixed width แล้วส่ง cell widget ของแต่ละแถวเข้ามาเอง
// เพื่อไม่ผูกกับโมเดลข้อมูลเฉพาะหน้าใดหน้าหนึ่ง — ใช้ซ้ำได้กับตารางอื่นในระบบ

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'status_badge.dart';

/// ช่องติ๊กเลือกแถว — ตรงกับ .ck ใน mockup (สี่เหลี่ยมมุมโค้งเล็ก 15x15 ไม่ใช่
/// วงกลม/สี่เหลี่ยมมาตรฐานของ Checkbox ปกติของ Flutter)
class DsCheckbox extends StatelessWidget {
  const DsCheckbox({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 15,
        height: 15,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value ? BrandAccent.teal(context) : colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: value ? BrandAccent.teal(context) : colorScheme.outline,
              width: 1.5),
        ),
        child: value
            ? const Icon(Icons.check, size: 11, color: Colors.white)
            : null,
      ),
    );
  }
}

/// นิยามคอลัมน์ — ใช้ทั้งวาดหัวตารางและกำหนดความกว้างให้แถวข้อมูลตรงกัน
class DsColumn {
  final String label;
  final double? width; // null = ยืดตาม flex
  final int flex;
  final TextAlign align;
  const DsColumn(this.label,
      {this.width, this.flex = 1, this.align = TextAlign.left});
}

/// หัวตาราง (thead) — พื้นหลังเข้มกว่าเนื้อหาเล็กน้อย ตัวหนังสือเล็ก ตัวหนา
class DsTableHeader extends StatelessWidget {
  const DsTableHeader(
      {super.key, required this.columns, this.leading, this.spacing = 0});
  final List<DsColumn> columns;
  final Widget? leading; // เช่น ช่องว่างเทียบตำแหน่ง checkbox column
  // ระยะห่างระหว่างคอลัมน์ — ค่าเริ่มต้น 0 (เดิม) เพื่อไม่กระทบตารางหลักของ
  // แดชบอร์ดที่จูนความกว้างคอลัมน์ให้พอดีแบบไม่มีช่องว่างอยู่แล้ว ตารางอื่นที่
  // คอลัมน์แน่นเกินไป (เช่นป้ายประเภท/สถานะชนกับข้อความคอลัมน์ถัดไป) ค่อยส่ง
  // ค่านี้เข้ามาเอง
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: BrandAccent.surface2(context),
        border: Border(bottom: BorderSide(color: colorScheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        spacing: spacing,
        children: [
          if (leading != null) leading!,
          for (final col in columns) _headerCell(col, colorScheme),
        ],
      ),
    );
  }

  Widget _headerCell(DsColumn col, ColorScheme colorScheme) {
    final text = Text(
      col.label,
      textAlign: col.align,
      style: TextStyle(
        fontSize: AppTypography.tiny,
        fontWeight: AppTypography.weightBold,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
    if (col.width != null) return SizedBox(width: col.width, child: text);
    return Expanded(flex: col.flex, child: text);
  }
}

/// cell ช่วย wrap widget ให้ตรงกับความกว้าง/flex ของ column ที่กำหนดไว้ใน DsColumn
class DsCell extends StatelessWidget {
  const DsCell({super.key, required this.column, required this.child});
  final DsColumn column;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (column.width != null)
      return SizedBox(width: column.width, child: child);
    return Expanded(flex: column.flex, child: child);
  }
}

/// แถวข้อมูลหนึ่งแถว — จัดการ zebra stripe / hover / selected / warning tint ให้เอง
/// รองรับเนื้อหาที่กางออกได้ (expandedContent) เช่น timeline ของแถวนั้น
class DsTableRow extends StatefulWidget {
  const DsTableRow({
    super.key,
    required this.index,
    required this.cells,
    this.leading,
    this.onTap,
    this.selected = false,
    this.warn = false,
    this.expandedContent,
    this.spacing = 0,
  });

  final int index;
  final List<Widget> cells;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool selected;
  final bool warn;
  final Widget? expandedContent;
  // ต้องส่งค่าเดียวกับ DsTableHeader.spacing ของตารางเดียวกันเสมอ ไม่งั้น
  // หัวตาราง/แถวข้อมูลจะเยื้องไม่ตรงคอลัมน์กัน
  final double spacing;

  @override
  State<DsTableRow> createState() => _DsTableRowState();
}

class _DsTableRowState extends State<DsTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color bg;
    if (widget.selected) {
      bg = BrandAccent.emerald(context).withValues(alpha: 0.08);
    } else if (_hover) {
      bg = BrandAccent.emerald(context).withValues(alpha: 0.05);
    } else if (widget.warn) {
      bg = BrandAccent.red(context).withValues(alpha: 0.04);
    } else if (widget.index.isEven) {
      bg = colorScheme.surface;
    } else {
      bg = BrandAccent.surface3(context);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        // สีพื้นหลังตอน hover/select คุมเองแล้วผ่าน MouseRegion ด้านบน (ตัวแปร
        // bg) — ปิด overlay ของ InkWell/Material 3 เริ่มต้นทิ้งไปเลย ไม่งั้นซ้อน
        // กันสองชั้น กลายเป็นกรอบ/เงาเกินขอบเวลาแถวกว้างกว่าพื้นที่มองเห็นจริง
        // (ตอนตารางเลื่อนแนวนอน) เพราะ overlay เริ่มต้นของ Material ไม่ตัดขอบ
        // ตามพื้นที่มองเห็นเสมอไปเวลาซ้อนอยู่ใน SingleChildScrollView
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: colorScheme.outline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  spacing: widget.spacing,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.leading != null) widget.leading!,
                    ...widget.cells,
                  ],
                ),
              ),
              if (widget.expandedContent != null) widget.expandedContent!,
            ],
          ),
        ),
      ),
    );
  }
}

/// ข้อความ 2 บรรทัด (บรรทัดหลัก + บรรทัดรอง) — ใช้ซ้ำในหลายคอลัมน์
/// เช่น เลขที่/วันที่, โครงการ›กิจกรรม (.dno / .pn ใน mockup)
class DsTwoLineCell extends StatelessWidget {
  const DsTwoLineCell({super.key, required this.primary, this.secondary});
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTypography.bodySmall,
            fontWeight: AppTypography.weightBold,
            color: colorScheme.onSurface,
          ),
        ),
        if (secondary != null && secondary!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.tiny,
              fontWeight: AppTypography.weightMedium,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// สีป้ายวิธีจัดซื้อ ตรงกับ .p-slt/.p-pur/.p-ind ใน mockup — จับคู่ตาม
/// คำที่มักปรากฏในชื่อวิธี เพราะ procurementMethod เป็น free text ผสมวงเงิน
/// อยู่ในสตริงเดียวกัน (เช่น "เฉพาะเจาะจงตาม ว.804 (ไม่เกิน 50,000 บาท)")
BadgeVariant _methodVariant(String label) {
  if (label.contains('e-bidding') || label.contains('ประกาศเชิญชวน'))
    return BadgeVariant.indigo;
  if (label.contains('คัดเลือก')) return BadgeVariant.purple;
  return BadgeVariant.neutral;
}

/// ป้ายชื่อร้านค้าแบบมี avatar อักษรย่อ — ตรงกับ .ven ใน mockup
class DsVendorTag extends StatelessWidget {
  const DsVendorTag({super.key, required this.name, this.methodLabel});
  final String name;
  final String? methodLabel;

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed.length >= 2 ? trimmed.substring(0, 2) : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BrandAccent.surface2(context),
            borderRadius: BorderRadius.circular(RadiusSize.sm),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Text(
            _initials,
            style: TextStyle(
              fontSize: AppTypography.tiny,
              fontWeight: AppTypography.weightBold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  fontWeight: AppTypography.weightSemiBold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (methodLabel != null && methodLabel!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: StatusBadge(
                      label: methodLabel!,
                      variant: _methodVariant(methodLabel!),
                      compact: true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// จำนวนเงิน ชิดขวา + บรรทัดย่อยอธิบายภาษี — ตรงกับ .amc ใน mockup
class DsAmountCell extends StatelessWidget {
  const DsAmountCell({super.key, required this.amount, this.note});
  final String amount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTypography.bodyMedium,
            fontWeight: AppTypography.weightBold,
            color: colorScheme.onSurface,
          ),
        ),
        if (note != null && note!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.nano,
              fontWeight: AppTypography.weightMedium,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class DsRowAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  const DsRowAction(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.danger = false});
}

/// ปุ่มไอคอนดำเนินการแบบกลุ่ม (glass style) — ตรงกับ .acts ใน mockup
class DsActionIconButtons extends StatelessWidget {
  const DsActionIconButtons({super.key, required this.actions});
  final List<DsRowAction> actions;

  @override
  Widget build(BuildContext context) {
    // Row(mainAxisSize.min) เฉยๆ ไม่มีอะไรจัดตำแหน่งให้ ปล่อยให้ลอยชิดซ้ายของ
    // คอลัมน์ (ซึ่งกว้างกว่าตัวปุ่มจริงเยอะ) เลยไปติดกับคอลัมน์ความคืบหน้าข้างๆ
    // — ต้อง Align ให้ชิดขวาจริงๆ ตรงกับที่ mockup วาง .acts ไว้ชิดขอบขวาสุด
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in actions)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: _ActionButton(action: a),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.action});
  final DsRowAction action;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoverColor = widget.action.danger
        ? BrandAccent.red(context)
        : BrandAccent.navy(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.action.tooltip,
        child: InkWell(
          onTap: widget.action.onTap,
          borderRadius: BorderRadius.circular(RadiusSize.sm),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? hoverColor : colorScheme.surface,
              borderRadius: BorderRadius.circular(RadiusSize.sm),
              border:
                  Border.all(color: _hover ? hoverColor : colorScheme.outline),
            ),
            child: Icon(
              widget.action.icon,
              size: IconSizes.md,
              color: _hover ? Colors.white : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
