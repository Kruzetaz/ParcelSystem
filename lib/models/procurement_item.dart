class ProcurementItem {
  final int? id;
  final String procurementNumber;
  final String itemName;
  final String quantity;
  final double unitPrice;
  final double totalPrice;

  ProcurementItem({
    this.id,
    required this.procurementNumber,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'procurement_number': procurementNumber,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory ProcurementItem.fromMap(Map<String, dynamic> map) {
    return ProcurementItem(
      id: map['id'] as int?,
      procurementNumber: map['procurement_number'] as String,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
    );
  }
}