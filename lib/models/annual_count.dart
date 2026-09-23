// annual_count.dart
// ตรวจนับพัสดุประจำปี (blueprint หน้าที่ 10) — บันทึกประวัติการตรวจสอบ
// สินทรัพย์ตามกฎหมาย (ครุภัณฑ์+วัสดุ) ประจำปีงบประมาณ
//
// เพิ่มเลขที่/วันที่เอกสาร 3 ฉบับ (บันทึกขออนุมัติแต่งตั้งกรรมการ, คำสั่งแต่งตั้ง,
// บันทึกรายงานผล) และรายชื่อกรรมการ/รายการพัสดุชำรุด แบบมีโครงสร้าง เพื่อพิมพ์
// เอกสารชุดตรวจสอบพัสดุประจำปีให้ครบอัตโนมัติได้ (ตามแบบฟอร์มจริงที่ใช้อยู่)
// — เก็บ committee members / damaged items เป็น JSON ในคอลัมน์เดียว แทนที่จะ
// แยกตาราง เพราะเป็นข้อมูลลูกของรอบตรวจนับ 1 รอบเท่านั้น ไม่ได้ query ข้ามรอบ

import 'dart:convert';

class AnnualCountMember {
  final String name;
  final String position; // ตำแหน่ง เช่น "ครูชำนาญการ"
  final String role; // "ประธานกรรมการ" | "กรรมการ" | "กรรมการและเลขานุการ"

  const AnnualCountMember(
      {required this.name, this.position = '', this.role = 'กรรมการ'});

  Map<String, dynamic> toJson() =>
      {'name': name, 'position': position, 'role': role};

  factory AnnualCountMember.fromJson(Map<String, dynamic> j) =>
      AnnualCountMember(
        name: j['name'] as String? ?? '',
        position: j['position'] as String? ?? '',
        role: j['role'] as String? ?? 'กรรมการ',
      );
}

// ประเภทความชำรุดสำหรับตาราง "บัญชีรายการพัสดุชำรุด" — ใช้เลือกว่าจะติ๊กช่องไหน
// ในตาราง (ชำรุด/เสื่อม/สูญไป) ตามแบบฟอร์มจริง
const annualCountDamageTypes = ['ชำรุด', 'เสื่อมสภาพ', 'สูญไป'];

class AnnualCountDamagedItem {
  final String name;
  final String? code;
  final String? brand;
  final String? damageDetail;
  final bool inUse;
  final String? damageType; // 'ชำรุด' | 'เสื่อมสภาพ' | 'สูญไป'
  final double? registeredPrice;
  final String? assignee; // ผู้ใช้งาน

  const AnnualCountDamagedItem({
    required this.name,
    this.code,
    this.brand,
    this.damageDetail,
    this.inUse = false,
    this.damageType,
    this.registeredPrice,
    this.assignee,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'brand': brand,
        'damageDetail': damageDetail,
        'inUse': inUse,
        'damageType': damageType,
        'registeredPrice': registeredPrice,
        'assignee': assignee,
      };

  factory AnnualCountDamagedItem.fromJson(Map<String, dynamic> j) =>
      AnnualCountDamagedItem(
        name: j['name'] as String? ?? '',
        code: j['code'] as String?,
        brand: j['brand'] as String?,
        damageDetail: j['damageDetail'] as String?,
        inUse: j['inUse'] as bool? ?? false,
        damageType: j['damageType'] as String?,
        registeredPrice: (j['registeredPrice'] as num?)?.toDouble(),
        assignee: j['assignee'] as String?,
      );
}

class AnnualCount {
  final int? id;
  final String fiscalYear;
  final String? startDate;
  final String? responsiblePersons;
  final int? totalItems;
  final int? foundItems;
  final int? damagedLostItems;
  final String status; // 'กำลังดำเนินการ' | 'เสร็จสิ้น'
  final String? summaryNotes;

  // บันทึกขออนุมัติแต่งตั้งคณะกรรมการตรวจสอบพัสดุประจำปี
  final String? memoNumber;
  final String? memoDate;
  // คำสั่งแต่งตั้งคณะกรรมการตรวจสอบพัสดุประจำปี
  final String? orderNumber;
  final String? orderDate;
  // บันทึกรายงานผลการตรวจสอบพัสดุประจำปี
  final String? reportNumber;
  final String? reportDate;

  // หนังสือนำส่งสำเนารายงานถึงเขตพื้นที่การศึกษา / สำนักงานตรวจเงินแผ่นดิน
  final String? transmittalDistrictNumber;
  final String? transmittalDistrictDate;
  final String? transmittalAuditNumber;
  final String? transmittalAuditDate;

  final List<AnnualCountMember> members;
  final List<AnnualCountDamagedItem> damagedItems;

  const AnnualCount({
    this.id,
    required this.fiscalYear,
    this.startDate,
    this.responsiblePersons,
    this.totalItems,
    this.foundItems,
    this.damagedLostItems,
    this.status = 'กำลังดำเนินการ',
    this.summaryNotes,
    this.memoNumber,
    this.memoDate,
    this.orderNumber,
    this.orderDate,
    this.reportNumber,
    this.reportDate,
    this.transmittalDistrictNumber,
    this.transmittalDistrictDate,
    this.transmittalAuditNumber,
    this.transmittalAuditDate,
    this.members = const [],
    this.damagedItems = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'fiscal_year': fiscalYear,
        'start_date': startDate,
        'responsible_persons': responsiblePersons,
        'total_items': totalItems,
        'found_items': foundItems,
        'damaged_lost_items': damagedLostItems,
        'status': status,
        'summary_notes': summaryNotes,
        'memo_number': memoNumber,
        'memo_date': memoDate,
        'order_number': orderNumber,
        'order_date': orderDate,
        'report_number': reportNumber,
        'report_date': reportDate,
        'transmittal_district_number': transmittalDistrictNumber,
        'transmittal_district_date': transmittalDistrictDate,
        'transmittal_audit_number': transmittalAuditNumber,
        'transmittal_audit_date': transmittalAuditDate,
        'members_json': jsonEncode(members.map((m) => m.toJson()).toList()),
        'damaged_items_json':
            jsonEncode(damagedItems.map((d) => d.toJson()).toList()),
      };

  factory AnnualCount.fromMap(Map<String, dynamic> m) => AnnualCount(
        id: m['id'] as int?,
        fiscalYear: m['fiscal_year'] as String,
        startDate: m['start_date'] as String?,
        responsiblePersons: m['responsible_persons'] as String?,
        totalItems: m['total_items'] as int?,
        foundItems: m['found_items'] as int?,
        damagedLostItems: m['damaged_lost_items'] as int?,
        status: m['status'] as String? ?? 'กำลังดำเนินการ',
        summaryNotes: m['summary_notes'] as String?,
        memoNumber: m['memo_number'] as String?,
        memoDate: m['memo_date'] as String?,
        orderNumber: m['order_number'] as String?,
        orderDate: m['order_date'] as String?,
        reportNumber: m['report_number'] as String?,
        reportDate: m['report_date'] as String?,
        transmittalDistrictNumber: m['transmittal_district_number'] as String?,
        transmittalDistrictDate: m['transmittal_district_date'] as String?,
        transmittalAuditNumber: m['transmittal_audit_number'] as String?,
        transmittalAuditDate: m['transmittal_audit_date'] as String?,
        members: _decodeMembers(m['members_json'] as String?),
        damagedItems: _decodeDamagedItems(m['damaged_items_json'] as String?),
      );

  static List<AnnualCountMember> _decodeMembers(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => AnnualCountMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<AnnualCountDamagedItem> _decodeDamagedItems(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map(
              (e) => AnnualCountDamagedItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  AnnualCount copyWith({
    int? id,
    String? fiscalYear,
    String? startDate,
    String? responsiblePersons,
    int? totalItems,
    int? foundItems,
    int? damagedLostItems,
    String? status,
    String? summaryNotes,
    String? memoNumber,
    String? memoDate,
    String? orderNumber,
    String? orderDate,
    String? reportNumber,
    String? reportDate,
    String? transmittalDistrictNumber,
    String? transmittalDistrictDate,
    String? transmittalAuditNumber,
    String? transmittalAuditDate,
    List<AnnualCountMember>? members,
    List<AnnualCountDamagedItem>? damagedItems,
  }) {
    return AnnualCount(
      id: id ?? this.id,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      startDate: startDate ?? this.startDate,
      responsiblePersons: responsiblePersons ?? this.responsiblePersons,
      totalItems: totalItems ?? this.totalItems,
      foundItems: foundItems ?? this.foundItems,
      damagedLostItems: damagedLostItems ?? this.damagedLostItems,
      status: status ?? this.status,
      summaryNotes: summaryNotes ?? this.summaryNotes,
      memoNumber: memoNumber ?? this.memoNumber,
      memoDate: memoDate ?? this.memoDate,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      reportNumber: reportNumber ?? this.reportNumber,
      reportDate: reportDate ?? this.reportDate,
      transmittalDistrictNumber:
          transmittalDistrictNumber ?? this.transmittalDistrictNumber,
      transmittalDistrictDate:
          transmittalDistrictDate ?? this.transmittalDistrictDate,
      transmittalAuditNumber:
          transmittalAuditNumber ?? this.transmittalAuditNumber,
      transmittalAuditDate: transmittalAuditDate ?? this.transmittalAuditDate,
      members: members ?? this.members,
      damagedItems: damagedItems ?? this.damagedItems,
    );
  }
}
