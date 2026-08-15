// ai_settings_screen.dart
// หน้าตั้งค่า AI (Gemini) แยกออกจากหน้าตั้งค่าโรงเรียน เพื่อไม่ให้ผู้ใช้สับสน
// ระหว่างข้อมูลโรงเรียน (ใช้กรอกเอกสาร) กับการเชื่อมต่อ AI (ใช้ฟีเจอร์อ่านใบเสร็จ,
// นำเข้าแผนงบ, ช่วยเขียนเหตุผล)

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/toast_service.dart';
import '../theme/design_tokens.dart';

const _geminiApiKeyUrl = 'https://aistudio.google.com/apikey';

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
  // แยกจากการเช็ค _geminiApiKeyCtrl.text.isEmpty ตรงๆ เพราะช่องกรอกไม่ได้
  // sync แบบ real-time กับปุ่ม "ลบค่าที่บันทึก" (แก้ไขในช่องแล้วยังไม่กด
  // บันทึก ก็ไม่ควรทำให้ปุ่มลบใช้งานไม่ได้ทั้งที่จริงยังมีคีย์บันทึกอยู่)
  bool _hasSavedKey = false;

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
    setState(() {
      _hasSavedKey = geminiKey != null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _geminiApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGeminiKey() async {
    await GeminiService.instance.saveApiKey(_geminiApiKeyCtrl.text);
    if (!mounted) return;
    setState(() => _hasSavedKey = _geminiApiKeyCtrl.text.trim().isNotEmpty);
    showAppToast('บันทึก Gemini API Key แล้ว');
  }

  Future<void> _testGeminiConnection() async {
    setState(() => _testingGemini = true);
    final result =
        await GeminiService.instance.testConnection(_geminiApiKeyCtrl.text);
    if (!mounted) return;
    setState(() => _testingGemini = false);
    if (result.ok) {
      // ทดสอบผ่าน → บันทึกคีย์นี้ไว้เลย จะได้ไม่ต้องกดบันทึกซ้ำ
      await GeminiService.instance.saveApiKey(_geminiApiKeyCtrl.text);
      if (!mounted) return;
      setState(() => _hasSavedKey = _geminiApiKeyCtrl.text.trim().isNotEmpty);
    }
    showAppToast(result.message, isError: !result.ok);
  }

  /// เปิดเว็บขอ API Key ด้วยเบราว์เซอร์ default ของเครื่อง — ใช้ Process.run
  /// เรียกคำสั่งเปิดของแต่ละ OS แบบเดียวกับที่ไฟล์ export/document อื่นๆ ในแอป
  /// เปิดไฟล์ผลลัพธ์อยู่แล้ว (ไม่ต้องเพิ่ม dependency url_launcher ใหม่)
  Future<void> _openGeminiApiKeyPage() async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [_geminiApiKeyUrl]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', _geminiApiKeyUrl]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [_geminiApiKeyUrl]);
      }
    } catch (_) {
      if (!mounted) return;
      showAppToast('เปิดเว็บไม่สำเร็จ กรุณาเปิดเองที่ $_geminiApiKeyUrl',
          isError: true);
    }
  }

  Future<void> _showApiKeyGuide() async {
    const steps = [
      (
        'ไปที่ Google AI Studio',
        'เปิดเว็บเบราว์เซอร์แล้วเข้าเว็บไซต์ aistudio.google.com/apikey'
      ),
      (
        'เข้าสู่ระบบด้วยบัญชี Google',
        'ล็อกอินด้วยบัญชี Gmail ของคุณ หากเข้าใช้งานครั้งแรกให้กดยอมรับข้อตกลงการใช้งาน'
      ),
      ('กดปุ่ม "Create API Key"', 'จะมีป๊อปอัพ "Create a new key" เด้งขึ้นมา'),
      (
        'กรอกป๊อปอัพให้ครบ',
        'ช่อง "Name your key" ใส่ชื่ออะไรก็ได้ (ปล่อยค่าเริ่มต้นไว้ก็ได้) ส่วนช่อง "Choose an imported project" '
            'ถ้าเป็นครั้งแรกให้เลือก "Create project" เพื่อให้ระบบสร้างโปรเจกต์ใหม่ให้อัตโนมัติ '
            'แต่ถ้าเคยสร้างคีย์มาก่อนแล้ว เลือกโปรเจกต์เดิมจากรายการได้เลย แล้วกด "Create"',
      ),
      ('คัดลอกคีย์ที่ได้', 'คีย์จะขึ้นต้นด้วย AIza... กดคัดลอกไว้'),
      (
        'นำคีย์มาตั้งค่าในระบบ',
        'วางคีย์ที่คัดลอกมาในช่อง "Gemini API Key" แล้วกด "บันทึก" หรือ "ทดสอบการเชื่อมต่อ" เพื่อยืนยันอีกที'
      ),
    ];
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusSize.card)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined,
                color: BrandAccent.tertiary(context), size: 22),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('วิธีขอ API Key ฟรีจาก Google AI Studio',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: BrandAccent.teal(context),
                            shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(steps[i].$1,
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(steps[i].$2,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: colors.onSurfaceVariant,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        BrandColors.amber.withValues(alpha: 0.12),
                        colors.surface),
                    borderRadius: BorderRadius.circular(RadiusSize.md),
                    border: Border.all(
                        color: BrandColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: BrandAccent.tertiary(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'คีย์ฟรีมีโควตาการใช้งานจำกัด เพียงพอสำหรับการใช้งานทั่วไปของโรงเรียน หากใช้เกินขีดจำกัด ระบบจะแจ้งเตือนตอนทดสอบ/ใช้งาน',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: colors.onSurface,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: const Text('ปิดหน้าต่าง'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openGeminiApiKeyPage();
            },
            style: FilledButton.styleFrom(
              backgroundColor: BrandAccent.teal(context),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RadiusSize.md)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.rocket_launch_outlined, size: 18),
            label: const Text('เปิด Google AI Studio ทันที'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSavedKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบค่าที่บันทึกไว้',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        content: const Text(
          'ต้องการลบ Gemini API Key ที่บันทึกไว้ในเครื่องนี้หรือไม่? ฟีเจอร์ AI ทั้งหมด (อ่านใบเสร็จ, นำเข้าแผนงบ, ช่วยเขียนเหตุผล) จะใช้งานไม่ได้จนกว่าจะใส่คีย์ใหม่',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await GeminiService.instance.deleteApiKey();
    if (!mounted) return;
    setState(() {
      _geminiApiKeyCtrl.clear();
      _hasSavedKey = false;
    });
    showAppToast('ลบ Gemini API Key ที่บันทึกไว้แล้ว');
  }

  InputDecoration _fieldDecoration(BuildContext context,
      {required String label, Widget? suffixIcon, Widget? prefixIcon}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontSize: AppTypography.bodyMedium,
          fontWeight: AppTypography.weightSemiBold),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: colors.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: colors.outline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md),
          borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    // ไม่ใช้ GuideFabOverlay (ปุ่มลอย "?" มุมจอ) ในหน้านี้แล้ว — เนื้อหาซ้ำกับ
    // ปุ่ม "วิธีขอ API Key ฟรี" ที่ฝังอยู่ในการ์ดโดยตรงแล้ว (เห็นชัดกว่า ไม่ต้อง
    // ไปหาปุ่มลอยมุมจอ) ทุกหน้าอื่นในแอปยังใช้ GuideFabOverlay ตามปกติ
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RadiusSize.card),
              border: Border.all(color: colors.outline),
              boxShadow: AppShadows.light1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ไอคอนกลมตรงกลางด้านบน + หัวข้อ/คำอธิบายกึ่งกลาง — แทนที่
                // หัวการ์ดชิดซ้ายแบบเดิม ให้ความรู้สึกเป็น "หน้าตั้งค่าเฉพาะทาง"
                // ที่มีเรื่องเดียว ไม่ใช่การ์ดย่อยในหน้าที่มีหลายเรื่อง
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: BrandAccent.teal(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome,
                        color: BrandAccent.tealOn(context), size: 30),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'การเชื่อมต่อ AI (Gemini)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: AppTypography.weightExtraBold,
                    fontSize: AppTypography.heading2,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ใส่ Gemini API Key เพื่อใช้ฟีเจอร์อ่านใบเสร็จ, นำเข้าแผนงบ '
                  'และช่วยเขียนเหตุผลความจำเป็น (บันทึกไว้ในเครื่องนี้เท่านั้น '
                  'ไม่ส่งขึ้นเซิร์ฟเวอร์อื่นใด)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AppTypography.bodyMedium,
                      height: 1.4),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _showApiKeyGuide,
                    style: TextButton.styleFrom(
                      backgroundColor: Color.alphaBlend(
                          BrandColors.amber.withValues(alpha: 0.12),
                          colors.surface),
                      foregroundColor: BrandAccent.tertiary(context),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.md),
                        side: BorderSide(
                            color: BrandColors.amber.withValues(alpha: 0.4)),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('วิธีขอ API Key ฟรี'),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _geminiApiKeyCtrl,
                  obscureText: !_geminiKeyVisible,
                  style: const TextStyle(fontSize: 17),
                  decoration: _fieldDecoration(
                    context,
                    label: 'Gemini API Key',
                    prefixIcon: Icon(Icons.vpn_key_outlined,
                        color: colors.onSurfaceVariant, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_geminiKeyVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _geminiKeyVisible = !_geminiKeyVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _testingGemini ? null : _testGeminiConnection,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colors.outline),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RadiusSize.md)),
                      textStyle: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    icon: _testingGemini
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.onSurfaceVariant),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: Text(
                        _testingGemini ? 'กำลังทดสอบ...' : 'ทดสอบการเชื่อมต่อ'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveGeminiKey,
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandAccent.teal(context),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(RadiusSize.md)),
                          textStyle: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _hasSavedKey ? _deleteSavedKey : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(RadiusSize.md)),
                          textStyle: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบค่าที่บันทึก'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
