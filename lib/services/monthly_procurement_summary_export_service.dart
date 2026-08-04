// monthly_procurement_summary_export_service.dart
// ส่งออก "แบบสรุปผลการจัดซื้อจัดจ้างรายเดือน" (ตามแบบที่ กวจ./สตง. ใช้ตรวจสอบ) เป็น
// ไฟล์ Excel พิมพ์ได้ — คอลัมน์อ้างอิงจากแบบฟอร์มจริงที่โรงเรียนใช้ส่ง (ลำดับ,
// งานที่จัดซื้อจัดจ้าง, วงเงิน, ราคากลาง, วิธีการจัดซื้อจัดจ้าง, ผู้เสนอราคา,
// ผู้ได้รับคัดเลือก, เหตุผลการคัดเลือก, เลขที่/วันที่สัญญา)
//
// หมายเหตุ: "เหตุผลการคัดเลือก" เติมข้อความมาตรฐาน "ราคาอยู่ในวงเงินงบประมาณ"
// ให้เป็นค่าเริ่มต้นเสมอ (ตรงกับที่โรงเรียนส่วนใหญ่ใช้จริงตามตัวอย่าง) — ผู้ใช้
// แก้ไขข้อความในไฟล์ Excel ที่ได้เองได้ถ้ากรณีนั้นมีเหตุผลอื่น ไม่ใช่การรับรอง
// ว่าถูกต้องตามระเบียบเสมอไป

import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import '../models/procurement_order.dart';
import '../utils/app_folder_name.dart';

class MonthlyProcurementSummaryExportService {
  static Future<File> export({
    required List<ProcurementOrder> orders,
    required String monthLabel,
    required String buddhistYearLabel,
    required String schoolName,
  }) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([xls.TextCellValue('แบบสรุปผลการจัดซื้อจัดจ้าง (รอบเดือน $monthLabel พ.ศ. $buddhistYearLabel)')]);
    sheet.appendRow([xls.TextCellValue(schoolName)]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('ลำดับ'),
      xls.TextCellValue('งานที่จัดซื้อจัดจ้าง'),
      xls.TextCellValue('วงเงินที่จัดซื้อจัดจ้าง (บาท)'),
      xls.TextCellValue('ราคากลาง (บาท)'),
      xls.TextCellValue('วิธีการจัดซื้อจัดจ้าง'),
      xls.TextCellValue('ชื่อผู้เสนอราคาและราคาที่เสนอ (บาท)'),
      xls.TextCellValue('ผู้ได้รับการคัดเลือกและตกลงซื้อหรือจ้าง'),
      xls.TextCellValue('เหตุผลที่คัดเลือก'),
      xls.TextCellValue('เลขที่และวันที่ของสัญญาในการซื้อหรือจ้าง'),
    ]);

    for (var i = 0; i < orders.length; i++) {
      final o = orders[i];
      final subject = (o.procurementSubject?.trim().isNotEmpty ?? false) ? o.procurementSubject! : (o.projectName ?? '-');
      final amount = o.currentOrderPrice ?? o.allocatedAmount ?? 0;
      final vendorAndPrice = '${o.vendorName ?? "-"} / ${amount.toStringAsFixed(2)}';
      final docLabel = o.orderType == 'จ้าง' ? 'ใบสั่งจ้าง' : 'ใบสั่งซื้อ';
      final contractRef = (o.orderNumber?.trim().isNotEmpty ?? false)
          ? '$docLabel เลขที่ ${o.orderNumber} ลงวันที่ ${o.dateContractSigned ?? o.dateOrderCreated ?? "-"}'
          : '-';

      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(subject),
        xls.DoubleCellValue(amount),
        xls.DoubleCellValue(o.allocatedAmount ?? amount),
        xls.TextCellValue(o.procurementMethod ?? '-'),
        xls.TextCellValue(vendorAndPrice),
        xls.TextCellValue(vendorAndPrice),
        xls.TextCellValue('ราคาอยู่ในวงเงินงบประมาณ'),
        xls.TextCellValue(contractRef),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('สร้างไฟล์ Excel ไม่สำเร็จ');

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = Directory('${docsDir.path}/$folderName');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    final stamp = DateTime.now();
    final fileName = 'แบบสรุปผลการจัดซื้อจัดจ้าง_${monthLabel}_$buddhistYearLabel'
        '_${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}${_pad(stamp.hour)}${_pad(stamp.minute)}.xlsx';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> exportAndOpen({
    required List<ProcurementOrder> orders,
    required String monthLabel,
    required String buddhistYearLabel,
    required String schoolName,
  }) async {
    final file = await export(
      orders: orders,
      monthLabel: monthLabel,
      buddhistYearLabel: buddhistYearLabel,
      schoolName: schoolName,
    );
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
      // ไม่ throw ต่อ — ไฟล์สร้างสำเร็จแล้ว แค่เปิดอัตโนมัติไม่ได้
    }
  }
}
