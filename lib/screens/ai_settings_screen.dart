// ai_settings_screen.dart
// หน้าตั้งค่า AI (Gemini) แยกออกจากหน้าตั้งค่าโรงเรียน เพื่อไม่ให้ผู้ใช้สับสน
// ระหว่างข้อมูลโรงเรียน (ใช้กรอกเอกสาร) กับการเชื่อมต่อ AI (ใช้ฟีเจอร์อ่านใบเสร็จ,
// นำเข้าแผนงบ, ช่วยเขียนเหตุผล)

import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/toast_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _geminiApiKeyCtrl;
  bool _loading = true;
  bool _geminiKeyVisible = false;
  bool _testingGemini = false;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final geminiKey = await GeminiService.instance.getApiKey();
    if (!mounted) return;
    if (geminiKey != null) _geminiApiKeyCtrl.text = geminiKey;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _geminiApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGeminiKey() async {
    await GeminiService.instance.saveApiKey(_geminiApiKeyCtrl.text);
    showAppToast('บันทึก Gemini API Key แล้ว');
  }

  Future<void> _testGeminiConnection() async {
    setState(() => _testingGemini = true);
    final result = await GeminiService.instance.testConnection(_geminiApiKeyCtrl.text);
    if (!mounted) return;
    setState(() => _testingGemini = false);
    if (result.ok) {
      // ทดสอบผ่าน → บันทึกคีย์นี้ไว้เลย จะได้ไม่ต้องกดบันทึกซ้ำ
      await GeminiService.instance.saveApiKey(_geminiApiKeyCtrl.text);
    }
    showAppToast(result.message, isError: !result.ok);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'การเชื่อมต่อ AI (Gemini)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ใส่ Gemini API Key เพื่อใช้ฟีเจอร์อ่านใบเสร็จ, นำเข้าแผนงบ '
                    'และช่วยเขียนเหตุผลความจำเป็น (บันทึกไว้ในเครื่องนี้เท่านั้น '
                    'ไม่ส่งขึ้นเซิร์ฟเวอร์อื่นใด)',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _geminiApiKeyCtrl,
                    obscureText: !_geminiKeyVisible,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: Icon(_geminiKeyVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _geminiKeyVisible = !_geminiKeyVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveGeminiKey,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึกคีย์'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _testingGemini ? null : _testGeminiConnection,
                          icon: _testingGemini
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: Text(_testingGemini ? 'กำลังทดสอบ...' : 'ทดสอบการเชื่อมต่อ'),
                          style: FilledButton.styleFrom(backgroundColor: colors.primary),
                        ),
                      ),
                    ],
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
