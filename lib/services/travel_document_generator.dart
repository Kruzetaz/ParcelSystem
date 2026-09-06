// travel_document_generator.dart
//
// ตัวเชื่อมระหว่าง UI (travel_reimbursement_wizard_screen.dart) กับ
// docx_template_service.dart สำหรับโมดูล "เบิกจ่ายค่าใช้จ่ายเดินทางไปราชการ
// (แบบ ๘๗๐๘)" — สร้างเอกสาร 3 ใบจากข้อมูลชุดเดียวกัน:
//   1. บันทึกข้อความขออนุมัติเบิกจ่าย (travel_memo_template.docx)
//   2. ใบเบิกค่าใช้จ่ายในการเดินทางไปราชการ ส่วนที่ 1 (travel_form8708_part1_template.docx)
//   3. หลักฐานการจ่ายเงิน ส่วนที่ 2 (travel_form8708_part2_template.docx — มีตาราง
//      loop รายชื่อผู้เดินทาง ผ่าน participantRows/{{participant_name}} เหมือนที่
//      DocxTemplateService ใช้ clone แถวรายการพัสดุอยู่แล้ว)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/travel_reimbursement.dart';
import '../models/travel_participant.dart';
import '../models/personnel.dart';
import '../models/school_settings.dart';
import '../utils/app_folder_name.dart';
import '../utils/calc_engine.dart';
import '../utils/thai_date.dart';
import 'docx_template_service.dart';

class TravelDocumentGeneratorException implements Exception {
  final String message;
  TravelDocumentGeneratorException(this.message);
  @override
  String toString() => 'TravelDocumentGeneratorException: $message';
}

enum TravelDocumentType { memo, form1, form2 }

class TravelDocumentGenerator {
  static const Map<TravelDocumentType, String> _templateAssetPaths = {
    TravelDocumentType.memo: 'assets/templates/travel_memo_template.docx',
    TravelDocumentType.form1: 'assets/templates/travel_form8708_part1_template.docx',
    TravelDocumentType.form2: 'assets/templates/travel_form8708_part2_template.docx',
  };

  static const Map<TravelDocumentType, String> _outputLabels = {
    TravelDocumentType.memo: 'บันทึกข้อความขออนุมัติเบิกค่าใช้จ่ายเดินทาง',
    TravelDocumentType.form1: 'ใบเบิกค่าใช้จ่ายเดินทาง ส่วนที่ 1',
    TravelDocumentType.form2: 'หลักฐานการจ่ายเงิน ส่วนที่ 2',
  };

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'en_US');

  static String _money(double? v) => _moneyFmt.format(v ?? 0);
  static String _str(String? v) => v ?? '';

  /// ยอดรวมแต่ละประเภทค่าใช้จ่าย รวมจากผู้เดินทางทุกคน
  static double _sumAllowance(List<TravelParticipant> p) =>
      p.fold(0, (sum, x) => sum + x.allowanceAmount);
  static double _sumAccommodation(List<TravelParticipant> p) =>
      p.fold(0, (sum, x) => sum + x.accommodationAmount);
  static double _sumTransport(List<TravelParticipant> p) =>
      p.fold(0, (sum, x) => sum + x.transportAmount);
  static double _sumRegistration(List<TravelParticipant> p) =>
      p.fold(0, (sum, x) => sum + x.registrationFee);
  static double sumTotal(List<TravelParticipant> p) =>
      _sumAllowance(p) + _sumAccommodation(p) + _sumTransport(p) + _sumRegistration(p);

  static Map<String, bool> buildConditionalFlags(TravelReimbursement r) => {
        'has_advance_payer': r.isAdvancePayer,
        'not_advance_payer': !r.isAdvancePayer,
        'departs_from_home': r.departsFromHome,
        'departs_from_office': !r.departsFromHome,
      };

  static Map<String, String> buildFieldMap(
    TravelReimbursement r,
    List<TravelParticipant> participants,
    SchoolSettings school, {
    Personnel? payee,
    Personnel? checker,
  }) {
    final totalAllowance = _sumAllowance(participants);
    final totalAccommodation = _sumAccommodation(participants);
    final totalTransport = _sumTransport(participants);
    final totalRegistration = _sumRegistration(participants);
    final total = totalAllowance + totalAccommodation + totalTransport + totalRegistration;

    // ผู้รับเงิน = ผู้สำรองจ่าย (ถ้ามี) — ไม่งั้นเป็นผู้เดินทางคนแรกในลิสต์
    final payeeName = payee?.name ?? (participants.isNotEmpty ? participants.first.participantName : '');
    final payeePosition = payee?.position ?? (participants.isNotEmpty ? participants.first.position : null);

    return {
      'school_name': _str(school.schoolName),
      'school_changwat': _str(school.schoolChangwat),
      'director_name': _str(school.directorName),
      'finance_officer': _str(school.financeOfficer),
      'document_number': _str(r.documentNumber),
      // บันทึกข้อความ/ใบเบิกฯ กรอกหลังเดินทางกลับเสร็จเรียบร้อยแล้วเสมอ —
      // ใช้วันที่สิ้นสุดการเดินทางเป็นวันที่เอกสารแทน ไม่มีช่องกรอกแยกต่างหาก
      'date_memo': _str(r.endDate),
      'date_form1': _str(r.endDate),
      'trip_subject': _str(r.subject),
      'trip_destination': _str(r.destination),
      'date_travel_start': _str(r.startDate),
      'date_travel_end': _str(r.endDate),
      'travel_days_count': _travelDaysCount(r).toString(),
      'participant_count': participants.length.toString(),
      'payee_name': _str(payeeName),
      'payee_position': _str(payeePosition),
      'checker_name': _str(checker?.name),
      'checker_position': _str(checker?.position),
      'total_allowance': _money(totalAllowance),
      'total_accommodation': _money(totalAccommodation),
      'total_transport': _money(totalTransport),
      'total_registration': _money(totalRegistration),
      'total_amount': _money(total),
      'total_amount_th': CalcEngine.bahtText(total),
      // "ประเภท" (อัตรา/หลักเกณฑ์การเบิก) ต่อหมวด — แบบ ๘๗๐๘ ส่วนที่ 1 จริง
      // แยกโชว์เป็นข้อความอธิบายอัตรา ไม่ใช่ตัวเลข ผูกกับใบเบิกทั้งใบ (ไม่ใช่
      // รายบุคคล) จำนวนวันที่เบิกเบี้ยเลี้ยง/ที่พัก ใช้จำนวนวันเดินทางรวมเดียวกัน
      'allowance_type': _str(r.allowanceType),
      'accommodation_type': _str(r.accommodationType),
      'transport_type': _str(r.transportType),
      'other_expense_type': _str(r.otherExpenseType),
    };
  }

  static int _travelDaysCount(TravelReimbursement r) {
    // วันที่เก็บเป็นข้อความไทย "{วัน} {เดือนไทยเต็ม} {ปี พ.ศ.}" เหมือนช่อง
    // วันที่อื่นๆ ทั่วทั้งแอป (ดู lib/utils/thai_date.dart)
    final start = parseThaiDate(r.startDate);
    final end = parseThaiDate(r.endDate);
    if (start == null || end == null) return 1;
    return end.difference(start).inDays + 1;
  }

  /// แถวตารางผู้เดินทาง (สำหรับ form2 — {{participant_name}} เป็น seed key)
  static List<Map<String, String>> buildParticipantRows(List<TravelParticipant> participants) {
    return [
      for (var i = 0; i < participants.length; i++)
        {
          'participant_idx': (i + 1).toString(),
          'participant_name': participants[i].participantName,
          'participant_position': _str(participants[i].position),
          'participant_allowance': _money(participants[i].allowanceAmount),
          'participant_accommodation': _money(participants[i].accommodationAmount),
          'participant_transport': _money(participants[i].transportAmount),
          'participant_other': _money(participants[i].registrationFee),
          'participant_subtotal': _money(participants[i].subtotal),
        },
    ];
  }

  static Future<Uint8List> _generateBytes(
    TravelDocumentType type,
    TravelReimbursement r,
    List<TravelParticipant> participants,
    SchoolSettings school, {
    Personnel? payee,
    Personnel? checker,
  }) async {
    final assetPath = _templateAssetPaths[type]!;
    late final ByteData templateData;
    try {
      templateData = await rootBundle.load(assetPath);
    } catch (e) {
      throw TravelDocumentGeneratorException(
        'ไม่พบไฟล์เทมเพลตที่ $assetPath\nรายละเอียด: $e',
      );
    }
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );

    return DocxTemplateService.processTemplate(
      templateBytes: templateBytes,
      fieldValues: buildFieldMap(r, participants, school, payee: payee, checker: checker),
      items: const [],
      conditionalFlags: buildConditionalFlags(r),
      participantRows: buildParticipantRows(participants),
    );
  }

  static Future<File> _saveDoc(
    TravelDocumentType type,
    Uint8List bytes,
    TravelReimbursement r,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = '${docsDir.path}/$folderName';
    return DocxTemplateService.saveOutput(
      docxBytes: bytes,
      outputDir: outputDir,
      procurementNumber: r.documentNumber ?? 'ไม่ระบุเลขที่',
      projectName: _outputLabels[type]!,
    );
  }

  /// สร้างเอกสารทั้ง 3 ใบพร้อมกัน คืนค่าเป็น List<File> ตามลำดับ
  /// [memo, form1, form2]
  static Future<List<File>> generateAll({
    required TravelReimbursement reimbursement,
    required List<TravelParticipant> participants,
    required SchoolSettings school,
    Personnel? payee,
    Personnel? checker,
  }) async {
    final files = <File>[];
    for (final type in TravelDocumentType.values) {
      final bytes = await _generateBytes(
        type,
        reimbursement,
        participants,
        school,
        payee: payee,
        checker: checker,
      );
      files.add(await _saveDoc(type, bytes, reimbursement));
    }
    return files;
  }

  static Future<void> openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      // ไม่ throw ต่อ — ไฟล์สร้างสำเร็จแล้ว แค่เปิดอัตโนมัติไม่ได้
    }
  }
}
