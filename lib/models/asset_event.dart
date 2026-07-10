// asset_event.dart
// ประวัติซ่อมแซม/โอนย้าย/จำหน่าย ของครุภัณฑ์แต่ละชิ้น

class AssetEvent {
  final int? id;
  final int assetId;
  final String eventType; // 'ซ่อมแซม' | 'โอนย้าย' | 'จำหน่าย'
  final String? eventDate;
  final String? description;

  const AssetEvent({
    this.id,
    required this.assetId,
    required this.eventType,
    this.eventDate,
    this.description,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'asset_id': assetId,
        'event_type': eventType,
        'event_date': eventDate,
        'description': description,
      };

  factory AssetEvent.fromMap(Map<String, dynamic> m) => AssetEvent(
        id: m['id'] as int?,
        assetId: m['asset_id'] as int,
        eventType: m['event_type'] as String,
        eventDate: m['event_date'] as String?,
        description: m['description'] as String?,
      );
}
