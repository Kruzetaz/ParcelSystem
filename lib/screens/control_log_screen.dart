// control_log_screen.dart
// "ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR" — รวมเลขที่ควบคุมที่มีอยู่แล้ว
// กระจายอยู่หลายหน้า (รายงานขอซื้อ/จ้าง, ใบสั่งซื้อ/สั่งจ้าง, TOR, สัญญา,
// ใบตรวจรับพัสดุ) มาแสดงเป็นทะเบียนเดียว เรียงตามวันที่ กรองตามปีงบประมาณได้
// ไม่ใช่ตารางแยก — ดึงจากข้อมูลที่บันทึกไว้แล้วในหน้าต่างๆ โดยตรง

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/control_log_entry.dart';
import '../services/control_log_export_service.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../widgets/column_visibility_menu.dart';

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
  const ControlLogScreen({super.key});
  @override
  State<ControlLogScreen> createState() => _ControlLogScreenState();
}

class _ControlLogScreenState extends State<ControlLogScreen> {
  final _repo = ProcurementRepository();
  List<ControlLogEntry> _entries = [];
  bool _loading = true;
  bool _exporting = false;
  String? _fiscalYearFilter;
  String? _docTypeFilter;
  Set<String> _visibleColumns = _controlLogOptionalColumns.toSet();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repo.getControlLogEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
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
                    Text('ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colors.primary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ColumnVisibilityMenu(
                          allColumns: _controlLogOptionalColumns,
                          visibleColumns: _visibleColumns,
                          onChanged: (v) => setState(() => _visibleColumns = v),
                        ),
                        OutlinedButton.icon(
                          onPressed: _entries.isEmpty || _exporting ? null : _exportToExcel,
                          icon: _exporting
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                              : const Icon(Icons.file_download_outlined),
                          label: Text(_exporting ? 'กำลังส่งออก...' : 'ส่งออก Excel'),
                        ),
                        SizedBox(
                          width: 175,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _docTypeFilter,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(isDense: true, hintText: 'ประเภทงาน (ทั้งหมด)'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('ประเภทงาน (ทั้งหมด)', overflow: TextOverflow.ellipsis)),
                              ..._docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _docTypeFilter = v),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _fiscalYearFilter,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(isDense: true, hintText: 'ปีงบ (ทั้งหมด)'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('ปีงบ (ทั้งหมด)', overflow: TextOverflow.ellipsis)),
                              ..._fiscalYears.map((y) => DropdownMenuItem(value: y, child: Text('ปี $y', overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _fiscalYearFilter = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    _entries.isEmpty
                                        ? 'ยังไม่มีเลขที่ควบคุมในระบบ\nกรอกเลขที่เอกสารในหน้า TOR/สัญญา/ตรวจรับ/wizard ก่อน'
                                        : 'ไม่พบรายการที่ตรงกับตัวกรอง',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
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
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.onSurfaceVariant);
    // ห่อด้วย SingleChildScrollView แนวตั้งชั้นนอกก่อนเสมอ — ตารางนี้อยู่ใน
    // Expanded (สูงจำกัดตามพื้นที่จอ) ถ้ามีแค่ scroll แนวนอนอย่างเดียวโดยไม่มี
    // แนวตั้งห่อไว้ พอแถวเยอะเกินพื้นที่จอจะ overflow ด้านล่างทันที (ไม่มีทาง
    // เลื่อนดูแถวที่เหลือได้เลย)
    return SingleChildScrollView(
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 1.5))),
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
                      ],
                      if (_visibleColumns.contains('หน่วยงาน/กลุ่มงาน')) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 150, child: Text('หน่วยงาน/กลุ่มงาน', style: headerStyle)),
                      ],
                      if (_visibleColumns.contains('ผู้รับผิดชอบหลัก')) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 140, child: Text('ผู้รับผิดชอบหลัก', style: headerStyle)),
                      ],
                    ],
                  ),
                ),
                for (var i = 0; i < _filtered.length; i++) _buildRow(colors, i, _filtered[i]),
                const SizedBox(height: 24),
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
          SizedBox(width: 40, child: Text('${index + 1}', style: const TextStyle(fontSize: 12.5))),
          const SizedBox(width: 8),
          if (_visibleColumns.contains('เลขที่บันทึก/คำสั่ง')) ...[
            SizedBox(width: 110, child: Text(e.controlNumber, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
          ],
          if (_visibleColumns.contains('ประเภทงาน')) ...[
            SizedBox(width: 160, child: Text(e.docType, style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
          ],
          if (_visibleColumns.contains('วันที่บันทึก')) ...[
            SizedBox(width: 110, child: Text(e.dateText ?? '-', style: const TextStyle(fontSize: 12.5))),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(e.description, style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (_visibleColumns.contains('วงเงิน')) ...[
            const SizedBox(width: 8),
            SizedBox(width: 110, child: Text(e.amount != null ? formatBaht(e.amount!) : '-', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
          ],
          if (_visibleColumns.contains('หน่วยงาน/กลุ่มงาน')) ...[
            const SizedBox(width: 8),
            SizedBox(width: 150, child: Text(e.department ?? '-', style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          if (_visibleColumns.contains('ผู้รับผิดชอบหลัก')) ...[
            const SizedBox(width: 8),
            SizedBox(width: 140, child: Text(e.responsiblePerson ?? '-', style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ],
      ),
    );
  }
}
