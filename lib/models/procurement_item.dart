class ProcurementItem {
  final int? id;
  final String procurementNumber;
  final String? itemName;
  final String? quantity;
  final double? unitPrice;
  final double? totalPrice;

  const ProcurementItem({
    this.id,
    required this.procurementNumber,
    this.itemName,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  double get computedTotal {
    if (unitPrice == null) return 0;
    final qty = double.tryParse(quantity ?? '') ?? 1;
    return unitPrice! * qty;
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'procurement_number': procurementNumber,
    'item_name': itemName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total_price': totalPrice ?? computedTotal,
  };

  factory ProcurementItem.fromMap(Map<String, dynamic> m) => ProcurementItem(
    id: m['id'] as int?,
    procurementNumber: m['procurement_number'] as String,
    itemName: m['item_name'] as String?,
    quantity: m['quantity'] as String?,
    unitPrice: m['unit_price'] as double?,
    totalPrice: m['total_price'] as double?,
  );

  ProcurementItem copyWith({
    int? id,
    String? procurementNumber,
    String? itemName,
    String? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return ProcurementItem(
      id: id ?? this.id,
      procurementNumber: procurementNumber ?? this.procurementNumber,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}
