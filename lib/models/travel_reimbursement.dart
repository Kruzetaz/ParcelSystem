// travel_reimbursement.dart
// ใบเบิกค่าใช้จ่ายเดินทางไปราชการ (แบบ ๘๗๐๘) หนึ่งใบ = การเดินทางหนึ่งครั้ง
// (อาจมีผู้เดินทางหลายคนพร้อมกัน — ดู TravelParticipant) ใช้สร้างเอกสาร 3 ใบ
// พร้อมกัน: บันทึกข้อความขออนุมัติ, ใบเบิกฯ ส่วนที่ 1, หลักฐานการจ่ายเงิน ส่วนที่ 2

// สัญลักษณ์แทน "ไม่ได้ส่งค่านี้มา" ใน copyWith — ให้ int? field ต่างๆ (budgetId,
// advancePayerPersonnelId ฯลฯ) เคลียร์กลับเป็น null ได้จริงตอนผู้ใช้กด "ไม่ระบุ"
// ใน dropdown แทนที่จะใช้ `field ?? this.field` แบบเดิมที่ทำให้ตั้งเป็น null
// ตรงๆ ไม่ได้เลย (ส่ง null เข้ามาจะถูกตีความว่า "ไม่เปลี่ยน" เสมอ)
const _unset = Object();

class TravelReimbursement {
  final int? id;
  final int? budgetId;
  final String? documentNumber;
  final String? subject;
  final String? destination;
  final String? startDate;
  final String? endDate;
  final bool isAdvancePayer;
  final int? advancePayerPersonnelId;
  // ผู้ขอเบิก/ผู้รับเงิน ตอนติ๊ก "ข้าพเจ้าคนเดียว" (ไม่มีผู้สำรองจ่าย) — แยกจาก
  // advancePayerPersonnelId ที่ใช้เฉพาะตอนติ๊ก "และคณะ" เท่านั้น ไม่งั้นถ้าไม่
  // ระบุ ระบบจะเดาเอาจากผู้เดินทางคนแรกในตารางแทน (ดู TravelDocumentGenerator)
  final int? requesterPersonnelId;
  final int? checkerPersonnelId;
  final double? totalAmount;
  final String? totalAmountTh;
  final String? createdAt;
  // "ประเภท" (อัตรา/หลักเกณฑ์การเบิก) ของแต่ละหมวดค่าใช้จ่าย ตามแบบ ๘๗๐๘
  // ส่วนที่ 1 จริง — เป็นข้อความอธิบายอัตราของการเบิกครั้งนี้ ไม่ผูกกับ
  // ผู้เดินทางคนใดคนหนึ่ง (เช่น "ระดับชำนาญการพิเศษ") จึงเก็บระดับใบเบิก
  final String? allowanceType;
  final String? accommodationType;
  final String? transportType;
  final String? otherExpenseType;
  // ☐ ที่พัก / ☐ สำนักงาน ในแบบ ๘๗๐๘ ส่วนที่ 1 — true = ออกเดินทางจากที่พัก
  final bool departsFromHome;

  const TravelReimbursement({
    this.id,
    this.budgetId,
    this.documentNumber,
    this.subject,
    this.destination,
    this.startDate,
    this.endDate,
    this.isAdvancePayer = false,
    this.advancePayerPersonnelId,
    this.requesterPersonnelId,
    this.checkerPersonnelId,
    this.totalAmount,
    this.totalAmountTh,
    this.createdAt,
    this.allowanceType,
    this.accommodationType,
    this.transportType,
    this.otherExpenseType,
    this.departsFromHome = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'budget_id': budgetId,
        'document_number': documentNumber,
        'subject': subject,
        'destination': destination,
        'start_date': startDate,
        'end_date': endDate,
        'is_advance_payer': isAdvancePayer ? 1 : 0,
        'advance_payer_personnel_id': advancePayerPersonnelId,
        'requester_personnel_id': requesterPersonnelId,
        'checker_personnel_id': checkerPersonnelId,
        'total_amount': totalAmount,
        'total_amount_th': totalAmountTh,
        'created_at': createdAt,
        'allowance_type': allowanceType,
        'accommodation_type': accommodationType,
        'transport_type': transportType,
        'other_expense_type': otherExpenseType,
        'departs_from_home': departsFromHome ? 1 : 0,
      };

  factory TravelReimbursement.fromMap(Map<String, dynamic> m) => TravelReimbursement(
        id: m['id'] as int?,
        budgetId: m['budget_id'] as int?,
        documentNumber: m['document_number'] as String?,
        subject: m['subject'] as String?,
        destination: m['destination'] as String?,
        startDate: m['start_date'] as String?,
        endDate: m['end_date'] as String?,
        isAdvancePayer: (m['is_advance_payer'] as int? ?? 0) == 1,
        advancePayerPersonnelId: m['advance_payer_personnel_id'] as int?,
        requesterPersonnelId: m['requester_personnel_id'] as int?,
        checkerPersonnelId: m['checker_personnel_id'] as int?,
        totalAmount: (m['total_amount'] as num?)?.toDouble(),
        totalAmountTh: m['total_amount_th'] as String?,
        createdAt: m['created_at'] as String?,
        allowanceType: m['allowance_type'] as String?,
        accommodationType: m['accommodation_type'] as String?,
        transportType: m['transport_type'] as String?,
        otherExpenseType: m['other_expense_type'] as String?,
        departsFromHome: (m['departs_from_home'] as int? ?? 1) == 1,
      );

  TravelReimbursement copyWith({
    int? id,
    Object? budgetId = _unset,
    String? documentNumber,
    String? subject,
    String? destination,
    String? startDate,
    String? endDate,
    bool? isAdvancePayer,
    Object? advancePayerPersonnelId = _unset,
    Object? requesterPersonnelId = _unset,
    Object? checkerPersonnelId = _unset,
    double? totalAmount,
    String? totalAmountTh,
    String? createdAt,
    String? allowanceType,
    String? accommodationType,
    String? transportType,
    String? otherExpenseType,
    bool? departsFromHome,
  }) =>
      TravelReimbursement(
        id: id ?? this.id,
        budgetId: identical(budgetId, _unset) ? this.budgetId : budgetId as int?,
        documentNumber: documentNumber ?? this.documentNumber,
        subject: subject ?? this.subject,
        destination: destination ?? this.destination,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        isAdvancePayer: isAdvancePayer ?? this.isAdvancePayer,
        advancePayerPersonnelId:
            identical(advancePayerPersonnelId, _unset) ? this.advancePayerPersonnelId : advancePayerPersonnelId as int?,
        requesterPersonnelId: identical(requesterPersonnelId, _unset) ? this.requesterPersonnelId : requesterPersonnelId as int?,
        checkerPersonnelId: identical(checkerPersonnelId, _unset) ? this.checkerPersonnelId : checkerPersonnelId as int?,
        totalAmount: totalAmount ?? this.totalAmount,
        totalAmountTh: totalAmountTh ?? this.totalAmountTh,
        createdAt: createdAt ?? this.createdAt,
        allowanceType: allowanceType ?? this.allowanceType,
        accommodationType: accommodationType ?? this.accommodationType,
        transportType: transportType ?? this.transportType,
        otherExpenseType: otherExpenseType ?? this.otherExpenseType,
        departsFromHome: departsFromHome ?? this.departsFromHome,
      );
}
