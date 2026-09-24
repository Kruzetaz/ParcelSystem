// license_grace_banner.dart
// แถบแจ้งเตือนตอนอยู่ในช่วงผ่อนผัน (grace period) — โผล่ตอนเครื่องเลยรอบเช็ค
// 90 วันไปแล้วแต่ยังต่อเน็ตไม่ได้ ให้ผู้ใช้รู้ตัวว่าต้องพาเครื่องไปต่อเน็ตเร็วๆ
// นี้ โดยที่งานเอกสารยังทำต่อได้ตามปกติทุกอย่าง ไม่ล็อกแอป

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class LicenseGraceBanner extends StatelessWidget {
  final int daysLeft;

  const LicenseGraceBanner({super.key, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: BrandColors.amber.withValues(alpha: 0.16),
      child: Row(
        children: [
          Icon(Icons.wifi_off_outlined, size: 18, color: BrandColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ไม่ได้เชื่อมต่ออินเทอร์เน็ตเพื่ออัปเดตสิทธิ์ลิขสิทธิ์เกิน 90 วันแล้ว '
              'กรุณาเชื่อมต่ออินเทอร์เน็ตภายใน $daysLeft วัน ไม่งั้นแอปจะถูกล็อกจนกว่าจะอัปเดตสิทธิ์',
              style: TextStyle(
                  fontSize: AppTypography.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
