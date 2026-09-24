// gap_filter_banner.dart
// แถบแจ้งเตือนเมื่อหน้านี้ถูกเปิดมาจากลิงก์ "ดูรายการที่ขาด" ในเช็คลิสต์ สตง.
// (หน้ารายงาน/สตง.) — บอกผู้ใช้ว่าตอนนี้กรองเฉพาะรายการที่ข้อมูลยังไม่ครบอยู่
// พร้อมปุ่มล้างตัวกรองกลับไปดูรายการทั้งหมดตามปกติ

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

class GapFilterBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClear;

  const GapFilterBanner(
      {super.key, required this.message, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RadiusSize.md),
        border: Border.all(color: BrandColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 18, color: BrandColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text('ล้างตัวกรอง แสดงทั้งหมด'),
          ),
        ],
      ),
    );
  }
}
