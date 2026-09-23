// annual_inventory_document_service.dart
// พิมพ์ชุดเอกสารตรวจสอบพัสดุประจำปีเป็นไฟล์ Word (.docx) เดียว 4 ส่วนต่อกัน
// (บันทึกขออนุมัติแต่งตั้งกรรมการ -> คำสั่งแต่งตั้งกรรมการ -> บันทึกรายงานผล
// -> บัญชีรายการพัสดุชำรุด/เสื่อมสภาพ/สูญไป) ตามแบบฟอร์มจริงที่โรงเรียนใช้อยู่
// ใช้ assets/templates/annual_inventory_check_template.docx ร่วมกับ
// DocxTemplateService.processMultiRowTemplate ซึ่ง clone ได้ 2 ชุดอิสระใน
// เอกสารเดียว (รายชื่อกรรมการ + รายการพัสดุชำรุด คนละ seedKey กัน)

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/annual_count.dart';
import '../models/fixed_asset.dart';
import '../models/school_settings.dart';
import '../utils/app_folder_name.dart';
import '../utils/thai_numerals.dart';
import 'docx_template_service.dart';
import 'feature_access_service.dart';

class AnnualInventoryDocumentService {
  static const String _templateAssetPath =
      'assets/templates/annual_inventory_check_template.docx';

  static Future<File> export({
    required AnnualCount count,
    required SchoolSettings school,
    List<FixedAsset> fixedAssets = const [],
  }) async {
    final templateData = await rootBundle.load(_templateAssetPath);
    final templateBytes = templateData.buffer
        .asUint8List(templateData.offsetInBytes, templateData.lengthInBytes);

    final memberRows = [
      for (var i = 0; i < count.members.length; i++)
        {
          'idx': '${i + 1}',
          'member_name': count.members[i].name,
          'member_position': count.members[i].position,
          'member_role': count.members[i].role,
        },
    ];

    final damagedRows = [
      for (var i = 0; i < count.damagedItems.length; i++)
        {
          'damaged_seq': '${i + 1}',
          'damaged_item_name': count.damagedItems[i].name,
          'damaged_item_code': count.damagedItems[i].code ?? '-',
          'damaged_item_brand': count.damagedItems[i].brand ?? '-',
          'damaged_item_detail': count.damagedItems[i].damageDetail ?? '-',
          'damaged_item_status':
              count.damagedItems[i].inUse ? 'ยังใช้งาน' : 'ไม่ใช้งาน',
          'damaged_item_date': count.reportDate ?? '-',
          'damaged_check_broken':
              count.damagedItems[i].damageType == 'ชำรุด' ? '✓' : '',
          'damaged_check_worn':
              count.damagedItems[i].damageType == 'เสื่อมสภาพ' ? '✓' : '',
          'damaged_check_lost':
              count.damagedItems[i].damageType == 'สูญไป' ? '✓' : '',
          'damaged_check_inuse': count.damagedItems[i].inUse ? '✓' : '',
          'damaged_check_notinuse': count.damagedItems[i].inUse ? '' : '✓',
          'damaged_item_price': count.damagedItems[i].registeredPrice != null
              ? count.damagedItems[i].registeredPrice!.toStringAsFixed(2)
              : '-',
          'damaged_item_assignee': count.damagedItems[i].assignee ?? '-',
        },
    ];

    final equipment = fixedAssets
        .where((a) => a.assetCategory != 'ที่ดินและสิ่งก่อสร้าง')
        .toList();
    final landAssets = fixedAssets
        .where((a) => a.assetCategory == 'ที่ดินและสิ่งก่อสร้าง')
        .toList();
    final goodAssets =
        equipment.where((a) => a.status == 'ใช้งานปกติ').toList();
    final badAssets = equipment.where((a) => a.status != 'ใช้งานปกติ').toList();
    final assetGoodRows = [
      for (var i = 0; i < goodAssets.length; i++)
        {
          'asset_good_seq': '${i + 1}',
          'asset_good_name': goodAssets[i].name,
          'asset_good_number': goodAssets[i].assetNumber ?? '-',
          'asset_good_qty':
              toArabicDigits(goodAssets[i].quantity.toStringAsFixed(0)),
          'asset_good_amount': goodAssets[i].totalValue.toStringAsFixed(2),
          'asset_good_date': goodAssets[i].acquiredDate ?? '-',
          'asset_good_method': goodAssets[i].procurementMethod ?? '-',
        },
    ];
    final assetGoodTotal =
        goodAssets.fold<double>(0, (sum, a) => sum + a.totalValue);
    final assetBadRows = [
      for (var i = 0; i < badAssets.length; i++)
        {
          'asset_bad_seq': '${i + 1}',
          'asset_bad_name': badAssets[i].name,
          'asset_bad_number': badAssets[i].assetNumber ?? '-',
          'asset_bad_qty':
              toArabicDigits(badAssets[i].quantity.toStringAsFixed(0)),
          'asset_bad_amount': badAssets[i].totalValue.toStringAsFixed(2),
          'asset_bad_date': badAssets[i].acquiredDate ?? '-',
          'asset_bad_method': badAssets[i].procurementMethod ?? '-',
        },
    ];
    final assetLandRows = [
      for (var i = 0; i < landAssets.length; i++)
        {
          'asset_land_seq': '${i + 1}',
          'asset_land_name': landAssets[i].name,
          'asset_land_number': landAssets[i].assetNumber ?? '-',
          'asset_land_qty':
              toArabicDigits(landAssets[i].quantity.toStringAsFixed(0)),
          'asset_land_amount': landAssets[i].totalValue.toStringAsFixed(2),
          'asset_land_date': landAssets[i].acquiredDate ?? '-',
          'asset_land_method': landAssets[i].procurementMethod ?? '-',
          'asset_land_note': landAssets[i].status,
        },
    ];
    final assetLandTotal =
        landAssets.fold<double>(0, (sum, a) => sum + a.totalValue);

    final directorName = school.directorName?.trim().isNotEmpty ?? false
        ? school.directorName!
        : '-';
    final members = count.members;
    String memberField(int idx, String Function(AnnualCountMember m) pick) =>
        idx < members.length ? pick(members[idx]) : '-';
    final fieldValues = {
      'department_name':
          (school.educationServiceArea?.trim().isNotEmpty ?? false)
              ? school.educationServiceArea!
              : (school.schoolName ?? ''),
      'school_name': school.schoolName ?? '',
      'school_subdistrict': school.schoolSubdistrict ?? '',
      'school_amphoe': school.schoolAmphoe ?? '',
      'school_changwat': school.schoolChangwat ?? '',
      'education_service_area':
          (school.educationServiceArea?.trim().isNotEmpty ?? false)
              ? school.educationServiceArea!
              : '-',
      'director_name': directorName,
      'procurement_officer':
          school.procurementOfficer?.trim().isNotEmpty ?? false
              ? school.procurementOfficer!
              : directorName,
      'fiscal_year': count.fiscalYear,
      'memo_number': count.memoNumber ?? '-',
      'memo_date': count.memoDate ?? '-',
      'order_number': count.orderNumber ?? '-',
      'order_date': count.orderDate ?? '-',
      'report_number': count.reportNumber ?? '-',
      'report_date': count.reportDate ?? '-',
      'transmittal_district_number': count.transmittalDistrictNumber ?? '-',
      'transmittal_district_date': count.transmittalDistrictDate ?? '-',
      'transmittal_audit_number': count.transmittalAuditNumber ?? '-',
      'transmittal_audit_date': count.transmittalAuditDate ?? '-',
      'asset_good_total': assetGoodTotal.toStringAsFixed(2),
      'asset_land_total': assetLandTotal.toStringAsFixed(2),
      'member1_name': memberField(0, (m) => m.name),
      'member1_role': memberField(0, (m) => m.role),
      'member2_name': memberField(1, (m) => m.name),
      'member2_role': memberField(1, (m) => m.role),
      'member3_name': memberField(2, (m) => m.name),
      'member3_role': memberField(2, (m) => m.role),
    };

    final hasDamaged = count.damagedItems.isNotEmpty;
    final docBytes = DocxTemplateService.processMultiRowTemplate(
      templateBytes: templateBytes,
      fieldValues: fieldValues,
      rowGroups: [
        RowCloneSpec(seedKey: 'member_name', rows: memberRows),
        RowCloneSpec(seedKey: 'damaged_item_name', rows: damagedRows),
        RowCloneSpec(seedKey: 'asset_good_name', rows: assetGoodRows),
        RowCloneSpec(seedKey: 'asset_bad_name', rows: assetBadRows),
        RowCloneSpec(seedKey: 'asset_land_name', rows: assetLandRows),
      ],
      conditionalFlags: {'has_damaged': hasDamaged, 'no_damaged': !hasDamaged},
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName =
        'ตรวจสอบพัสดุประจำปี_${count.fiscalYear}_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.docx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(docBytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required AnnualCount count,
    required SchoolSettings school,
    List<FixedAsset> fixedAssets = const [],
  }) async {
    FeatureAccessService.instance
        .requireModule(FeatureModules.assetManagement, 'ตรวจนับพัสดุประจำปี');
    final file =
        await export(count: count, school: school, fixedAssets: fixedAssets);
    await _openFile(file.path);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Future<void> _openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // เปิดไฟล์อัตโนมัติไม่สำเร็จ — ไฟล์ยังถูกสร้างไว้แล้ว ผู้ใช้เปิดเองได้
    }
  }
}
