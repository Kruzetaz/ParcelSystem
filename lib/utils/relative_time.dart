// relative_time.dart
// ข้อความเวลาแบบสัมพัทธ์ ("5 นาทีที่แล้ว") สำหรับรายการแจ้งเตือน — ไม่ใช้วันที่
// เต็มแบบเอกสารราชการ (thai_date.dart) เพราะบริบทคนละแบบกัน

String relativeTimeLabel(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inSeconds < 60) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  final weeks = (diff.inDays / 7).floor();
  if (diff.inDays < 30) return '$weeks สัปดาห์ที่แล้ว';
  final months = (diff.inDays / 30).floor();
  if (diff.inDays < 365) return '$months เดือนที่แล้ว';
  final years = (diff.inDays / 365).floor();
  return '$years ปีที่แล้ว';
}
