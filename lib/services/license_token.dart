// license_token.dart
// โมเดล + ตัวตรวจสอบ "license token" ที่เซ็นด้วย RSA-SHA256 (PKCS#1 v1.5)
// จาก server — ออกแบบให้แอปตรวจสอบความถูกต้องได้เอง 100% แบบออฟไลน์ล้วนๆ
// (ไม่ต้องต่อเน็ตตอนตรวจ) ตามที่ต้องการรองรับโรงเรียนพื้นที่ห่างไกลที่เน็ต
// ไม่เสถียร
//
// ใช้ RSA-SHA256 แทน Ed25519 เพราะ Google Apps Script (ฝั่ง server) มีฟังก์ชัน
// เซ็น RSA-SHA256 ติดตัวมาให้เลย (Utilities.computeRsaSha256Signature) ไม่ต้อง
// พึ่งไลบรารีภายนอกที่ไม่มีใครทดสอบในสภาพแวดล้อม Apps Script จริงได้เลย —
// ปลอดภัยกว่าการเอาโค้ด elliptic-curve จากภายนอกมาแปะทั้งดุ้น
//
// รูปแบบ token (compact string): "<base64url(payload json)>.<base64url(signature)>"
// payload JSON มีฟิลด์:
//   hwid        — ผูกกับเครื่องที่ activate (กันเอา token ไปใช้เครื่องอื่น)
//   org_name    — ชื่อโรงเรียน/หน่วยงาน (โชว์ใน UI)
//   issued_at   — เวลาที่ server ออก token นี้ (ISO 8601)
//   expires_at  — issued_at + รอบเช็ค (90 วัน) — server เป็นคนกำหนดตรงๆ
//                 ไม่ใช่แอปคำนวณเอง กันแก้นาฬิกาเครื่องโกงอายุ token
//   modules     — รายชื่อโมดูลที่ปลดล็อก เช่น ["PROCUREMENT", "TRAVEL_EXPENSE"]
//   tier        — ชื่อแพ็กเกจ (ไม่บังคับ ใช้โชว์ผลเฉยๆ ไม่ใช้ตัดสินสิทธิ์จริง
//                 สิทธิ์จริงตัดสินจาก modules เท่านั้น)
//
// วิธี generate RSA keypair สำหรับฝั่ง server: ดูคอมเมนต์ท้ายไฟล์นี้

import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class LicenseToken {
  final String hwid;
  final String orgName;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<String> modules;
  final String? tier;

  const LicenseToken({
    required this.hwid,
    required this.orgName,
    required this.issuedAt,
    required this.expiresAt,
    required this.modules,
    this.tier,
  });

  bool hasModule(String key) => modules.contains(key);

  factory LicenseToken.fromJson(Map<String, dynamic> json) => LicenseToken(
        hwid: json['hwid'] as String? ?? '',
        orgName: json['org_name'] as String? ?? '',
        issuedAt: DateTime.parse(json['issued_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        modules: (json['modules'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        tier: json['tier'] as String?,
      );
}

class LicenseTokenException implements Exception {
  final String message;
  LicenseTokenException(this.message);
  @override
  String toString() => 'LicenseTokenException: $message';
}

class LicenseTokenVerifier {
  LicenseTokenVerifier._();

  // TODO(deploy): แทนที่ด้วย modulus จริง (เลขฐาน 16/hex) ของ RSA public key
  // ที่ generate คู่กับ private key ฝั่ง server ก่อนปล่อยใช้งานจริง — ตอนนี้
  // เป็นคีย์ปลอมสำหรับพัฒนา/ทดสอบเท่านั้น
  //
  // วิธีสร้างคู่คีย์จริง (รันบนเครื่องที่มี openssl — มีมาให้แล้วบน macOS/
  // Linux, บน Windows ใช้ Git Bash หรือ WSL):
  //   openssl genrsa -out private.pem 2048
  //   openssl rsa -in private.pem -pubout -out public.pem
  //   openssl rsa -in private.pem -modulus -noout      ← เอาค่านี้มาแทน
  //                                                        _rsaModulusHex ด้านล่าง
  // private.pem ทั้งไฟล์เก็บไว้ฝั่ง server เท่านั้น (Script Properties ของ
  // Google Apps Script) ห้ามเอาเข้า repo นี้หรือส่งต่อใครเด็ดขาด
  static const String _rsaModulusHex =
      'CE387DDD20A20D3CF32176FED3B040D0627CBC67908349079F7A08A5B01D021A6363461B2BAD38C05AA5BB2BD03D0BBD69618E394B256529AEF80BAA9E0A7A35B1EB9396F32EC044DD6E5ECAE78C772C34578486D9479D0070735BD763BF31A6310F8A49EC9153904E60BE14876AF2EF4988C2BAB7D2C0386DB9A8AF85471C6FA1F6DC55C268173AF25A37B967C3D5C9A5163EA464C1C965318CB81B2E62B7F254BCE1C2749CD007DDDDBF53FF0D940B52E221B281F9676462B3E428023D4F90C7CC33A397146BAC8C32AE1E5E56B7878CF61110DFF30CC28B1A74D960E117D8DE4A23F3BD1DB1D8CDD7F9A22A6670962B3D4DAF77CE99DFAABBC1346B9B28A7';

  // เลขชี้กำลังสาธารณะมาตรฐาน (65537 / 0x10001) — ตรงกับที่ openssl genrsa
  // และ Google Apps Script ใช้เป็นค่าเริ่มต้นเสมอ ไม่ต้องเปลี่ยน
  static final BigInt _rsaExponent = BigInt.from(65537);

  // OID ของ SHA-256 ตาม DigestInfo (PKCS#1 v1.5) — ค่ามาตรฐานตายตัว ไม่ต้องแก้
  static const String _sha256DigestOid = '0609608648016503040201';

  /// ตรวจลายเซ็นแล้วแกะ payload กลับเป็น [LicenseToken] — throw
  /// [LicenseTokenException] ถ้ารูปแบบผิดหรือลายเซ็นไม่ถูกต้อง (แก้ไข/ปลอมแปลง)
  static Future<LicenseToken> verifyAndParse(String rawToken) async {
    final parts = rawToken.split('.');
    if (parts.length != 2) {
      throw LicenseTokenException('รูปแบบ token ไม่ถูกต้อง');
    }

    late final Uint8List payloadBytes;
    late final Uint8List signatureBytes;
    try {
      payloadBytes =
          Uint8List.fromList(base64Url.decode(base64Url.normalize(parts[0])));
      signatureBytes =
          Uint8List.fromList(base64Url.decode(base64Url.normalize(parts[1])));
    } catch (e) {
      throw LicenseTokenException('ถอดรหัส token ไม่สำเร็จ: $e');
    }

    final publicKey =
        RSAPublicKey(BigInt.parse(_rsaModulusHex, radix: 16), _rsaExponent);
    final signer = RSASigner(SHA256Digest(), _sha256DigestOid)
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

    bool isValid;
    try {
      isValid =
          signer.verifySignature(payloadBytes, RSASignature(signatureBytes));
    } catch (e) {
      throw LicenseTokenException('ตรวจลายเซ็นไม่สำเร็จ: $e');
    }
    if (!isValid) {
      throw LicenseTokenException(
          'ลายเซ็น token ไม่ถูกต้อง (อาจถูกแก้ไข/ปลอมแปลง)');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw LicenseTokenException('อ่านข้อมูล token ไม่สำเร็จ: $e');
    }
    return LicenseToken.fromJson(json);
  }
}
