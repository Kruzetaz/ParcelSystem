// material_transaction.dart
// ประวัติรับเข้า/เบิกจ่ายวัสดุทีละรายการ (บัตรคุมสต๊อก) — ผูกกับ MaterialItem
// แบบ many-to-one ผ่าน material_id ใช้คู่กับ stock_in/stock_out สะสมใน
// MaterialItem (สะสมไว้ให้คำนวณคงเหลือเร็ว ไม่ต้อง sum ตารางนี้ทุกครั้ง)

class MaterialTransaction {
  final int? id;
  final int materialId;
  final String? transactionDate; // "d MMMM yyyy" พ.ศ.
  final String transactionType; // 'รับเข้า' | 'เบิกจ่าย'
  final double quantity;
  final double? unitPrice;
  final String? refDocument;
  final String? counterparty; // รับจากใคร (รับเข้า) / จ่ายให้ใคร (เบิกจ่าย)
  final String? note;

  const MaterialTransaction({
    this.id,
    required this.materialId,
    this.transactionDate,
    required this.transactionType,
    required this.quantity,
    this.unitPrice,
    this.refDocument,
    this.counterparty,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'material_id': materialId,
        'transaction_date': transactionDate,
        'transaction_type': transactionType,
        'quantity': quantity,
        'unit_price': unitPrice,
        'ref_document': refDocument,
        'counterparty': counterparty,
        'note': note,
      };

  factory MaterialTransaction.fromMap(Map<String, dynamic> m) => MaterialTransaction(
        id: m['id'] as int?,
        materialId: m['material_id'] as int,
        transactionDate: m['transaction_date'] as String?,
        transactionType: m['transaction_type'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
        refDocument: m['ref_document'] as String?,
        counterparty: m['counterparty'] as String?,
        note: m['note'] as String?,
      );
}
