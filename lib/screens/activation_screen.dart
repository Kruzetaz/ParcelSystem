// activation_screen.dart v2
// แสดงเมื่อ HWID ไม่พบในระบบ — ให้ user กรอก code เพื่อ activate

import 'package:flutter/material.dart';
import '../services/license_service.dart';

const _brandColor = Color(0xFF1A3A5C);

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(32),
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
                          color: _brandColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 40),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ParcelSystem- ระบบเจ้าหน้าที่พัสดุ-จัดซื้อจัดจ้าง',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _brandColor,
                              ),
                            ),
                            Text(
                              'v2.4 · พัฒนาโดย Kru.ZetaZ',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Input ────────────────────────────────────────
                  const Text(
                    'กรุณากรอก License Key เพื่อเปิดใช้งาน',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    decoration: InputDecoration(
                      labelText: 'License Key',
                      hintText: 'XXXX-XXXX-XXXX-XXXX',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: _errorMsg,
                    ),
                    onSubmitted: (_) => _activate(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _activate,
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Hardware ID ──────────────────────────────────
                  Text(
                    'Hardware ID ของเครื่องนี้:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      _hwId ?? 'กำลังโหลด...',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หากต้องการ License Key กรุณาติดต่อผู้พัฒนาพร้อมแจ้ง Hardware ID ข้างต้น',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Line ID: @157vaipv',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Facebook: Acha Sangkannork',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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