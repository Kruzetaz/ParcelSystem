// contract.dart
// บริหารสัญญา/ใบสั่งซื้อ/สั่งจ้าง (blueprint หน้าที่ 5) — ผูกกับ procurement_orders
// แบบ many-to-one ผ่าน order_id ได้ (ไม่บังคับ เผื่อสัญญาที่ยังไม่ได้ผูกเอกสาร)

class Contract {
  final int? id;
  final String? contractNumber;
  final String? egpNumber;
  final int? orderId;
  final String? contractType; // 'สัญญาซื้อขาย' | 'สัญญาจ้าง' | 'ใบสั่งซื้อ' | 'ใบสั่งจ้าง'
  final double? contractAmount;
  final String? vendorName;
  final String? startDate; // "d MMMM yyyy" พ.ศ.
  final String? endDate;
  final int? installmentCount;
  final String status; // 'กำลังดำเนินการ' | 'ครบกำหนดแล้ว' | 'ยกเลิก'

  const Contract({
    this.id,
    this.contractNumber,
    this.egpNumber,
    this.orderId,
    this.contractType,
    this.contractAmount,
    this.vendorName,
    this.startDate,
    this.endDate,
    this.installmentCount,
    this.status = 'กำลังดำเนินการ',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contract_number': contractNumber,
        'egp_number': egpNumber,
        'order_id': orderId,
        'contract_type': contractType,
        'contract_amount': contractAmount,
        'vendor_name': vendorName,
        'start_date': startDate,
        'end_date': endDate,
        'installment_count': installmentCount,
        'status': status,
      };

  factory Contract.fromMap(Map<String, dynamic> m) => Contract(
        id: m['id'] as int?,
        contractNumber: m['contract_number'] as String?,
        egpNumber: m['egp_number'] as String?,
        orderId: m['order_id'] as int?,
        contractType: m['contract_type'] as String?,
        contractAmount: (m['contract_amount'] as num?)?.toDouble(),
        vendorName: m['vendor_name'] as String?,
        startDate: m['start_date'] as String?,
        endDate: m['end_date'] as String?,
        installmentCount: m['installment_count'] as int?,
        status: m['status'] as String? ?? 'กำลังดำเนินการ',
      );
}
