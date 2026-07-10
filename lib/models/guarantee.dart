// guarantee.dart
// ทะเบียนหลักประกัน (blueprint หน้าที่ 6) — หลักประกันซอง/สัญญา/เงินสด/หนังสือ
// ค้ำประกันธนาคาร ผูกกับสัญญาได้แบบไม่บังคับ (contract_id)

class Guarantee {
  final int? id;
  final String? guaranteeType; // 'หลักประกันซอง' | 'หลักประกันสัญญา' | 'เงินสด' | 'หนังสือค้ำประกันธนาคาร'
  final String? counterpartyName;
  final double? amount;
  final String? startDate;
  final String? expiryDate;
  final int? contractId;
  final String status; // 'ถืออยู่' | 'คืนแล้ว'
  final String? returnedDate;

  const Guarantee({
    this.id,
    this.guaranteeType,
    this.counterpartyName,
    this.amount,
    this.startDate,
    this.expiryDate,
    this.contractId,
    this.status = 'ถืออยู่',
    this.returnedDate,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'guarantee_type': guaranteeType,
        'counterparty_name': counterpartyName,
        'amount': amount,
        'start_date': startDate,
        'expiry_date': expiryDate,
        'contract_id': contractId,
        'status': status,
        'returned_date': returnedDate,
      };

  factory Guarantee.fromMap(Map<String, dynamic> m) => Guarantee(
        id: m['id'] as int?,
        guaranteeType: m['guarantee_type'] as String?,
        counterpartyName: m['counterparty_name'] as String?,
        amount: (m['amount'] as num?)?.toDouble(),
        startDate: m['start_date'] as String?,
        expiryDate: m['expiry_date'] as String?,
        contractId: m['contract_id'] as int?,
        status: m['status'] as String? ?? 'ถืออยู่',
        returnedDate: m['returned_date'] as String?,
      );

  Guarantee copyWith({String? status, String? returnedDate}) => Guarantee(
        id: id,
        guaranteeType: guaranteeType,
        counterpartyName: counterpartyName,
        amount: amount,
        startDate: startDate,
        expiryDate: expiryDate,
        contractId: contractId,
        status: status ?? this.status,
        returnedDate: returnedDate ?? this.returnedDate,
      );
}
