// license_service.dart v2
// - เช็ค HWID ก่อนเสมอ (ไม่ต้องกรอก key ถ้าเครื่องนี้ลงทะเบียนไว้แล้ว)
// - cache 30 วัน (ออฟไลน์ได้สูงสุด 30 วัน)
// - Revoked/Expired → ล้าง cache ทันที

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _scriptUrl =
    'https://script.google.com/macros/s/AKfycbyXkspN6qK_K89YU3pLu3R6pBzGcBGdntyB4yBdrpUf8Ch0cDKmv6uzqYhswHyMjqj9bg/exec';

const _prefHwId        = 'hw_id';
const _prefCacheStatus = 'cache_status';   // 'ok' | ''
const _prefCacheTime   = 'cache_time';     // millisecondsSinceEpoch
const _prefOrgName     = 'org_name';
const _prefSavedCode   = 'license_code';

const _cacheDays = 30;

class LicenseResult {
  final bool isValid;
  final String? orgName;
  final String? errorReason;

  const LicenseResult({
    required this.isValid,
    this.orgName,
    this.errorReason,
  });
}

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  // ── Hardware ID ─────────────────────────────────────────────────

  Future<String> getHardwareId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefHwId);
    if (cached != null && cached.isNotEmpty) return cached;
    final id = await _fetchHardwareId();
    await prefs.setString(_prefHwId, id);
    return id;
  }

  Future<String> _fetchHardwareId() async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run(
          'system_profiler',
          ['SPHardwareDataType'],
        );
        final out = result.stdout.toString();
        final match = RegExp(r'Hardware UUID:\s*([A-F0-9\-]+)').firstMatch(out);
        final id = match?.group(1)?.trim() ?? '';
        if (id.isNotEmpty) return 'MAC-$id';
      } else if (Platform.isWindows) {
        final id = await _fetchWindowsHwIdViaWmic() ?? await _fetchWindowsHwIdViaPowerShell();
        if (id != null && id.isNotEmpty) return 'WIN-$id';
      }
    } catch (_) {}
    return 'DEV-${Platform.localHostname}-${Platform.operatingSystem}';
  }

  /// วิธีหลัก: wmic (เร็ว, ใช้ได้กับ Windows ส่วนใหญ่ที่ยังมี wmic ติดตั้งอยู่)
  /// คืนค่า null ถ้าใช้ไม่ได้ (คำสั่งไม่มี/error) — ไม่ throw ออกไปให้ตัวเรียกจัดการ fallback ต่อ
  Future<String?> _fetchWindowsHwIdViaWmic() async {
    try {
      final result = await Process.run(
        'wmic',
        ['csproduct', 'get', 'UUID'],
        runInShell: true,
      );
      if (result.exitCode != 0) return null;
      final lines = result.stdout
          .toString()
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l != 'UUID')
          .toList();
      final id = lines.isNotEmpty ? lines.last : '';
      return id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  /// วิธีสำรอง: PowerShell — ใช้เมื่อ wmic ใช้ไม่ได้ (Windows รุ่นใหม่บางเครื่อง
  /// เริ่มถอด wmic ออกแล้ว หรือถูกปิดโดย group policy ขององค์กร/โรงเรียน)
  Future<String?> _fetchWindowsHwIdViaPowerShell() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_ComputerSystemProduct).UUID',
        ],
        runInShell: true,
      );
      if (result.exitCode != 0) return null;
      final id = result.stdout.toString().trim();
      return id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  // ── Cache ────────────────────────────────────────────────────────

  Future<bool> _isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString(_prefCacheStatus) ?? '';
    if (status != 'ok') return false;
    final saved = prefs.getInt(_prefCacheTime) ?? 0;
    final days = (DateTime.now().millisecondsSinceEpoch - saved) /
        (1000 * 60 * 60 * 24);
    return days < _cacheDays;
  }

  Future<void> _setCache(String orgName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCacheStatus, 'ok');
    await prefs.setInt(_prefCacheTime, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_prefOrgName, orgName);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCacheStatus, '');
    await prefs.remove(_prefOrgName);
  }

  Future<String?> getCachedOrgName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefOrgName);
  }

  // ── Code (key) storage ───────────────────────────────────────────

  Future<String?> getSavedCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSavedCode);
  }

  Future<void> saveCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSavedCode, code);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSavedCode);
    await _clearCache();
  }

  // ── Main check (เรียกตอนเปิดแอป) ────────────────────────────────

  Future<LicenseResult> checkOnStartup() async {
    // เช็ค online ก่อนเสมอทุกครั้งที่เปิดแอป (ให้ revoke มีผลทันที ไม่ต้องรอ
    // cache หมดอายุ) — cache ใช้เป็น fallback เฉพาะตอนเชื่อมเน็ตไม่ได้จริงๆ
    final hwId = await getHardwareId();
    try {
      final result = await _checkByHwId(hwId);

      if (result.isValid) {
        await _setCache(result.orgName ?? '');
      } else {
        // Revoked / Expired / ไม่พบในระบบ → ล้าง cache ด้วย
        if (result.errorReason == 'revoked' ||
            result.errorReason == 'expired' ||
            result.errorReason == 'not_registered') {
          await _clearCache();
        }
      }
      return result;
    } catch (_) {
      // ออฟไลน์จริง — ใช้ cache แทนถ้ายังไม่หมดอายุ (สูงสุด 30 วัน)
      if (await _isCacheValid()) {
        final orgName = await getCachedOrgName();
        return LicenseResult(isValid: true, orgName: orgName);
      }
      return const LicenseResult(
        isValid: false,
        errorReason: 'network_error',
      );
    }
  }

  // ── Check by HWID (ส่งไปถามว่าเครื่องนี้ลงทะเบียนไว้ไหม) ────────

  Future<LicenseResult> _checkByHwId(String hwId) async {
    final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
      'action': 'check',
      'hwid': hwId,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    return _parseResponse(response);
  }

  // ── Activate (กรอก code เพื่อลงทะเบียนเครื่องใหม่) ─────────────

  Future<LicenseResult> activate(String code) async {
    final hwId = await getHardwareId();
    final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
      'action': 'activate',
      'hwid': hwId,
      'code': code.trim(),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final result = _parseResponse(response);
    if (result.isValid) {
      await saveCode(code.trim());
      await _setCache(result.orgName ?? '');
    }
    return result;
  }

  // ── Parse response จาก Apps Script ──────────────────────────────

  LicenseResult _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      return const LicenseResult(isValid: false, errorReason: 'server_error');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final ok = json['ok'] as bool? ?? false;
    if (ok) {
      return LicenseResult(
        isValid: true,
        orgName: json['name'] as String?,
      );
    }
    return LicenseResult(
      isValid: false,
      errorReason: json['reason'] as String? ?? 'unknown',
    );
  }
}