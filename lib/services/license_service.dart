// license_service.dart v3
// - เช็ค HWID ก่อนเสมอ (ไม่ต้องกรอก key ถ้าเครื่องนี้ลงทะเบียนไว้แล้ว)
// - ยืนยันสิทธิ์แบบ digital signature (Ed25519): server เซ็น token ที่มี HWID
//   + วันหมดอายุ (issued_at + 90 วัน) + รายชื่อโมดูลที่ปลดล็อกไว้ให้ แอปเก็บ
//   token นี้ไว้ในเครื่องแล้วตรวจสอบเองได้ทั้งหมดแบบออฟไลน์ล้วนๆ ไม่ต้องพึ่ง
//   เน็ตตอนตรวจเลย — ออกแบบมาให้โรงเรียนพื้นที่ห่างไกลใช้งานได้ต่อเนื่อง
// - รอบเช็ค 90 วัน + ผ่อนผัน (grace period) อีก 14 วันหลังจากนั้นถ้ายังต่อ
//   เน็ตไม่ได้ (ไม่ล็อกแอปทันทีตอนครบ 90 วัน — งานเอกสารต้องไม่สะดุด) รวม
//   ออฟไลน์ต่อเนื่องได้สูงสุด 104 วันก่อนจะถูกล็อกจริง
// - Revoked/Expired (เช็คออนไลน์สำเร็จแล้วพบว่าไม่ผ่าน) → ล้าง token ทันที
//
// หมายเหตุ migration: ถ้า response จาก server ยังไม่มีฟิลด์ "token" (เช่น
// ยังไม่ได้อัปเดต Apps Script ฝั่ง server) จะ fallback ไปใช้ระบบ cache แบบเดิม
// (ok/reason + cache 30 วัน) โดยอัตโนมัติ ไม่พังของเดิม — พอ server พร้อมส่ง
// token ค่อยสลับมาใช้ระบบ 90+14 วันเองอัตโนมัติโดยไม่ต้องแก้โค้ดแอปอีก

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'feature_access_service.dart';
import 'license_token.dart';

const _scriptUrl =
    'https://script.google.com/macros/s/AKfycbyXkspN6qK_K89YU3pLu3R6pBzGcBGdntyB4yBdrpUf8Ch0cDKmv6uzqYhswHyMjqj9bg/exec';

const _prefHwId = 'hw_id';
const _prefSavedCode = 'license_code';
const _prefTokenRaw = 'license_token_raw_v1';
// เก็บไว้เผื่อ server ยังไม่ส่ง token มา (ช่วง migration) — พฤติกรรมเดิมทุกอย่าง
const _prefCacheStatus = 'cache_status';
const _prefCacheTime = 'cache_time';
const _prefOrgName = 'org_name';

const _legacyCacheDays = 30;
const _graceDays = 14;

enum LicenseStatus { valid, grace, blocked }

class LicenseResult {
  final LicenseStatus status;
  final String? orgName;
  final String? errorReason;
  final LicenseToken? token;
  // จำนวนวันที่เหลือในช่วงผ่อนผัน (มีค่าเฉพาะตอน status == grace)
  final int? graceDaysLeft;
  // เก็บ raw token string ไว้ใช้ภายใน service เอง (สำหรับบันทึกลงเครื่อง)
  final String? _rawToken;

  const LicenseResult({
    required this.status,
    this.orgName,
    this.errorReason,
    this.token,
    this.graceDaysLeft,
    String? rawToken,
  }) : _rawToken = rawToken;

  bool get isValid => status != LicenseStatus.blocked;
  bool get isGracePeriod => status == LicenseStatus.grace;
}

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  /// ผลการเช็คล่าสุด — AppShell อ่านค่านี้เพื่อโชว์แถบผ่อนผัน (grace banner)
  /// โดยไม่ต้องส่งผ่าน navigation เอง
  LicenseResult? lastResult;

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
        final id = await _fetchWindowsHwIdViaWmic() ??
            await _fetchWindowsHwIdViaPowerShell();
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

  // ── Token storage (ระบบใหม่ — digital signature) ──────────────────

  Future<void> _storeToken(String rawToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenRaw, rawToken);
  }

  Future<String?> _getStoredRawToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefTokenRaw);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTokenRaw);
  }

  // ── Legacy cache (fallback ช่วง migration ก่อน server ส่ง token) ──

  Future<bool> _isLegacyCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString(_prefCacheStatus) ?? '';
    if (status != 'ok') return false;
    final saved = prefs.getInt(_prefCacheTime) ?? 0;
    final days =
        (DateTime.now().millisecondsSinceEpoch - saved) / (1000 * 60 * 60 * 24);
    return days < _legacyCacheDays;
  }

  Future<void> _setLegacyCache(String orgName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCacheStatus, 'ok');
    await prefs.setInt(_prefCacheTime, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_prefOrgName, orgName);
  }

  Future<void> _clearLegacyCache() async {
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
    await _clearLegacyCache();
    await _clearToken();
    FeatureAccessService.instance.updateToken(null);
  }

  // ── Main check (เรียกตอนเปิดแอป) ────────────────────────────────

  Future<LicenseResult> checkOnStartup() async {
    // เช็ค online ก่อนเสมอทุกครั้งที่เปิดแอป (ให้ revoke มีผลทันทีตอนต่อเน็ต
    // ได้ ไม่ต้องรอครบรอบ) — offline fallback ใช้ token ที่เซ็นไว้แล้วแทน
    final hwId = await getHardwareId();
    LicenseResult result;
    try {
      result = await _checkByHwId(hwId);

      if (result.status == LicenseStatus.valid && result._rawToken != null) {
        await _storeToken(result._rawToken!);
        await _setLegacyCache(result.orgName ?? '');
      } else if (result.status == LicenseStatus.valid) {
        // migration: server ยังไม่ส่ง token มา (ok:true แต่ไม่มี "token" field)
        await _setLegacyCache(result.orgName ?? '');
      } else if (result.errorReason == 'revoked' ||
          result.errorReason == 'expired' ||
          result.errorReason == 'not_registered' ||
          result.errorReason == 'invalid_code') {
        await _clearToken();
        await _clearLegacyCache();
      }
    } catch (_) {
      // ออฟไลน์จริง — ตรวจสอบจาก token ที่เซ็นไว้แล้วในเครื่องแบบออฟไลน์ล้วนๆ
      result = await _offlineCheckFromStoredToken();
    }

    FeatureAccessService.instance.updateToken(result.token);
    lastResult = result;
    return result;
  }

  /// ตรวจสอบสิทธิ์แบบออฟไลน์ล้วนๆ จาก token ที่เซ็นไว้แล้วในเครื่อง — ไม่ยิง
  /// request ออกไปเลย เช็คแค่ลายเซ็น + วันหมดอายุ + ช่วงผ่อนผัน
  Future<LicenseResult> _offlineCheckFromStoredToken() async {
    final raw = await _getStoredRawToken();
    if (raw == null || raw.isEmpty) {
      // ยังไม่เคยได้ token ใหม่เลย (เช่นเพิ่งอัปเดตแอปแต่ server ยังไม่พร้อม
      // ส่ง token) — fallback ไปใช้ legacy cache 30 วันแทนชั่วคราว พร้อมถือว่า
      // ทุกโมดูลใช้ได้เหมือนเดิม (migration — กันฟีเจอร์ที่มีอยู่แล้วพังทันที)
      if (await _isLegacyCacheValid()) {
        final orgName = await getCachedOrgName();
        return LicenseResult(
            status: LicenseStatus.valid,
            orgName: orgName,
            token: _migrationAllAccessToken(orgName ?? ''));
      }
      return const LicenseResult(
          status: LicenseStatus.blocked, errorReason: 'network_error');
    }

    final LicenseToken token;
    try {
      token = await LicenseTokenVerifier.verifyAndParse(raw);
    } catch (_) {
      return const LicenseResult(
          status: LicenseStatus.blocked, errorReason: 'invalid_token');
    }

    final hwId = await getHardwareId();
    if (token.hwid != hwId) {
      return const LicenseResult(
          status: LicenseStatus.blocked, errorReason: 'hwid_mismatch');
    }

    final now = DateTime.now().toUtc();
    final graceEnd = token.expiresAt.add(const Duration(days: _graceDays));

    if (now.isBefore(token.expiresAt)) {
      return LicenseResult(
          status: LicenseStatus.valid, orgName: token.orgName, token: token);
    }
    if (now.isBefore(graceEnd)) {
      final daysLeft = graceEnd.difference(now).inDays + 1;
      return LicenseResult(
        status: LicenseStatus.grace,
        orgName: token.orgName,
        token: token,
        graceDaysLeft: daysLeft,
      );
    }
    return const LicenseResult(
        status: LicenseStatus.blocked, errorReason: 'expired');
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
    final result = await _parseResponse(response);
    if (result.status == LicenseStatus.valid) {
      await saveCode(code.trim());
      if (result._rawToken != null) {
        await _storeToken(result._rawToken!);
      }
      await _setLegacyCache(result.orgName ?? '');
    }
    FeatureAccessService.instance.updateToken(result.token);
    lastResult = result;
    return result;
  }

  // ── Parse response จาก Apps Script ──────────────────────────────
  //
  // รูปแบบ response ที่รองรับ:
  //   { ok: true, name: "...", token: "<signed token>" }   ← ระบบใหม่
  //   { ok: true, name: "..." }                             ← ระบบเดิม (migration)
  //   { ok: false, reason: "..." }
  Future<LicenseResult> _parseResponse(http.Response response) async {
    if (response.statusCode != 200) {
      return const LicenseResult(
          status: LicenseStatus.blocked, errorReason: 'server_error');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const LicenseResult(
          status: LicenseStatus.blocked, errorReason: 'server_error');
    }
    final ok = json['ok'] as bool? ?? false;
    if (!ok) {
      return LicenseResult(
          status: LicenseStatus.blocked,
          errorReason: json['reason'] as String? ?? 'unknown');
    }

    final rawToken = json['token'] as String?;
    if (rawToken == null || rawToken.isEmpty) {
      // server รุ่นเก่ายังไม่ส่ง token มา — ใช้ผลแบบเดิม (migration path) พร้อม
      // ถือว่าทุกโมดูลใช้ได้เหมือนเดิม จนกว่า server จะเริ่มส่ง token ที่มี
      // modules list มาเอง (ค่อยเริ่ม gate เป็นรายโมดูลจริงจังตอนนั้น)
      final orgName = json['name'] as String?;
      return LicenseResult(
          status: LicenseStatus.valid,
          orgName: orgName,
          token: _migrationAllAccessToken(orgName ?? ''));
    }

    try {
      final token = await LicenseTokenVerifier.verifyAndParse(rawToken);
      return LicenseResult(
        status: LicenseStatus.valid,
        orgName: token.orgName,
        token: token,
        rawToken: rawToken,
      );
    } catch (e) {
      // server ส่ง token มาแต่ลายเซ็นไม่ถูกต้อง/parse ไม่ได้ — ถือว่าใช้ไม่ได้
      // (อย่าเชื่อ ok:true เฉยๆ โดยไม่ตรวจลายเซ็น ไม่งั้นเสียจุดประสงค์การเซ็น
      // token ไปเลย)
      return const LicenseResult(
          status: LicenseStatus.blocked, errorReason: 'invalid_token');
    }
  }

  /// token ปลอมที่สร้างขึ้นในเครื่อง (ไม่ได้เซ็น ไม่ได้เก็บลง storage เลย) —
  /// ใช้เฉพาะช่วง migration ที่ server ยังตอบแบบเก่า (ok/reason อย่างเดียว
  /// ไม่มี token field) เพื่อให้ FeatureAccessService ยังคง "ปลดล็อกทุกโมดูล"
  /// เหมือนพฤติกรรมเดิมก่อนมีระบบ feature-gating นี้ — พอ server เริ่มส่ง
  /// token จริงที่เซ็นแล้วมา ค่านี้จะไม่ถูกใช้อีกต่อไปโดยอัตโนมัติ
  LicenseToken _migrationAllAccessToken(String orgName) => LicenseToken(
        hwid: '',
        orgName: orgName,
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 90)),
        modules: const [
          FeatureModules.procurement,
          FeatureModules.travelExpense
        ],
      );
}
