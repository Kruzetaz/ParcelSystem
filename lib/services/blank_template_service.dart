// blank_template_service.dart
// ให้ผู้ใช้คัดลอกไฟล์ "แบบฟอร์มเปล่า" (.docx/.pdf) จาก assets/templates ออกมา
// เป็นไฟล์จริงเพื่อกรอกเองด้วยมือ — ต่างจาก DocumentGenerator ตรงที่ไม่มีการ
// แทนที่ {{placeholder}} ใดๆ เลย เอาไว้ใช้กับแบบฟอร์มที่ไม่ได้ผูกกับข้อมูล order
// ในระบบ (เช่น แบบแจ้งข้อมูลรับเงินโอนของธนาคาร)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../utils/app_folder_name.dart';

enum BlankTemplateKind { ktbCorporateOnline }

enum BlankTemplateFormat {
  docx('.docx'),
  pdf('.pdf');

  const BlankTemplateFormat(this.extension);
  final String extension;
}

class BlankTemplateInfo {
  final BlankTemplateKind kind;
  final String title;
  final String subtitle;
  final String fileName;

  /// path ของไฟล์ asset แยกตามฟอร์แมต เช่น {docx: 'assets/templates/xxx.docx', pdf: 'assets/templates/xxx.pdf'}
  final Map<BlankTemplateFormat, String> assetPaths;

  const BlankTemplateInfo({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.assetPaths,
  });
}

const blankTemplates = [
  BlankTemplateInfo(
    kind: BlankTemplateKind.ktbCorporateOnline,
    title: 'แบบแจ้งข้อมูลรับเงินโอน (KTB Corporate Online)',
    subtitle: 'แบบฟอร์มเปล่าสำหรับกรอกด้วยตนเอง',
    fileName: 'แบบแจ้งข้อมูลการรับเงินโอนผ่านระบบKTBCorporate Online',
    assetPaths: {
      BlankTemplateFormat.docx: 'assets/templates/ktb_corporate_online_form.docx',
      BlankTemplateFormat.pdf: 'assets/templates/ktb_corporate_online_form.pdf',
    },
  ),
];

class BlankTemplateException implements Exception {
  final String message;
  BlankTemplateException(this.message);
  @override
  String toString() => 'BlankTemplateException: $message';
}

class BlankTemplateService {
  /// คัดลอกไฟล์เทมเพลตเปล่าไปไว้ที่โฟลเดอร์เอกสารของโรงเรียน (กันชื่อซ้ำแบบ
  /// เดียวกับ DocxTemplateService.saveOutput) แล้วเปิดด้วยโปรแกรมเริ่มต้นของระบบ
  static Future<File> exportAndOpen(BlankTemplateInfo info, BlankTemplateFormat format) async {
    final assetPath = info.assetPaths[format];
    if (assetPath == null) {
      throw BlankTemplateException('แบบฟอร์มนี้ไม่มีไฟล์รูปแบบ ${format.extension}');
    }

    late final ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } catch (e) {
      throw BlankTemplateException(
        'ไม่พบไฟล์เทมเพลตที่ $assetPath\nรายละเอียด: $e',
      );
    }
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final docsDir = await getApplicationDocumentsDirectory();
    final folderName = await getSchoolDocumentsFolderName();
    final outputDir = '${docsDir.path}/$folderName';
    await Directory(outputDir).create(recursive: true);

    var candidate = File('$outputDir/${info.fileName}${format.extension}');
    var counter = 1;
    while (await candidate.exists()) {
      candidate = File('$outputDir/${info.fileName} ($counter)${format.extension}');
      counter++;
    }
    await candidate.writeAsBytes(bytes, flush: true);

    await _openFile(candidate.path);
    return candidate;
  }

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
      // ไม่ throw ต่อ — ไฟล์คัดลอกสำเร็จแล้ว แค่เปิดอัตโนมัติไม่ได้
    }
  }
}
