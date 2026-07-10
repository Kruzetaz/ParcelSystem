// inspection.dart
// ตรวจรับพัสดุ (blueprint หน้าที่ 7) — ผูกกับ procurement_orders เพื่อดึงชื่อ
// ผู้ส่งมอบ (vendor_name) และวงเงิน/อัตราค่าปรับมาใช้คำนวณค่าปรับอัตโนมัติ

class Inspection {
  final int? id;
  final String? inspectionNumber;
  final int? orderId;
  final String? dueDate;
  final String? actualDeliveryDate;
  final String? result; // 'ผ่าน' | 'ไม่ผ่าน' | null (ยังไม่ตรวจ)
  final double? penaltyAmount;
  final String? notes;

  const Inspection({
    this.id,
    this.inspectionNumber,
    this.orderId,
    this.dueDate,
    this.actualDeliveryDate,
    this.result,
    this.penaltyAmount,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'inspection_number': inspectionNumber,
        'order_id': orderId,
        'due_date': dueDate,
        'actual_delivery_date': actualDeliveryDate,
        'result': result,
        'penalty_amount': penaltyAmount,
        'notes': notes,
      };

  factory Inspection.fromMap(Map<String, dynamic> m) => Inspection(
        id: m['id'] as int?,
        inspectionNumber: m['inspection_number'] as String?,
        orderId: m['order_id'] as int?,
        dueDate: m['due_date'] as String?,
        actualDeliveryDate: m['actual_delivery_date'] as String?,
        result: m['result'] as String?,
        penaltyAmount: (m['penalty_amount'] as num?)?.toDouble(),
        notes: m['notes'] as String?,
      );
}
