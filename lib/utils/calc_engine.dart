/// ─────────────────────────────────────────
/// Auto-calculation engine
/// ใช้ใน Tab 3 และ Tab 4
/// ─────────────────────────────────────────

class CalcEngine {
  // อัตราภาษีมาตรฐาน (แก้ได้ตามต้องการ)
  static const double vatRate = 0.07;          // VAT 7%
  static const double withholdingRate = 0.03;  // หัก ณ ที่จ่าย 3%

  // ─────────────────────────────────────────
  // คำนวณราคารวมจาก items
  // ─────────────────────────────────────────

  /// รวมราคาทุก item
  static double sumItems(List<({double unitPrice, double qty})> items) {
    return items.fold(0, (sum, i) => sum + (i.unitPrice * i.qty));
  }

  // ─────────────────────────────────────────
  // คำนวณภาษีจากยอดรวมที่กรอก (ยอดรวมที่กรอกในตารางรายการถือเป็นยอดที่รวม VAT
  // ไว้แล้วเสมอ — ตรงกับที่ร้านค้าคำนวณในบิลจริง เช่น ยอดจ่ายสุทธิ 1,000 บาท
  // แยกเป็นรวมเงิน 934.58 + VAT 65.42 ระบบจึง "แยก" VAT ออกจากยอดที่กรอก
  // แทนที่จะ "บวกเพิ่ม" เข้าไปเหมือนเดิม)
  // ─────────────────────────────────────────

  /// แยกยอดก่อน VAT ออกจากยอดรวมที่มี VAT รวมอยู่แล้ว (totalInclVat / (1+rate))
  static double calcPreVat(double totalInclVat, {double rate = vatRate}) =>
      totalInclVat / (1 + rate);

  /// แยกจำนวนเงิน VAT ออกจากยอดรวมที่มี VAT รวมอยู่แล้ว
  static double calcVat(double totalInclVat, {double rate = vatRate}) =>
      totalInclVat - calcPreVat(totalInclVat, rate: rate);

  /// หัก ณ ที่จ่าย คำนวณจากยอดก่อน VAT เสมอ (ตามระเบียบจริง)
  static double calcWithholding(double preVatAmount, {double rate = withholdingRate}) =>
      preVatAmount * rate;

  /// คืน map ครบทุก field ที่ต้องบันทึกลง DB
  static Map<String, double> calcAll(double totalInclVat) {
    return calcAllWithRates(totalInclVat, vatRate: vatRate, withholdingRate: withholdingRate);
  }

  /// คำนวณด้วย rate ที่กรอกเองต่อบิล — [totalInclVat] คือยอดรวมจากตารางรายการ
  /// (จำนวน x ราคาต่อหน่วย รวมทุกแถว) ซึ่งถือว่า "รวม VAT ไว้แล้ว" ถ้าอัตรา VAT
  /// เป็น 0 (ไม่มีภาษีในบิล) ค่าที่ได้จะเท่ากับยอดที่กรอกพอดี ไม่มีผลกระทบ
  static Map<String, double> calcAllWithRates(
    double totalInclVat, {
    required double vatRate,
    required double withholdingRate,
  }) {
    final preVat = calcPreVat(totalInclVat, rate: vatRate);
    final vat = totalInclVat - preVat;
    final withholding = preVat * withholdingRate;
    final net = totalInclVat - withholding;
    return {
      'subtotal_before_vat': preVat,
      'vat_amount': vat,
      'tax_withholding_amount': withholding,
      'net_payable_amount': net,
      'current_order_price': totalInclVat,
    };
  }

  // ─────────────────────────────────────────
  // แปลงตัวเลขเป็นคำอ่านภาษาไทย
  // เช่น 5250.00 → "ห้าพันสองร้อยห้าสิบบาทถ้วน"
  // ─────────────────────────────────────────

  static const _ones = [
    '', 'หนึ่ง', 'สอง', 'สาม', 'สี่',
    'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า',
  ];

  static const _places = [
    '', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน', 'ล้าน',
  ];

  static String bahtText(double amount) {
    if (amount == 0) return 'ศูนย์บาทถ้วน';

    // แยกบาทกับสตางค์
    final wholePart = amount.floor();
    final satangPart = ((amount - wholePart) * 100).round();

    final baht = _convertWholeNumber(wholePart);
    final result = StringBuffer();
    result.write(baht);
    result.write('บาท');

    if (satangPart == 0) {
      result.write('ถ้วน');
    } else {
      result.write(_convertWholeNumber(satangPart));
      result.write('สตางค์');
    }

    return result.toString();
  }

  static String _convertWholeNumber(int number) {
    if (number == 0) return '';
    if (number < 0) return 'ลบ${_convertWholeNumber(-number)}';

    // จัดการล้าน
    if (number >= 1000000) {
      final millions = number ~/ 1000000;
      final remainder = number % 1000000;
      return '${_convertWholeNumber(millions)}ล้าน${_convertWholeNumber(remainder)}';
    }

    final digits = number.toString().split('').map(int.parse).toList();
    final len = digits.length;
    final result = StringBuffer();

    for (int i = 0; i < len; i++) {
      final digit = digits[i];
      final place = len - 1 - i;

      if (digit == 0) continue;

      // กรณีพิเศษ: หลักสิบ
      if (place == 1 && digit == 2) {
        result.write('ยี่สิบ');
        continue;
      }
      if (place == 1 && digit == 1) {
        result.write('สิบ');
        continue;
      }
      // กรณีพิเศษ: หลักหน่วยเป็น 1 และมีหลักสิบ
      if (place == 0 && digit == 1 && len > 1) {
        result.write('เอ็ด');
        continue;
      }

      result.write(_ones[digit]);
      result.write(_places[place]);
    }

    return result.toString();
  }
}
