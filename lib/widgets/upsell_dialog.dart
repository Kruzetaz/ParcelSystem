// upsell_dialog.dart
// กล่องแนะนำอัปเกรดแพ็กเกจ — โผล่ตอนผู้ใช้กดเข้าเมนูที่ยังไม่ได้ปลดล็อกในสิทธิ์
// ปัจจุบัน (ดู FeatureAccessService) ทั้งจากการกดที่แถบเมนู (UI level) และ
// จากการกันซ้ำที่ระดับ routing/service (Security level) เผื่อมีการเรียก
// ข้ามเมนูมาโดยตรง

import 'package:flutter/material.dart';
import '../services/feature_access_service.dart';
import '../theme/design_tokens.dart';

/// โมดูลไหนอยู่ในแพ็กเกจไหนบ้าง (ต้องตรงกับ TIER_PRESETS ฝั่ง server ใน
/// LicenseSigning.gs) — ใช้แค่บอกผู้ใช้ว่าต้องอัปเกรดเป็นแพ็กเกจไหนถึงจะได้
/// โมดูลนี้ ไม่ใช่แหล่งความจริงของสิทธิ์จริง (สิทธิ์จริงตัดสินจาก token
/// เท่านั้น)
String _recommendedTierLabel(String requiredModule) {
  switch (requiredModule) {
    case FeatureModules.contractManagement:
    case FeatureModules.procurementCreate:
      return 'Premium หรือ Pro';
    default:
      return 'Pro';
  }
}

Future<void> showUpsellDialog(
  BuildContext context, {
  required String featureLabel,
  required String requiredModule,
}) {
  final colors = Theme.of(context).colorScheme;
  final tierLabel = _recommendedTierLabel(requiredModule);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.lock_outline, color: BrandColors.amber, size: 32),
      title: const Text('ฟีเจอร์นี้ยังไม่ได้ปลดล็อก'),
      content: Text(
        '"$featureLabel" เป็นโมดูลเสริมที่ยังไม่ได้ปลดล็อกในแพ็กเกจปัจจุบันของคุณ '
        'อัปเกรดเป็นแพ็กเกจ $tierLabel เพื่อเปิดใช้งานโมดูลนี้ '
        'ติดต่อผู้พัฒนาเพื่อสอบถามการอัปเกรด',
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('ปิด'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          onPressed: () => Navigator.pop(ctx),
          child: Text('อัปเกรดเป็น $tierLabel'),
        ),
      ],
    ),
  );
}
