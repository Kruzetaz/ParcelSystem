// activation_screen.dart v2
// แสดงเมื่อ HWID ไม่พบในระบบ — ให้ user กรอก code เพื่อ activate

import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../theme/design_tokens.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _codeCtrl = TextEditingController();
  final _service  = LicenseService.instance;

  bool    _loading = false;
  String? _errorMsg;
  String? _hwId;

  @override
  void initState() {
    super.initState();
    _loadHwId();
  }

  Future<void> _loadHwId() async {
    final id = await _service.getHardwareId();
    if (mounted) setState(() => _hwId = id);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String _translateError(String? reason) {
    switch (reason) {
      case 'invalid_code':
        return 'ไม่พบ License Key นี้ในระบบ กรุณาตรวจสอบอีกครั้ง';
      case 'code_used':
        return 'Key นี้ถูกใช้งานกับเครื่องอื่นไปแล้ว (Single License)';
      case 'quota_exceeded':
        return 'Key นี้ถูกใช้งานครบจำนวนเครื่องที่กำหนดแล้ว';
      case 'revoked':
        return 'License Key นี้ถูกระงับการใช้งาน กรุณาติดต่อผู้พัฒนา';
      case 'expired':
        return 'License Key นี้หมดอายุแล้ว กรุณาติดต่อผู้พัฒนา';
      case 'network_error':
        return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
      case 'server_error':
        return 'เกิดข้อผิดพลาดในระบบ กรุณาติดต่อผู้พัฒนา';
      default:
        return 'เกิดข้อผิดพลาด: ${reason ?? "unknown"} กรุณาติดต่อผู้พัฒนา';
    }
  }

  Future<void> _activate() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = 'กรุณากรอก License Key');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

    try {
      final result = await _service.activate(code);
      if (!mounted) return;

      if (result.isValid) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _errorMsg = _translateError(result.errorReason));
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMsg = 'ไม่สามารถเชื่อมต่อได้ กรุณาตรวจสอบอินเทอร์เน็ต');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RadiusSize.card),
              border: Border.all(color: colors.outline),
              boxShadow: AppShadows.light1,
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BrandAccent.teal(context),
                          borderRadius: BorderRadius.circular(RadiusSize.md),
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ParcelSystem — ระบบเจ้าหน้าที่พัสดุ-จัดซื้อจัดจ้าง',
                              style: TextStyle(
                                fontWeight: AppTypography.weightExtraBold,
                                fontSize: AppTypography.heading4,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              'v3.0 FullUpdate · พัฒนาโดย Kru.ZetaZ',
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Input ────────────────────────────────────────
                  Text(
                    'กรุณากรอก License Key เพื่อเปิดใช้งาน',
                    style: TextStyle(fontSize: AppTypography.body, color: colors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(fontSize: 17),
                    decoration: InputDecoration(
                      labelText: 'License Key',
                      hintText: 'XXXX-XXXX-XXXX-XXXX',
                      errorText: _errorMsg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      labelStyle: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.45), width: 1.3),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.45), width: 1.3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.6),
                      ),
                    ),
                    onSubmitted: (_) => _activate(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _activate,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('เปิดใช้งาน'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, color: colors.outlineVariant),
                  const SizedBox(height: 16),

                  // ── Hardware ID ──────────────────────────────────
                  Text(
                    'Hardware ID ของเครื่องนี้:',
                    style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant, fontWeight: AppTypography.weightSemiBold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(RadiusSize.sm),
                      border: Border.all(color: colors.outline),
                    ),
                    child: SelectableText(
                      _hwId ?? 'กำลังโหลด...',
                      style: TextStyle(fontFamily: 'monospace', fontSize: AppTypography.caption, color: colors.onSurface),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'หากต้องการ License Key กรุณาติดต่อผู้พัฒนาพร้อมแจ้ง Hardware ID ข้างต้น',
                    style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Line ID: @157vaipv',
                    style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant, fontWeight: AppTypography.weightSemiBold),
                  ),
                  Text(
                    'Facebook: Acha Sangkannork',
                    style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant, fontWeight: AppTypography.weightSemiBold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}