// selection_bar.dart
// แถบเมื่อเปิดโหมด "เลือกหลายรายการ" ในตาราง — ตรงกับ .selbar ใน mockup

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'glass_container.dart';

class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onCancel,
    this.onCopyToCurrentYear,
    this.onGenerateDocuments,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback? onCopyToCurrentYear;
  // สร้างเอกสารหลัก (ชุดเต็ม) ให้ทุกรายการที่ติ๊กเลือกไว้ทีเดียว — null =
  // ไม่มีรายการเลือกอยู่ ปิดปุ่มไว้
  final VoidCallback? onGenerateDocuments;

  @override
  Widget build(BuildContext context) {
    final teal = BrandAccent.teal(context);
    final primaryContainer = BrandAccent.primaryContainer(context);
    final onPrimaryContainer = BrandAccent.onPrimaryContainer(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: BoxDecoration(
        color: primaryContainer,
        border: Border(
          bottom: BorderSide(color: teal.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 13, color: onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            'เลือกแล้ว $selectedCount รายการ',
            style: TextStyle(
              fontSize: AppTypography.caption,
              fontWeight: AppTypography.weightBold,
              color: onPrimaryContainer,
            ),
          ),
          const Spacer(),
          _pillButton(context, label: 'เลือกทั้งหมด ($totalCount)', onTap: onSelectAll),
          if (onGenerateDocuments != null) ...[
            const SizedBox(width: 8),
            _pillButton(
              context,
              label: 'สร้างเอกสาร',
              icon: Icons.description_outlined,
              onTap: onGenerateDocuments!,
              emphasized: true,
            ),
          ],
          if (onCopyToCurrentYear != null) ...[
            const SizedBox(width: 8),
            _pillButton(
              context,
              label: 'คัดลอกไปปีงบปัจจุบัน',
              icon: Icons.drive_file_move_outline,
              onTap: onCopyToCurrentYear!,
              emphasized: true,
            ),
          ],
          const SizedBox(width: 8),
          _pillButton(context, label: 'ยกเลิก', onTap: onCancel),
        ],
      ),
    );
  }

  Widget _pillButton(
    BuildContext context, {
    required String label,
    IconData? icon,
    required VoidCallback onTap,
    bool emphasized = false,
  }) {
    final teal = BrandAccent.teal(context);
    final onPrimaryContainer = BrandAccent.onPrimaryContainer(context);
    final content = Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: emphasized ? Colors.white : onPrimaryContainer),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.caption,
              fontWeight: AppTypography.weightBold,
              color: emphasized ? Colors.white : onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
    // ปุ่มในแถบเลือกหลายรายการมีไม่กี่ปุ่มต่อครั้ง — ใส่กระจกฝ้าได้ไม่กระทบ
    // ประสิทธิภาพ ยกเว้นปุ่ม emphasized ที่พื้นทึบอยู่แล้ว
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusSize.lg),
      child: emphasized
          ? Container(
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(RadiusSize.lg),
                border: Border.all(color: teal),
              ),
              child: content,
            )
          : GlassContainer(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(RadiusSize.lg),
              border: Border.all(color: teal.withValues(alpha: 0.2)),
              child: content,
            ),
    );
  }
}
