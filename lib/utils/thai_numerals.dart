// thai_numerals.dart
// แปลงเลขไทย (๐-๙) เป็นเลขอารบิก (0-9) — ใช้กับข้อมูลที่ก๊อปมาจาก eGP ซึ่งบาง
// โครงการเลขที่โครงการเป็นเลขไทยติดมาโดยไม่ได้ตั้งใจ ตัวเลขอื่นในระบบยังคงเป็น
// เลขอารบิกปกติ ทำให้ดูไม่สม่ำเสมอ/เรียงลำดับสตริงผิดเพี้ยนได้

const _thaiDigits = '๐๑๒๓๔๕๖๗๘๙';

String toArabicDigits(String? input) {
  if (input == null || input.isEmpty) return input ?? '';
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final idx = _thaiDigits.indexOf(ch);
    buffer.write(idx == -1 ? ch : idx.toString());
  }
  return buffer.toString();
}
