// procurement_item.dart
// แก้บั๊กเดิม: quantity เคยเป็น TEXT รวมหน่วย (เช่น "5 เครื่อง") ทำให้
// double.tryParse ล้มเหลวเงียบๆ แล้ว fallback เป็น 1 → ยอดเงินผิด
// ตอนนี้แยกเป็น quantity (double, ตัวเลขล้วน) + unit (String, หน่วยนับ)
// ตรงกับ schema ใหม่: quantity REAL NOT NULL, unit TEXT

class ProcurementItem {
  final int? id;
  final int? orderId; // FK -> procurement_orders.id
  final String itemName;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double? totalPrice; // ถ้าไม่ระบุ จะคำนวณจาก computedTotal ตอน toMap()

  const ProcurementItem({
    this.id,
    this.orderId,
    required this.itemName,
    required this.quantity,
    this.unit,
    required this.unitPrice,
    this.totalPrice,
  });

  /// quantity x unit_price — ไม่มีการ parse ข้อความอีกต่อไป คำนวณตรงจากตัวเลข
  double get computedTotal => quantity * unitPrice;

  /// สำหรับแสดงผล/ใส่ลง {{quantity}} ใน docx (รวมหน่วยกลับเข้าไปเป็นข้อความเดียว)
  /// เช่น quantity=5, unit='เครื่อง' -> "5 เครื่อง"
  String get quantityDisplay {
    final qtyStr = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return unit == null || unit!.isEmpty ? qtyStr : '$qtyStr $unit';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_id': orderId,
        'item_name': itemName,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'total_price': totalPrice ?? computedTotal,
      };

  factory ProcurementItem.fromMap(Map<String, dynamic> m) => ProcurementItem(
        id: m['id'] as int?,
        orderId: m['order_id'] as int?,
        itemName: m['item_name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: m['unit'] as String?,
        unitPrice: (m['unit_price'] as num).toDouble(),
        totalPrice: (m['total_price'] as num?)?.toDouble(),
      );

  ProcurementItem copyWith({
    int? id,
    int? orderId,
    String? itemName,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
  }) {
    return ProcurementItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}
