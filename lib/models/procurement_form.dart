class ProcurementForm {
  final String procurementNumber;
  final String? schoolName;
  final String? schoolAddressNo;
  final String? schoolSubdistrict;
  final String? schoolAmphoe;
  final String? schoolChangwat;
  final String? projectName;
  final String? activityName;
  final double? allocatedAmount;
  final double? usedBudget;
  final double? remainingAmount;
  final String? purposeReason;
  final String? purposeObjective;
  final String? ownerName;
  final String? ownerPosition;
  final String? financeOfficer;
  final String? specCreatorName;
  final String? procurementOfficer;
  final String? procurementHead;
  final String? directorName;
  final String? inspectorTitleGroup;
  final String? inspector1;
  final String? inspector1Pos;
  final String? inspector2;
  final String? inspector2Pos;
  final String? inspector3;
  final String? inspector3Pos;
  final String? vendorName;
  final String? vendorOwner;
  final String? vendorAddressNo;
  final String? vendorSubdistrict;
  final String? vendorDistrict;
  final String? vendorProvince;
  final String? vendorPhone;
  final String? vendorTaxId;
  final double? currentOrderPrice;
  final String? totalPriceTh;
  final double? subtotalBeforeVat;
  final double? vatAmount;
  final double? taxWithholdingAmount;
  final double? netPayableAmount;
  final int? shippingDays;
  final double? penaltyRate;
  final String? warrantyPeriod;
  final String? egpProjectId;
  final String? contractControlNumber;
  final String? inspectionControlNumber;
  final String? dateMemoUsed;
  final String? dateOrderCreated;
  final String? dateAnnouncement;
  final String? dateQuotation;
  final String? dateContractSigned;
  final String? dateDeadline;
  final String? dateShipping;
  final String? dateInspection;
  final String? dateDisbursement;

  ProcurementForm({
    required this.procurementNumber,
    this.schoolName,
    this.schoolAddressNo,
    this.schoolSubdistrict,
    this.schoolAmphoe,
    this.schoolChangwat,
    this.projectName,
    this.activityName,
    this.allocatedAmount,
    this.usedBudget,
    this.remainingAmount,
    this.purposeReason,
    this.purposeObjective,
    this.ownerName,
    this.ownerPosition,
    this.financeOfficer,
    this.specCreatorName,
    this.procurementOfficer,
    this.procurementHead,
    this.directorName,
    this.inspectorTitleGroup,
    this.inspector1,
    this.inspector1Pos,
    this.inspector2,
    this.inspector2Pos,
    this.inspector3,
    this.inspector3Pos,
    this.vendorName,
    this.vendorOwner,
    this.vendorAddressNo,
    this.vendorSubdistrict,
    this.vendorDistrict,
    this.vendorProvince,
    this.vendorPhone,
    this.vendorTaxId,
    this.currentOrderPrice,
    this.totalPriceTh,
    this.subtotalBeforeVat,
    this.vatAmount,
    this.taxWithholdingAmount,
    this.netPayableAmount,
    this.shippingDays,
    this.penaltyRate,
    this.warrantyPeriod,
    this.egpProjectId,
    this.contractControlNumber,
    this.inspectionControlNumber,
    this.dateMemoUsed,
    this.dateOrderCreated,
    this.dateAnnouncement,
    this.dateQuotation,
    this.dateContractSigned,
    this.dateDeadline,
    this.dateShipping,
    this.dateInspection,
    this.dateDisbursement,
  });

  Map<String, dynamic> toMap() {
    return {
      'procurement_number': procurementNumber,
      'school_name': schoolName,
      'school_address_no': schoolAddressNo,
      'school_subdistrict': schoolSubdistrict,
      'school_amphoe': schoolAmphoe,
      'school_changwat': schoolChangwat,
      'project_name': projectName,
      'activity_name': activityName,
      'allocated_amount': allocatedAmount,
      'used_budget': usedBudget,
      'remaining_amount': remainingAmount,
      'purpose_reason': purposeReason,
      'purpose_objective': purposeObjective,
      'owner_name': ownerName,
      'owner_position': ownerPosition,
      'finance_officer': financeOfficer,
      'spec_creator_name': specCreatorName,
      'procurement_officer': procurementOfficer,
      'procurement_head': procurementHead,
      'director_name': directorName,
      'inspector_title_group': inspectorTitleGroup,
      'inspector_1': inspector1,
      'inspector_1_pos': inspector1Pos,
      'inspector_2': inspector2,
      'inspector_2_pos': inspector2Pos,
      'inspector_3': inspector3,
      'inspector_3_pos': inspector3Pos,
      'vendor_name': vendorName,
      'vendor_owner': vendorOwner,
      'vendor_address_no': vendorAddressNo,
      'vendor_subdistrict': vendorSubdistrict,
      'vendor_district': vendorDistrict,
      'vendor_province': vendorProvince,
      'vendor_phone': vendorPhone,
      'vendor_tax_id': vendorTaxId,
      'current_order_price': currentOrderPrice,
      'total_price_th': totalPriceTh,
      'subtotal_before_vat': subtotalBeforeVat,
      'vat_amount': vatAmount,
      'tax_withholding_amount': taxWithholdingAmount,
      'net_payable_amount': netPayableAmount,
      'shipping_days': shippingDays,
      'penalty_rate': penaltyRate,
      'warranty_period': warrantyPeriod,
      'egp_project_id': egpProjectId,
      'contract_control_number': contractControlNumber,
      'inspection_control_number': inspectionControlNumber,
      'date_memo_used': dateMemoUsed,
      'date_order_created': dateOrderCreated,
      'date_announcement': dateAnnouncement,
      'date_quotation': dateQuotation,
      'date_contract_signed': dateContractSigned,
      'date_deadline': dateDeadline,
      'date_shipping': dateShipping,
      'date_inspection': dateInspection,
      'date_disbursement': dateDisbursement,
    };
  }

  factory ProcurementForm.fromMap(Map<String, dynamic> map) {
    return ProcurementForm(
      procurementNumber: map['procurement_number'] as String,
      schoolName: map['school_name'] as String?,
      schoolAddressNo: map['school_address_no'] as String?,
      schoolSubdistrict: map['school_subdistrict'] as String?,
      schoolAmphoe: map['school_amphoe'] as String?,
      schoolChangwat: map['school_changwat'] as String?,
      projectName: map['project_name'] as String?,
      activityName: map['activity_name'] as String?,
      allocatedAmount: (map['allocated_amount'] as num?)?.toDouble(),
      usedBudget: (map['used_budget'] as num?)?.toDouble(),
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble(),
      purposeReason: map['purpose_reason'] as String?,
      purposeObjective: map['purpose_objective'] as String?,
      ownerName: map['owner_name'] as String?,
      ownerPosition: map['owner_position'] as String?,
      financeOfficer: map['finance_officer'] as String?,
      specCreatorName: map['spec_creator_name'] as String?,
      procurementOfficer: map['procurement_officer'] as String?,
      procurementHead: map['procurement_head'] as String?,
      directorName: map['director_name'] as String?,
      inspectorTitleGroup: map['inspector_title_group'] as String?,
      inspector1: map['inspector_1'] as String?,
      inspector1Pos: map['inspector_1_pos'] as String?,
      inspector2: map['inspector_2'] as String?,
      inspector2Pos: map['inspector_2_pos'] as String?,
      inspector3: map['inspector_3'] as String?,
      inspector3Pos: map['inspector_3_pos'] as String?,
      vendorName: map['vendor_name'] as String?,
      vendorOwner: map['vendor_owner'] as String?,
      vendorAddressNo: map['vendor_address_no'] as String?,
      vendorSubdistrict: map['vendor_subdistrict'] as String?,
      vendorDistrict: map['vendor_district'] as String?,
      vendorProvince: map['vendor_province'] as String?,
      vendorPhone: map['vendor_phone'] as String?,
      vendorTaxId: map['vendor_tax_id'] as String?,
      currentOrderPrice: (map['current_order_price'] as num?)?.toDouble(),
      totalPriceTh: map['total_price_th'] as String?,
      subtotalBeforeVat: (map['subtotal_before_vat'] as num?)?.toDouble(),
      vatAmount: (map['vat_amount'] as num?)?.toDouble(),
      taxWithholdingAmount: (map['tax_withholding_amount'] as num?)?.toDouble(),
      netPayableAmount: (map['net_payable_amount'] as num?)?.toDouble(),
      shippingDays: map['shipping_days'] as int?,
      penaltyRate: (map['penalty_rate'] as num?)?.toDouble(),
      warrantyPeriod: map['warranty_period'] as String?,
      egpProjectId: map['egp_project_id'] as String?,
      contractControlNumber: map['contract_control_number'] as String?,
      inspectionControlNumber: map['inspection_control_number'] as String?,
      dateMemoUsed: map['date_memo_used'] as String?,
      dateOrderCreated: map['date_order_created'] as String?,
      dateAnnouncement: map['date_announcement'] as String?,
      dateQuotation: map['date_quotation'] as String?,
      dateContractSigned: map['date_contract_signed'] as String?,
      dateDeadline: map['date_deadline'] as String?,
      dateShipping: map['date_shipping'] as String?,
      dateInspection: map['date_inspection'] as String?,
      dateDisbursement: map['date_disbursement'] as String?,
    );
  }

  ProcurementForm copyWith(Map<String, dynamic> changes) {
    final merged = {...toMap(), ...changes};
    return ProcurementForm.fromMap(merged);
  }
}