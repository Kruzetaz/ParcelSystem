// delivery_note.dart
// ทะเบียนคุมใบส่งของ — 1 โครงการจัดซื้อจัดจ้างอาจมีการส่งมอบหลายรอบ (หลายใบส่ง
// ของ) จึงแยกเป็นตารางของตัวเอง ผูกกับ procurement_orders ผ่าน order_id

const deliveryDocTypes = [
  'ใบส่งของ',
  'ใบกำกับภาษี/ใบส่งของ',
  'ใบเสร็จรับเงิน',
  'บิลเงินสด',
];

class DeliveryNote {
  final int? id;
  final int? orderId;
  final String? docType;
  final String? docNumber;
  final String? deliveryDate;
  final String? itemsDescription;
  final String? receivedBy;
  final String? note;

  const DeliveryNote({
    this.id,
    this.orderId,
    this.docType,
    this.docNumber,
    this.deliveryDate,
    this.itemsDescription,
    this.receivedBy,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'doc_type': docType,
        'doc_number': docNumber,
        'delivery_date': deliveryDate,
        'items_description': itemsDescription,
        'received_by': receivedBy,
        'note': note,
      };

  factory DeliveryNote.fromMap(Map<String, dynamic> m) => DeliveryNote(
        id: m['id'] as int?,
        orderId: m['order_id'] as int?,
        docType: m['doc_type'] as String?,
        docNumber: m['doc_number'] as String?,
        deliveryDate: m['delivery_date'] as String?,
        itemsDescription: m['items_description'] as String?,
        receivedBy: m['received_by'] as String?,
        note: m['note'] as String?,
      );
}
