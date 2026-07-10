// audit_log_entry.dart
// รายการ Audit Trail — บันทึกเฉพาะ สร้าง/แก้ไข/ลบ ไม่บันทึกการเปิดดู

class AuditLogEntry {
  final int? id;
  final String timestamp; // "d MMMM yyyy HH:mm" พ.ศ.
  final String action; // 'สร้าง' | 'แก้ไข' | 'ลบ'
  final String tableLabel; // ชื่อหมวดข้อมูลแบบอ่านง่าย เช่น "แผนงบประมาณ"
  final String description; // เช่น "แผนงบ: จัดซื้อวัสดุสำนักงาน"
  final String? userName;

  const AuditLogEntry({
    this.id,
    required this.timestamp,
    required this.action,
    required this.tableLabel,
    required this.description,
    this.userName,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'timestamp': timestamp,
        'action': action,
        'table_label': tableLabel,
        'description': description,
        'user_name': userName,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> m) => AuditLogEntry(
        id: m['id'] as int?,
        timestamp: m['timestamp'] as String,
        action: m['action'] as String,
        tableLabel: m['table_label'] as String? ?? '',
        description: m['description'] as String? ?? '',
        userName: m['user_name'] as String?,
      );
}
