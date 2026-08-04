// asset_repair_entry.dart
// แถวหนึ่งใน "ประวัติซ่อมครุภัณฑ์" (เมนูรวมศูนย์) — join asset_events (event_type
// = 'ซ่อมแซม') เข้ากับ fixed_assets เพื่อโชว์ชื่อ/เลขครุภัณฑ์โดยไม่ต้องเปิดเข้าไป
// ทีละชิ้นเหมือนก่อนหน้านี้ (ที่มีแค่ประวัติแยกตามชิ้นในหน้าทะเบียนครุภัณฑ์)

class AssetRepairEntry {
  final int eventId;
  final int assetId;
  final String? assetNumber;
  final String assetName;
  final String? assetLocation;
  final String? eventDate;
  final String? description;

  const AssetRepairEntry({
    required this.eventId,
    required this.assetId,
    this.assetNumber,
    required this.assetName,
    this.assetLocation,
    this.eventDate,
    this.description,
  });

  factory AssetRepairEntry.fromMap(Map<String, dynamic> m) => AssetRepairEntry(
        eventId: m['event_id'] as int,
        assetId: m['asset_id'] as int,
        assetNumber: m['asset_number'] as String?,
        assetName: m['asset_name'] as String,
        assetLocation: m['asset_location'] as String?,
        eventDate: m['event_date'] as String?,
        description: m['description'] as String?,
      );
}
