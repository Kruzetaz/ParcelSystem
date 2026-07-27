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
      icon: Icon(Icons.view_column_outlined, color: colors.primary),
      itemBuilder: (context) => allColumns
          .map((col) => CheckedPopupMenuItem<String>(
                value: col,
                checked: visibleColumns.contains(col),
                child: Text(col),
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
