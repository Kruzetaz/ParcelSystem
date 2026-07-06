// license_service.dart v2
// - เช็ค HWID ก่อนเสมอ (ไม่ต้องกรอก key ถ้าเครื่องนี้ลงทะเบียนไว้แล้ว)
// - cache 30 วัน (ออฟไลน์ได้สูงสุด 30 วัน)
// - Revoked/Expired → ล้าง cache ทันที

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _scriptUrl =
    'https://script.google.com/macros/s/AKfycbz6zAyDY35iXlXILNQbqlvQi4h473TWJVtHtLkNTLWtbz3QJPGS-oep3uygJ5CBkTWE/exec';

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
        final result = await Process.run(
          'wmic',
          ['csproduct', 'get', 'UUID'],
          runInShell: true,
        );
        final lines = result.stdout
            .toString()
            .trim()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && l != 'UUID')
            .toList();
        final id = lines.isNotEmpty ? lines.last : '';
        if (id.isNotEmpty) return 'WIN-$id';
      }
    } catch (_) {}
    return 'DEV-${Platform.localHostname}-${Platform.operatingSystem}';
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
    // 1. cache ยังใช้ได้อยู่ → ผ่านเลยไม่ยิง request
    if (await _isCacheValid()) {
      final orgName = await getCachedOrgName();
      return LicenseResult(isValid: true, orgName: orgName);
    }

    // 2. cache หมด/ไม่มี → เช็คออนไลน์ด้วย HWID
    final hwId = await getHardwareId();
    try {
      final result = await _checkByHwId(hwId);

      if (result.isValid) {
        await _setCache(result.orgName ?? '');
      } else {
        // Revoked / Expired → ล้าง cache ด้วย
        if (result.errorReason == 'revoked' ||
            result.errorReason == 'expired') {
          await _clearCache();
        }
      }
      return result;
    } catch (_) {
      // ออฟไลน์ — cache หมดแล้วและเชื่อมเน็ตไม่ได้
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