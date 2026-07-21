// fixed_asset.dart
// ทะเบียนครุภัณฑ์ (blueprint หน้าที่ 8) — photo_path เก็บ path ไฟล์รูปในเครื่อง
// (local storage) เท่านั้น ไม่อัปโหลดขึ้น cloud
//
// [อัปเดต]: เพิ่มฟิลด์ให้ตรงกับแบบฟอร์ม "ทะเบียนคุมครุภัณฑ์/ทรัพย์สิน" ของราชการ
// (ผู้ขาย/ผู้รับจ้าง, ประเภทเงิน, วิธีการได้มา, อายุการใช้งาน) และเพิ่มการคำนวณ
// ค่าเสื่อมราคาแบบเส้นตรง (straight-line) เป็นค่าประมาณการเท่านั้น

const fixedAssetFundTypes = ['เงินงบประมาณ', 'เงินนอกงบประมาณ', 'เงินบริจาค', 'อื่นๆ'];
const fixedAssetProcurementMethods = [
  'เฉพาะเจาะจง',
  'e-bidding (ประกวดราคาอิเล็กทรอนิกส์)',
  'คัดเลือก',
  'กรณีพิเศษ',
  'บริจาค/รับโอน',
  'อื่นๆ',
];

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
  final String? vendorName;
  final String? fundType;
  final String? procurementMethod;
  final int? usefulLifeYears;

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
    this.vendorName,
    this.fundType,
    this.procurementMethod,
    this.usefulLifeYears,
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
        'vendor_name': vendorName,
        'fund_type': fundType,
        'procurement_method': procurementMethod,
        'useful_life_years': usefulLifeYears,
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
        vendorName: m['vendor_name'] as String?,
        fundType: m['fund_type'] as String?,
        procurementMethod: m['procurement_method'] as String?,
        usefulLifeYears: m['useful_life_years'] as int?,
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
    String? vendorName,
    String? fundType,
    String? procurementMethod,
    int? usefulLifeYears,
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
      vendorName: vendorName ?? this.vendorName,
      fundType: fundType ?? this.fundType,
      procurementMethod: procurementMethod ?? this.procurementMethod,
      usefulLifeYears: usefulLifeYears ?? this.usefulLifeYears,
    );
  }
}

/// ผลคำนวณค่าเสื่อมราคาแบบเส้นตรง (straight-line) — เป็นค่าประมาณการเท่านั้น
/// ตัดค่าเสื่อมจนเหลือมูลค่าขั้นต่ำ 1 บาท (ไม่ตัดเป็นศูนย์ ตามแนวทางบัญชีภาครัฐทั่วไป)
class DepreciationInfo {
  final double ratePercentPerYear;
  final double annualDepreciation;
  final double accumulatedDepreciation;
  final double netBookValue;

  const DepreciationInfo({
    required this.ratePercentPerYear,
    required this.annualDepreciation,
    required this.accumulatedDepreciation,
    required this.netBookValue,
  });
}

/// คำนวณค่าเสื่อมราคา ณ วันนี้ — คืน null ถ้าข้อมูลไม่ครบ (ไม่มีอายุการใช้งาน
/// หรือแปลงวันที่ได้มาไม่ได้)
DepreciationInfo? calcDepreciation(FixedAsset asset, DateTime? acquiredDateParsed) {
  final years = asset.usefulLifeYears;
  if (years == null || years <= 0 || acquiredDateParsed == null) return null;
  final cost = asset.totalValue;
  if (cost <= 0) return null;

  final rate = 100 / years;
  final annualDep = cost * rate / 100;
  final elapsedDays = DateTime.now().difference(acquiredDateParsed).inDays;
  final elapsedYears = (elapsedDays / 365.25).clamp(0, years.toDouble());
  final maxAccum = cost - 1 > 0 ? cost - 1 : 0.0;
  final accumulatedDep = (annualDep * elapsedYears).clamp(0.0, maxAccum);
  final netBookValue = cost - accumulatedDep;

  return DepreciationInfo(
    ratePercentPerYear: rate,
    annualDepreciation: annualDep,
    accumulatedDepreciation: accumulatedDep,
    netBookValue: netBookValue,
  );
}
