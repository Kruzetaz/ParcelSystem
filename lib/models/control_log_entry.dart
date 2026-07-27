// control_log_entry.dart
// แถวหนึ่งใน "ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR" — ไม่ใช่ตารางแยกในฐานข้อมูล
// แต่เป็น view model ที่รวบรวมมาจากเลขที่ควบคุมซึ่งมีอยู่แล้วกระจายอยู่หลายตาราง
// (procurement_orders, tor_documents, contracts, inspections) ให้เห็นในที่เดียว
// ตรงกับตัวอย่างทะเบียนคุมจริงที่โรงเรียนใช้ (เลขที่บันทึก/ประเภทงาน/วันที่/
// รายการ/วงเงิน/หน่วยงาน/ผู้รับผิดชอบ)

class ControlLogEntry {
  final String controlNumber;
  final String docType;
  final String? dateText; // "d MMMM yyyy" พ.ศ. ตามที่บันทึกไว้จริง — อาจว่างได้
  final String description;
  final double? amount;
  final String? department;
  final String? responsiblePerson;
  final String fiscalYear;
  final int? orderId;

  const ControlLogEntry({
    required this.controlNumber,
    required this.docType,
    this.dateText,
    required this.description,
    this.amount,
    this.department,
    this.responsiblePerson,
    required this.fiscalYear,
    this.orderId,
  });
}
