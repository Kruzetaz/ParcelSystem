// travel_participant.dart
// ผู้เดินทางแต่ละคนในใบเบิกค่าใช้จ่ายเดินทางไปราชการ (แบบ ๘๗๐๘) หนึ่งใบ —
// snapshot ชื่อ/ตำแหน่งไว้ในแถวเสมอ (เหมือน vendor/personnel ที่อื่นในระบบ)
// กันแก้ทำเนียบบุคลากรทีหลังแล้วเอกสารเก่าที่พิมพ์ไปแล้วเพี้ยน

class TravelParticipant {
  final int? id;
  final int? reimbursementId;
  final int? personnelId;
  final String participantName;
  final String? position;
  final double allowanceAmount;
  final double accommodationAmount;
  final double transportAmount;
  final double registrationFee;
  final int sortOrder;

  const TravelParticipant({
    this.id,
    this.reimbursementId,
    this.personnelId,
    required this.participantName,
    this.position,
    this.allowanceAmount = 0,
    this.accommodationAmount = 0,
    this.transportAmount = 0,
    this.registrationFee = 0,
    this.sortOrder = 0,
  });

  double get subtotal =>
      allowanceAmount + accommodationAmount + transportAmount + registrationFee;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (reimbursementId != null) 'reimbursement_id': reimbursementId,
        'personnel_id': personnelId,
        'participant_name': participantName,
        'position': position,
        'allowance_amount': allowanceAmount,
        'accommodation_amount': accommodationAmount,
        'transport_amount': transportAmount,
        'registration_fee': registrationFee,
        'sort_order': sortOrder,
      };

  factory TravelParticipant.fromMap(Map<String, dynamic> m) => TravelParticipant(
        id: m['id'] as int?,
        reimbursementId: m['reimbursement_id'] as int?,
        personnelId: m['personnel_id'] as int?,
        participantName: m['participant_name'] as String,
        position: m['position'] as String?,
        allowanceAmount: (m['allowance_amount'] as num?)?.toDouble() ?? 0,
        accommodationAmount: (m['accommodation_amount'] as num?)?.toDouble() ?? 0,
        transportAmount: (m['transport_amount'] as num?)?.toDouble() ?? 0,
        registrationFee: (m['registration_fee'] as num?)?.toDouble() ?? 0,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  TravelParticipant copyWith({
    int? id,
    int? reimbursementId,
    int? personnelId,
    String? participantName,
    String? position,
    double? allowanceAmount,
    double? accommodationAmount,
    double? transportAmount,
    double? registrationFee,
    int? sortOrder,
  }) =>
      TravelParticipant(
        id: id ?? this.id,
        reimbursementId: reimbursementId ?? this.reimbursementId,
        personnelId: personnelId ?? this.personnelId,
        participantName: participantName ?? this.participantName,
        position: position ?? this.position,
        allowanceAmount: allowanceAmount ?? this.allowanceAmount,
        accommodationAmount: accommodationAmount ?? this.accommodationAmount,
        transportAmount: transportAmount ?? this.transportAmount,
        registrationFee: registrationFee ?? this.registrationFee,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
