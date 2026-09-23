// staff_appointment_document_service.dart
// พิมพ์คำสั่งแต่งตั้งหัวหน้าเจ้าหน้าที่พัสดุ/เจ้าหน้าที่พัสดุ ประจำปีงบประมาณ
// เป็นไฟล์ Word (.docx) — ใช้ assets/templates/staff_appointment_order_template.docx
// ร่วมกับ DocxTemplateService.processGenericTemplate (clone แถวรายชื่อผู้ได้รับ
// แต่งตั้งได้ตามจำนวนจริง)

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/staff_appointment_order.dart';
import '../models/school_settings.dart';
import '../utils/app_folder_name.dart';
import 'docx_template_service.dart';
import 'feature_access_service.dart';

class StaffAppointmentDocumentService {
  static const String _templateAssetPath =
      'assets/templates/staff_appointment_order_template.docx';

  static Future<File> export({
    required StaffAppointmentOrder order,
    required SchoolSettings school,
  }) async {
    final templateData = await rootBundle.load(_templateAssetPath);
    final templateBytes = templateData.buffer
        .asUint8List(templateData.offsetInBytes, templateData.lengthInBytes);

    final staffRows = [
      for (var i = 0; i < order.staff.length; i++)
        {
          'staff_idx': '${i + 1}',
          'staff_name': order.staff[i].name,
          'staff_position': order.staff[i].position,
          'staff_role': order.staff[i].role,
        },
    ];

    final directorName = school.directorName?.trim().isNotEmpty ?? false
        ? school.directorName!
        : '-';
    final fieldValues = {
      'school_name': school.schoolName ?? '',
      'director_name': directorName,
      'fiscal_year': order.fiscalYear,
      'order_number': order.orderNumber ?? '-',
      'order_date': order.orderDate ?? '-',
      'effective_date': order.effectiveDate ?? '-',
    };

    final docBytes = DocxTemplateService.processGenericTemplate(
      templateBytes: templateBytes,
      fieldValues: fieldValues,
      rowsSeedKey: 'staff_name',
      rows: staffRows,
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName =
        'คำสั่งแต่งตั้งเจ้าหน้าที่พัสดุ_${order.fiscalYear}_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.docx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(docBytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required StaffAppointmentOrder order,
    required SchoolSettings school,
  }) async {
    FeatureAccessService.instance.requireModule(
        FeatureModules.assetManagement, 'แต่งตั้งเจ้าหน้าที่พัสดุ');
    final file = await export(order: order, school: school);
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
