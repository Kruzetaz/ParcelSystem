// disposal.dart
// จำหน่ายพัสดุ (blueprint หน้าที่ 11) — คัดแยกพัสดุออกจากบัญชี ผูกกับ
// fixed_assets แบบไม่บังคับ (item_name เก็บสำรองไว้เผื่อไม่ได้ผูกกับ asset จริง)

class Disposal {
  final int? id;
  final int? assetId;
  final String? itemName;
  final String? disposalMethod; // 'ขายทอดตลาด' | 'โอนให้หน่วยงานอื่น' | 'ทำลาย'
  final String? approvedDate;
  final String? approverName;
  final String status; // 'รอดำเนินการ' | 'ตัดยอดแล้ว'

  const Disposal({
    this.id,
    this.assetId,
    this.itemName,
    this.disposalMethod,
    this.approvedDate,
    this.approverName,
    this.status = 'รอดำเนินการ',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'asset_id': assetId,
        'item_name': itemName,
        'disposal_method': disposalMethod,
        'approved_date': approvedDate,
        'approver_name': approverName,
        'status': status,
      };

  factory Disposal.fromMap(Map<String, dynamic> m) => Disposal(
        id: m['id'] as int?,
        assetId: m['asset_id'] as int?,
        itemName: m['item_name'] as String?,
        disposalMethod: m['disposal_method'] as String?,
        approvedDate: m['approved_date'] as String?,
        approverName: m['approver_name'] as String?,
        status: m['status'] as String? ?? 'รอดำเนินการ',
      );
}
