// material_item.dart
// วัสดุ/คลังพัสดุ (blueprint หน้าที่ 9) — ของสิ้นเปลือง คงเหลือคำนวณจาก
// stock_in - stock_out เสมอ ไม่เก็บ "คงเหลือ" แยกต่างหาก กันข้อมูลเพี้ยนจากการ
// แก้ไขไม่ตรงกัน
//
// [อัปเดต — บัญชีวัสดุแบบบัตรคุมสต๊อก]: เพิ่ม min_stock/max_stock (จำนวนอย่าง
// ต่ำ/อย่างสูง), storage_location (ที่เก็บ), size_spec (ขนาด/ลักษณะ) ให้ตรงกับ
// แบบฟอร์ม "บัญชีวัสดุ" ของราชการ — ประวัติรับ-จ่ายทีละรายการแยกเก็บที่
// MaterialTransaction (material_transaction.dart) ไม่ใช่ในไฟล์นี้

class MaterialItem {
  final int? id;
  final String? materialCode;
  final String name;
  final String? category;
  final String? unit;
  final double stockIn;
  final double stockOut;
  final double? unitPrice;
  final double? minStock;
  final double? maxStock;
  final String? storageLocation;
  final String? sizeSpec;

  const MaterialItem({
    this.id,
    this.materialCode,
    required this.name,
    this.category,
    this.unit,
    this.stockIn = 0,
    this.stockOut = 0,
    this.unitPrice,
    this.minStock,
    this.maxStock,
    this.storageLocation,
    this.sizeSpec,
  });

  double get remaining => stockIn - stockOut;
  double get totalValue => remaining * (unitPrice ?? 0);

  /// ต่ำกว่าเกณฑ์ "จำนวนอย่างต่ำ" ที่กำหนดไว้ ถ้ายังไม่กำหนดไว้ใช้เกณฑ์ทั่วไป ≤5
  bool get isLowStock => remaining <= (minStock ?? 5);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'material_code': materialCode,
        'name': name,
        'category': category,
        'unit': unit,
        'stock_in': stockIn,
        'stock_out': stockOut,
        'unit_price': unitPrice,
        'min_stock': minStock,
        'max_stock': maxStock,
        'storage_location': storageLocation,
        'size_spec': sizeSpec,
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
        minStock: (m['min_stock'] as num?)?.toDouble(),
        maxStock: (m['max_stock'] as num?)?.toDouble(),
        storageLocation: m['storage_location'] as String?,
        sizeSpec: m['size_spec'] as String?,
      );

  MaterialItem copyWith({
    String? materialCode,
    String? name,
    String? category,
    String? unit,
    double? stockIn,
    double? stockOut,
    double? unitPrice,
    double? minStock,
    double? maxStock,
    String? storageLocation,
    String? sizeSpec,
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
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      storageLocation: storageLocation ?? this.storageLocation,
      sizeSpec: sizeSpec ?? this.sizeSpec,
    );
  }
}
