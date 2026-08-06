// procurement_installment.dart
// งวดการเบิกจ่ายสำหรับสัญญาแบบต่อเนื่องหลายเดือน (เช่น จ้างเหมาประกอบ
// อาหารกลางวัน, เช่าอินเทอร์เน็ตรายเดือน) — 1 ProcurementOrder มีได้หลาย
// งวด แต่ละงวดสร้างชุดเอกสาร (ใบส่งมอบงาน/ใบตรวจรับพัสดุ/บันทึกขออนุมัติ
// เบิกจ่าย/ใบสำคัญรับเงิน) แยกกัน โดยใช้จำนวนเงิน+วันที่ของงวดนั้นแทนยอด
// รวมทั้งสัญญา (ต่างจาก order-level fields เดิมที่มีค่าเดียวตลอดสัญญา)

class ProcurementInstallment {
  final int? id;
  final int orderId;
  final int periodNo; // งวดที่
  final String? periodLabel; // เช่น "พฤษภาคม 2569"
  final double? amount; // จำนวนเงินงวดนี้
  final String? amountTh; // ตัวอักษรไทย
  final String? dateDelivery; // วันที่ส่งมอบงาน
  final String? dateInspection; // วันที่ตรวจรับ
  final String? dateDisbursement; // วันที่อนุมัติเบิกจ่าย
  final String? inspectionResult; // 'ถูกต้องครบถ้วนตามสัญญา' | 'ไม่ครบถ้วนตามสัญญา'
  final bool hasPenalty;
  final double? penaltyAmount;
  final String? controlNumberInspection; // เลขคุมตรวจรับ

  const ProcurementInstallment({
    this.id,
    required this.orderId,
    required this.periodNo,
    this.periodLabel,
    this.amount,
    this.amountTh,
    this.dateDelivery,
    this.dateInspection,
    this.dateDisbursement,
    this.inspectionResult,
    this.hasPenalty = false,
    this.penaltyAmount,
    this.controlNumberInspection,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'period_no': periodNo,
        'period_label': periodLabel,
        'amount': amount,
        'amount_th': amountTh,
        'date_delivery': dateDelivery,
        'date_inspection': dateInspection,
        'date_disbursement': dateDisbursement,
        'inspection_result': inspectionResult,
        'has_penalty': hasPenalty ? 1 : 0,
        'penalty_amount': penaltyAmount,
        'control_number_inspection': controlNumberInspection,
      };

  factory ProcurementInstallment.fromMap(Map<String, dynamic> m) => ProcurementInstallment(
        id: m['id'] as int?,
        orderId: m['order_id'] as int,
        periodNo: m['period_no'] as int,
        periodLabel: m['period_label'] as String?,
        amount: (m['amount'] as num?)?.toDouble(),
        amountTh: m['amount_th'] as String?,
        dateDelivery: m['date_delivery'] as String?,
        dateInspection: m['date_inspection'] as String?,
        dateDisbursement: m['date_disbursement'] as String?,
        inspectionResult: m['inspection_result'] as String?,
        hasPenalty: (m['has_penalty'] as int? ?? 0) == 1,
        penaltyAmount: (m['penalty_amount'] as num?)?.toDouble(),
        controlNumberInspection: m['control_number_inspection'] as String?,
      );

  ProcurementInstallment copyWith({
    int? id,
    int? orderId,
    int? periodNo,
    String? periodLabel,
    double? amount,
    String? amountTh,
    String? dateDelivery,
    String? dateInspection,
    String? dateDisbursement,
    String? inspectionResult,
    bool? hasPenalty,
    double? penaltyAmount,
    String? controlNumberInspection,
  }) {
    return ProcurementInstallment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      periodNo: periodNo ?? this.periodNo,
      periodLabel: periodLabel ?? this.periodLabel,
      amount: amount ?? this.amount,
      amountTh: amountTh ?? this.amountTh,
      dateDelivery: dateDelivery ?? this.dateDelivery,
      dateInspection: dateInspection ?? this.dateInspection,
      dateDisbursement: dateDisbursement ?? this.dateDisbursement,
      inspectionResult: inspectionResult ?? this.inspectionResult,
      hasPenalty: hasPenalty ?? this.hasPenalty,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      controlNumberInspection: controlNumberInspection ?? this.controlNumberInspection,
    );
  }
}
