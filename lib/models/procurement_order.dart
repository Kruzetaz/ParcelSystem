// procurement_order.dart
// แทนที่ ProcurementForm เดิม — ตรงกับตาราง procurement_orders (schema v3)
// PK เปลี่ยนจาก procurement_number (TEXT) เป็น id (INTEGER AUTOINCREMENT)
// เพราะ 1 budget ต้องผูกได้กับหลาย order และ id ใช้เป็น FK ให้ procurement_items
//
// [อัปเดตล่าสุด 2026]: เพิ่มฟิลด์เอกสารสำหรับตรวจรับ deliveryDocType และ deliveryDocNumber

class ProcurementOrder {
  final int? id;
  final int? budgetId;
  final String? fiscalYear;
  final String? orderType; // 'ซื้อ' | 'จ้าง'

  final String? procurementNumber; // {{procurement_number}}
  final String? orderNumber; // {{order_number}}

  final String? projectName;
  final String? activityName;
  final String? purposeReason;
  final String? purposeObjective;

  final double? allocatedAmount;
  final String? allocatedAmountTh; // {{allocated_amount_th}}
  final double? usedBudget;
  final double? remainingAmount;

  final String? ownerName;
  final String? ownerPosition;
  final String? financeOfficer;
  final String? specCreatorName;
  final String? specCreatorPosition; // {{spec_creator_position}}
  final String? procurementOfficer;
  final String? procurementHead;
  final String? directorName;

  final String? inspectorTitleGroup; // 'ผู้ตรวจรับพัสดุ' | 'คณะกรรมการตรวจรับ'
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
  final String? marketPriceCheck; // {{market_price_check}}

  // ข้อมูลเอกสารหลักฐานที่ใช้ส่งมอบเพื่อการตรวจรับ (เพิ่มใหม่ปี 2026)
  final String? deliveryDocType;    // {{delivery_doc_type}} เช่น ใบส่งของ, ใบกำกับภาษี
  final String? deliveryDocNumber;  // {{delivery_doc_number}} เลขที่ใบส่งของ/หลักฐาน

  final double? currentOrderPrice;
  final String? totalPriceTh;
  final double? subtotalBeforeVat;
  final double vatRate;
  final double? vatAmount;
  final double withholdingTaxRate;
  final double? taxWithholdingAmount;
  final double? netPayableAmount;

  final int? shippingDays;
  final double penaltyRate;
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

  final double progressPercent;
  final String currentStatus; // 'DRAFT' | 'COMPLETED'

  const ProcurementOrder({
    this.id,
    this.budgetId,
    this.fiscalYear,
    this.orderType,
    this.procurementNumber,
    this.orderNumber,
    this.projectName,
    this.activityName,
    this.purposeReason,
    this.purposeObjective,
    this.allocatedAmount,
    this.allocatedAmountTh,
    this.usedBudget,
    this.remainingAmount,
    this.ownerName,
    this.ownerPosition,
    this.financeOfficer,
    this.specCreatorName,
    this.specCreatorPosition,
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
    this.marketPriceCheck,
    this.deliveryDocType,
    this.deliveryDocNumber,
    this.currentOrderPrice,
    this.totalPriceTh,
    this.subtotalBeforeVat,
    this.vatRate = 0.07,
    this.vatAmount,
    this.withholdingTaxRate = 0.01,
    this.taxWithholdingAmount,
    this.netPayableAmount,
    this.shippingDays,
    this.penaltyRate = 0.20,
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
    this.progressPercent = 0.0,
    this.currentStatus = 'DRAFT',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'budget_id': budgetId,
        'fiscal_year': fiscalYear,
        'order_type': orderType,
        'procurement_number': procurementNumber,
        'order_number': orderNumber,
        'project_name': projectName,
        'activity_name': activityName,
        'purpose_reason': purposeReason,
        'purpose_objective': purposeObjective,
        'allocated_amount': allocatedAmount,
        'allocated_amount_th': allocatedAmountTh,
        'used_budget': usedBudget,
        'remaining_amount': remainingAmount,
        'owner_name': ownerName,
        'owner_position': ownerPosition,
        'finance_officer': financeOfficer,
        'spec_creator_name': specCreatorName,
        'spec_creator_position': specCreatorPosition,
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
        'market_price_check': marketPriceCheck,
        'delivery_doc_type': deliveryDocType,
        'delivery_doc_number': deliveryDocNumber,
        'current_order_price': currentOrderPrice,
        'total_price_th': totalPriceTh,
        'subtotal_before_vat': subtotalBeforeVat,
        'vat_rate': vatRate,
        'vat_amount': vatAmount,
        'withholding_tax_rate': withholdingTaxRate,
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
        'progress_percent': progressPercent,
        'current_status': currentStatus,
      };

  factory ProcurementOrder.fromMap(Map<String, dynamic> m) => ProcurementOrder(
        id: m['id'] as int?,
        budgetId: m['budget_id'] as int?,
        fiscalYear: m['fiscal_year'] as String?,
        orderType: m['order_type'] as String?,
        procurementNumber: m['procurement_number'] as String?,
        orderNumber: m['order_number'] as String?,
        projectName: m['project_name'] as String?,
        activityName: m['activity_name'] as String?,
        purposeReason: m['purpose_reason'] as String?,
        purposeObjective: m['purpose_objective'] as String?,
        allocatedAmount: (m['allocated_amount'] as num?)?.toDouble(),
        allocatedAmountTh: m['allocated_amount_th'] as String?,
        usedBudget: (m['used_budget'] as num?)?.toDouble(),
        remainingAmount: (m['remaining_amount'] as num?)?.toDouble(),
        ownerName: m['owner_name'] as String?,
        ownerPosition: m['owner_position'] as String?,
        financeOfficer: m['finance_officer'] as String?,
        specCreatorName: m['spec_creator_name'] as String?,
        specCreatorPosition: m['spec_creator_position'] as String?,
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
        marketPriceCheck: m['market_price_check'] as String?,
        deliveryDocType: m['delivery_doc_type'] as String?,
        deliveryDocNumber: m['delivery_doc_number'] as String?,
        currentOrderPrice: (m['current_order_price'] as num?)?.toDouble(),
        totalPriceTh: m['total_price_th'] as String?,
        subtotalBeforeVat: (m['subtotal_before_vat'] as num?)?.toDouble(),
        vatRate: (m['vat_rate'] as num?)?.toDouble() ?? 0.07,
        vatAmount: (m['vat_amount'] as num?)?.toDouble(),
        withholdingTaxRate: (m['withholding_tax_rate'] as num?)?.toDouble() ?? 0.01,
        taxWithholdingAmount: (m['tax_withholding_amount'] as num?)?.toDouble(),
        netPayableAmount: (m['net_payable_amount'] as num?)?.toDouble(),
        shippingDays: m['shipping_days'] as int?,
        penaltyRate: (m['penalty_rate'] as num?)?.toDouble() ?? 0.20,
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
        progressPercent: (m['progress_percent'] as num?)?.toDouble() ?? 0.0,
        currentStatus: m['current_status'] as String? ?? 'DRAFT',
      );

  ProcurementOrder copyWith({
    int? id,
    int? budgetId,
    String? fiscalYear,
    String? orderType,
    String? procurementNumber,
    String? orderNumber,
    String? projectName,
    String? activityName,
    String? purposeReason,
    String? purposeObjective,
    double? allocatedAmount,
    String? allocatedAmountTh,
    double? usedBudget,
    double? remainingAmount,
    String? ownerName,
    String? ownerPosition,
    String? financeOfficer,
    String? specCreatorName,
    String? specCreatorPosition,
    String? procurementOfficer,
    String? procurementHead,
    String? directorName,
    String? inspectorTitleGroup,
    String? inspector1,
    String? inspector1Pos,
    String? inspector2,
    String? inspector2Pos,
    String? inspector3,
    String? inspector3Pos,
    String? vendorName,
    String? vendorOwner,
    String? vendorAddressNo,
    String? vendorSubdistrict,
    String? vendorDistrict,
    String? vendorProvince,
    String? vendorPhone,
    String? vendorTaxId,
    String? marketPriceCheck,
    String? deliveryDocType,
    String? deliveryDocNumber,
    double? currentOrderPrice,
    String? totalPriceTh,
    double? subtotalBeforeVat,
    double? vatRate,
    double? vatAmount,
    double? withholdingTaxRate,
    double? taxWithholdingAmount,
    double? netPayableAmount,
    int? shippingDays,
    double? penaltyRate,
    String? warrantyPeriod,
    String? egpProjectId,
    String? contractControlNumber,
    String? inspectionControlNumber,
    String? dateMemoUsed,
    String? dateOrderCreated,
    String? dateAnnouncement,
    String? dateQuotation,
    String? dateContractSigned,
    String? dateDeadline,
    String? dateShipping,
    String? dateInspection,
    String? dateDisbursement,
    double? progressPercent,
    String? currentStatus,
  }) {
    return ProcurementOrder(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      orderType: orderType ?? this.orderType,
      procurementNumber: procurementNumber ?? this.procurementNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      projectName: projectName ?? this.projectName,
      activityName: activityName ?? this.activityName,
      purposeReason: purposeReason ?? this.purposeReason,
      purposeObjective: purposeObjective ?? this.purposeObjective,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      allocatedAmountTh: allocatedAmountTh ?? this.allocatedAmountTh,
      usedBudget: usedBudget ?? this.usedBudget,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      ownerName: ownerName ?? this.ownerName,
      ownerPosition: ownerPosition ?? this.ownerPosition,
      financeOfficer: financeOfficer ?? this.financeOfficer,
      specCreatorName: specCreatorName ?? this.specCreatorName,
      specCreatorPosition: specCreatorPosition ?? this.specCreatorPosition,
      procurementOfficer: procurementOfficer ?? this.procurementOfficer,
      procurementHead: procurementHead ?? this.procurementHead,
      directorName: directorName ?? this.directorName,
      inspectorTitleGroup: inspectorTitleGroup ?? this.inspectorTitleGroup,
      inspector1: inspector1 ?? this.inspector1,
      inspector1Pos: inspector1Pos ?? this.inspector1Pos,
      inspector2: inspector2 ?? this.inspector2,
      inspector2Pos: inspector2Pos ?? this.inspector2Pos,
      inspector3: inspector3 ?? this.inspector3,
      inspector3Pos: inspector3Pos ?? this.inspector3Pos,
      vendorName: vendorName ?? this.vendorName,
      vendorOwner: vendorOwner ?? this.vendorOwner,
      vendorAddressNo: vendorAddressNo ?? this.vendorAddressNo,
      vendorSubdistrict: vendorSubdistrict ?? this.vendorSubdistrict,
      vendorDistrict: vendorDistrict ?? this.vendorDistrict,
      vendorProvince: vendorProvince ?? this.vendorProvince,
      vendorPhone: vendorPhone ?? this.vendorPhone,
      vendorTaxId: vendorTaxId ?? this.vendorTaxId,
      marketPriceCheck: marketPriceCheck ?? this.marketPriceCheck,
      deliveryDocType: deliveryDocType ?? this.deliveryDocType,
      deliveryDocNumber: deliveryDocNumber ?? this.deliveryDocNumber,
      currentOrderPrice: currentOrderPrice ?? this.currentOrderPrice,
      totalPriceTh: totalPriceTh ?? this.totalPriceTh,
      subtotalBeforeVat: subtotalBeforeVat ?? this.subtotalBeforeVat,
      vatRate: vatRate ?? this.vatRate,
      vatAmount: vatAmount ?? this.vatAmount,
      withholdingTaxRate: withholdingTaxRate ?? this.withholdingTaxRate,
      taxWithholdingAmount: taxWithholdingAmount ?? this.taxWithholdingAmount,
      netPayableAmount: netPayableAmount ?? this.netPayableAmount,
      shippingDays: shippingDays ?? this.shippingDays,
      penaltyRate: penaltyRate ?? this.penaltyRate,
      warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
      egpProjectId: egpProjectId ?? this.egpProjectId,
      contractControlNumber: contractControlNumber ?? this.contractControlNumber,
      inspectionControlNumber: inspectionControlNumber ?? this.inspectionControlNumber,
      dateMemoUsed: dateMemoUsed ?? this.dateMemoUsed,
      dateOrderCreated: dateOrderCreated ?? this.dateOrderCreated,
      dateAnnouncement: dateAnnouncement ?? this.dateAnnouncement,
      dateQuotation: dateQuotation ?? this.dateQuotation,
      dateContractSigned: dateContractSigned ?? this.dateContractSigned,
      dateDeadline: dateDeadline ?? this.dateDeadline,
      dateShipping: dateShipping ?? this.dateShipping,
      dateInspection: dateInspection ?? this.dateInspection,
      dateDisbursement: dateDisbursement ?? this.dateDisbursement,
      progressPercent: progressPercent ?? this.progressPercent,
      currentStatus: currentStatus ?? this.currentStatus,
    );
  }
}