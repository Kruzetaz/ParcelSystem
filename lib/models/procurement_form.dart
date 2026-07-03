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

  const ProcurementForm({
    required this.procurementNumber,
    this.schoolName, this.schoolAddressNo, this.schoolSubdistrict,
    this.schoolAmphoe, this.schoolChangwat, this.projectName,
    this.activityName, this.allocatedAmount, this.usedBudget,
    this.remainingAmount, this.purposeReason, this.purposeObjective,
    this.ownerName, this.ownerPosition, this.financeOfficer,
    this.specCreatorName, this.procurementOfficer, this.procurementHead,
    this.directorName, this.inspectorTitleGroup,
    this.inspector1, this.inspector1Pos,
    this.inspector2, this.inspector2Pos,
    this.inspector3, this.inspector3Pos,
    this.vendorName, this.vendorOwner, this.vendorAddressNo,
    this.vendorSubdistrict, this.vendorDistrict, this.vendorProvince,
    this.vendorPhone, this.vendorTaxId,
    this.currentOrderPrice, this.totalPriceTh,
    this.subtotalBeforeVat, this.vatAmount,
    this.taxWithholdingAmount, this.netPayableAmount,
    this.shippingDays, this.penaltyRate, this.warrantyPeriod,
    this.egpProjectId, this.contractControlNumber, this.inspectionControlNumber,
    this.dateMemoUsed, this.dateOrderCreated, this.dateAnnouncement,
    this.dateQuotation, this.dateContractSigned, this.dateDeadline,
    this.dateShipping, this.dateInspection, this.dateDisbursement,
  });

  Map<String, dynamic> toMap() => {
    'procurement_number': procurementNumber,
    'school_name': schoolName, 'school_address_no': schoolAddressNo,
    'school_subdistrict': schoolSubdistrict, 'school_amphoe': schoolAmphoe,
    'school_changwat': schoolChangwat, 'project_name': projectName,
    'activity_name': activityName, 'allocated_amount': allocatedAmount,
    'used_budget': usedBudget, 'remaining_amount': remainingAmount,
    'purpose_reason': purposeReason, 'purpose_objective': purposeObjective,
    'owner_name': ownerName, 'owner_position': ownerPosition,
    'finance_officer': financeOfficer, 'spec_creator_name': specCreatorName,
    'procurement_officer': procurementOfficer, 'procurement_head': procurementHead,
    'director_name': directorName, 'inspector_title_group': inspectorTitleGroup,
    'inspector_1': inspector1, 'inspector_1_pos': inspector1Pos,
    'inspector_2': inspector2, 'inspector_2_pos': inspector2Pos,
    'inspector_3': inspector3, 'inspector_3_pos': inspector3Pos,
    'vendor_name': vendorName, 'vendor_owner': vendorOwner,
    'vendor_address_no': vendorAddressNo, 'vendor_subdistrict': vendorSubdistrict,
    'vendor_district': vendorDistrict, 'vendor_province': vendorProvince,
    'vendor_phone': vendorPhone, 'vendor_tax_id': vendorTaxId,
    'current_order_price': currentOrderPrice, 'total_price_th': totalPriceTh,
    'subtotal_before_vat': subtotalBeforeVat, 'vat_amount': vatAmount,
    'tax_withholding_amount': taxWithholdingAmount, 'net_payable_amount': netPayableAmount,
    'shipping_days': shippingDays, 'penalty_rate': penaltyRate,
    'warranty_period': warrantyPeriod, 'egp_project_id': egpProjectId,
    'contract_control_number': contractControlNumber,
    'inspection_control_number': inspectionControlNumber,
    'date_memo_used': dateMemoUsed, 'date_order_created': dateOrderCreated,
    'date_announcement': dateAnnouncement, 'date_quotation': dateQuotation,
    'date_contract_signed': dateContractSigned, 'date_deadline': dateDeadline,
    'date_shipping': dateShipping, 'date_inspection': dateInspection,
    'date_disbursement': dateDisbursement,
  };

  factory ProcurementForm.fromMap(Map<String, dynamic> m) => ProcurementForm(
    procurementNumber: m['procurement_number'] as String,
    schoolName: m['school_name'] as String?,
    schoolAddressNo: m['school_address_no'] as String?,
    schoolSubdistrict: m['school_subdistrict'] as String?,
    schoolAmphoe: m['school_amphoe'] as String?,
    schoolChangwat: m['school_changwat'] as String?,
    projectName: m['project_name'] as String?,
    activityName: m['activity_name'] as String?,
    allocatedAmount: m['allocated_amount'] as double?,
    usedBudget: m['used_budget'] as double?,
    remainingAmount: m['remaining_amount'] as double?,
    purposeReason: m['purpose_reason'] as String?,
    purposeObjective: m['purpose_objective'] as String?,
    ownerName: m['owner_name'] as String?,
    ownerPosition: m['owner_position'] as String?,
    financeOfficer: m['finance_officer'] as String?,
    specCreatorName: m['spec_creator_name'] as String?,
    procurementOfficer: m['procurement_officer'] as String?,
    procurementHead: m['procurement_head'] as String?,
    directorName: m['director_name'] as String?,
    inspectorTitleGroup: m['inspector_title_group'] as String?,
    inspector1: m['inspector_1'] as String?,
    inspector1Pos: m['inspector_1_pos'] as String?,
    inspector2: m['inspector_2'] as String?,
    inspector2Pos: m['inspector_2_pos'] as String?,
    inspector3: m['inspector_3'] as String?,
    inspector3Pos: m['inspector_3_pos'] as String?,
    vendorName: m['vendor_name'] as String?,
    vendorOwner: m['vendor_owner'] as String?,
    vendorAddressNo: m['vendor_address_no'] as String?,
    vendorSubdistrict: m['vendor_subdistrict'] as String?,
    vendorDistrict: m['vendor_district'] as String?,
    vendorProvince: m['vendor_province'] as String?,
    vendorPhone: m['vendor_phone'] as String?,
    vendorTaxId: m['vendor_tax_id'] as String?,
    currentOrderPrice: m['current_order_price'] as double?,
    totalPriceTh: m['total_price_th'] as String?,
    subtotalBeforeVat: m['subtotal_before_vat'] as double?,
    vatAmount: m['vat_amount'] as double?,
    taxWithholdingAmount: m['tax_withholding_amount'] as double?,
    netPayableAmount: m['net_payable_amount'] as double?,
    shippingDays: m['shipping_days'] as int?,
    penaltyRate: m['penalty_rate'] as double?,
    warrantyPeriod: m['warranty_period'] as String?,
    egpProjectId: m['egp_project_id'] as String?,
    contractControlNumber: m['contract_control_number'] as String?,
    inspectionControlNumber: m['inspection_control_number'] as String?,
    dateMemoUsed: m['date_memo_used'] as String?,
    dateOrderCreated: m['date_order_created'] as String?,
    dateAnnouncement: m['date_announcement'] as String?,
    dateQuotation: m['date_quotation'] as String?,
    dateContractSigned: m['date_contract_signed'] as String?,
    dateDeadline: m['date_deadline'] as String?,
    dateShipping: m['date_shipping'] as String?,
    dateInspection: m['date_inspection'] as String?,
    dateDisbursement: m['date_disbursement'] as String?,
  );
}
