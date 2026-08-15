// thai_date.dart
// แปลงวันที่รูปแบบ "{วัน} {เดือนไทยเต็ม} {ปี พ.ศ.}" เช่น "22 กรกฎาคม 2569"
// กลับเป็น DateTime — รูปแบบนี้คือรูปแบบที่หน้าจอกรอกวันที่ทั่วทั้งแอปใช้บันทึกจริง
// (ดู _formatThaiDate ใน order_wizard_screen.dart) เดิม parser นี้เขียนซ้ำแบบ
// private ในหลายหน้า (order_wizard_screen, inspections_screen, fixed_assets_screen,
// installment_contracts_screen) — ย้ายมารวมไว้ที่เดียวให้เรียกใช้ซ้ำได้

const _thaiMonthNames = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

const thaiMonthsAbbrev = [
  '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// คืนค่า null ถ้า parse ไม่ได้ (ข้อความว่าง/รูปแบบไม่ตรง)
DateTime? parseThaiDate(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final parts = text.trim().split(' ');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final monthIndex = _thaiMonthNames.indexOf(parts[1]);
  final buddhistYear = int.tryParse(parts[2]);
  if (day == null || monthIndex <= 0 || buddhistYear == null) return null;
  try {
    return DateTime(buddhistYear - 543, monthIndex, day);
  } catch (_) {
    return null;
  }
}

/// แปลง "{วัน} {เดือนไทยเต็ม} {ปี พ.ศ.}" เป็นรูปแบบย่อ "{วัน} {เดือนย่อ} {ปี 2
/// หลัก}" เช่น "11 พฤษภาคม 2569" -> "11 พ.ค. 69" — คืนค่าเดิมถ้า parse ไม่ได้
/// (กันข้อความที่ไม่ตรงรูปแบบ เช่น "-"/ว่าง ไม่ให้หายไปเฉยๆ)
String formatThaiDateShort(String? text) {
  if (text == null || text.trim().isEmpty) return text ?? '';
  final parts = text.trim().split(' ');
  if (parts.length != 3) return text;
  final day = int.tryParse(parts[0]);
  final monthIndex = _thaiMonthNames.indexOf(parts[1]);
  final buddhistYear = int.tryParse(parts[2]);
  if (day == null || monthIndex <= 0 || buddhistYear == null) return text;
  final yy = (buddhistYear % 100).toString().padLeft(2, '0');
  return '$day ${thaiMonthsAbbrev[monthIndex]} $yy';
}
