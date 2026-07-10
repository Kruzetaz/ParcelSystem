// gemini_service.dart
// จัดการ Gemini API Key (บันทึกไว้ในเครื่องผ่าน shared_preferences เท่านั้น
// ไม่ส่งขึ้น server ของเราเอง) และฟังก์ชันพื้นฐานสำหรับเรียก Gemini API
// ใช้เป็นฐานให้ฟีเจอร์ AI อื่นๆ (อ่านใบเสร็จ, นำเข้าแผนงบ, ช่วยเขียนเหตุผล)
// เรียกใช้ต่อในขั้นถัดไป
//
// ลองหลายโมเดลเรียงกัน (fallback chain) — ถ้าโมเดลแรกโดน rate-limit/overload
// (HTTP 429/503) จะลองโมเดลถัดไปในลิสต์อัตโนมัติ ก่อนจะถือว่าล้มเหลวจริง

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _prefGeminiApiKey = 'gemini_api_key';

// เรียงจากตัวที่แนะนำให้ใช้หลักก่อน ตามด้วยตัวสำรอง
// (gemini-2.0 / gemini-2.5 series ถูกยกเลิกไปกลางปี 2569 แล้ว ห้ามใช้)
const _geminiModels = [
  'gemini-3.5-flash',
  'gemini-3.1-flash-lite',
  'gemini-flash-latest',
];

class GeminiTestResult {
  final bool ok;
  final String message;
  const GeminiTestResult({required this.ok, required this.message});
}

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefGeminiApiKey);
    return (key == null || key.isEmpty) ? null : key;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefGeminiApiKey, key.trim());
  }

  Uri _endpoint(String model, String apiKey) => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

  /// ส่ง request สั้นๆ ไปเช็คว่าคีย์ใช้งานได้จริงไหม — เรียกจากปุ่ม "ทดสอบการเชื่อมต่อ"
  /// ไล่ลองทีละโมเดลตาม _geminiModels จนกว่าจะสำเร็จ
  Future<GeminiTestResult> testConnection(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      return const GeminiTestResult(ok: false, message: 'กรุณากรอก API Key ก่อน');
    }
    String lastError = '';
    for (final model in _geminiModels) {
      try {
        final response = await http
            .post(
              _endpoint(model, apiKey.trim()),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'ตอบคำว่า OK คำเดียว'}
                    ]
                  }
                ],
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return GeminiTestResult(ok: true, message: 'เชื่อมต่อสำเร็จ ใช้งานได้ ($model)');
        }
        lastError = _errorMessage(response);
        // 429 (rate limit) / 503 (overload) → ลองโมเดลถัดไป, ค่า error อื่น (เช่น
        // API key ผิด) ไม่มีประโยชน์จะลองซ้ำ หยุดแจ้งผลทันที
        if (response.statusCode != 429 && response.statusCode != 503) {
          return GeminiTestResult(ok: false, message: 'เชื่อมต่อไม่สำเร็จ: $lastError');
        }
      } catch (e) {
        lastError = '$e';
      }
    }
    return GeminiTestResult(ok: false, message: 'เชื่อมต่อไม่สำเร็จ: $lastError');
  }

  /// เรียก Gemini แบบข้อความล้วน — ใช้ต่อกับ Feature C (ช่วยเขียนเหตุผล)
  /// และ Feature B ส่วนอ่านไฟล์ .docx/.pdf
  Future<String> generateText(String prompt) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      throw Exception('ยังไม่ได้ตั้งค่า Gemini API Key ในหน้าตั้งค่า');
    }
    return _generateWithFallback(
      apiKey: apiKey,
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      },
    );
  }

  /// เรียก Gemini แบบแนบไฟล์รูป/PDF — ใช้ต่อกับ Feature A (อ่านใบเสร็จ)
  Future<String> generateFromFile({
    required String prompt,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      throw Exception('ยังไม่ได้ตั้งค่า Gemini API Key ในหน้าตั้งค่า');
    }
    return _generateWithFallback(
      apiKey: apiKey,
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(fileBytes),
                }
              },
            ]
          }
        ],
      },
    );
  }

  Future<String> _generateWithFallback({
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    String lastError = '';
    for (final model in _geminiModels) {
      try {
        final response = await http
            .post(
              _endpoint(model, apiKey),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 60));
        if (response.statusCode == 200) {
          return _extractText(response);
        }
        lastError = _errorMessage(response);
        if (response.statusCode != 429 && response.statusCode != 503) {
          throw Exception(lastError);
        }
      } catch (e) {
        lastError = '$e';
      }
    }
    throw Exception(lastError);
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['error']?['message'] as String? ?? 'HTTP ${response.statusCode}';
    } catch (_) {
      return 'HTTP ${response.statusCode}';
    }
  }

  String _extractText(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('AI ไม่ตอบกลับข้อมูล');
    }
    final parts = (candidates.first as Map<String, dynamic>)['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('AI ไม่ตอบกลับข้อมูล');
    }
    return (parts.first as Map<String, dynamic>)['text'] as String? ?? '';
  }
}
