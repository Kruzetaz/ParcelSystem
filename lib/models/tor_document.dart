// tor_document.dart
// TOR / ข้อมูลคุณลักษณะเฉพาะ — เอกสารกำหนดสเปกก่อนเข้าสู่ขั้นตอนจัดซื้อจัดจ้างจริง
// (blueprint หน้าที่ 4) ยังไม่ผูกกับ procurement_orders โดยตรง — เป็นแค่ทะเบียน
// เก็บร่าง/อนุมัติสเปกไว้อ้างอิงตอนสร้างเอกสารจัดซื้อจัดจ้างในขั้นถัดไป

class TorDocument {
  final int? id;
  final String? documentNumber;
  final String title;
  final String? category; // 'ครุภัณฑ์' | 'วัสดุ' | 'จ้าง'
  final double? estimatedAmount;
  final String? createdDate; // "d MMMM yyyy" พ.ศ.
  final String status; // 'ร่าง' | 'อนุมัติ'
  final String? specificationText;
  final int? orderId; // ผูกกับ procurement_orders — ใช้ export เอกสาร .docx

  const TorDocument({
    this.id,
    this.documentNumber,
    required this.title,
    this.category,
    this.estimatedAmount,
    this.createdDate,
    this.status = 'ร่าง',
    this.specificationText,
    this.orderId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'document_number': documentNumber,
        'title': title,
        'category': category,
        'estimated_amount': estimatedAmount,
        'created_date': createdDate,
        'status': status,
        'specification_text': specificationText,
        'order_id': orderId,
      };

  factory TorDocument.fromMap(Map<String, dynamic> m) => TorDocument(
        id: m['id'] as int?,
        documentNumber: m['document_number'] as String?,
        title: m['title'] as String,
        category: m['category'] as String?,
        estimatedAmount: (m['estimated_amount'] as num?)?.toDouble(),
        createdDate: m['created_date'] as String?,
        status: m['status'] as String? ?? 'ร่าง',
        specificationText: m['specification_text'] as String?,
        orderId: m['order_id'] as int?,
      );

  TorDocument copyWith({
    int? id,
    String? documentNumber,
    String? title,
    String? category,
    double? estimatedAmount,
    String? createdDate,
    String? status,
    String? specificationText,
  }) {
    return TorDocument(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      title: title ?? this.title,
      category: category ?? this.category,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      createdDate: createdDate ?? this.createdDate,
      status: status ?? this.status,
      specificationText: specificationText ?? this.specificationText,
    );
  }
}
