// fixed_asset.dart
// ทะเบียนครุภัณฑ์ (blueprint หน้าที่ 8) — photo_path เก็บ path ไฟล์รูปในเครื่อง
// (local storage) เท่านั้น ไม่อัปโหลดขึ้น cloud

class FixedAsset {
  final int? id;
  final String? assetNumber;
  final String name;
  final double quantity;
  final double? unitPrice;
  final String? location;
  final String? acquiredDate;
  final String? photoPath;
  final String status; // 'ใช้งานปกติ' | 'ชำรุด' | 'รอจำหน่าย'

  const FixedAsset({
    this.id,
    this.assetNumber,
    required this.name,
    this.quantity = 1,
    this.unitPrice,
    this.location,
    this.acquiredDate,
    this.photoPath,
    this.status = 'ใช้งานปกติ',
  });

  double get totalValue => quantity * (unitPrice ?? 0);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'asset_number': assetNumber,
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'location': location,
        'acquired_date': acquiredDate,
        'photo_path': photoPath,
        'status': status,
      };

  factory FixedAsset.fromMap(Map<String, dynamic> m) => FixedAsset(
        id: m['id'] as int?,
        assetNumber: m['asset_number'] as String?,
        name: m['name'] as String,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
        location: m['location'] as String?,
        acquiredDate: m['acquired_date'] as String?,
        photoPath: m['photo_path'] as String?,
        status: m['status'] as String? ?? 'ใช้งานปกติ',
      );

  FixedAsset copyWith({
    String? assetNumber,
    String? name,
    double? quantity,
    double? unitPrice,
    String? location,
    String? acquiredDate,
    String? photoPath,
    String? status,
  }) {
    return FixedAsset(
      id: id,
      assetNumber: assetNumber ?? this.assetNumber,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      location: location ?? this.location,
      acquiredDate: acquiredDate ?? this.acquiredDate,
      photoPath: photoPath ?? this.photoPath,
      status: status ?? this.status,
    );
  }
}
