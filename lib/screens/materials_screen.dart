// materials_screen.dart
// วัสดุ/คลังพัสดุ (blueprint หน้าที่ 9) — ของสิ้นเปลือง มีปุ่ม +รับเข้า/-เบิกจ่าย
// สลับมุมมองตาราง/กริดได้ (ไม่มี split-pane ตามที่ตกลงกันไว้ว่าใช้เฉพาะ
// ทะเบียนครุภัณฑ์เท่านั้น)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/material_item.dart';
import '../models/material_transaction.dart';
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import '../services/feature_access_service.dart';
import '../services/material_ledger_docx_export_service.dart';
import '../services/material_list_docx_export_service.dart';
import '../services/procurement_document_generator.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kpi_card.dart';
import '../widgets/design_system/data_table_shell.dart'
    show DsActionIconButtons, DsRowAction;
import '../widgets/design_system/clearable_text_field.dart';

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle =
    TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

InputDecoration _dialogFieldDecoration(BuildContext context,
    {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.outline;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(
        color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
    ),
  );
}

const _thaiMonths = [
  '',
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

String _todayThai() {
  final now = DateTime.now();
  return '${now.day} ${_thaiMonths[now.month]} ${now.year + 543}';
}

enum _MaterialViewMode { table, grid, byProject }

// ใช้ชื่อเต็มตามหมวดวัสดุที่ราชการใช้จริง (เดิมใช้ชื่อย่อ "สำนักงาน"/"ไฟฟ้า"/
// "งานบ้าน" — ตอนเปลี่ยนมาใช้ชื่อเต็มนี้ มีการ migrate ข้อมูลเก่าใน database.dart
// (oldVersion < 40) ให้ตรงกับชื่อใหม่ด้วยแล้ว กันไม่ให้ dropdown ค่าเดิมพัง)
const _materialCategories = [
  'วัสดุสำนักงาน',
  'วัสดุการศึกษา',
  'วัสดุไฟฟ้าและวิทยุ',
  'วัสดุงานบ้านงานครัว',
  'อื่นๆ'
];

/// คำหลักไว้เดา "ประเภทวัสดุ" จากชื่อวัสดุแบบคร่าวๆ — ไม่ได้ฉลาดจริง แค่จับ
/// คำที่พบบ่อย ช่วยลดการกดเลือกเองทุกครั้ง ผู้ใช้ยังแก้ไขเองได้เสมอ ใช้ร่วมกัน
/// ทั้งตอนกรอกฟอร์มเพิ่ม/แก้ไขวัสดุเอง และตอน "ดึงจากโครงการ" ที่สร้างวัสดุ
/// ใหม่แบบอัตโนมัติโดยไม่ผ่านฟอร์ม (ไม่งั้นวัสดุที่ถูกดึงมาจะไม่มีประเภทเลย)
// คำหลักชุดนี้เทียบมาจากรายชื่อวัสดุจริงของโรงเรียน (ไฟล์บัญชีวัสดุที่แนบมา
// 438 รายการไม่ซ้ำ) ไม่ได้เดาลอยๆ — ส่วนใหญ่เป็นหนังสือเรียน/แบบฝึกหัดที่ชื่อ
// เป็นชื่อวิชา+ระดับชั้น (เช่น "คณิตศาสตร์ ป.4 ล.1-กรม") ไม่มีคำว่า "หนังสือ"
// อยู่เลย เลยต้องเติมชื่อวิชา/สำนักพิมพ์/ชุดหนังสือเป็นคำหลักตรงๆ
const _materialCategoryKeywords = <String, List<String>>{
  // ระวัง: ใช้ 'หลอดไฟ' แทนคำว่า 'หลอด' เฉยๆ เพราะ 'หลอด' เพียงคำเดียวจะไป
  // ชนกับ "หลอดดูดน้ำ" (ของใช้ในครัว ไม่ใช่ไฟฟ้า) ในรายการจริงที่เจอ
  'วัสดุไฟฟ้าและวิทยุ': [
    'ไฟฟ้า',
    'หลอดไฟ',
    'สวิตช์',
    'ปลั๊ก',
    'สายไฟ',
    'แบตเตอรี่',
    'ถ่านไฟฉาย',
    'ไฟฉาย',
    'ฟิวส์',
    'เต้ารับ',
    'เต้าเสียบ',
    'ปลั๊กพ่วง'
  ],
  'วัสดุสำนักงาน': [
    'กระดาษ',
    'ปากกา',
    'ดินสอ',
    'แฟ้ม',
    'คลิป',
    'เทป',
    'กาว',
    'สมุด',
    'หมึก',
    'ลวดเย็บ',
    'กรรไกร',
    'ไม้บรรทัด',
    'ซองเอกสาร',
    'มาร์กเกอร์',
    'แล็กซีน',
    'แม็ก',
    'เคลือบบัตร',
    'สันรูด',
  ],
  'วัสดุงานบ้านงานครัว': [
    'ไม้กวาด',
    'ผงซักฟอก',
    'สบู่',
    'น้ำยา',
    'ถุงมือ',
    'ถุงดำ',
    'ผ้าเช็ด',
    'แปรง',
    'สเปรย์',
    'ไม้ถูพื้น',
    'ทิชชู่',
    'กระดาษชำระ',
    'หลอดดูดน้ำ',
    'ถังขยะ',
    'กะละมัง',
    'แก้วน้ำ',
    'แก้วพลาสติก',
    'โหล',
    'ตะเกียบ',
    'ไม้เสียบอาหาร',
    'น้ำมันพืช',
    'เกลือ',
    'เบกกิ้งโซดา',
    'ยาสีฟัน',
    'แปรงสีฟัน',
    'ก๊อกน้ำ',
  ],
  // วัสดุการศึกษา — ครอบคลุมหนังสือเรียน/แบบฝึกหัด (ชื่อวิชา+ระดับชั้น เช่น
  // "ภาษาพาที ป.3-กรม", "Action ม.2-อจท"), สื่อ/อุปกรณ์การเรียน, อุปกรณ์กีฬา
  // และดนตรีของโรงเรียน, และวัสดุกิจกรรมเกษตร/ทดลองของนักเรียน (เมล็ดพันธุ์
  // ฟองน้ำเพาะกล้า ปุ๋ย) ที่มักซื้อรวมในโครงการเรียนรู้
  'วัสดุการศึกษา': [
    'เมล็ดพันธุ์',
    'เมล็ด',
    'พันธุ์พืช',
    'ปุ๋ย',
    'กระถาง',
    'เพาะกล้า',
    'ดินปลูก',
    'สื่อการสอน',
    'อุปกรณ์การเรียน',
    'ชุดทดลอง',
    'แบบฝึกหัด',
    'แบบฝึกทักษะ',
    'หนังสือเรียน',
    'ของเล่นเสริมพัฒนาการ',
    'บฝ.',
    'คณิตศาสตร์',
    'วิทยาศาสตร์',
    'ภาษาพาที',
    'วรรณคดี',
    'วิวิธภาษา',
    'ประวัติศาสตร์',
    'สังคมศึกษา',
    'สุขศึกษา',
    'พลศึกษา',
    'พระพุทธศาสนา',
    'การงานอาชีพ',
    'ดนตรี',
    'นาฏศิลป์',
    'ทักษะภาษา',
    'ปฐมวัย',
    'สมรรถนะ',
    'เสริมประสบการณ์',
    'เทคโนโลยี',
    'STEM',
    'Action',
    'SMILE',
    'Smile',
    'EXTRA',
    'Kids Corner',
    'Around me',
    'Say Hello',
    'ลูกฟุตบอล',
    'ลูกวอลเลย์บอล',
    'ลูกเทนนิส',
    'ลูกปิงปอง',
    'ตาข่ายวอลเลย์บอล',
    'ตะกร้าแชร์บอล',
    'กลองสแนร์',
    'กลองเบสดรัม',
    'ฉาบมาร์ชชิ่ง',
    'มาร์ชชิ่งเบลล์',
    'เมโลเดียน',
  ],
};

/// เดาประเภทจากคำหลักในชื่อ ถ้าไม่เจอคำหลักไหนเข้าเลยจริงๆ ให้ตกเป็น "อื่นๆ"
/// แทนการปล่อยว่าง — ดีกว่าเดาผิดไปเลือกหมวดที่ไม่เกี่ยวข้อง แต่ก็ไม่ปล่อยให้
/// ไม่มีประเภทเลย ผู้ใช้ยังแก้ไขเองภายหลังได้เสมอ
String _guessMaterialCategory(String name) {
  for (final entry in _materialCategoryKeywords.entries) {
    if (entry.value.any((kw) => name.contains(kw))) return entry.key;
  }
  return 'อื่นๆ';
}

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _repo = ProcurementRepository();
  List<MaterialItem> _materials = [];
  List<ProcurementOrder> _unpulledOrders = [];
  // วัสดุ id -> โครงการที่ดึงมา (ไม่มี key = ไม่เคยดึงจากโครงการ/เพิ่มเอง) ใช้
  // จัดกลุ่มในมุมมอง "แบ่งตามโครงการ" เท่านั้น
  Map<int, String> _sourceProjectLabels = {};
  bool _loading = true;
  _MaterialViewMode _viewMode = _MaterialViewMode.table;
  String _searchQuery = '';

  // โหมดเลือกหลายรายการ — เปิดแล้วแต่ละแถว/การ์ดจะมี checkbox ให้ติ๊กเลือก
  // เพื่อลบพร้อมกันหลายชิ้น (ตามแพทเทิร์นเดียวกับหน้า Dashboard หลัก)
  bool _selectionMode = false;
  final Set<int> _selectedMaterialIds = {};

  // ผู้ใช้ติ๊ก "จำคำตอบไว้" ในไดอะล็อก "ออกเอกสารใบเบิกพัสดุ" แล้ว — จะไม่ถาม
  // ซ้ำอีกจนกว่าจะออกจากหน้านี้ (state อยู่แค่ระดับหน้าจอ ไม่บันทึกถาวร เพราะ
  // ผู้ใช้อาจอยากได้/ไม่อยากได้เอกสารสลับกันไปคนละวันได้)
  bool _skipRequisitionPrompt = false;
  bool _skipRequisitionAnswer = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getAllMaterials();
    final unpulled = await _repo.getOrdersNotYetPulledToMaterials();
    final sourceLabels = await _repo.getMaterialSourceProjectLabels();
    if (!mounted) return;
    setState(() {
      _materials = list;
      _unpulledOrders = unpulled;
      _sourceProjectLabels = sourceLabels;
      _loading = false;
    });
  }

  List<MaterialItem> get _filtered => _searchQuery.isEmpty
      ? _materials
      : _materials
          .where(
              (m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

  double get _totalValue => _materials.fold(0, (s, m) => s + m.totalValue);
  List<MaterialItem> get _lowStockItems =>
      _materials.where((m) => m.isLowStock).toList();
  int get _lowStockCount => _lowStockItems.length;

  bool _exportingLedger = false;
  bool _exportingList = false;

  /// ส่งออก "รายการวัสดุคงเหลือ" (ตารางสรุปหน้าเดียว) — คนละอันกับบัญชีวัสดุ
  /// (บัตรคุมสต๊อกแยกหน้าต่อชิ้นพร้อมประวัติรับ-จ่าย) ใช้ตอนอยากได้แค่รายการ
  /// สรุปสั้นๆ เช่น แนบประกอบการตรวจนับประจำปี
  Future<void> _exportList({List<MaterialItem>? only}) async {
    final targets = only ?? _materials;
    if (targets.isEmpty) return;
    setState(() => _exportingList = true);
    try {
      final school = await _repo.getSchoolSettings();
      await MaterialListDocxExportService.exportAndOpen(
        materials: targets,
        schoolName: school?.schoolName,
        educationServiceArea: school?.educationServiceArea,
        preparerName: school?.procurementOfficer,
        directorName: school?.directorName,
      );
      if (!mounted) return;
      showAppToast('สร้างรายการวัสดุคงเหลือแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingList = false);
    }
  }

  /// ส่งออก "บัญชีวัสดุ" (บัตรคุมสต๊อก) รวมทุกรายการ พร้อมประวัติรับ-จ่ายทีละ
  /// รายการ — ดึงประวัติของแต่ละชิ้นมาก่อนแล้วค่อยส่งออกรวดเดียว
  Future<void> _exportLedger({List<MaterialItem>? only}) async {
    final targets = only ?? _materials;
    if (targets.isEmpty) return;
    setState(() => _exportingLedger = true);
    try {
      final txByMaterial = <int, List<MaterialTransaction>>{};
      for (final m in targets) {
        if (m.id == null) continue;
        txByMaterial[m.id!] =
            await _repo.getMaterialTransactionsChronological(m.id!);
      }
      final school = await _repo.getSchoolSettings();
      await MaterialLedgerDocxExportService.exportAndOpen(
        materials: targets,
        transactionsByMaterialId: txByMaterial,
        schoolName: school?.schoolName,
        educationServiceArea: school?.educationServiceArea,
      );
      if (!mounted) return;
      showAppToast('สร้างบัญชีวัสดุแล้ว');
      if (only != null) {
        setState(() {
          _selectedMaterialIds.clear();
          _selectionMode = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingLedger = false);
    }
  }

  /// [ids] ไม่ระบุ = ใช้รายการที่เลือกไว้ทั้งหมด (แถบเลือกส่วนกลาง) ระบุมา =
  /// จำกัดเฉพาะรายการในกลุ่มนั้น (ปุ่ม action ต่อกลุ่มในมุมมอง "แบ่งตามโครงการ")
  Future<void> _exportLedgerSelected({List<int>? ids}) async {
    final targetIds = ids ?? _selectedMaterialIds.toList();
    final selected = _materials
        .where((m) => m.id != null && targetIds.contains(m.id))
        .toList();
    await _exportLedger(only: selected);
  }

  /// แสดงประวัติรับ-จ่ายทีละรายการของวัสดุชิ้นนี้
  Future<void> _viewHistory(MaterialItem m) async {
    if (m.id == null) return;
    final transactions = await _repo.getMaterialTransactions(m.id!);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ประวัติรับ-จ่าย "${m.name}"', style: _dialogTitleStyle),
        content: SizedBox(
          width: 460,
          height: 420,
          child: transactions.isEmpty
              ? Center(
                  child: Text('ยังไม่มีประวัติรับ-จ่าย',
                      style: _dialogContentStyle))
              : ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = transactions[i];
                    final isIn = t.transactionType == 'รับเข้า';
                    final iconColor = isIn
                        ? BrandAccent.green(ctx)
                        : BrandAccent.tertiary(ctx);
                    final details = [
                      if (t.transactionDate != null) t.transactionDate!,
                      if (t.counterparty?.trim().isNotEmpty ?? false)
                        t.counterparty!,
                      if (t.refDocument?.trim().isNotEmpty ?? false)
                        'เอกสาร: ${t.refDocument}',
                    ].join(' · ');
                    return ListTile(
                      dense: true,
                      leading: Icon(
                          isIn
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                          color: iconColor),
                      title: Text(
                          '${t.transactionType} ${t.quantity.toStringAsFixed(0)} ${m.unit ?? ""}',
                          style: TextStyle(
                              fontSize: AppTypography.body,
                              fontWeight: AppTypography.weightSemiBold)),
                      subtitle: details.isEmpty
                          ? null
                          : Text(details,
                              style:
                                  TextStyle(fontSize: AppTypography.bodySmall)),
                      trailing: isIn
                          ? null
                          : IconButton(
                              tooltip: 'พิมพ์ใบเบิกพัสดุสำหรับรายการนี้',
                              icon: const Icon(Icons.print_outlined, size: 20),
                              onPressed: () =>
                                  _printRequisitionForTransaction(m, t),
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  /// พิมพ์ใบเบิกพัสดุย้อนหลังจากประวัติรายการที่เคยเบิกจ่ายไปแล้ว — ใช้ตอนที่
  /// ตอนเบิกจ่ายจริงกดข้าม/ปิดไดอะล็อกออกเอกสารไปแล้ว แต่ภายหลังอยากได้เอกสาร
  /// ของรายการนั้นอีกครั้ง ไม่ต้องเบิกซ้ำ (ต่างจาก _offerRequisitionDoc ที่ถาม
  /// ก่อนออกเอกสาร — ตรงนี้ผู้ใช้กดปุ่มพิมพ์เองแล้ว ไม่ต้องถามซ้ำ)
  Future<void> _printRequisitionForTransaction(
      MaterialItem m, MaterialTransaction t) async {
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน',
          isError: true);
      return;
    }
    try {
      FeatureAccessService.instance
          .requireModule(FeatureModules.assetManagement, 'วัสดุ/คลังพัสดุ');
      await ProcurementDocumentGenerator.generateAndOpen(
        type: ProcurementDocumentType.requisition,
        order:
            ProcurementOrder(dateShipping: t.transactionDate ?? _todayThai()),
        school: school,
        items: [
          ProcurementItem(
              itemName: m.name,
              quantity: t.quantity,
              unit: m.unit,
              unitPrice: t.unitPrice ?? m.unitPrice ?? 0),
        ],
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _openForm({MaterialItem? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaterialFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(MaterialItem m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบ "${m.name}" ใช่หรือไม่?',
            style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && m.id != null) {
      await _repo.deleteMaterial(m.id!);
      _load();
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedMaterialIds.clear();
    });
  }

  void _toggleSelectAllFiltered() {
    final filteredIds =
        _filtered.where((m) => m.id != null).map((m) => m.id!).toSet();
    final allSelected =
        filteredIds.isNotEmpty && _selectedMaterialIds.containsAll(filteredIds);
    setState(() {
      if (allSelected) {
        _selectedMaterialIds.removeAll(filteredIds);
      } else {
        _selectedMaterialIds.addAll(filteredIds);
      }
    });
  }

  void _toggleOneSelected(int id) {
    setState(() {
      if (_selectedMaterialIds.contains(id)) {
        _selectedMaterialIds.remove(id);
      } else {
        _selectedMaterialIds.add(id);
      }
    });
  }

  /// [ids] ไม่ระบุ = ใช้รายการที่เลือกไว้ทั้งหมด ระบุมา = จำกัดเฉพาะกลุ่มนั้น
  Future<void> _bulkDeleteSelected({List<int>? ids}) async {
    final targetIds = ids ?? _selectedMaterialIds.toList();
    final count = targetIds.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบหลายรายการ', style: _dialogTitleStyle),
        content: Text(
            'ต้องการลบวัสดุที่เลือกไว้ $count รายการใช่หรือไม่? ประวัติรับ-จ่ายของแต่ละรายการจะถูกลบไปด้วย กู้คืนไม่ได้',
            style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ลบ $count รายการ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final id in targetIds) {
      await _repo.deleteMaterial(id);
    }
    if (!mounted) return;
    showAppToast('ลบวัสดุแล้ว $count รายการ');
    setState(() {
      _selectedMaterialIds.removeAll(targetIds);
      if (ids == null) _selectionMode = false;
    });
    _load();
  }

  /// เบิกจ่ายหลายรายการพร้อมกัน — กรอกจำนวนที่จะเบิกของแต่ละชิ้นในไดอะล็อก
  /// เดียว แล้วบันทึกทีละรายการ จบด้วยการถามออกเอกสารใบเบิกพัสดุ "ครั้งเดียว"
  /// รวมทุกชิ้นในใบเดียว แทนที่จะเด้งถามทีละชิ้นแบบตอนเบิกเดี่ยว
  Future<void> _bulkWithdrawSelected({List<int>? ids}) async {
    final targetIds = ids ?? _selectedMaterialIds.toList();
    final selected = _materials
        .where((m) => m.id != null && targetIds.contains(m.id))
        .toList();
    if (selected.isEmpty) return;
    final picked = await _pickWithdrawQuantitiesDialog(selected);
    if (picked == null || picked.qty.isEmpty || !mounted) return;
    final qtyByMaterialId = picked.qty;
    final project = picked.project;
    final ref = project != null ? _orderRef(project) : null;
    final resolvedPerson = await _resolveProjectResponsiblePerson(project);
    if (!mounted) return;
    final counterparty = _withdrawnToLabel(resolvedPerson, project);

    final withdrawnItems = <ProcurementItem>[];
    var skippedOverStock = 0;
    for (final m in selected) {
      final qty = qtyByMaterialId[m.id];
      if (qty == null || qty <= 0) continue;
      if (qty > m.remaining) {
        skippedOverStock++;
        continue;
      }
      await _recordStockTransaction(m,
          isIn: false, qty: qty, ref: ref, counterparty: counterparty);
      withdrawnItems.add(ProcurementItem(
          itemName: m.name,
          quantity: qty,
          unit: m.unit,
          unitPrice: m.unitPrice ?? 0));
    }
    if (!mounted) return;
    if (withdrawnItems.isEmpty) {
      showAppToast('ไม่มีรายการที่เบิกจ่ายสำเร็จ', isError: true);
      return;
    }
    showAppToast('เบิกจ่ายแล้ว ${withdrawnItems.length} รายการ'
        '${skippedOverStock > 0 ? " (ข้าม $skippedOverStock รายการเพราะคงเหลือไม่พอ)" : ""}');
    setState(() {
      _selectedMaterialIds.removeAll(targetIds);
      if (ids == null) _selectionMode = false;
    });
    _load();
    await _offerRequisitionDocMulti(withdrawnItems,
        project: project, withdrawnTo: counterparty);
  }

  /// ไดอะล็อกกรอกจำนวนที่จะเบิกของแต่ละชิ้นที่เลือกไว้ — เว้นว่างไว้ = ไม่เบิก
  /// ชิ้นนั้น (ไม่บังคับเบิกทุกชิ้นที่ติ๊กเลือกมา) พร้อมเลือกโครงการที่เบิกจ่าย
  /// ให้ได้ 1 โครงการ ใช้ร่วมกันทุกชิ้นในไดอะล็อกนี้ (เบิกครั้งเดียวออกใบเดียว
  /// จึงอ้างอิงได้แค่โครงการเดียว)
  Future<({Map<int, double> qty, ProcurementOrder? project})?>
      _pickWithdrawQuantitiesDialog(List<MaterialItem> materials) async {
    final controllers = {
      for (final m in materials) m.id!: TextEditingController()
    };
    ProcurementOrder? selectedProject;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('เบิกจ่ายหลายรายการ (${materials.length} ชิ้น)',
              style: _dialogTitleStyle),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in materials) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                              '${m.name}\nคงเหลือ ${_formatQty(m.remaining)} ${m.unit ?? ""}',
                              style: _dialogContentStyle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ClearableTextField(
                            controller: controllers[m.id!],
                            style: _dialogFieldStyle,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _dialogFieldDecoration(ctx,
                                label: 'จำนวน', hint: '0'),
                          ),
                        ),
                        TextButton(
                          onPressed: m.remaining <= 0
                              ? null
                              : () => setDialogState(() => controllers[m.id!]!
                                  .text = _formatQty(m.remaining)),
                          child: const Text('MAX'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setDialogState(() {
                        for (final m in materials) {
                          if (m.remaining > 0)
                            controllers[m.id!]!.text = _formatQty(m.remaining);
                        }
                      }),
                      child: const Text('เบิกเต็มจำนวนทุกรายการ'),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedProject == null
                              ? 'โครงการที่เบิกจ่ายให้ (ไม่บังคับ)'
                              : 'โครงการ: ${(selectedProject!.procurementSubject?.trim().isNotEmpty ?? false) ? selectedProject!.procurementSubject! : _orderRef(selectedProject!)}',
                          style: _dialogContentStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedProject != null)
                        IconButton(
                          tooltip: 'ล้างโครงการที่เลือก',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setDialogState(() => selectedProject = null),
                        ),
                      TextButton(
                        onPressed: () async {
                          final picked = await _pickSingleOrderDialog();
                          if (picked != null)
                            setDialogState(() => selectedProject = picked);
                        },
                        child: Text(selectedProject == null
                            ? 'เลือกโครงการ'
                            : 'เปลี่ยน'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  padding: _dialogButtonPadding,
                  textStyle: _dialogButtonTextStyle),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: _dialogButtonPadding,
                  textStyle: _dialogButtonTextStyle),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยันเบิกจ่าย'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return null;
    final result = <int, double>{};
    for (final entry in controllers.entries) {
      final qty = double.tryParse(entry.value.text.trim());
      if (qty != null && qty > 0) result[entry.key] = qty;
    }
    return (qty: result, project: selectedProject);
  }

  /// เวอร์ชันหลายรายการของ _offerRequisitionDoc — ถามครั้งเดียวแล้วออก
  /// เอกสารใบเบิกพัสดุใบเดียวที่รวมทุกชิ้นไว้ด้วยกัน
  Future<void> _offerRequisitionDocMulti(List<ProcurementItem> items,
      {ProcurementOrder? project, String? withdrawnTo}) async {
    if (!mounted) return;
    final wantsDoc = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกเอกสารใบเบิกพัสดุ', style: _dialogTitleStyle),
        content: Text(
            'ต้องการออกเอกสารใบเบิกพัสดุรวม ${items.length} รายการนี้หรือไม่?',
            style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ไม่ต้อง'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ออกเอกสาร'),
          ),
        ],
      ),
    );
    if (wantsDoc != true || !mounted) return;
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน',
          isError: true);
      return;
    }
    try {
      FeatureAccessService.instance
          .requireModule(FeatureModules.assetManagement, 'วัสดุ/คลังพัสดุ');
      await ProcurementDocumentGenerator.generateAndOpen(
        type: ProcurementDocumentType.requisition,
        order: _orderForRequisitionDoc(project, withdrawnTo: withdrawnTo),
        school: school,
        items: items,
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    }
    _load();
  }

  /// คัดลอกวัสดุเป็นรายการใหม่ — คัดลอกข้อมูลบรรยาย (ชื่อ/รหัส/หน่วย/ราคา/ที่เก็บ/
  /// จำนวนอย่างสูง-ต่ำ) มาตรงๆ แต่เริ่มยอดรับ-จ่ายที่ 0 ใหม่เสมอ (ไม่ใช่ล้างข้อมูล
  /// บรรยาย แต่ยอดสต๊อกเป็นประวัติจริงของชิ้นเดิม เอามาใช้กับของชิ้นใหม่ไม่ได้)
  Future<void> _duplicateMaterial(MaterialItem m) async {
    try {
      final map = m.toMap();
      map.remove('id');
      map['name'] = '${m.name} (สำเนา)';
      map['stock_in'] = 0.0;
      map['stock_out'] = 0.0;
      await _repo.insertMaterial(MaterialItem.fromMap(map));
      if (!mounted) return;
      showAppToast('คัดลอกวัสดุแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกวัสดุไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _adjustStock(MaterialItem m, {required bool isIn}) async {
    final qtyCtrl = TextEditingController();
    final counterpartyCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    ProcurementOrder? selectedProject;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isIn ? 'รับเข้า "${m.name}"' : 'เบิกจ่าย "${m.name}"',
              style: _dialogTitleStyle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClearableTextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  style: _dialogFieldStyle,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dialogFieldDecoration(ctx,
                      label:
                          'จำนวน${isIn ? "ที่รับเข้า" : "ที่เบิกจ่าย"} (${m.unit ?? "หน่วย"})',
                      hint: 'เช่น 10'),
                ),
                const SizedBox(height: 18),
                ClearableTextField(
                  controller: counterpartyCtrl,
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(ctx,
                      label:
                          isIn ? 'รับจาก (ไม่บังคับ)' : 'จ่ายให้ (ไม่บังคับ)',
                      hint: isIn
                          ? 'เช่น ร้านเจริญพาณิชย์'
                          : 'เช่น ครูประจำชั้น ป.1'),
                ),
                const SizedBox(height: 18),
                ClearableTextField(
                  controller: refCtrl,
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(ctx,
                      label: 'เลขที่เอกสารอ้างอิง (ไม่บังคับ)',
                      hint: 'เช่น ใบเบิกที่ 12/2569'),
                ),
                if (!isIn) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedProject == null
                              ? 'โครงการที่เบิกจ่ายให้ (ไม่บังคับ)'
                              : 'โครงการ: ${(selectedProject!.procurementSubject?.trim().isNotEmpty ?? false) ? selectedProject!.procurementSubject! : _orderRef(selectedProject!)}',
                          style: _dialogContentStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedProject != null)
                        IconButton(
                          tooltip: 'ล้างโครงการที่เลือก',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setDialogState(() => selectedProject = null),
                        ),
                      TextButton(
                        onPressed: () async {
                          final picked = await _pickSingleOrderDialog();
                          if (picked != null)
                            setDialogState(() => selectedProject = picked);
                        },
                        child: Text(selectedProject == null
                            ? 'เลือกโครงการ'
                            : 'เปลี่ยน'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  padding: _dialogButtonPadding,
                  textStyle: _dialogButtonTextStyle),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: _dialogButtonPadding,
                  textStyle: _dialogButtonTextStyle),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final qty = double.tryParse(qtyCtrl.text.trim());
    if (qty == null || qty <= 0 || m.id == null) return;

    if (!isIn && qty > m.remaining) {
      showAppToast('เบิกจ่ายไม่ได้ — คงเหลือแค่ ${m.remaining} ${m.unit ?? ""}',
          isError: true);
      return;
    }

    final ref = refCtrl.text.trim().isNotEmpty
        ? refCtrl.text.trim()
        : (selectedProject != null ? _orderRef(selectedProject!) : null);
    var counterparty = counterpartyCtrl.text.trim().isEmpty
        ? null
        : counterpartyCtrl.text.trim();
    counterparty ??= await _resolveProjectResponsiblePerson(selectedProject);
    counterparty = _withdrawnToLabel(counterparty, selectedProject);
    await _recordStockTransaction(
      m,
      isIn: isIn,
      qty: qty,
      counterparty: counterparty,
      ref: ref,
    );
    if (!mounted) return;
    showAppToast(isIn
        ? 'รับเข้า $qty ${m.unit ?? ""} แล้ว'
        : 'เบิกจ่าย $qty ${m.unit ?? ""} แล้ว');
    _load();
    if (!isIn)
      await _offerRequisitionDoc(m, qty,
          project: selectedProject, withdrawnTo: counterparty);
  }

  /// บันทึกทั้งยอดสะสม (stock_in/stock_out) และประวัติรายการเดี่ยวควบคู่กัน —
  /// ใช้ร่วมกันทั้งจากไดอะล็อกรับเข้า/เบิกจ่ายทีละชิ้น และการเบิกจ่ายหลาย
  /// รายการพร้อมกัน กันโค้ดซ้ำ/พฤติกรรมเพี้ยนกันระหว่าง 2 ทาง
  Future<void> _recordStockTransaction(
    MaterialItem m, {
    required bool isIn,
    required double qty,
    String? counterparty,
    String? ref,
  }) async {
    final updated = isIn
        ? m.copyWith(stockIn: m.stockIn + qty)
        : m.copyWith(stockOut: m.stockOut + qty);
    await _repo.updateMaterial(updated);
    await _repo.insertMaterialTransaction(MaterialTransaction(
      materialId: m.id!,
      transactionDate: _todayThai(),
      transactionType: isIn ? 'รับเข้า' : 'เบิกจ่าย',
      quantity: qty,
      unitPrice: m.unitPrice,
      refDocument: ref,
      counterparty: counterparty,
    ));
  }

  /// เลือกโครงการที่เบิกจ่ายให้ — ไม่ได้แยกสต๊อกวัสดุตามโครงการ (สต๊อกยังรวม
  /// เป็นก้อนเดียวเหมือนเดิม) แต่ใช้ระบุว่าการเบิกจ่ายครั้งนี้เอาไปใช้กับ
  /// โครงการไหน เพื่อพิมพ์อ้างอิงลงในใบเบิกพัสดุและบันทึกไว้ในประวัติรับ-จ่าย
  Future<ProcurementOrder?> _pickSingleOrderDialog() async {
    final orders = await _repo.getAllOrders();
    if (!mounted) return null;
    var query = '';
    return showDialog<ProcurementOrder>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? orders
              : orders.where((o) {
                  final hay = [
                    o.orderNumber,
                    o.procurementNumber,
                    o.procurementSubject,
                    o.projectName,
                    o.vendorName,
                  ]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' ')
                      .toLowerCase();
                  return hay.contains(q);
                }).toList();
          return AlertDialog(
            title: const Text('เลือกโครงการที่เบิกจ่ายให้',
                style: _dialogTitleStyle),
            content: SizedBox(
              width: 520,
              height: 440,
              child: Column(
                children: [
                  ClearableTextField(
                    autofocus: true,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(ctx,
                        label: 'ค้นหาโครงการ',
                        hint: 'เลขที่/ชื่อโครงการ/ร้านค้า'),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('ไม่พบโครงการที่ค้นหา',
                                style: _dialogContentStyle))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final o = filtered[i];
                              final docNumber =
                                  o.orderNumber ?? o.procurementNumber ?? '-';
                              final label =
                                  (o.procurementSubject?.trim().isNotEmpty ??
                                          false)
                                      ? o.procurementSubject!
                                      : (o.projectName ?? '(ไม่มีชื่อรายการ)');
                              return ListTile(
                                dense: true,
                                title: Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '$docNumber • ${o.vendorName ?? "-"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () => Navigator.pop(ctx, o),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                style: TextButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                child: const Text('ยกเลิก'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ดึงรายการวัสดุที่เคยจัดซื้อไว้ในโครงการ (ProcurementItem) เข้าคลังพัสดุ
  /// อัตโนมัติ — เลือกโครงการ -> เลือกรายการที่จะดึง -> จับคู่ชื่อกับวัสดุที่มี
  /// อยู่แล้ว (ตรงตัวแบบไม่สนตัวพิมพ์เล็ก-ใหญ่/เว้นวรรคหัวท้าย) ถ้าไม่พบสร้าง
  /// วัสดุใหม่ให้เลย แล้วบันทึกเป็นรายการ "รับเข้า" พร้อม ref_document อ้างอิง
  /// เลขที่โครงการ กันดึงซ้ำโดยไม่ตั้งใจ (เตือนไว้ก่อน ไม่บล็อกเด็ดขาด)
  Future<void> _pullFromProjectFlow() async {
    final orders = await _pickOrdersDialog();
    if (orders == null || orders.isEmpty || !mounted) return;

    // โหลดรายการวัสดุของทุกโครงการที่เลือกพร้อมกัน (เร็วกว่ารอทีละโครงการ)
    final itemsByOrder = <ProcurementOrder, List<ProcurementItem>>{};
    final itemLists =
        await Future.wait(orders.map((o) => _repo.getItems(o.id!)));
    for (var i = 0; i < orders.length; i++) {
      if (itemLists[i].isNotEmpty) itemsByOrder[orders[i]] = itemLists[i];
    }
    if (!mounted) return;
    if (itemsByOrder.isEmpty) {
      showAppToast('โครงการที่เลือกยังไม่มีรายการวัสดุให้ดึงเลย',
          isError: true);
      return;
    }

    // เช็ครวมว่ามีโครงการไหนในกลุ่มที่เลือกเคยถูกดึงไปแล้วบ้าง — เตือนครั้งเดียว
    // รวมกันแทนที่จะถามทีละโครงการ (ช้า/น่ารำคาญเวลาเลือกมาหลายสิบโครงการ)
    final alreadyPulledLabels = <String>[];
    for (final o in itemsByOrder.keys) {
      final ref = _orderRef(o);
      if (await _repo.hasMaterialTransactionsForRef('ดึงจากโครงการ $ref')) {
        alreadyPulledLabels.add(ref);
      }
    }
    if (!mounted) return;
    if (alreadyPulledLabels.isNotEmpty) {
      final confirmAgain = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('มีโครงการที่เคยดึงวัสดุไปแล้ว',
              style: _dialogTitleStyle),
          content: Text(
            '${alreadyPulledLabels.length} โครงการที่เลือก (${alreadyPulledLabels.take(5).join(", ")}${alreadyPulledLabels.length > 5 ? " ..." : ""}) เคยถูกดึงวัสดุเข้าคลังไปแล้วอย่างน้อย 1 ครั้ง ถ้าดึงซ้ำอีกจะรับเข้าเพิ่มอีกรอบ (ไม่ใช่แก้ไขของเดิม) ต้องการดึงซ้ำหรือไม่?',
            style: _dialogContentStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  padding: _dialogButtonPadding,
                  textStyle: _dialogButtonTextStyle),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: _dialogButtonPadding,
                  textStyle: _dialogButtonTextStyle),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ดึงซ้ำ'),
            ),
          ],
        ),
      );
      if (confirmAgain != true || !mounted) return;
    }

    final selectionRaw = await _pickItemsDialog(itemsByOrder);
    if (selectionRaw == null || !mounted) return;
    // ตัดโครงการที่ไม่เหลือรายการที่ติ๊กไว้เลยออก (ผู้ใช้ติ๊กออกหมดทุกอันของ
    // โครงการนั้น) กันโครงการเปล่าๆ ไปโผล่ในลูปประมวลผลข้างล่างเฉยๆ
    final selection = {
      for (final e in selectionRaw.entries)
        if (e.value.isNotEmpty) e.key: e.value
    };
    if (selection.isEmpty) {
      showAppToast('ไม่มีรายการที่เลือกไว้', isError: true);
      return;
    }

    var createdCount = 0;
    var restockedCount = 0;
    for (final entry in selection.entries) {
      final order = entry.key;
      final refDocument = 'ดึงจากโครงการ ${_orderRef(order)}';
      for (final item in entry.value) {
        final existing = _findMatchingMaterial(item.itemName);
        int materialId;
        if (existing != null) {
          final updated =
              existing.copyWith(stockIn: existing.stockIn + item.quantity);
          await _repo.updateMaterial(updated);
          materialId = existing.id!;
          restockedCount++;
        } else {
          materialId = await _repo.insertMaterial(MaterialItem(
            name: item.itemName,
            category: _guessMaterialCategory(item.itemName),
            unit: item.unit,
            unitPrice: item.unitPrice,
            stockIn: item.quantity,
          ));
          createdCount++;
        }
        await _repo.insertMaterialTransaction(MaterialTransaction(
          materialId: materialId,
          transactionDate: _todayThai(),
          transactionType: 'รับเข้า',
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          refDocument: refDocument,
          counterparty: _vendorCounterpartyLabel(order),
          note: null,
        ));
      }
    }

    if (!mounted) return;
    final total = createdCount + restockedCount;
    showAppToast(
        'ดึงวัสดุเข้าคลังแล้ว $total รายการ จาก ${selection.length} โครงการ (วัสดุใหม่ $createdCount, เติมของเดิม $restockedCount)');
    _load();
  }

  String _orderRef(ProcurementOrder o) =>
      o.orderNumber ?? o.procurementNumber ?? 'โครงการ #${o.id}';

  /// สร้างข้อความ "รับจาก" แบบเต็ม (ชื่อร้าน + ที่อยู่ + เอกสารอ้างอิงตอนตรวจรับ
  /// + วันที่) ตอนดึงวัสดุจากโครงการเข้าคลัง — ให้ครบเหมือนบัญชีวัสดุจริงที่ใช้
  /// เขียนด้วยมือ แทนที่จะมีแค่ชื่อร้านเฉยๆ
  String _vendorCounterpartyLabel(ProcurementOrder order) {
    final addressParts = [
      if ((order.vendorAddressNo ?? '').trim().isNotEmpty)
        'เลขที่ ${order.vendorAddressNo!.trim()}',
      if ((order.vendorSubdistrict ?? '').trim().isNotEmpty)
        'ตำบล${order.vendorSubdistrict!.trim()}',
      if ((order.vendorDistrict ?? '').trim().isNotEmpty)
        'อำเภอ${order.vendorDistrict!.trim()}',
      if ((order.vendorProvince ?? '').trim().isNotEmpty)
        'จังหวัด${order.vendorProvince!.trim()}',
      if ((order.vendorPostalCode ?? '').trim().isNotEmpty)
        order.vendorPostalCode!.trim(),
    ];
    final lines = <String>[
      order.vendorName?.trim().isNotEmpty ?? false
          ? order.vendorName!.trim()
          : '-'
    ];
    if (addressParts.isNotEmpty) lines.add(addressParts.join(' '));
    final refDate = order.dateShipping?.trim().isNotEmpty ?? false
        ? order.dateShipping
        : order.dateContractSigned;
    if (refDate != null && refDate.trim().isNotEmpty) {
      final docType = (order.deliveryDocType?.trim().isNotEmpty ?? false)
          ? order.deliveryDocType!
          : 'ใบส่งของ';
      lines.add('$docType ลงวันที่ $refDate');
    }
    return lines.join('\n');
  }

  /// รวมชื่อผู้รับพัสดุ (จ่ายให้) กับโครงการ/กิจกรรมที่เบิกไปใช้ ให้อยู่ใน
  /// ข้อความเดียวกัน — ถ้าไม่มีทั้งคู่คืน null (ไม่บังคับกรอก)
  String? _withdrawnToLabel(String? person, ProcurementOrder? project) {
    final trimmedPerson =
        person?.trim().isNotEmpty ?? false ? person!.trim() : null;
    if (project == null) return trimmedPerson;
    final projectLabel =
        (project.procurementSubject?.trim().isNotEmpty ?? false)
            ? project.procurementSubject!
            : _orderRef(project);
    if (trimmedPerson == null) return projectLabel;
    return '$trimmedPerson ($projectLabel)';
  }

  /// โชว์จำนวนแบบไม่มีทศนิยมห้อยถ้าเป็นเลขเต็ม (เช่น 3 แทน 3.0) แต่คงทศนิยม
  /// ไว้ถ้าจำเป็นจริงๆ (เช่น 2.5) — ใช้ตอนเติมค่า MAX ลงช่องกรอกจำนวนเบิก
  String _formatQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toStringAsFixed(0) : qty.toString();

  /// จับคู่ชื่อวัสดุแบบตรงตัว ไม่สนตัวพิมพ์เล็ก-ใหญ่/เว้นวรรคหัวท้าย — ตั้งใจให้
  /// เข้มงวด (ไม่ fuzzy match) กันจับคู่ผิดตัวเงียบๆ จนยอดสต๊อกของวัสดุคนละชิ้น
  /// ปนกัน ถ้าชื่อไม่ตรงเป๊ะระบบจะสร้างวัสดุใหม่แทนเสมอ
  MaterialItem? _findMatchingMaterial(String itemName) {
    final target = itemName.trim().toLowerCase();
    for (final m in _materials) {
      if (m.name.trim().toLowerCase() == target) return m;
    }
    return null;
  }

  /// เลือกได้หลายโครงการพร้อมกัน (ติ๊กเลือกทีละอัน หรือกด "เลือกที่ยังไม่ดึง
  /// ทั้งหมด" ให้เร็วขึ้น) — แต่ละแถวมีป้ายบอกสถานะว่าโครงการนั้นเคยถูกดึงวัสดุ
  /// ไปแล้วหรือยัง กันงงว่าอันไหนทำไปแล้วบ้าง เฉพาะโครงการที่มีรายการวัสดุจริง
  /// เท่านั้นถึงจะโผล่ในลิสต์ (กรองโครงการที่ไม่มีของให้ดึงออกไปก่อน)
  Future<List<ProcurementOrder>?> _pickOrdersDialog() async {
    final results = await Future.wait([
      _repo.getAllOrders(),
      _repo.getOrderIdsWithItems(),
      _repo.getOrdersNotYetPulledToMaterials(),
    ]);
    if (!mounted) return null;
    final allOrders = results[0] as List<ProcurementOrder>;
    final idsWithItems = results[1] as Set<int>;
    final unpulledIds =
        (results[2] as List<ProcurementOrder>).map((o) => o.id).toSet();
    // เฉพาะโครงการ "จัดซื้อ" เท่านั้น (ตัดโครงการ "จัดจ้าง" ออก เช่น จ้างเหมา
    // ประกอบอาหาร/จ้างบุคคล — ไม่ใช่ของที่ต้องนับสต๊อกเป็นวัสดุ) — โครงการที่ยัง
    // ไม่มีรายการวัสดุเลยยังคงแสดงไว้ (ไม่กรองออกเหมือนเดิม) แต่ขึ้นป้ายเตือน
    // "ยังไม่มีพัสดุ" แทน ให้เห็นว่ายังไม่ได้กรอกรายการไว้ ไม่ใช่ถูกซ่อนเงียบๆ
    final orders = allOrders.where((o) => o.orderType != 'จ้าง').toList();

    var query = '';
    final selected = <int>{};
    return showDialog<List<ProcurementOrder>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? orders
              : orders.where((o) {
                  final hay = [
                    o.orderNumber,
                    o.procurementNumber,
                    o.procurementSubject,
                    o.projectName,
                    o.vendorName,
                  ]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' ')
                      .toLowerCase();
                  return hay.contains(q);
                }).toList();
          return AlertDialog(
            title: const Text('เลือกโครงการที่จะดึงวัสดุ (เลือกได้หลายรายการ)',
                style: _dialogTitleStyle),
            content: SizedBox(
              width: 560,
              height: 480,
              child: Column(
                children: [
                  ClearableTextField(
                    autofocus: true,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(ctx,
                        label: 'ค้นหาโครงการ',
                        hint: 'เลขที่/ชื่อโครงการ/ร้านค้า'),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setDialogState(() => selected.addAll(
                            filtered
                                .where((o) => unpulledIds.contains(o.id))
                                .map((o) => o.id!))),
                        child: const Text('เลือกที่ยังไม่ดึงทั้งหมด'),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(selected.clear),
                        child: const Text('ล้างที่เลือก'),
                      ),
                      const Spacer(),
                      Text('เลือกอยู่ ${selected.length} โครงการ',
                          style: TextStyle(
                              fontSize: AppTypography.bodySmall,
                              color:
                                  Theme.of(ctx).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('ไม่พบโครงการที่ค้นหา',
                                style: _dialogContentStyle))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final o = filtered[i];
                              final docNumber =
                                  o.orderNumber ?? o.procurementNumber ?? '-';
                              final label =
                                  (o.procurementSubject?.trim().isNotEmpty ??
                                          false)
                                      ? o.procurementSubject!
                                      : (o.projectName ?? '(ไม่มีชื่อรายการ)');
                              final hasItems = idsWithItems.contains(o.id);
                              final unpulled = unpulledIds.contains(o.id);
                              final chipColor = !hasItems
                                  ? BrandAccent.red(ctx)
                                  : unpulled
                                      ? BrandAccent.tealOn(ctx)
                                      : Theme.of(ctx)
                                          .colorScheme
                                          .onSurfaceVariant;
                              final chipLabel = !hasItems
                                  ? 'ยังไม่มีพัสดุ'
                                  : (unpulled ? 'ยังไม่ดึง' : 'เคยดึงแล้ว');
                              return CheckboxListTile(
                                value: selected.contains(o.id),
                                onChanged: !hasItems
                                    ? null
                                    : (v) => setDialogState(() {
                                          if (v == true) {
                                            selected.add(o.id!);
                                          } else {
                                            selected.remove(o.id);
                                          }
                                        }),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '$docNumber • ${o.vendorName ?? "-"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                secondary: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: chipColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    chipLabel,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: chipColor),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx,
                        orders.where((o) => selected.contains(o.id)).toList()),
                child: Text('ต่อไป (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<ProcurementOrder, List<ProcurementItem>>?> _pickItemsDialog(
      Map<ProcurementOrder, List<ProcurementItem>> itemsByOrder) async {
    final selected = {
      for (final items in itemsByOrder.values)
        for (final item in items) item: true
    };
    return showDialog<Map<ProcurementOrder, List<ProcurementItem>>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedCount = selected.values.where((v) => v).length;
          return AlertDialog(
            title: Text(
                'เลือกวัสดุที่จะดึงเข้าคลัง (${itemsByOrder.length} โครงการ)',
                style: _dialogTitleStyle),
            content: SizedBox(
              width: 560,
              height: 480,
              child: ListView(
                children: [
                  for (final entry in itemsByOrder.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        (entry.key.procurementSubject?.trim().isNotEmpty ??
                                false)
                            ? entry.key.procurementSubject!
                            : (entry.key.projectName ?? _orderRef(entry.key)),
                        style: TextStyle(
                            fontSize: AppTypography.bodyMedium,
                            fontWeight: FontWeight.w800,
                            color: BrandAccent.tealOn(ctx)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final item in entry.value)
                      CheckboxListTile(
                        value: selected[item],
                        onChanged: (v) =>
                            setDialogState(() => selected[item] = v ?? false),
                        title: Text(item.itemName,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${item.quantityDisplay} × ${formatBaht(item.unitPrice)} บาท'),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    const Divider(height: 16),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                onPressed: () => Navigator.pop(ctx, {
                  for (final entry in itemsByOrder.entries)
                    entry.key: [
                      for (final item in entry.value)
                        if (selected[item] == true) item
                    ],
                }),
                child: Text('ดึงเข้าคลัง ($selectedCount)'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// สต๊อกวัสดุยังรวมเป็นก้อนเดียวไม่แยกตามโครงการ — [project] แค่ใช้อ้างอิง
  /// (เลขที่/ชื่อโครงการ) ลงในใบเบิกพัสดุที่พิมพ์ออกมา ไม่กระทบยอดคงเหลือ
  /// [withdrawnTo] คือชื่อผู้เบิก/ผู้รับของจริง (คนที่กรอก "จ่ายให้" หรือ
  /// ผู้รับผิดชอบโครงการที่เดามาให้) — ใช้แทน specCreatorName เดิมของโครงการ
  /// ในเทมเพลตใบเบิกพัสดุ ({{spec_creator_name}} = ช่องผู้เบิก/ผู้รับของ)
  ProcurementOrder _orderForRequisitionDoc(ProcurementOrder? project,
      {String? withdrawnTo}) {
    final base = project?.copyWith(dateShipping: _todayThai()) ??
        ProcurementOrder(dateShipping: _todayThai());
    if (withdrawnTo == null || withdrawnTo.trim().isEmpty) return base;
    return base.copyWith(specCreatorName: withdrawnTo.trim());
  }

  /// หาชื่อ "ผู้รับผิดชอบ" ของโครงการที่เลือก — ดึงจากแผนงบประมาณ/กิจกรรม
  /// (Budget.responsiblePerson) ที่ผูกกับโครงการนั้นก่อน ถ้าไม่มีค่อย fallback
  /// ไปใช้ผู้จัดทำรายละเอียดคุณลักษณะ (specCreatorName) ของโครงการแทน
  Future<String?> _resolveProjectResponsiblePerson(
      ProcurementOrder? project) async {
    if (project == null) return null;
    if (project.budgetId != null) {
      final budget = await _repo.getBudget(project.budgetId!);
      if (budget?.responsiblePerson?.trim().isNotEmpty ?? false)
        return budget!.responsiblePerson;
    }
    return project.specCreatorName?.trim().isNotEmpty ?? false
        ? project.specCreatorName
        : null;
  }

  Future<void> _offerRequisitionDoc(MaterialItem m, double qty,
      {ProcurementOrder? project, String? withdrawnTo}) async {
    if (!mounted) return;
    bool wantsDoc;
    if (_skipRequisitionPrompt) {
      wantsDoc = _skipRequisitionAnswer;
    } else {
      var rememberChoice = false;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('ออกเอกสารใบเบิกพัสดุ', style: _dialogTitleStyle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'ต้องการออกเอกสารใบเบิกพัสดุสำหรับ "${m.name}" จำนวน $qty ${m.unit ?? ""} นี้หรือไม่?',
                    style: _dialogContentStyle),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: rememberChoice,
                  onChanged: (v) =>
                      setDialogState(() => rememberChoice = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text(
                      'จำคำตอบนี้ไว้จนกว่าจะออกจากหน้านี้ (ไม่ต้องถามอีก)',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (rememberChoice) {
                    _skipRequisitionPrompt = true;
                    _skipRequisitionAnswer = false;
                  }
                  Navigator.pop(ctx, false);
                },
                style: TextButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                child: const Text('ไม่ต้อง'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    padding: _dialogButtonPadding,
                    textStyle: _dialogButtonTextStyle),
                onPressed: () {
                  if (rememberChoice) {
                    _skipRequisitionPrompt = true;
                    _skipRequisitionAnswer = true;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('ออกเอกสาร'),
              ),
            ],
          ),
        ),
      );
      wantsDoc = result ?? false;
    }
    if (!wantsDoc) return;
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน',
          isError: true);
      return;
    }
    try {
      FeatureAccessService.instance
          .requireModule(FeatureModules.assetManagement, 'วัสดุ/คลังพัสดุ');
      await ProcurementDocumentGenerator.generateAndOpen(
        type: ProcurementDocumentType.requisition,
        order: _orderForRequisitionDoc(project, withdrawnTo: withdrawnTo),
        school: school,
        items: [
          ProcurementItem(
              itemName: m.name,
              quantity: qty,
              unit: m.unit,
              unitPrice: m.unitPrice ?? 0),
        ],
      );
      if (!mounted) return;
      showAppToast('สร้างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้หน้าวัสดุ/คลังพัสดุ',
      icon: Icons.inventory_outlined,
      // การ์ดสรุปด้านบนกว้างเต็มจอ ปุ่มไกด์เลยต้องลอยมุมซ้ายล่างแทนมุมขวาบน
      // (มุมขวาล่างมีปุ่ม "เพิ่มวัสดุ" อยู่แล้ว)
      corner: Alignment.bottomLeft,
      steps: const [
        'ยอดคงเหลือคำนวณจากยอด "รับเข้า" ลบ "เบิกจ่าย" สะสมทั้งหมด — ทุกครั้งที่กดรับเข้า/เบิกจ่าย ระบบจะบันทึกประวัติทีละรายการไว้ด้วย (วันที่/รับจาก-จ่ายให้/เลขที่เอกสาร) กดไอคอนนาฬิกาที่แถวรายการเพื่อดูประวัติได้',
        'กด "เบิกจ่าย" ที่รายการวัสดุเพื่อตัดยอดออก ระบบจะเสนอสร้างใบเบิกพัสดุให้อัตโนมัติถ้าต้องการ',
        'ใกล้หมด หมายถึงจำนวนคงเหลือถึงเกณฑ์ "จำนวนอย่างต่ำ" ที่กำหนดไว้ในฟอร์มวัสดุ (ถ้ายังไม่กำหนด ใช้เกณฑ์ทั่วไป ≤5) ควรพิจารณาจัดซื้อเพิ่ม',
        'กรอกขนาด/ที่เก็บ/จำนวนอย่างสูง-ต่ำ ในฟอร์มเพิ่ม/แก้ไข ให้ตรงกับแบบฟอร์มบัญชีวัสดุของราชการ แล้วกด "พิมพ์บัญชีวัสดุ" มุมขวาบนเพื่อออกเป็นไฟล์ Word พร้อมประวัติรับ-จ่ายครบทุกชิ้น หรือกด "พิมพ์รายการวัสดุ" เพื่อออกตารางสรุปวัสดุคงเหลือหน้าเดียว',
        'สลับมุมมองตาราง/กริด/แบ่งตามโครงการได้ที่ปุ่มด้านบนขวาของรายการ ใช้ช่องค้นหาเพื่อหาชื่อวัสดุที่ต้องการเร็วขึ้น',
        'มุมมอง "แบ่งตามโครงการ" (ไอคอนโฟลเดอร์) จัดกลุ่มวัสดุตามโครงการที่เคย "ดึงจากโครงการ" มาให้อัตโนมัติ — กด "เลือกทั้งกลุ่ม" แล้วใช้ปุ่มเบิกจ่าย/พิมพ์บัญชี/ลบในแถบเลือกได้เลย ไม่ต้องลบวัสดุโครงการอื่นทิ้งก่อนเพื่อทำทีละโครงการแบบเดิมอีกต่อไป',
      ],
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                // เดิมปักหัว (การ์ดสรุป/แถบแจ้งเตือน/ช่องค้นหา) ไว้นิ่ง แล้วให้
                // แค่ส่วนรายการข้างล่างเลื่อนเองใน Expanded ที่เหลือ — พอมีแถบ
                // แจ้งเตือนสูงๆ พื้นที่เลื่อนจริงเหลือแค่ครึ่งจอ ดูเหมือน "เลื่อน
                // ได้แค่ครึ่งหน้า" เปลี่ยนมาให้ทั้งหน้ารวมหัวเลื่อนไปด้วยกันแทน
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_outlined,
                                color: BrandAccent.tealOn(context), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('วัสดุ/คลังพัสดุ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: AppTypography.heading2,
                                      fontWeight: AppTypography.weightExtraBold,
                                      color: colors.onSurface)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _pullFromProjectFlow,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                side: BorderSide(color: colors.outline),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.md)),
                                textStyle: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              icon: const Icon(Icons.move_to_inbox_outlined,
                                  size: 18),
                              label: const Text('ดึงจากโครงการ'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  (_materials.isEmpty || _exportingLedger)
                                      ? null
                                      : _exportLedger,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                side: BorderSide(color: colors.outline),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.md)),
                                textStyle: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              icon: _exportingLedger
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onSurfaceVariant))
                                  : const Icon(Icons.receipt_long_outlined,
                                      size: 18),
                              label: Text(_exportingLedger
                                  ? 'กำลังสร้าง...'
                                  : 'พิมพ์บัญชีวัสดุ'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: (_materials.isEmpty || _exportingList)
                                  ? null
                                  : () => _exportList(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                side: BorderSide(color: colors.outline),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.md)),
                                textStyle: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              icon: _exportingList
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onSurfaceVariant))
                                  : const Icon(Icons.list_alt_outlined,
                                      size: 18),
                              label: Text(_exportingList
                                  ? 'กำลังสร้าง...'
                                  : 'พิมพ์รายการวัสดุ'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCards(context, colors),
                        if (_unpulledOrders.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildUnpulledOrdersBanner(context, colors),
                        ],
                        if (_lowStockCount > 0) ...[
                          const SizedBox(height: 12),
                          _buildLowStockBanner(context, colors),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ClearableTextField(
                                style: TextStyle(
                                    fontSize: AppTypography.bodyMedium,
                                    color: colors.onSurface),
                                decoration: InputDecoration(
                                  prefixIcon:
                                      const Icon(Icons.search, size: 20),
                                  hintText: 'ค้นหาชื่อวัสดุ',
                                  hintStyle: TextStyle(
                                      fontSize: AppTypography.bodyMedium,
                                      color: colors.onSurfaceVariant),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.md),
                                    borderSide:
                                        BorderSide(color: colors.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.md),
                                    borderSide:
                                        BorderSide(color: colors.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(RadiusSize.md),
                                    borderSide: BorderSide(
                                        color: BrandAccent.teal(context),
                                        width: 1.5),
                                  ),
                                ),
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<_MaterialViewMode>(
                              segments: const [
                                ButtonSegment(
                                    value: _MaterialViewMode.table,
                                    icon: Icon(Icons.table_chart_outlined),
                                    tooltip: 'มุมมองตาราง'),
                                ButtonSegment(
                                    value: _MaterialViewMode.grid,
                                    icon: Icon(Icons.grid_view_outlined),
                                    tooltip: 'มุมมองการ์ด'),
                                ButtonSegment(
                                    value: _MaterialViewMode.byProject,
                                    icon: Icon(Icons.folder_outlined),
                                    tooltip: 'แบ่งตามโครงการ'),
                              ],
                              selected: {_viewMode},
                              onSelectionChanged: (s) =>
                                  setState(() => _viewMode = s.first),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSelectionBar(context, colors,
                            showActions:
                                _viewMode != _MaterialViewMode.byProject),
                        const SizedBox(height: 12),
                        _filtered.isEmpty
                            ? SizedBox(
                                height: 360,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_outlined,
                                          size: 64,
                                          color: colors.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text(
                                        _materials.isEmpty
                                            ? 'ยังไม่มีวัสดุ\nกด "เพิ่มวัสดุ" เพื่อเริ่มต้น'
                                            : 'ไม่พบรายการที่ค้นหา',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: AppTypography.heading4),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : switch (_viewMode) {
                                _MaterialViewMode.table =>
                                  _buildTable(context, colors),
                                _MaterialViewMode.grid =>
                                  _buildGrid(context, colors),
                                _MaterialViewMode.byProject =>
                                  _buildByProject(context, colors),
                              },
                      ],
                    ),
                  ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'materials_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มวัสดุ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'รายการวัสดุทั้งหมด',
            value: '${_materials.length}',
            unit: 'รายการ',
            icon: Icons.inventory_2_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'มูลค่าคงคลังรวม',
            value: formatBaht(_totalValue),
            unit: 'บาท',
            icon: Icons.savings_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RedKpiCard(
            label: 'ใกล้หมด',
            value: '$_lowStockCount',
            unit: 'รายการ',
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  // แจ้งชื่อวัสดุที่ใกล้หมดตรงๆ แทนที่จะให้ดูแค่ตัวเลขในการ์ดสรุปแล้วต้องไล่หา
  // เองว่ารายการไหนบ้าง
  /// แถบสลับโหมด "เลือกหลายรายการ" — ปิดอยู่โชว์แค่ปุ่มเปิดโหมดเล็กๆ ชิดขวา
  /// เปิดแล้วโชว์เป็นแถบเต็ม บอกจำนวนที่เลือก + ปุ่มเลือกทั้งหมด/ลบ/ยกเลิก
  /// (แพทเทิร์นเดียวกับหน้า Dashboard หลัก)
  /// [showActions] = false ใช้ตอนมุมมอง "แบ่งตามโครงการ" — ปุ่มพิมพ์บัญชี/
  /// เบิกจ่าย/ลบ ย้ายไปอยู่ในหัวการ์ดของแต่ละกลุ่มแทน (ดู _buildProjectGroup)
  /// กันไม่ให้ต้องเลื่อนกลับขึ้นมาบนสุดทุกครั้งที่จะกดใช้งานกับกลุ่มที่กำลังดูอยู่
  Widget _buildSelectionBar(BuildContext context, ColorScheme colors,
      {bool showActions = true}) {
    if (!_selectionMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _toggleSelectionMode,
          icon: const Icon(Icons.checklist_outlined, size: 18),
          label: const Text('เลือกหลายรายการ'),
        ),
      );
    }
    final filteredIds =
        _filtered.where((m) => m.id != null).map((m) => m.id!).toSet();
    final allSelected =
        filteredIds.isNotEmpty && _selectedMaterialIds.containsAll(filteredIds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(RadiusSize.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'เลือกแล้ว ${_selectedMaterialIds.length} รายการ'
              '${showActions ? '' : ' — ใช้ปุ่มพิมพ์บัญชี/เบิกจ่าย/ลบ ที่หัวการ์ดแต่ละโครงการ'}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: _toggleSelectAllFiltered,
            child: Text(allSelected
                ? 'ยกเลิกทั้งหมด'
                : 'เลือกทั้งหมด (${filteredIds.length})'),
          ),
          if (showActions) ...[
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: (_selectedMaterialIds.isEmpty || _exportingLedger)
                  ? null
                  : _exportLedgerSelected,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label:
                  Text('พิมพ์บัญชีที่เลือก (${_selectedMaterialIds.length})'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed:
                  _selectedMaterialIds.isEmpty ? null : _bulkWithdrawSelected,
              icon: const Icon(Icons.outbox_outlined, size: 18),
              label: Text('เบิกจ่าย (${_selectedMaterialIds.length})'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed:
                  _selectedMaterialIds.isEmpty ? null : _bulkDeleteSelected,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text('ลบ (${_selectedMaterialIds.length})'),
            ),
          ],
          const SizedBox(width: 4),
          TextButton(
            onPressed: _toggleSelectionMode,
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  /// ป้ายเตือน "มีโครงการที่ยังไม่ได้ดึงวัสดุ" — แจ้งเฉยๆ ไม่ได้บังคับดึง
  /// กดแล้วเปิดหน้าเลือกโครงการเดียวกับปุ่ม "ดึงจากโครงการ" ทันที (เลือกทีละ
  /// โครงการตามที่ตกลงกันไว้ ไม่รวมหลายโครงการพร้อมกัน)
  Widget _buildUnpulledOrdersBanner(BuildContext context, ColorScheme colors) {
    const maxShown = 3;
    final labels = _unpulledOrders.take(maxShown).map((o) {
      final docNumber = o.orderNumber ?? o.procurementNumber ?? '-';
      return (o.procurementSubject?.trim().isNotEmpty ?? false)
          ? o.procurementSubject!
          : docNumber;
    }).join(', ');
    final remainder = _unpulledOrders.length - maxShown;
    final message = remainder > 0
        ? 'มีโครงการใหม่ ${_unpulledOrders.length} รายการยังไม่ได้ดึงวัสดุ: $labels และอีก $remainder รายการ — กดเพื่อดึงเข้าคลัง'
        : 'มีโครงการใหม่ ${_unpulledOrders.length} รายการยังไม่ได้ดึงวัสดุ: $labels — กดเพื่อดึงเข้าคลัง';
    return InkWell(
      borderRadius: BorderRadius.circular(RadiusSize.sm),
      onTap: _pullFromProjectFlow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: BrandAccent.tealOn(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(RadiusSize.sm),
          border: Border.all(
              color: BrandAccent.tealOn(context).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.move_to_inbox_outlined,
                color: BrandAccent.tealOn(context), size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: BrandAccent.tealOn(context),
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right,
                color: BrandAccent.tealOn(context), size: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockBanner(BuildContext context, ColorScheme colors) {
    const maxShown = 4;
    final items = _lowStockItems;
    final shownNames = items.take(maxShown).map((m) => m.name).join(', ');
    final remainder = items.length - maxShown;
    final message = remainder > 0
        ? 'วัสดุใกล้หมด: $shownNames และอีก $remainder รายการ — ควรพิจารณาจัดซื้อเพิ่ม'
        : 'วัสดุใกล้หมด: $shownNames — ควรพิจารณาจัดซื้อเพิ่ม';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BrandAccent.red(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RadiusSize.sm),
        border:
            Border.all(color: BrandAccent.red(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: BrandAccent.red(context), size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: BrandAccent.red(context),
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// เลือก/ยกเลิกเลือกทั้งกลุ่มในมุมมอง "แบ่งตามโครงการ" — เปิดโหมดเลือกหลาย
  /// รายการให้อัตโนมัติถ้ายังไม่ได้เปิด เพื่อให้กดปุ่มในแถบเลือก (เบิกจ่าย/
  /// พิมพ์บัญชีที่เลือก/ลบ) ที่มีอยู่แล้วทำงานกับเฉพาะกลุ่มนี้ได้ทันที โดยไม่ต้อง
  /// สร้างปุ่ม action ใหม่ซ้ำซ้อนต่อกลุ่ม
  void _toggleGroupSelected(List<int> ids, {required bool select}) {
    setState(() {
      if (!_selectionMode) _selectionMode = true;
      if (select) {
        _selectedMaterialIds.addAll(ids);
      } else {
        _selectedMaterialIds.removeAll(ids);
      }
    });
  }

  /// มุมมอง "แบ่งตามโครงการ" — จัดกลุ่มวัสดุตามโครงการที่ดึงมา (ดูจาก
  /// _sourceProjectLabels) แก้ปัญหาที่ผู้ใช้ต้องดึงทีละโครงการ->เบิก->พิมพ์->
  /// ลบทั้งหมด->ดึงโครงการถัดไปวนซ้ำ เพราะตอนนี้เลือก/เบิก/พิมพ์/ลบ "เฉพาะ
  /// โครงการเดียว" ได้โดยไม่ต้องลบวัสดุโครงการอื่นทิ้งก่อน
  static const _unknownProjectGroupLabel = 'ไม่ทราบที่มา / เพิ่มเอง';

  Widget _buildByProject(BuildContext context, ColorScheme colors) {
    final groups = <String, List<MaterialItem>>{};
    for (final m in _filtered) {
      final label = m.id != null ? _sourceProjectLabels[m.id] : null;
      final key = (label != null && label.trim().isNotEmpty)
          ? label
          : _unknownProjectGroupLabel;
      groups.putIfAbsent(key, () => []).add(m);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == _unknownProjectGroupLabel) return 1;
        if (b == _unknownProjectGroupLabel) return -1;
        return a.compareTo(b);
      });
    final headerStyle = TextStyle(
        fontWeight: AppTypography.weightBold,
        fontSize: AppTypography.bodySmall,
        color: colors.onSurfaceVariant);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final key in sortedKeys)
              _buildProjectGroup(
                  context, colors, key, groups[key]!, headerStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectGroup(BuildContext context, ColorScheme colors,
      String label, List<MaterialItem> items, TextStyle headerStyle) {
    final ids = items.where((m) => m.id != null).map((m) => m.id!).toList();
    final allSelected =
        ids.isNotEmpty && ids.every(_selectedMaterialIds.contains);
    final totalValue = items.fold<double>(0, (sum, m) => sum + m.totalValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(RadiusSize.card),
        boxShadow: AppShadows.light1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: BrandAccent.surface2(context),
                border: Border(bottom: BorderSide(color: colors.outline))),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 18, color: BrandAccent.tealOn(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: AppTypography.weightBold,
                          fontSize: AppTypography.body,
                          color: colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                    '${items.length} รายการ • มูลค่า ${formatBaht(totalValue)}',
                    style: TextStyle(
                        fontSize: AppTypography.bodySmall,
                        color: colors.onSurfaceVariant)),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: ids.isEmpty
                      ? null
                      : () => _toggleGroupSelected(ids, select: !allSelected),
                  child: Text(
                      allSelected ? 'ยกเลิกเลือกกลุ่มนี้' : 'เลือกทั้งกลุ่ม'),
                ),
              ],
            ),
          ),
          if (_selectionMode) _buildGroupActionRow(context, colors, ids),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text('รหัส', style: headerStyle)),
                Expanded(flex: 3, child: Text('ชื่อวัสดุ', style: headerStyle)),
                SizedBox(width: 90, child: Text('ประเภท', style: headerStyle)),
                SizedBox(
                    width: 80,
                    child: Text('รับเข้า',
                        style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(
                    width: 80,
                    child: Text('จ่ายออก',
                        style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(
                    width: 80,
                    child: Text('คงเหลือ',
                        style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(
                    width: 100,
                    child: Text('มูลค่ารวม',
                        style: headerStyle, textAlign: TextAlign.right)),
                const SizedBox(width: 206),
              ],
            ),
          ),
          for (final m in items) _buildRow(context, colors, m),
        ],
      ),
    );
  }

  /// แถบ action (พิมพ์บัญชี/เบิกจ่าย/ลบ) เฉพาะของกลุ่มนี้ — โผล่เฉพาะตอนมีรายการ
  /// ในกลุ่มนี้ถูกเลือกอยู่อย่างน้อย 1 รายการ ทำงานกับแค่ [groupIds] เท่านั้น
  /// ไม่กระทบรายการที่เลือกไว้ในกลุ่มอื่น แก้ปัญหาที่ต้องเลื่อนกลับขึ้นไปแถบ
  /// บนสุดทุกครั้งที่จะใช้งานกับโครงการที่กำลังดูอยู่
  Widget _buildGroupActionRow(
      BuildContext context, ColorScheme colors, List<int> groupIds) {
    final selectedInGroup =
        groupIds.where(_selectedMaterialIds.contains).toList();
    if (selectedInGroup.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: colors.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: Text('เลือกแล้ว ${selectedInGroup.length} รายการในกลุ่มนี้',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant)),
          ),
          OutlinedButton.icon(
            onPressed: _exportingLedger
                ? null
                : () => _exportLedgerSelected(ids: selectedInGroup),
            icon: const Icon(Icons.receipt_long_outlined, size: 16),
            label: Text('พิมพ์บัญชี (${selectedInGroup.length})'),
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _bulkWithdrawSelected(ids: selectedInGroup),
            icon: const Icon(Icons.outbox_outlined, size: 16),
            label: Text('เบิกจ่าย (${selectedInGroup.length})'),
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _bulkDeleteSelected(ids: selectedInGroup),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text('ลบ (${selectedInGroup.length})'),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, ColorScheme colors) {
    final headerStyle = TextStyle(
        fontWeight: AppTypography.weightBold,
        fontSize: AppTypography.bodySmall,
        color: colors.onSurfaceVariant);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: BrandAccent.surface2(context),
                    border: Border(bottom: BorderSide(color: colors.outline))),
                child: Row(
                  children: [
                    SizedBox(
                        width: 90, child: Text('รหัส', style: headerStyle)),
                    Expanded(
                        flex: 3, child: Text('ชื่อวัสดุ', style: headerStyle)),
                    SizedBox(
                        width: 90, child: Text('ประเภท', style: headerStyle)),
                    SizedBox(
                        width: 80,
                        child: Text('รับเข้า',
                            style: headerStyle, textAlign: TextAlign.right)),
                    SizedBox(
                        width: 80,
                        child: Text('จ่ายออก',
                            style: headerStyle, textAlign: TextAlign.right)),
                    SizedBox(
                        width: 80,
                        child: Text('คงเหลือ',
                            style: headerStyle, textAlign: TextAlign.right)),
                    SizedBox(
                        width: 100,
                        child: Text('มูลค่ารวม',
                            style: headerStyle, textAlign: TextAlign.right)),
                    const SizedBox(width: 206),
                  ],
                ),
              ),
              for (final m in _filtered) _buildRow(context, colors, m),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, ColorScheme colors, MaterialItem m) {
    final lowStock = m.isLowStock;
    final selected = m.id != null && _selectedMaterialIds.contains(m.id);
    return InkWell(
      onTap: _selectionMode
          ? (m.id == null ? null : () => _toggleOneSelected(m.id!))
          : () => _openForm(existing: m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? colors.primaryContainer.withValues(alpha: 0.25) : null,
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            if (_selectionMode) ...[
              Checkbox(
                  value: selected,
                  onChanged:
                      m.id == null ? null : (_) => _toggleOneSelected(m.id!)),
              const SizedBox(width: 4),
            ],
            SizedBox(
                width: 90,
                child: Text(m.materialCode ?? '-',
                    style: TextStyle(
                        fontSize: AppTypography.bodyMedium,
                        color: colors.onSurfaceVariant))),
            Expanded(
                flex: 3,
                child: Text(m.name,
                    style: TextStyle(
                        fontSize: AppTypography.body,
                        fontWeight: AppTypography.weightSemiBold,
                        color: colors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 90,
                child: Text(m.category ?? '-',
                    style: TextStyle(
                        fontSize: AppTypography.bodyMedium,
                        color: colors.onSurfaceVariant))),
            SizedBox(
                width: 80,
                child: Text(m.stockIn.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: AppTypography.body,
                        color: colors.onSurface))),
            SizedBox(
                width: 80,
                child: Text(m.stockOut.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: AppTypography.body,
                        color: colors.onSurface))),
            SizedBox(
              width: 80,
              child: Text('${m.remaining.toStringAsFixed(0)} ${m.unit ?? ""}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: AppTypography.body,
                      fontWeight: AppTypography.weightBold,
                      color: lowStock
                          ? BrandAccent.red(context)
                          : colors.onSurface)),
            ),
            SizedBox(
                width: 100,
                child: Text(formatBaht(m.totalValue),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: AppTypography.body,
                        color: colors.onSurface))),
            // ซ่อนปุ่ม action ต่อแถวไว้ตอนอยู่ในโหมดเลือกหลายรายการ กันกดพลาด
            // โดนลบ/ปรับสต๊อกทีละชิ้นขณะกำลังจะติ๊กเลือกหลายรายการ
            SizedBox(
              width: 206,
              child: _selectionMode
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        DsActionIconButtons(
                          actions: [
                            DsRowAction(
                                icon: Icons.history,
                                tooltip: 'ดูประวัติรับ-จ่าย',
                                onTap: () => _viewHistory(m)),
                          ],
                        ),
                        const SizedBox(width: 3),
                        _StockAdjustButton(
                            icon: Icons.add_circle_outline,
                            tooltip: 'รับเข้า',
                            color: BrandAccent.green(context),
                            onTap: () => _adjustStock(m, isIn: true)),
                        const SizedBox(width: 3),
                        _StockAdjustButton(
                            icon: Icons.remove_circle_outline,
                            tooltip: 'เบิกจ่าย',
                            color: BrandAccent.tertiary(context),
                            onTap: () => _adjustStock(m, isIn: false)),
                        const SizedBox(width: 3),
                        DsActionIconButtons(
                          actions: [
                            DsRowAction(
                                icon: Icons.copy_all_outlined,
                                tooltip: 'คัดลอกวัสดุ',
                                onTap: () => _duplicateMaterial(m)),
                            DsRowAction(
                                icon: Icons.delete_outline,
                                tooltip: 'ลบ',
                                onTap: () => _confirmDelete(m),
                                danger: true),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, ColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      // ฝังอยู่ใน SingleChildScrollView ของหน้าทั้งหน้าแล้ว (ให้หัวหน้าเลื่อน
      // ไปพร้อมกับรายการ) เลยต้องปิดสกอลล์ของตัวเองไม่ให้ซ้อนกัน 2 ชั้น
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final m = _filtered[i];
        final lowStock = m.isLowStock;
        final selected = m.id != null && _selectedMaterialIds.contains(m.id);
        return InkWell(
          borderRadius: BorderRadius.circular(RadiusSize.card),
          onTap: _selectionMode
              ? (m.id == null ? null : () => _toggleOneSelected(m.id!))
              : () => _openForm(existing: m),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer.withValues(alpha: 0.25)
                  : colors.surface,
              border: Border.all(
                  color: selected ? colors.primary : colors.outline,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(RadiusSize.card),
              boxShadow: AppShadows.light1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_selectionMode)
                      Checkbox(
                          value: selected,
                          onChanged: m.id == null
                              ? null
                              : (_) => _toggleOneSelected(m.id!))
                    else
                      Icon(Icons.inventory_outlined,
                          color: BrandAccent.tealOn(context), size: 20),
                    const Spacer(),
                    if (m.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: BrandAccent.teal(context)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(RadiusSize.sm)),
                        child: Text(m.category!,
                            style: TextStyle(
                                fontSize: AppTypography.micro,
                                color: BrandAccent.tealOn(context))),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m.name,
                    style: TextStyle(
                        fontWeight: AppTypography.weightBold,
                        fontSize: AppTypography.heading4,
                        color: colors.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text(
                    'คงเหลือ ${m.remaining.toStringAsFixed(0)} ${m.unit ?? ""}',
                    style: TextStyle(
                        fontSize: AppTypography.body,
                        fontWeight: AppTypography.weightBold,
                        color: lowStock
                            ? BrandAccent.red(context)
                            : BrandAccent.tealOn(context))),
                Text('${formatBaht(m.totalValue)} บาท',
                    style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: colors.onSurfaceVariant)),
                // ซ่อนปุ่ม action ไว้ตอนอยู่ในโหมดเลือกหลายรายการ เหมือนตาราง
                if (!_selectionMode) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _adjustStock(m, isIn: true),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(RadiusSize.sm)),
                          ),
                          child: Icon(Icons.add,
                              size: 16, color: BrandAccent.green(context)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _adjustStock(m, isIn: false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(RadiusSize.sm)),
                          ),
                          child: Icon(Icons.remove,
                              size: 16, color: BrandAccent.tertiary(context)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _viewHistory(m),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(RadiusSize.sm)),
                          ),
                          child: Icon(Icons.history,
                              size: 16, color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// การ์ด KPI โทนแดง — KpiCard ของดีไซน์ระบบไม่มี variant สีแดงในชุดโทเค็น จึง
/// ต้องสร้างเองแยกต่างหาก แต่ต้องเลียนแบบโครงสร้างจริงของ KpiCard ให้ครบ (แถบสี
/// บนสุด + ไอคอนในกล่องสี่เหลี่ยมมุมมน + ตัวเลขใหญ่) ไม่งั้นจะดูไม่เข้าชุดกับ
/// การ์ดข้างๆ ที่เป็น KpiCard จริง (เคยพลาดมาแล้ว — ทำแค่กล่องสีจางๆ ไม่มีไอคอน)
class _RedKpiCard extends StatelessWidget {
  const _RedKpiCard(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon});
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = BrandAccent.red(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: Border.all(color: colors.outline),
        boxShadow: AppShadows.light1,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(color: accent, boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 14)
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: Dimensions.kpiIconSize,
                      height: Dimensions.kpiIconSize,
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(RadiusSize.md)),
                      child: Icon(icon, size: IconSizes.md, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: AppTypography.caption,
                              fontWeight: AppTypography.weightBold,
                              color: colors.onSurfaceVariant,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppTypography.display1,
                              fontWeight: AppTypography.weightExtraBold,
                              letterSpacing: -1.1,
                              height: 1,
                              color: colors.onSurface)),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(unit,
                          style: TextStyle(
                              fontSize: AppTypography.caption,
                              fontWeight: AppTypography.weightBold,
                              color: colors.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ปุ่มปรับสต๊อก (รับเข้า/เบิกจ่าย) ในมุมมองตาราง — คงสีเขียว/ส้มไว้ให้เห็นชัดว่า
/// เป็นการเพิ่ม/ลดของ ต่างจาก DsActionIconButtons ที่ใช้สีเดียว (navy) กับทุกปุ่ม
/// เพราะสีที่นี่มีความหมายเชิงสถานะ ไม่ใช่แค่ตกแต่ง
class _StockAdjustButton extends StatefulWidget {
  const _StockAdjustButton(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_StockAdjustButton> createState() => _StockAdjustButtonState();
}

class _StockAdjustButtonState extends State<_StockAdjustButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(RadiusSize.sm),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? widget.color : colors.surface,
              borderRadius: BorderRadius.circular(RadiusSize.sm),
              border: Border.all(color: _hover ? widget.color : colors.outline),
            ),
            child: Icon(widget.icon,
                size: IconSizes.md,
                color: _hover ? Colors.white : widget.color),
          ),
        ),
      ),
    );
  }
}

class _MaterialFormDialog extends StatefulWidget {
  final MaterialItem? existing;
  const _MaterialFormDialog({this.existing});
  @override
  State<_MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<_MaterialFormDialog> {
  final _repo = ProcurementRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _unitPriceCtrl;
  late final TextEditingController _sizeSpecCtrl;
  late final TextEditingController _storageLocationCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _maxStockCtrl;
  late final FocusNode _nameFocusNode;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _codeCtrl = TextEditingController(text: m?.materialCode ?? '');
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _unitCtrl = TextEditingController(text: m?.unit ?? '');
    _unitPriceCtrl =
        TextEditingController(text: m?.unitPrice?.toStringAsFixed(2) ?? '');
    _sizeSpecCtrl = TextEditingController(text: m?.sizeSpec ?? '');
    _storageLocationCtrl =
        TextEditingController(text: m?.storageLocation ?? '');
    _minStockCtrl =
        TextEditingController(text: m?.minStock?.toStringAsFixed(0) ?? '');
    _maxStockCtrl =
        TextEditingController(text: m?.maxStock?.toStringAsFixed(0) ?? '');
    _category = m?.category;
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) _autofillFromName();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _unitPriceCtrl.dispose();
    _sizeSpecCtrl.dispose();
    _storageLocationCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// พอออกจากช่อง "ชื่อวัสดุ" — ถ้าเจอวัสดุอื่นในระบบที่ชื่อตรงกันเป๊ะ (เช่น
  /// รายการที่เคยถูกดึงมาจากโครงการแล้วมีแค่ชื่อ/หน่วย/ราคา ไม่มีรายละเอียด
  /// เพิ่มเติม) ให้เติมช่องที่ยังว่างอยู่ (ประเภท/ขนาด/ที่เก็บ/จำนวนอย่างต่ำ-สูง/
  /// ราคา) จากรายการนั้นให้อัตโนมัติ — เติมเฉพาะช่องที่ว่างเท่านั้น ไม่ทับข้อมูล
  /// ที่ผู้ใช้กรอกเองไว้แล้ว ถ้าไม่เจอรายการซ้ำชื่อเลยก็ลองเดา "ประเภทวัสดุ"
  /// จากคำในชื่อแทน
  Future<void> _autofillFromName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final all = await _repo.getAllMaterials();
    if (!mounted) return;
    MaterialItem? match;
    for (final other in all) {
      if (other.id != null && other.id == widget.existing?.id) continue;
      if (other.name.trim().toLowerCase() == name.toLowerCase()) {
        match = other;
        break;
      }
    }
    if (match != null) {
      var filledAny = false;
      setState(() {
        if (_category == null && match!.category != null) {
          _category = match.category;
          filledAny = true;
        }
        if (_unitCtrl.text.trim().isEmpty &&
            (match!.unit?.trim().isNotEmpty ?? false)) {
          _unitCtrl.text = match.unit!;
          filledAny = true;
        }
        if (_unitPriceCtrl.text.trim().isEmpty && match!.unitPrice != null) {
          _unitPriceCtrl.text = match.unitPrice!.toStringAsFixed(2);
          filledAny = true;
        }
        if (_sizeSpecCtrl.text.trim().isEmpty &&
            (match!.sizeSpec?.trim().isNotEmpty ?? false)) {
          _sizeSpecCtrl.text = match.sizeSpec!;
          filledAny = true;
        }
        if (_storageLocationCtrl.text.trim().isEmpty &&
            (match!.storageLocation?.trim().isNotEmpty ?? false)) {
          _storageLocationCtrl.text = match.storageLocation!;
          filledAny = true;
        }
        if (_minStockCtrl.text.trim().isEmpty && match!.minStock != null) {
          _minStockCtrl.text = match.minStock!.toStringAsFixed(0);
          filledAny = true;
        }
        if (_maxStockCtrl.text.trim().isEmpty && match!.maxStock != null) {
          _maxStockCtrl.text = match.maxStock!.toStringAsFixed(0);
          filledAny = true;
        }
      });
      if (filledAny)
        showAppToast(
            'เติมข้อมูลจากรายการ "${match.name}" ที่มีอยู่แล้วให้อัตโนมัติ');
    }
    _guessCategoryIfEmpty();
  }

  void _guessCategoryIfEmpty() {
    if (_category != null) return;
    setState(() => _category = _guessMaterialCategory(_nameCtrl.text));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // การันตีว่าเดาประเภทแล้วก่อนบันทึกเสมอ — เผื่อผู้ใช้พิมพ์ชื่อแล้วกด
    // "บันทึก" ทันทีโดยไม่เผลอออกจากช่องชื่อก่อน (เช่น กด Enter/กดปุ่มตรงๆ)
    // ซึ่งจะไม่ทัน trigger blur listener ของช่องชื่อ
    _guessCategoryIfEmpty();
    setState(() => _saving = true);
    final m = MaterialItem(
      id: widget.existing?.id,
      materialCode:
          _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      category: _category,
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      stockIn: widget.existing?.stockIn ?? 0,
      stockOut: widget.existing?.stockOut ?? 0,
      unitPrice: double.tryParse(_unitPriceCtrl.text.trim()),
      sizeSpec:
          _sizeSpecCtrl.text.trim().isEmpty ? null : _sizeSpecCtrl.text.trim(),
      storageLocation: _storageLocationCtrl.text.trim().isEmpty
          ? null
          : _storageLocationCtrl.text.trim(),
      minStock: double.tryParse(_minStockCtrl.text.trim()),
      maxStock: double.tryParse(_maxStockCtrl.text.trim()),
    );
    if (widget.existing == null) {
      await _repo.insertMaterial(m);
    } else {
      await _repo.updateMaterial(m);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title:
          Text(isEdit ? 'แก้ไขวัสดุ' : 'เพิ่มวัสดุ', style: _dialogTitleStyle),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClearableTextField(
                    controller: _codeCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context,
                        label: 'รหัสวัสดุ', hint: 'เช่น MAT-001'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClearableTextField(
                    controller: _nameCtrl,
                    focusNode: _nameFocusNode,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context,
                        label: 'ชื่อวัสดุ *', hint: 'เช่น กระดาษ A4'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณากรอกชื่อวัสดุ'
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _category,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(context,
                            label: 'ประเภทวัสดุ')
                        .copyWith(
                            floatingLabelBehavior: FloatingLabelBehavior.auto),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('(ไม่ระบุ)')),
                      ..._materialCategories.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: ClearableTextField(
                          controller: _unitCtrl,
                          style: _dialogFieldStyle,
                          decoration: _dialogFieldDecoration(context,
                              label: 'หน่วยนับ', hint: 'เช่น ชิ้น, กล่อง'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: ClearableTextField(
                          controller: _unitPriceCtrl,
                          style: _dialogFieldStyle,
                          keyboardType: TextInputType.number,
                          decoration: _dialogFieldDecoration(context,
                              label: 'ราคาต่อหน่วย', hint: 'เช่น 120.00'),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClearableTextField(
                    controller: _sizeSpecCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context,
                        label: 'ขนาดหรือลักษณะ', hint: 'เช่น 180 แกรม, A4'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClearableTextField(
                    controller: _storageLocationCtrl,
                    style: _dialogFieldStyle,
                    decoration: _dialogFieldDecoration(context,
                        label: 'ที่เก็บ', hint: 'เช่น ห้องพัสดุ ชั้น 2'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: ClearableTextField(
                          controller: _minStockCtrl,
                          style: _dialogFieldStyle,
                          keyboardType: TextInputType.number,
                          decoration: _dialogFieldDecoration(context,
                              label: 'จำนวนอย่างต่ำ', hint: 'เช่น 10'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: ClearableTextField(
                          controller: _maxStockCtrl,
                          style: _dialogFieldStyle,
                          keyboardType: TextInputType.number,
                          decoration: _dialogFieldDecoration(context,
                              label: 'จำนวนอย่างสูง', hint: 'เช่น 100'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'จำนวนรับเข้า/เบิกจ่าย ปรับได้ทีหลังจากปุ่ม +รับเข้า / -เบิกจ่าย ในตาราง',
                      style: TextStyle(
                          fontSize: AppTypography.bodySmall,
                          color: colors.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
              padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: _dialogButtonPadding,
              textStyle: _dialogButtonTextStyle),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
