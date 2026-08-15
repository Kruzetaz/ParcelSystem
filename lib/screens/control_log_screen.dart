// control_log_screen.dart
// "ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR" — รวมเลขที่ควบคุมที่มีอยู่แล้ว
// กระจายอยู่หลายหน้า (รายงานขอซื้อ/จ้าง, ใบสั่งซื้อ/สั่งจ้าง, TOR, สัญญา,
// ใบตรวจรับพัสดุ) มาแสดงเป็นทะเบียนเดียว เรียงตามวันที่ กรองตามปีงบประมาณได้
// ไม่ใช่ตารางแยก — ดึงจากข้อมูลที่บันทึกไว้แล้วในหน้าต่างๆ โดยตรง

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/control_log_entry.dart';
import '../models/school_settings.dart';
import '../services/control_log_export_service.dart';
import '../services/document_generator.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../utils/thai_date.dart';
import '../widgets/guide_panel.dart';
import '../widgets/column_visibility_menu.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/data_table_shell.dart' show DsActionIconButtons, DsRowAction;

/// คอลัมน์ที่ซ่อน/แสดงได้ — "ที่" กับ "ชื่อรายการ" แสดงเสมอ ไม่อยู่ในนี้
const _controlLogOptionalColumns = [
  'เลขที่บันทึก/คำสั่ง',
  'ประเภทงาน',
  'วันที่บันทึก',
  'วงเงิน',
  'หน่วยงาน/กลุ่มงาน',
  'ผู้รับผิดชอบหลัก',
];

class ControlLogScreen extends StatefulWidget {
  // ปุ่มลัด "สร้างเอกสาร" ในแต่ละแถว — พาไปหน้ารวมศูนย์เอกสารพร้อมเลือกรายการ
  // อ้างอิง (orderId) ของแถวนั้นไว้ล่วงหน้า
  final void Function(int orderId) onGenerateDocument;

  const ControlLogScreen({super.key, required this.onGenerateDocument});
  @override
  State<ControlLogScreen> createState() => _ControlLogScreenState();
}

class _ControlLogScreenState extends State<ControlLogScreen> {
  final _repo = ProcurementRepository();
  List<ControlLogEntry> _entries = [];
  SchoolSettings? _school;
  bool _loading = true;
  bool _exporting = false;
  String? _fiscalYearFilter;
  String? _docTypeFilter;
  Set<String> _visibleColumns = _controlLogOptionalColumns.toSet();
  final _scrollCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();
  // กันกดปุ่ม "ดูตัวอย่าง" ซ้ำตอนกำลังสร้างไฟล์อยู่ — ใช้เลขที่ควบคุมของแถว
  // เป็น key เพราะแถวไม่มี id ของตัวเอง (เป็น view model รวมจากหลายตาราง)
  String? _previewingKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _vScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repo.getControlLogEntries();
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _school = school;
      _loading = false;
    });
  }

  /// ปุ่มลัด "ดูตัวอย่าง" — สร้างเอกสารหลักของรายการอ้างอิงแล้วเปิดด้วย Word ทันที
  Future<void> _previewEntry(ControlLogEntry e) async {
    if (e.orderId == null) return;
    final school = _school;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    setState(() => _previewingKey = e.controlNumber);
    try {
      final order = await _repo.getOrder(e.orderId!);
      if (order == null) {
        showAppToast('ไม่พบรายการอ้างอิงนี้แล้ว (อาจถูกลบไปแล้ว)', isError: true);
        return;
      }
      final items = await _repo.getItems(order.id!);
      await DocumentGenerator.generateAndOpen(order: order, school: school, items: items);
      if (!mounted) return;
      showAppToast('เปิดตัวอย่างเอกสารแล้ว');
    } catch (err) {
      if (!mounted) return;
      showAppToast('สร้างตัวอย่างเอกสารไม่สำเร็จ: $err', isError: true);
    } finally {
      if (mounted) setState(() => _previewingKey = null);
    }
  }

  List<String> get _fiscalYears =>
      _entries.map((e) => e.fiscalYear).toSet().toList()..sort();

  List<String> get _docTypes =>
      _entries.map((e) => e.docType).toSet().toList()..sort();

  List<ControlLogEntry> get _filtered => _entries.where((e) {
        if (_fiscalYearFilter != null && e.fiscalYear != _fiscalYearFilter) return false;
        if (_docTypeFilter != null && e.docType != _docTypeFilter) return false;
        return true;
      }).toList();

  Future<void> _exportToExcel() async {
    setState(() => _exporting = true);
    try {
      await ControlLogExportService.exportAndOpen(_filtered);
      if (!mounted) return;
      showAppToast('ส่งออก Excel สำเร็จ กำลังเปิดไฟล์...');
    } catch (e) {
      if (!mounted) return;
      showAppToast('ส่งออกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR',
      icon: Icons.receipt_long_outlined,
      corner: Alignment.bottomRight,
      steps: const [
        'หน้านี้รวบรวมเลขที่ควบคุมที่มีอยู่แล้วในระบบมาแสดงในที่เดียว: เลขที่รายงานขอซื้อ/จ้าง, เลขที่ใบสั่งซื้อ/สั่งจ้าง, เลขที่เอกสาร TOR, เลขที่สัญญา, และเลขที่ใบตรวจรับพัสดุ',
        'ไม่ต้องกรอกซ้ำ — แค่กรอกเลขที่ไว้ในหน้าเดิมของแต่ละเอกสาร (Tab 1 ของ wizard, หน้า TOR, หน้าสัญญา, หน้าตรวจรับ) แล้วมันจะมารวมกันที่นี่เอง',
        'กรองตามปีงบประมาณ หรือประเภทงานได้ที่มุมขวาบน แล้วกด "ส่งออก Excel" เพื่อพิมพ์ทะเบียนคุมเป็นไฟล์',
        'ถ้าแถวไหนไม่มีวันที่หรือวงเงิน แปลว่ายังไม่ได้กรอกวันที่/วงเงินนั้นในหน้าเอกสารต้นทาง',
      ],
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: BrandAccent.tealOn(context), size: 22),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text('ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR',
                            style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading2, color: colors.onSurface),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _docTypeFilter,
                            isDense: true,
                            isExpanded: true,
                            style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'ประเภทงาน (ทั้งหมด)',
                              hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RadiusSize.md),
                                borderSide: BorderSide(color: colors.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RadiusSize.md),
                                borderSide: BorderSide(color: colors.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RadiusSize.md),
                                borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(RadiusSize.md),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('ประเภทงาน (ทั้งหมด)', overflow: TextOverflow.ellipsis)),
                              ..._docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _docTypeFilter = v),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _fiscalYearFilter,
                            isDense: true,
                            isExpanded: true,
                            style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurface),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'ปีงบ (ทั้งหมด)',
                              hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RadiusSize.md),
                                borderSide: BorderSide(color: colors.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RadiusSize.md),
                                borderSide: BorderSide(color: colors.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(RadiusSize.md),
                                borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(RadiusSize.md),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('ปีงบ (ทั้งหมด)', overflow: TextOverflow.ellipsis)),
                              ..._fiscalYears.map((y) => DropdownMenuItem(value: y, child: Text('ปี $y', overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _fiscalYearFilter = v),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _entries.isEmpty || _exporting ? null : _exportToExcel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                          icon: _exporting
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurfaceVariant))
                              : const Icon(Icons.file_download_outlined, size: 18),
                          label: Text(_exporting ? 'กำลังส่งออก...' : 'ส่งออก Excel'),
                        ),
                        Container(width: 1, height: 28, color: colors.outlineVariant),
                        ColumnVisibilityMenu(
                          allColumns: _controlLogOptionalColumns,
                          visibleColumns: _visibleColumns,
                          onChanged: (v) => setState(() => _visibleColumns = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 64, color: colors.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text(
                                        _entries.isEmpty
                                            ? 'ยังไม่มีเลขที่ควบคุมในระบบ\nกรอกเลขที่เอกสารในหน้า TOR/สัญญา/ตรวจรับ/wizard ก่อน'
                                            : 'ไม่พบรายการที่ตรงกับตัวกรอง',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.heading4),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildTable(colors),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(ColorScheme colors) {
    final headerStyle = TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant);
    // แนวนอนเป็นชั้นนอกสุด (ความสูงยึดตาม Expanded ของหน้า — bounded) แนวตั้ง
    // สกอลล์เฉพาะแถวข้อมูลอยู่ชั้นในสุด (หัวตารางเลยลอยนิ่งไม่เลื่อนตามไปด้วย)
    // — เดิมห่อด้วย SingleChildScrollView แนวตั้งชั้นนอกสุดก่อนเสมอ ทำให้ตาราง
    // สูงเท่าที่ต้องการ (ไม่ bounded) ผลคือแถบเลื่อนแนวนอนไปโผล่ที่ก้นตาราง
    // จริงๆ ซึ่งอาจอยู่ไกลเกินจอ ต้องเลื่อนหน้าลงสุดก่อนถึงจะเห็น/ลากได้
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1408,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: BrandAccent.surface2(context), border: Border(bottom: BorderSide(color: colors.outline))),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text('ที่', style: headerStyle)),
                      const SizedBox(width: 8),
                      if (_visibleColumns.contains('เลขที่บันทึก/คำสั่ง')) ...[
                        SizedBox(width: 110, child: Text('เลขที่บันทึก/คำสั่ง', style: headerStyle)),
                        const SizedBox(width: 8),
                      ],
                      if (_visibleColumns.contains('ประเภทงาน')) ...[
                        SizedBox(width: 160, child: Text('ประเภทงาน', style: headerStyle)),
                        const SizedBox(width: 8),
                      ],
                      if (_visibleColumns.contains('วันที่บันทึก')) ...[
                        SizedBox(width: 110, child: Text('วันที่บันทึก', style: headerStyle)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text('ชื่อรายการ/บันทึกข้อความ', style: headerStyle)),
                      if (_visibleColumns.contains('วงเงิน')) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 110, child: Text('วงเงิน', style: headerStyle, textAlign: TextAlign.right)),
                        if (_visibleColumns.contains('หน่วยงาน/กลุ่มงาน') || _visibleColumns.contains('ผู้รับผิดชอบหลัก')) ...[
                          const SizedBox(width: 10),
                          Container(width: 1, height: 16, color: colors.outlineVariant),
                          const SizedBox(width: 2),
                        ],
                      ],
                      if (_visibleColumns.contains('หน่วยงาน/กลุ่มงาน')) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 150, child: Text('หน่วยงาน/กลุ่มงาน', style: headerStyle)),
                      ],
                      if (_visibleColumns.contains('ผู้รับผิดชอบหลัก')) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 140, child: Text('ผู้รับผิดชอบหลัก', style: headerStyle)),
                      ],
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: Text('จัดการ', style: headerStyle)),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vScrollCtrl,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _vScrollCtrl,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildRow(colors, i, _filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, int index, ControlLogEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('${index + 1}', style: TextStyle(fontSize: AppTypography.bodyMedium))),
          const SizedBox(width: 8),
          if (_visibleColumns.contains('เลขที่บันทึก/คำสั่ง')) ...[
            SizedBox(width: 110, child: Text(e.controlNumber, style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightSemiBold))),
            const SizedBox(width: 8),
          ],
          if (_visibleColumns.contains('ประเภทงาน')) ...[
            SizedBox(width: 160, child: Text(e.docType, style: TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
          ],
          if (_visibleColumns.contains('วันที่บันทึก')) ...[
            SizedBox(width: 110, child: Text(e.dateText != null ? formatThaiDateShort(e.dateText) : '-', style: TextStyle(fontSize: AppTypography.bodyMedium))),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(e.description, style: TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (_visibleColumns.contains('วงเงิน')) ...[
            const SizedBox(width: 8),
            SizedBox(width: 110, child: Text(e.amount != null ? formatBaht(e.amount!) : '-', textAlign: TextAlign.right, style: TextStyle(fontSize: AppTypography.bodyMedium))),
            if (_visibleColumns.contains('หน่วยงาน/กลุ่มงาน') || _visibleColumns.contains('ผู้รับผิดชอบหลัก')) ...[
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: colors.outlineVariant),
              const SizedBox(width: 2),
            ],
          ],
          if (_visibleColumns.contains('หน่วยงาน/กลุ่มงาน')) ...[
            const SizedBox(width: 8),
            SizedBox(width: 150, child: Text(e.department ?? '-', style: TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          if (_visibleColumns.contains('ผู้รับผิดชอบหลัก')) ...[
            const SizedBox(width: 8),
            SizedBox(width: 140, child: Text(e.responsiblePerson ?? '-', style: TextStyle(fontSize: AppTypography.bodyMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          const SizedBox(width: 8),
          // ปุ่มลัด "ดูตัวอย่าง"/"สร้างเอกสาร" — ใช้ได้เฉพาะแถวที่ผูกกับรายการ
          // จัดซื้อจัดจ้างจริง (orderId) เท่านั้น ไม่มีปุ่มลบเพราะแถวนี้ไม่ใช่
          // ข้อมูลของตัวเอง เป็นแค่มุมมองรวมจากหน้าต้นทาง ต้องไปลบที่ต้นทาง
          SizedBox(
            width: 80,
            child: e.orderId == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _previewingKey == e.controlNumber
                          ? Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 3),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(RadiusSize.sm),
                                border: Border.all(color: colors.outline),
                              ),
                              child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : DsActionIconButtons(
                              actions: [
                                DsRowAction(icon: Icons.visibility_outlined, tooltip: 'ดูตัวอย่างเอกสาร', onTap: () => _previewEntry(e)),
                              ],
                            ),
                      DsActionIconButtons(
                        actions: [
                          DsRowAction(icon: Icons.description_outlined, tooltip: 'สร้างเอกสาร', onTap: () => widget.onGenerateDocument(e.orderId!)),
                        ],
                      ),
                    ],
                  ),
                  ),
          ),
        ],
      ),
    );
  }
}
