// material_item.dart
// วัสดุ/คลังพัสดุ (blueprint หน้าที่ 9) — ของสิ้นเปลือง คงเหลือคำนวณจาก
// stock_in - stock_out เสมอ ไม่เก็บ "คงเหลือ" แยกต่างหาก กันข้อมูลเพี้ยนจากการ
// แก้ไขไม่ตรงกัน

class MaterialItem {
  final int? id;
  final String? materialCode;
  final String name;
  final String? category;
  final String? unit;
  final double stockIn;
  final double stockOut;
  final double? unitPrice;

  const MaterialItem({
    this.id,
    this.materialCode,
    required this.name,
    this.category,
    this.unit,
    this.stockIn = 0,
    this.stockOut = 0,
    this.unitPrice,
  });

  double get remaining => stockIn - stockOut;
  double get totalValue => remaining * (unitPrice ?? 0);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'material_code': materialCode,
        'name': name,
        'category': category,
        'unit': unit,
        'stock_in': stockIn,
        'stock_out': stockOut,
        'unit_price': unitPrice,
      };

  factory MaterialItem.fromMap(Map<String, dynamic> m) => MaterialItem(
        id: m['id'] as int?,
        materialCode: m['material_code'] as String?,
        name: m['name'] as String,
        category: m['category'] as String?,
        unit: m['unit'] as String?,
        stockIn: (m['stock_in'] as num?)?.toDouble() ?? 0,
        stockOut: (m['stock_out'] as num?)?.toDouble() ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
      );

  MaterialItem copyWith({
    String? materialCode,
    String? name,
    String? category,
    String? unit,
    double? stockIn,
    double? stockOut,
    double? unitPrice,
  }) {
    return MaterialItem(
      id: id,
      materialCode: materialCode ?? this.materialCode,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      stockIn: stockIn ?? this.stockIn,
      stockOut: stockOut ?? this.stockOut,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
