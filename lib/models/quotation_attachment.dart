// quotation_attachment.dart
// ไฟล์สแกนใบเสนอราคาจากร้านค้า — 1 โครงการอาจมีหลายใบเสนอราคา (เทียบราคาหลาย
// เจ้า) จึงแยกเป็นตารางของตัวเอง ผูกกับ procurement_orders ผ่าน order_id
// เก็บแค่ path ไฟล์ที่คัดลอกไว้ในเครื่อง ไม่อัปโหลด cloud เหมือนรูปครุภัณฑ์

class QuotationAttachment {
  final int? id;
  final int? orderId;
  final String? vendorName;
  final String filePath;
  final String? originalFileName;
  final String? uploadedAt;
  final String? note;

  const QuotationAttachment({
    this.id,
    this.orderId,
    this.vendorName,
    required this.filePath,
    this.originalFileName,
    this.uploadedAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'vendor_name': vendorName,
        'file_path': filePath,
        'original_file_name': originalFileName,
        'uploaded_at': uploadedAt,
        'note': note,
      };

  factory QuotationAttachment.fromMap(Map<String, dynamic> m) =>
      QuotationAttachment(
        id: m['id'] as int?,
        orderId: m['order_id'] as int?,
        vendorName: m['vendor_name'] as String?,
        filePath: m['file_path'] as String,
        originalFileName: m['original_file_name'] as String?,
        uploadedAt: m['uploaded_at'] as String?,
        note: m['note'] as String?,
      );

  QuotationAttachment copyWith({int? id, int? orderId}) => QuotationAttachment(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        vendorName: vendorName,
        filePath: filePath,
        originalFileName: originalFileName,
        uploadedAt: uploadedAt,
        note: note,
      );
}
