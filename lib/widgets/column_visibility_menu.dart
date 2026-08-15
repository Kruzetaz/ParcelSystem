// column_visibility_menu.dart
// ปุ่มเลือกซ่อน/แสดงคอลัมน์ในตารางที่มีคอลัมน์เยอะ (ทะเบียนคุมต่างๆ) — คลิกแล้ว
// ติ๊กออก/เข้าได้ทีละคอลัมน์ ไม่กระทบข้อมูล แค่ซ่อนการแสดงผลบางคอลัมน์ชั่วคราว

import 'package:flutter/material.dart';

class ColumnVisibilityMenu extends StatelessWidget {
  final List<String> allColumns;
  final Set<String> visibleColumns;
  final ValueChanged<Set<String>> onChanged;

  const ColumnVisibilityMenu({
    super.key,
    required this.allColumns,
    required this.visibleColumns,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'เลือกคอลัมน์ที่จะแสดง',
      // เดิมใช้ icon: (บังคับ IconButton ล้อมรอบเริ่มต้นของ Material — วงกลม
      // โปร่งไม่มีขอบ) เปลี่ยนมาใช้ child: กล่องสี่เหลี่ยมมีขอบแทน ให้หน้าตา
      // เหมือนปุ่มไอคอนอื่นๆ ในตาราง (เช่นปุ่มดู/แก้ไข/ลบท้ายแถว) ไม่ใช่ปุ่มลอย
      // ไม่มีกรอบแยกออกจากกลุ่มปุ่มข้างๆ
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outline),
        ),
        child: Icon(Icons.view_column_outlined, size: 18, color: colors.onSurface),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline),
      ),
      elevation: 6,
      itemBuilder: (context) => allColumns
          .map((col) => CheckedPopupMenuItem<String>(
                value: col,
                checked: visibleColumns.contains(col),
                child: Text(col, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onSelected: (col) {
        final next = Set<String>.from(visibleColumns);
        if (next.contains(col)) {
          next.remove(col);
        } else {
          next.add(col);
        }
        onChanged(next);
      },
    );
  }
}
