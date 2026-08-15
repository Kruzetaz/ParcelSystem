// dashboard_screen_v2.dart
// Dashboard หน้าใหม่ — ใช้ design system จาก mockup dashboard-finalv2
// แทนที่ dashboard_screen.dart เดิม

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/budget.dart';
import '../models/inspection.dart';
import '../models/school_settings.dart';
import '../services/document_generator.dart';
import '../services/fiscal_year_controller.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../utils/thai_date.dart';
import '../widgets/design_system/design_system.dart';
import '../theme/design_tokens.dart';

/// ปุ่มลัดเสริมที่ผู้ใช้เลือกเพิ่ม/ลดเองได้ในเมนูด่วน — แยกจาก 5 ปุ่มพื้นฐาน
/// (สร้างใหม่/แผนงบ/ตั้งค่า/ตั้งค่า AI/รีเฟรช) ที่บังคับแสดงตลอด — ย้ายมาจาก
/// dashboard_screen.dart (v1) ที่มีฟีเจอร์นี้อยู่แล้ว แค่เปลี่ยน AppMode เป็น
/// String key ให้ตรงกับ onNavigate ของ v2
class _OptionalQuickAction {
  final String id;
  final IconData icon;
  final String label;
  final String mode;
  const _OptionalQuickAction({required this.id, required this.icon, required this.label, required this.mode});
}

const _optionalQuickActionsCatalog = [
  _OptionalQuickAction(id: 'easy_wizard', icon: Icons.auto_awesome_outlined, label: 'Easy Wizard', mode: 'easy_wizard'),
  _OptionalQuickAction(id: 'procurement_calendar', icon: Icons.event_note_outlined, label: 'ปฏิทินงานพัสดุ', mode: 'procurement_calendar'),
  _OptionalQuickAction(id: 'tor', icon: Icons.description_outlined, label: 'TOR/คุณลักษณะ', mode: 'tor'),
  _OptionalQuickAction(id: 'contracts', icon: Icons.article_outlined, label: 'บริหารสัญญา', mode: 'contracts'),
  _OptionalQuickAction(id: 'guarantees', icon: Icons.shield_outlined, label: 'หลักประกัน', mode: 'guarantees'),
  _OptionalQuickAction(id: 'inspections', icon: Icons.fact_check_outlined, label: 'ตรวจรับพัสดุ', mode: 'inspections'),
  _OptionalQuickAction(id: 'installment_contracts', icon: Icons.event_repeat_outlined, label: 'สัญญาต่อเนื่องหลายงวด', mode: 'installment_contracts'),
  _OptionalQuickAction(id: 'document_hub', icon: Icons.file_copy_outlined, label: 'สร้างเอกสารราชการ', mode: 'document_hub'),
  _OptionalQuickAction(id: 'order_register', icon: Icons.numbers_outlined, label: 'ทะเบียนคุมเลขที่', mode: 'order_register'),
  _OptionalQuickAction(id: 'control_log', icon: Icons.receipt_long_outlined, label: 'ทะเบียนคุมเลขบันทึก/TOR', mode: 'control_log'),
  _OptionalQuickAction(id: 'fixed_assets', icon: Icons.inventory_2_outlined, label: 'ทะเบียนครุภัณฑ์', mode: 'fixed_assets'),
  _OptionalQuickAction(id: 'repair_history', icon: Icons.build_outlined, label: 'ประวัติซ่อมครุภัณฑ์', mode: 'repair_history'),
  _OptionalQuickAction(id: 'materials', icon: Icons.inventory_outlined, label: 'วัสดุ/คลังพัสดุ', mode: 'materials'),
  _OptionalQuickAction(id: 'annual_count', icon: Icons.checklist_outlined, label: 'ตรวจนับประจำปี', mode: 'annual_count'),
  _OptionalQuickAction(id: 'disposals', icon: Icons.delete_sweep_outlined, label: 'จำหน่ายพัสดุ', mode: 'disposals'),
  _OptionalQuickAction(id: 'reports', icon: Icons.bar_chart_outlined, label: 'รายงาน/สตง.', mode: 'reports'),
];

const _quickActionsPrefsKey = 'dashboard_quick_actions_v1';

/// รายการ "ครบกำหนดเร็วๆ นี้" หนึ่งแถว — ผูกกับ order/inspection จริง (ไม่ใช่
/// ข้อมูลตัวอย่าง) เพื่อให้กดแล้วเปิดเอกสารที่เกี่ยวข้องได้จริง
class _DeadlineEntry {
  final DateTime date;
  final String taskType;
  final String projectLabel;
  final String controlNumber;
  final ProcurementOrder? order;
  const _DeadlineEntry({
    required this.date,
    required this.taskType,
    required this.projectLabel,
    required this.controlNumber,
    this.order,
  });
}

enum _OrderStatusKind { missingEgp, overdue, completed, inProgress, draft }

// ความกว้างคอลัมน์ตรงกับ colgroup ใน mockup พอดี (88/auto/155/110/120/130/144)
const _orderColumns = [
  DsColumn('เลขที่ / วันที่', width: 88),
  DsColumn('โครงการ › กิจกรรม', flex: 3),
  DsColumn('ร้านค้า / วิธีจัดซื้อ', width: 155),
  DsColumn('วงเงิน / สุทธิ', width: 110, align: TextAlign.right),
  DsColumn('สถานะ', width: 120, align: TextAlign.center),
  // ลดจาก 130/144 ลงมาหน่อย — เนื้อหาจริง (หลอด 70px + ป้าย% / ปุ่มไอคอน 4 อัน)
  // ไม่ได้ต้องการพื้นที่มากขนาดนั้น เหลือช่องว่างตรงกลางระหว่างสองคอลัมน์นี้
  // เยอะเกินไปเมื่อก่อน
  DsColumn('ความคืบหน้า', width: 116),
  DsColumn('ดำเนินการ', width: 130, align: TextAlign.right),
];

class DashboardScreenV2 extends StatefulWidget {
  final VoidCallback onCreateNew;
  final void Function(ProcurementOrder order) onEditOrder;
  final void Function(String mode) onNavigate; // simplified for now
  final void Function(ProcurementOrder order) onGenerateDocument;
  // ตัวกรองเริ่มต้นตอนเปิดหน้า — ใช้ตอนกดรายการในปุ่มกระดิ่งแจ้งเตือนที่
  // AppShell แล้วอยากพามาที่นี่พร้อมกรองให้ตรงหมวดที่กดไว้เลย (เช่นกด "ไม่มี
  // เลข e-GP" ก็ควรเห็นรายการที่ขาดจริงๆ ไม่ใช่ต้องมานั่งหากรองเอง)
  final String? initialFilter;

  const DashboardScreenV2({
    super.key,
    required this.onCreateNew,
    required this.onEditOrder,
    required this.onNavigate,
    required this.onGenerateDocument,
    this.initialFilter,
  });

  @override
  State<DashboardScreenV2> createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends State<DashboardScreenV2> {
  final _repo = ProcurementRepository();
  final _searchCtrl = TextEditingController();

  List<ProcurementOrder> _orders = [];
  List<Budget> _budgets = [];
  List<Inspection> _inspections = [];
  SchoolSettings? _school;
  bool _loading = true;
  String _query = '';
  late String _filter = widget.initialFilter ?? 'all';
  String _sortMode = 'latest';
  static const _sortOptions = {
    'latest': 'แก้ไข/สร้างล่าสุดก่อน',
    'oldest': 'เก่าสุดก่อน',
    'control_asc': 'เลขที่ ซ./จ. น้อย → มาก',
    'control_desc': 'เลขที่ ซ./จ. มาก → น้อย',
  };

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  int? _expandedOrderId;
  bool _bulkGenerating = false;

  int _currentPage = 1;
  int _pageSize = 10;
  static const _pageSizeOptions = [5, 10, 15, 20, 25];

  // ปุ่มลัดเสริมที่ผู้ใช้เลือกเปิดไว้ในเมนูด่วน — จำไว้ในเครื่องนี้ (ไม่ผูกกับ
  // โรงเรียน/ผู้ใช้คนอื่น) โหลดตอนเปิดหน้าครั้งแรก
  Set<String> _enabledQuickActionIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadQuickActionPrefs();
    FiscalYearController.instance.addListener(_onFiscalYearChanged);
  }

  Future<void> _loadQuickActionPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _enabledQuickActionIds = (prefs.getStringList(_quickActionsPrefsKey) ?? []).toSet());
  }

  Future<void> _saveQuickActionPrefs(Set<String> ids) async {
    setState(() => _enabledQuickActionIds = ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_quickActionsPrefsKey, ids.toList());
  }

  /// เปิดกล่องแก้ไขเมนูด่วน — 5 ปุ่มพื้นฐานติ๊กค้างไว้แก้ไม่ได้ ส่วนปุ่มเสริมอื่นๆ
  /// เลือกเพิ่ม/ลดได้อิสระ
  Future<void> _openQuickActionsEditor() async {
    var draft = Set<String>.from(_enabledQuickActionIds);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('แก้ไขเมนูด่วน'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('5 ปุ่มพื้นฐาน (บังคับแสดงเสมอ)',
                      style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightSemiBold)),
                  for (final label in const ['สร้างใหม่', 'แผนงบ', 'ตั้งค่า', 'ตั้งค่า AI', 'รีเฟรช'])
                    CheckboxListTile(
                      value: true,
                      onChanged: null,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(label, style: const TextStyle(fontSize: AppTypography.body)),
                    ),
                  const Divider(height: 20),
                  const Text('ปุ่มเสริม (เลือกเพิ่ม/ลดได้ตามต้องการ)',
                      style: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightSemiBold)),
                  for (final a in _optionalQuickActionsCatalog)
                    CheckboxListTile(
                      value: draft.contains(a.id),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(a.label, style: const TextStyle(fontSize: AppTypography.body)),
                      secondary: Icon(a.icon, size: 18),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          draft.add(a.id);
                        } else {
                          draft.remove(a.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
          ],
        ),
      ),
    );
    if (saved == true) await _saveQuickActionPrefs(draft);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    FiscalYearController.instance.removeListener(_onFiscalYearChanged);
    super.dispose();
  }

  void _onFiscalYearChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final viewingYear = FiscalYearController.instance.viewingYear;
    final orders = _query.trim().isEmpty
        ? await _repo.getAllOrders(fiscalYear: viewingYear)
        : await _repo.searchOrders(_query.trim(), fiscalYear: viewingYear);
    final budgets = await _repo.getAllBudgets(fiscalYear: viewingYear);
    final inspections = await _repo.getAllInspections(fiscalYear: viewingYear);
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _budgets = budgets;
      _inspections = inspections;
      _school = school;
      _loading = false;
    });
  }

  // KPI calculations
  int get _draftCount => _orders.where((o) => o.currentStatus != 'COMPLETED').length;
  int get _completedCount => _orders.where((o) => o.currentStatus == 'COMPLETED').length;
  double get _totalSpent => _orders
      .where((o) => o.currentStatus == 'COMPLETED')
      .fold(0.0, (sum, o) => sum + (o.currentOrderPrice ?? 0));
  // "ผูกพันรอเบิก" — โครงการที่มีวงเงินตั้งไว้แล้ว (มีร้านค้า/ราคาแล้ว) แต่ยังไม่
  // เสร็จสมบูรณ์ (ยังไม่เบิกจ่ายจริง) ต่างจาก _totalSpent ที่นับเฉพาะเสร็จแล้ว
  double get _totalCommitted => _orders
      .where((o) => o.currentStatus != 'COMPLETED')
      .fold(0.0, (sum, o) => sum + (o.currentOrderPrice ?? 0));
  double get _totalAllocatedBudget =>
      _budgets.fold(0.0, (sum, b) => sum + (b.allocatedAmount ?? 0));
  // เดิมรวม Budget.remainingAmount ตรงๆ ซึ่งเป็นคอลัมน์ที่ไม่เคยถูกหักลดตามการ
  // ใช้จ่ายจริงเลย (เท่ากับ allocatedAmount เสมอ) — เปลี่ยนมาหักลบยอดที่ออร์เดอร์
  // "เสร็จสมบูรณ์" ที่ผูกกับแผนงบ (budgetId) ใช้ไปจริงแทน ให้ตรงกับตรรกะเดียวกัน
  // ที่ใช้ในกราฟ "งบประมาณตามฝ่าย/กลุ่มงาน" ด้านล่างและหน้าแผนงบประมาณ ไม่ให้
  // สองหน้าโชว์ตัวเลข "คงเหลือ" ไม่ตรงกัน
  double get _totalSpentLinkedToBudget => _orders
      .where((o) => o.currentStatus == 'COMPLETED' && o.budgetId != null)
      .fold(0.0, (sum, o) => sum + (o.currentOrderPrice ?? 0));
  double get _totalRemainingBudget => _totalAllocatedBudget - _totalSpentLinkedToBudget;
  // "รอตรวจรับพัสดุ" — รายการตรวจรับที่ยังไม่บันทึกวันที่รับมอบจริง
  int get _pendingInspectionCount =>
      _inspections.where((i) => i.actualDeliveryDate == null || i.actualDeliveryDate!.trim().isEmpty).length;

  /// "ครบกำหนดเร็วๆ นี้" — รวม 2 แหล่งที่มาจริง: วันครบกำหนดส่งมอบงานของ order
  /// (dateDeadline) ที่ยังไม่เสร็จ + วันครบกำหนดตรวจรับของ inspection ที่ยังไม่
  /// ได้บันทึกวันรับมอบจริง เรียงจากใกล้ครบที่สุดก่อน (เกินกำหนดแล้วขึ้นบนสุด)
  List<_DeadlineEntry> get _upcomingDeadlines {
    final entries = <_DeadlineEntry>[];
    for (final o in _orders) {
      if (o.currentStatus == 'COMPLETED') continue;
      final d = parseThaiDate(o.dateDeadline);
      if (d == null) continue;
      entries.add(_DeadlineEntry(
        date: d,
        taskType: 'ส่งมอบงาน',
        projectLabel: o.projectName ?? o.procurementSubject ?? '(ไม่มีชื่อโครงการ)',
        controlNumber: o.procurementNumber ?? '-',
        order: o,
      ));
    }
    for (final i in _inspections) {
      if ((i.actualDeliveryDate ?? '').trim().isNotEmpty) continue;
      final d = parseThaiDate(i.dueDate);
      if (d == null) continue;
      ProcurementOrder? order;
      for (final o in _orders) {
        if (o.id != null && o.id == i.orderId) {
          order = o;
          break;
        }
      }
      entries.add(_DeadlineEntry(
        date: d,
        taskType: 'ตรวจรับพัสดุ',
        projectLabel: order?.projectName ?? order?.procurementSubject ?? '(ไม่มีชื่อโครงการ)',
        controlNumber: order?.procurementNumber ?? i.inspectionNumber ?? '-',
        order: order,
      ));
    }
    // ไม่จำกัดช่วงเวลา — เอารายการใกล้ครบ/เกินกำหนดที่สุด 6 อันดับแรกเสมอ ไม่ว่า
    // จะเก่าหรือไกลแค่ไหน กันไม่ให้โครงการเก่าที่ยังไม่จบหลุดลืมไปจากสายตา
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries.take(6).toList();
  }

  String _deadlineDaysLabel(DateTime due) {
    final today = DateTime.now();
    final diff = DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff < 0) return 'เกินกำหนด ${-diff} วัน';
    if (diff == 0) return 'ครบกำหนดวันนี้';
    if (diff == 1) return 'พรุ่งนี้';
    return 'อีก $diff วัน';
  }

  List<ProcurementOrder> get _filteredOrders {
    List<ProcurementOrder> list;
    switch (_filter) {
      case 'draft':
        list = _orders.where((o) => o.currentStatus != 'COMPLETED').toList();
        break;
      case 'completed':
        list = _orders.where((o) => o.currentStatus == 'COMPLETED').toList();
        break;
      case 'under5k':
        list = _orders.where((o) => (o.currentOrderPrice ?? 0) > 0 && o.currentOrderPrice! <= 5000).toList();
        break;
      case 'w804':
        list = _orders
            .where((o) => (o.currentOrderPrice ?? 0) > 5000 && o.currentOrderPrice! <= 50000)
            .toList();
        break;
      case 'missing_egp':
        list = _orders.where(_egpRequiredButMissing).toList();
        break;
      case 'deadline':
        // ตรรกะเดียวกับ _notifDeadlineCount ฝั่ง AppShell (นับเฉพาะฝั่งเอกสาร
        // ที่นี่ — ฝั่งตรวจรับพัสดุมีปุ่มลัดของตัวเองแยกไปหน้าตรวจรับพัสดุแล้ว)
        list = _orders
            .where((o) => o.currentStatus != 'COMPLETED' && parseThaiDate(o.dateDeadline) != null)
            .toList();
        break;
      default:
        list = List<ProcurementOrder>.from(_orders);
    }
    final sorted = List<ProcurementOrder>.from(list);
    switch (_sortMode) {
      case 'control_asc':
      case 'control_desc':
        sorted.sort((a, b) {
          final an = _controlNumberValue(a);
          final bn = _controlNumberValue(b);
          // เอกสารที่ยังไม่มีเลขที่ไปอยู่ท้ายสุดเสมอไม่ว่าจะเรียงทิศไหน —
          // เดิมใช้วิธีสร้าง sort key เป็น String แล้วเทียบด้วย compareTo ตรงๆ
          // (ใส่ 'zzzzzz' ไว้ปลาย ๆ หวังให้มาท้ายสุด) แต่พังเพราะอักษรไทย
          // (โค้ดยูนิโค้ด ~0E01 ขึ้นไป) มีค่าตัวเลข "สูงกว่า" ตัวอักษรละติน z
          // (0x7A) เสมอ — เทียบ String ข้ามภาษาแบบนี้ทำให้ 'zzzzzz' ดันไปเรียง
          // "ก่อน" เลขที่จริงทุกรายการที่มีคำนำหน้าไทย (ตรงข้ามกับที่ตั้งใจไว้
          // เป๊ะ) เปลี่ยนมาเทียบเป็นตัวเลขจริงแยกจาก string เทียบข้ามภาษาไปเลย
          if (an == null && bn == null) return 0;
          if (an == null) return 1;
          if (bn == null) return -1;
          // ผู้ใช้ต้องการให้เรียงตาม "ตัวเลข" ล้วนๆ ข้ามคำนำหน้า (ซ./จ./ช. ฯลฯ)
          // ไม่แยกกลุ่มตามคำนำหน้าก่อนแล้วค่อยเรียงเลขในกลุ่ม
          return _sortMode == 'control_asc' ? an.compareTo(bn) : bn.compareTo(an);
        });
        break;
      case 'oldest':
        sorted.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
        break;
      default: // 'latest'
        sorted.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    }
    return sorted;
  }

  /// ดึงเฉพาะตัวเลขจาก procurementNumber (เช่น "ซ00/2569" -> 0, "จ56/2569" ->
  /// 56) — จับเลขที่อยู่หลังคำนำหน้าและก่อน "/ปีงบประมาณ" โดยตรง คืนค่า null
  /// ถ้าไม่มีเลขที่/รูปแบบไม่ตรงเลย
  int? _controlNumberValue(ProcurementOrder o) {
    final raw = o.procurementNumber?.trim();
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'^([^\d]*)(\d+)/').firstMatch(raw) ?? RegExp(r'^([^\d]*)(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(2) ?? '');
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _currentPage = 1;
    });
  }

  /// คัดลอกโครงการ — ใช้ toMap()/fromMap() round-trip แทนการไล่ก็อปทีละฟิลด์
  /// (ตัวโมเดลมี 60+ ฟิลด์ ไล่มือเสี่ยงตกหล่น) แล้วเคลียร์ id/เลขที่เอกสาร/สถานะ
  /// ให้เป็นของใหม่ล้วนๆ ไม่ชนกับต้นฉบับ — คัดลอกรายการสินค้า (items) ไปด้วย
  Future<void> _duplicateOrder(ProcurementOrder order) async {
    final items = order.id != null ? await _repo.getItems(order.id!) : <ProcurementItem>[];
    final map = order.toMap()
      ..remove('id')
      ..['procurement_number'] = null
      ..['order_number'] = null
      ..['egp_project_id'] = null
      ..['contract_control_number'] = null
      ..['inspection_control_number'] = null
      ..['current_status'] = 'DRAFT'
      ..['progress_percent'] = 0.0;
    final newOrder = ProcurementOrder.fromMap(map);
    final newItems = [
      for (final i in items)
        ProcurementItem(itemName: i.itemName, quantity: i.quantity, unit: i.unit, unitPrice: i.unitPrice),
    ];
    await _repo.saveOrderWithItems(newOrder, newItems);
    if (!mounted) return;
    showAppToast('คัดลอกโครงการแล้ว — แก้ไขเลขที่/รายละเอียดที่ยังว่างอยู่ได้ที่หน้าสร้างใหม่');
    _load();
  }

  Future<void> _confirmDeleteOrder(ProcurementOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบเอกสารนี้?'),
        content: Text(
          'จะลบ "${order.projectName ?? order.procurementSubject ?? "เอกสารนี้"}" ทิ้งถาวร '
          'พร้อมรายการสินค้าทั้งหมดในเอกสาร การลบนี้กู้คืนไม่ได้',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบทิ้งถาวร'),
          ),
        ],
      ),
    );
    if (confirmed != true || order.id == null) return;
    await _repo.deleteOrder(order.id!);
    if (!mounted) return;
    showAppToast('ลบเอกสารแล้ว');
    _load();
  }

  /// ปุ่มลัด "สร้างเอกสาร" แบบเลือกหลายรายการ — สร้างเอกสารหลัก (ชุดเต็ม) ของ
  /// ทุกรายการที่ติ๊กไว้รวดเดียว (ไม่เปิด Word ทีละไฟล์เพราะจะเปิดหน้าต่างรัว
  /// เกินไปถ้าเลือกเยอะ) เสร็จแล้วเปิดโฟลเดอร์ที่เก็บไฟล์ให้ครั้งเดียว — พอร์ตมา
  /// จาก dashboard_screen.dart (v1) ที่มีฟีเจอร์นี้อยู่แล้ว
  Future<void> _bulkGenerateSelected() async {
    final school = _school;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    final selectedOrders = _orders.where((o) => _selectedIds.contains(o.id)).toList();
    if (selectedOrders.isEmpty) return;

    setState(() => _bulkGenerating = true);
    var successCount = 0;
    String? lastFolderPath;
    for (final order in selectedOrders) {
      try {
        final items = await _repo.getItems(order.id!);
        final file = await DocumentGenerator.generate(order: order, school: school, items: items);
        lastFolderPath = file.parent.path;
        successCount++;
      } catch (_) {
        // ข้ามรายการที่สร้างไม่สำเร็จ ไปต่อรายการถัดไป แล้วสรุปจำนวนที่สำเร็จ
        // ให้ดูตอนจบแทน ไม่ให้ทั้งชุดหยุดกลางคันเพราะรายการเดียวมีปัญหา
      }
    }
    if (!mounted) return;
    setState(() => _bulkGenerating = false);
    final failCount = selectedOrders.length - successCount;
    showAppToast(
      failCount == 0
          ? 'สร้างเอกสารสำเร็จ $successCount ฉบับ'
          : 'สร้างเอกสารสำเร็จ $successCount ฉบับ (ไม่สำเร็จ $failCount รายการ)',
      isError: failCount > 0 && successCount == 0,
    );
    if (lastFolderPath != null) await DocumentGenerator.openFolder(lastFolderPath);
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// ขั้นตอนกระบวนการจัดซื้อของ order นี้ — เดาสถานะ "ทำแล้ว/กำลังทำ/ยังไม่ถึง"
  /// จากวันที่ที่กรอกไว้จริงในแต่ละขั้น (ไม่มีฟิลด์ "แต่งตั้งกรรมการ"/"ลงทะเบียนพัสดุ"
  /// แยกในโมเดล จึงใช้ dateAnnouncement และสถานะ COMPLETED แทนตามลำดับ)
  List<TimelineStep> _timelineStepsFor(ProcurementOrder o) {
    bool has(String? d) => d != null && d.trim().isNotEmpty;
    final steps = [
      TimelineStep(
        label: 'บันทึกขออนุมัติ',
        date: formatThaiDateShort(o.dateMemoUsed),
        state: has(o.dateMemoUsed) ? TimelineStepState.done : TimelineStepState.pending,
      ),
      TimelineStep(
        label: 'แต่งตั้งกรรมการ',
        date: formatThaiDateShort(o.dateAnnouncement),
        state: has(o.dateAnnouncement) ? TimelineStepState.done : TimelineStepState.pending,
      ),
      TimelineStep(
        label: 'ใบสั่งซื้อ/สัญญา',
        date: formatThaiDateShort(o.dateContractSigned),
        state: has(o.dateContractSigned) ? TimelineStepState.done : TimelineStepState.pending,
      ),
      TimelineStep(
        label: 'ตรวจรับพัสดุ',
        date: formatThaiDateShort(o.dateInspection),
        state: has(o.dateInspection) ? TimelineStepState.done : TimelineStepState.pending,
      ),
      TimelineStep(
        label: 'เบิกจ่าย',
        date: formatThaiDateShort(o.dateDisbursement),
        state: has(o.dateDisbursement) ? TimelineStepState.done : TimelineStepState.pending,
      ),
      TimelineStep(
        label: 'ลงทะเบียนพัสดุ',
        state: o.currentStatus == 'COMPLETED' ? TimelineStepState.done : TimelineStepState.pending,
      ),
    ];
    final lastDoneIndex = steps.lastIndexWhere((s) => s.state == TimelineStepState.done);
    final nextIndex = lastDoneIndex + 1;
    if (nextIndex < steps.length && steps[nextIndex].state == TimelineStepState.pending) {
      steps[nextIndex] = TimelineStep(
        label: steps[nextIndex].label,
        date: steps[nextIndex].date,
        state: TimelineStepState.current,
      );
    }
    return steps;
  }

  String _progressSubStep(List<TimelineStep> steps) {
    final current = steps.firstWhere(
      (s) => s.state != TimelineStepState.done,
      orElse: () => steps.last,
    );
    if (current.state == TimelineStepState.done) return 'เสร็จสมบูรณ์';
    return 'ค้างที่ ${current.label}';
  }

  /// สถานะรวมของ order — คำนวณครั้งเดียวแล้วใช้ทั้งป้ายสถานะและสีหลอด
  /// ความคืบหน้า (ต้องสีเดียวกันเสมอตาม mockup) กันไม่ให้ตรรกะสถานะแยกกันคนละที่
  /// แล้วขัดกันภายหลัง — ลำดับความสำคัญตาม mockup: ไม่มีเลข e-GP มาก่อนเสมอ
  /// (แม้จะเกินกำหนดหรือคืบหน้าไปแล้วก็ตาม)
  /// ไม่มีเลข e-GP "จริงๆ" ต้องรีบแก้ — ไม่นับรายการที่ได้รับยกเว้นตามกฎหมาย
  /// (จัดซื้อจัดจ้างวงเงินไม่เกิน 5,000 บาท ไม่ต้องลงระบบ e-GP อยู่แล้วตาม
  /// พ.ร.บ.จัดซื้อจัดจ้างฯ 2560) ไม่งั้นรายการเล็กๆ พวกนี้จะโดนติดธงแดงเป็น
  /// "ปัญหา" ทั้งที่ไม่ได้ทำอะไรผิด
  bool _egpRequiredButMissing(ProcurementOrder o) {
    final hasEgp = o.egpProjectId?.trim().isNotEmpty ?? false;
    if (hasEgp) return false;
    final exempt = (o.currentOrderPrice ?? 0) > 0 && o.currentOrderPrice! <= 5000;
    return !exempt;
  }

  _OrderStatusKind _statusKindFor(ProcurementOrder o, List<TimelineStep> steps) {
    if (_egpRequiredButMissing(o)) return _OrderStatusKind.missingEgp;
    if (o.currentStatus == 'COMPLETED') return _OrderStatusKind.completed;
    final deadline = parseThaiDate(o.dateDeadline);
    if (deadline != null && deadline.isBefore(DateTime.now())) return _OrderStatusKind.overdue;
    final started = steps.any((s) => s.state != TimelineStepState.pending);
    if (!started) return _OrderStatusKind.draft;
    return _OrderStatusKind.inProgress;
  }

  Widget _statusPillFor(_OrderStatusKind kind) {
    switch (kind) {
      case _OrderStatusKind.missingEgp:
        return const StatusBadge(label: 'ไม่มีเลข e-GP', variant: BadgeVariant.danger, compact: true);
      case _OrderStatusKind.completed:
        return const StatusBadge(label: 'เสร็จสิ้น', variant: BadgeVariant.success, compact: true);
      case _OrderStatusKind.overdue:
        return const StatusBadge(label: 'เกินกำหนด', variant: BadgeVariant.warning, compact: true);
      case _OrderStatusKind.draft:
        return const StatusBadge(label: 'ร่าง', variant: BadgeVariant.neutral, compact: true);
      case _OrderStatusKind.inProgress:
        return const StatusBadge(label: 'กำลังดำเนินการ', variant: BadgeVariant.info, compact: true);
    }
  }

  /// สีหลอดความคืบหน้า — ไล่ตาม % ตรงๆ (ไม่อิงสถานะ) 100% ถือว่าเสร็จสมบูรณ์
  /// เป็นสีเขียวเสมอ ต่ำกว่านั้นไล่จากแดง(เพิ่งเริ่ม)→ส้ม→น้ำเงิน(ใกล้เสร็จ)
  Color _progressColorFor(double progress) {
    if (progress >= 1.0) return BrandAccent.green(context);
    if (progress >= 0.7) return BrandAccent.blue(context);
    if (progress >= 0.4) return BrandAccent.tertiary(context);
    return BrandAccent.red(context);
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    // ปุ่มยังไม่ active ใช้กระจกฝ้าแบบ mockup (.gbt) — ปุ่ม active (พื้นทึบ
    // ทึบแสง) ไม่ต้องเบลอเพราะพื้นหลังทึบอยู่แล้วมองไม่ออกว่ามี blur หรือไม่
    // ประหยัด BackdropFilter ไปได้จุดหนึ่ง
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusSize.lg),
      child: (active
          ? Container(
              decoration: BoxDecoration(
                color: BrandAccent.teal(context),
                borderRadius: BorderRadius.circular(RadiusSize.lg),
                border: Border.all(color: BrandAccent.teal(context)),
              ),
              child: _headerButtonContent(active, icon, label),
            )
          : GlassContainer(
              color: colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(RadiusSize.lg),
              border: Border.all(color: colorScheme.outline),
              child: _headerButtonContent(active, icon, label),
            )),
    );
  }

  Widget _headerButtonContent(bool active, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    // mockup .gbt (ปุ่มไม่ active) ใช้ color:var(--on) (สีตัวหนังสือเต็มความ
    // สว่าง) ไม่ใช่ var(--on-var) (สีจาง) — ของเดิมใช้ onSurfaceVariant ผิดไป
    // ทำให้ปุ่มดูจางกลืนพื้นหลังกว่าที่ตั้งใจไว้ในโหมดมืด
    final inactiveColor = colorScheme.onSurface;
    return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? Colors.white : inactiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.bodySmall,
                fontWeight: AppTypography.weightBold,
                color: active ? Colors.white : inactiveColor,
              ),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: BrandAccent.background(context),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // mockup จำกัดความกว้างเนื้อหาไว้ที่ 1150px เสมอ (.wrap{max-width:
          // 1150px;margin:0 auto}) ไม่ว่าหน้าจอจะกว้างแค่ไหน — ของเดิมไม่เคยใส่
          // ขอบเขตนี้เลย ปล่อยให้เนื้อหายืดเต็มความกว้างหน้าต่าง บนจอกว้างๆ
          // การ์ด/โดนัทที่เป็น fixed-size (เช่น donut 100px) เลยดูเล็ก/บางลีบ
          // เทียบกับการ์ดที่ยืดเกินสัดส่วนที่ตั้งใจไว้ — ใส่ Center+ConstrainedBox
          // ครอบตรงนี้เพื่อจำกัดความกว้างเหมือน mockup จริงๆ
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Dimensions.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.all(Dimensions.pageMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroSection(colorScheme),
                    SizedBox(height: Dimensions.sectionGap),
                    _buildAlertSection(colorScheme),
                    SizedBox(height: Dimensions.sectionGap),
                    _buildKpiSection(colorScheme),
                    SizedBox(height: Dimensions.sectionGap),
                    _buildMainContent(colorScheme),
                    SizedBox(height: Dimensions.sectionGap),
                    _buildBudgetChart(colorScheme),
                    // FAB "สร้างใหม่" ลอยตายตัวมุมขวาล่างเสมอ (ไม่ได้เลื่อนไป
                    // กับเนื้อหา) — ถ้าการ์ดสุดท้าย (งบประมาณตามฝ่าย) มีหลาย
                    // แถวจนสูงเลยพื้นที่จอ ปุ่มจะลอยทับบังแถวท้ายๆ ไว้ถาวร
                    // เพราะเลื่อนจนสุดแล้วก็ยังโดนปุ่มบังอยู่ดี — กันที่ว่างท้าย
                    // สุดไว้ให้พอเลื่อนพ้นปุ่มได้จริง
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onCreateNew,
        backgroundColor: BrandAccent.teal(context),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        // mockup .fab ตัวหนา 800 (extraBold) ไม่ใช่ 700 (bold ธรรมดา)
        label: const Text('สร้างใหม่', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  static const _thaiMonths = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  String get _todayThaiLabel {
    final now = DateTime.now();
    return '${now.day} ${_thaiMonths[now.month]} ${now.year + 543}';
  }

  Widget _buildHeroSection(ColorScheme colorScheme) {
    final school = _school;
    final subtitleParts = [
      'ปีงบประมาณ ${FiscalYearController.instance.viewingYear}',
      if (school?.schoolAmphoe?.isNotEmpty == true) 'อ.${school!.schoolAmphoe}',
      if (school?.schoolChangwat?.isNotEmpty == true) 'จ.${school!.schoolChangwat}',
      'ข้อมูล ณ $_todayThaiLabel',
    ];

    final allocated = _totalAllocatedBudget;
    final spent = _totalSpent;
    final committed = _totalCommitted;
    final spentPct = allocated > 0 ? (spent / allocated * 100) : 0.0;
    final committedPct = allocated > 0 ? (committed / allocated * 100) : 0.0;
    final unusedPct = (100 - spentPct - committedPct).clamp(0.0, 100.0);
    final unused = (allocated - spent - committed).clamp(0.0, double.infinity);

    return HeroCard(
      icon: Icons.school,
      title: school?.schoolName?.isNotEmpty == true ? school!.schoolName! : 'โครงการงบประมาณ',
      subtitle: subtitleParts.join(' · '),
      moneyItems: [
        MoneyItem(
          label: 'วงเงินที่ได้รับจัดสรร',
          value: formatBaht(allocated),
          unit: 'บาท',
        ),
      ],
      progressLabel: 'สัดส่วนการใช้งบประมาณ',
      progressValue: spent + committed,
      progressTotal: allocated,
      progressPercentage: spentPct + committedPct,
      donutCenterPercentage: spentPct,
      donutCenterLabel: 'เบิกจ่ายแล้ว',
      donutSegments: [
        DonutSegment(spentPct, const Color(0xFF22C55E)),
        DonutSegment(committedPct, const Color(0xFFFB923C)),
        DonutSegment(unusedPct, Colors.white.withValues(alpha: 0.22)),
      ],
      legendItems: [
        HeroDonutLegendItem(color: const Color(0xFF22C55E), label: 'เบิกจ่ายแล้ว', value: formatBaht(spent)),
        HeroDonutLegendItem(color: const Color(0xFFFB923C), label: 'ผูกพันรอเบิก', value: formatBaht(committed)),
        HeroDonutLegendItem(
          color: Colors.white.withValues(alpha: 0.2),
          outlined: true,
          label: 'ยังไม่ใช้',
          value: formatBaht(unused),
        ),
      ],
    );
  }

  Widget _buildAlertSection(ColorScheme colorScheme) {
    final missingEgpCount = _orders.where(_egpRequiredButMissing).length;

    final alerts = <Widget>[
      if (missingEgpCount > 0)
        AlertTile(
          icon: Icons.error_outline,
          count: missingEgpCount,
          message: 'รายการยังไม่มีเลขที่ e-GP ต้องกรอกตาม ม.23 พ.ร.บ.จัดซื้อจัดจ้างฯ 2560',
          variant: BadgeVariant.danger,
          onTap: () => _setFilter('missing_egp'),
        ),
      if (_draftCount > 0)
        AlertTile(
          icon: Icons.edit_note,
          count: _draftCount,
          message: 'เอกสารร่างที่ยังไม่เสร็จ รอดำเนินการ',
          variant: BadgeVariant.warning,
          onTap: () => _setFilter('draft'),
        ),
      if (_pendingInspectionCount > 0)
        AlertTile(
          icon: Icons.fact_check_outlined,
          count: _pendingInspectionCount,
          message: 'รอตรวจรับพัสดุ ยังไม่บันทึกวันที่รับมอบ',
          variant: BadgeVariant.info,
          onTap: () => widget.onNavigate('inspections'),
        ),
    ];

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (int i = 0; i < alerts.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: alerts[i]),
        ],
      ],
    );
  }

  Widget _buildKpiSection(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'เอกสารทั้งหมด',
            value: '${_orders.length}',
            subtitle: 'ร่าง $_draftCount • เสร็จ $_completedCount',
            icon: Icons.description_outlined,
            variant: KpiCardVariant.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'เสร็จสมบูรณ์',
            value: '$_completedCount',
            subtitle: _orders.isEmpty
                ? '-'
                : '${(_completedCount / _orders.length * 100).toStringAsFixed(0)}% ของทั้งหมด',
            icon: Icons.check_circle_outline,
            variant: KpiCardVariant.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'ยอดใช้จ่ายรวม',
            value: formatBaht(_totalSpent),
            unit: 'บาท',
            subtitle: 'เฉพาะเอกสารที่เสร็จแล้ว',
            icon: Icons.payments_outlined,
            variant: KpiCardVariant.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: KpiCard(
            label: 'งบประมาณคงเหลือ',
            value: formatBaht(_totalRemainingBudget),
            unit: 'บาท',
            subtitle: '${_orders.length} รายการ',
            icon: Icons.account_balance_wallet_outlined,
            variant: KpiCardVariant.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main table area
        Expanded(
          child: AppCard(
            // titleWidget แทน title ธรรมดา — ให้ badge นับจำนวนรายการติดอยู่
            // ข้างๆ หัวข้อเลย ตรงกับ mockup (.ch h3 + .ch .nb ติดกัน) เดิมเอา
            // badge ไปไว้ใน titleAction ซึ่งโดน WrapAlignment.spaceBetween ดัน
            // ไปไกลจากหัวข้อ (กลุ่มเดียวกับช่องค้นหา/ปุ่มต่างๆ ฝั่งขวาสุด)
            titleWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'รายการจัดซื้อจัดจ้าง',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.heading4,
                    fontWeight: AppTypography.weightExtraBold,
                  ),
                ),
                const SizedBox(width: 8),
                // ตรงกับ .ch .nb ใน mockup — พื้นเทาอ่อน มุมมนเต็ม
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: BrandAccent.surface2(context),
                    borderRadius: BorderRadius.circular(RadiusSize.full),
                  ),
                  child: Text(
                    '${_filteredOrders.length} รายการ',
                    style: TextStyle(
                      fontSize: AppTypography.micro,
                      fontWeight: AppTypography.weightBold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            padding: EdgeInsets.zero,
            titleAction: Wrap(
              spacing: 7,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // ช่องค้นหาย้ายมาอยู่แถวเดียวกับหัวการ์ด/ปุ่มต่างๆ ตรงกับ
                // mockup (.ch .sbox) — เดิมอยู่แยกแถวข้างล่างใต้ชิปกรอง ทำให้
                // เสียพื้นที่แนวตั้งไปโดยไม่จำเป็น ความกว้าง 240 ตาม
                // mockup (min-width:240px) แทนความกว้างเริ่มต้น 290 ที่กว้าง
                // เกินไปเมื่อต้องอยู่ปนกับปุ่มอื่นในแถวเดียวกัน
                SearchField(
                  controller: _searchCtrl,
                  hintText: 'ค้นหาเลขที่ / โครงการ / ร้านค้า...',
                  // ลดจาก 240 ลงมาอีกหน่อย — พื้นที่หัวการ์ดต้องแบ่งให้ทั้งชื่อ
                  // การ์ด+badge, ช่องค้นหา, ปุ่ม 2 ปุ่ม, ลิงก์เรียงลำดับ รวมกัน
                  // ในบรรทัดเดียว 240 กว้างไปจนต้องตกไปอีกบรรทัดบ่อย
                  width: 190,
                  onSubmitted: (v) {
                    _query = v;
                    _currentPage = 1;
                    _load();
                  },
                ),
                _headerActionButton(
                  icon: Icons.checklist_outlined,
                  label: 'เลือกหลายรายการ',
                  active: _selectionMode,
                  onTap: () => setState(() {
                    _selectionMode = !_selectionMode;
                    _expandedOrderId = null;
                    if (!_selectionMode) _selectedIds.clear();
                  }),
                ),
                _headerActionButton(
                  icon: Icons.description_outlined,
                  label: 'สร้างเอกสาร',
                  active: true,
                  onTap: () => widget.onNavigate('document_hub'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'เรียงลำดับ',
                  onSelected: (v) => setState(() => _sortMode = v),
                  offset: const Offset(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    side: BorderSide(color: colorScheme.outline),
                  ),
                  elevation: 6,
                  itemBuilder: (context) => [
                    for (final entry in _sortOptions.entries)
                      PopupMenuItem(
                        value: entry.key,
                        height: 36,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              child: _sortMode == entry.key
                                  ? Icon(Icons.check, size: 15, color: BrandAccent.tealOn(context))
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: AppTypography.bodySmall,
                                fontWeight: _sortMode == entry.key
                                    ? AppTypography.weightBold
                                    : AppTypography.weightMedium,
                                color: _sortMode == entry.key ? BrandAccent.tealOn(context) : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortOptions[_sortMode] ?? _sortOptions['latest']!,
                        style: TextStyle(
                          fontSize: AppTypography.bodySmall,
                          fontWeight: AppTypography.weightBold,
                          color: BrandAccent.tealOn(context),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.swap_vert, size: 13, color: BrandAccent.tealOn(context)),
                    ],
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Dimensions.cardPadding,
                    Dimensions.cardPadding,
                    Dimensions.cardPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Filter chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          DSFilterChip(
                            label: 'ทั้งหมด',
                            isSelected: _filter == 'all',
                            onTap: () => _setFilter('all'),
                          ),
                          DSFilterChip(
                            label: 'ร่าง',
                            isSelected: _filter == 'draft',
                            onTap: () => _setFilter('draft'),
                          ),
                          DSFilterChip(
                            label: 'เสร็จแล้ว',
                            isSelected: _filter == 'completed',
                            onTap: () => _setFilter('completed'),
                          ),
                          DSFilterChip(
                            label: 'เฉพาะเจาะจง ≤5,000 บาท',
                            isSelected: _filter == 'under5k',
                            onTap: () => _setFilter('under5k'),
                          ),
                          DSFilterChip(
                            label: 'ว.804 ≤50,000 บาท',
                            isSelected: _filter == 'w804',
                            onTap: () => _setFilter('w804'),
                          ),
                          DSFilterChip(
                            label: 'ไม่มีเลข e-GP',
                            isSelected: _filter == 'missing_egp',
                            isDanger: true,
                            onTap: () => _setFilter('missing_egp'),
                          ),
                          DSFilterChip(
                            label: 'ใกล้/เกินกำหนด',
                            isSelected: _filter == 'deadline',
                            onTap: () => _setFilter('deadline'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // Table
                _buildOrderTable(colorScheme),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Sidebar
        CollapsibleSidebar(
          width: 190,
          children: [
            SidebarSection(
              title: 'เมนูด่วน',
              trailingIcon: Icons.tune,
              trailingIconColor: BrandAccent.tealOn(context),
              onTrailingIconTap: _openQuickActionsEditor,
              child: QuickActionsGrid(
                actions: [
                  QuickAction(
                    icon: Icons.add,
                    label: 'สร้างใหม่',
                    onTap: widget.onCreateNew,
                  ),
                  QuickAction(
                    icon: Icons.description,
                    label: 'แผนงบ',
                    onTap: () => widget.onNavigate('budgets'),
                  ),
                  QuickAction(
                    icon: Icons.settings,
                    label: 'ตั้งค่า',
                    onTap: () => widget.onNavigate('settings'),
                  ),
                  QuickAction(
                    icon: Icons.auto_awesome,
                    label: 'ตั้งค่า AI',
                    onTap: () => widget.onNavigate('ai_settings'),
                  ),
                  QuickAction(
                    icon: Icons.refresh,
                    label: 'รีเฟรช',
                    onTap: _load,
                  ),
                  for (final a in _optionalQuickActionsCatalog)
                    if (_enabledQuickActionIds.contains(a.id))
                      QuickAction(
                        icon: a.icon,
                        label: a.label,
                        onTap: () => widget.onNavigate(a.mode),
                      ),
                ],
                crossAxisCount: 2,
              ),
            ),
            if (_upcomingDeadlines.isNotEmpty)
              SidebarSection(
                title: 'ครบกำหนดเร็ว ๆ นี้',
                count: _upcomingDeadlines.length,
                trailingIcon: Icons.calendar_today_outlined,
                child: Column(
                  children: [
                    for (final e in _upcomingDeadlines)
                      DeadlineListItem(
                        date: '${e.date.day}',
                        month: thaiMonthsAbbrev[e.date.month],
                        title: '${e.taskType} · ${e.projectLabel}',
                        subtitle: '${e.controlNumber} · ${_deadlineDaysLabel(e.date)}',
                        isUrgent: !e.date.isAfter(DateTime.now()),
                        onTap: e.order != null ? () => widget.onEditOrder(e.order!) : null,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTable(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filtered = _filteredOrders;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty ? 'ไม่พบผลการค้นหา' : 'ไม่มีเอกสารในหมวดนี้',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: AppTypography.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999999);
    final page = _currentPage.clamp(1, totalPages);
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);

    // ผลรวมความกว้างคอลัมน์แบบ fixed ทั้งหมด + ความกว้างขั้นต่ำของคอลัมน์
    // "โครงการ › กิจกรรม" (flex) — ใช้ตัดสินใจว่าต้องเลื่อนแนวนอนแทนหรือไม่
    // กันปัญหา RenderFlex overflow ตอนหน้าต่างแคบ/เปิด sidebar ขวาพร้อมกัน
    // ตัวเลขนี้ตั้งใจให้เล็กพอที่จะไม่ทำงานในสภาพปกติ (ตอนนี้เนื้อหาทั้งหน้าถูก
    // จำกัดไว้ที่ 1150px แล้ว พื้นที่ตารางจริงจึงคาดเดาได้แคบกว่าเดิม ถ้าตั้งเลข
    // นี้สูงไปจะเลื่อนแนวนอนทุกครั้งโดยไม่จำเป็นเหมือนที่เจอมาแล้ว) — 100px ยังพอ
    // ให้ ellipsis ข้อความสั้นๆ อ่านได้ ไม่ใช่ตัวเลขที่ต้องแม่นเป๊ะ แค่กันพังจริงๆ
    const minFlexColumnWidth = 100.0;
    final fixedColumnsWidth = _orderColumns.fold<double>(0, (sum, c) => sum + (c.width ?? 0));
    final leadingWidth = _selectionMode ? 34.0 : 0.0;
    final minTableWidth = fixedColumnsWidth + minFlexColumnWidth + leadingWidth;

    final tableBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTableHeader(
          columns: _orderColumns,
          leading: _selectionMode ? const SizedBox(width: 34) : null,
        ),
        for (int i = 0; i < pageItems.length; i++) _buildTableRow(colorScheme, pageItems[i], start + i),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectionMode)
          SelectionBar(
            selectedCount: _selectedIds.length,
            totalCount: filtered.length,
            onSelectAll: () => setState(
              () => _selectedIds.addAll(filtered.map((o) => o.id).whereType<int>()),
            ),
            onCancel: () => setState(() {
              _selectionMode = false;
              _selectedIds.clear();
            }),
            onCopyToCurrentYear: _selectedIds.isEmpty
                ? null
                : () => showAppToast('ฟีเจอร์คัดลอกไปปีงบปัจจุบันยังไม่เปิดใช้งาน'),
            onGenerateDocuments: _selectedIds.isEmpty || _bulkGenerating
                ? null
                : _bulkGenerateSelected,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= minTableWidth) return tableBody;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minTableWidth, child: tableBody),
            );
          },
        ),
        PaginationBar(
          currentPage: page,
          totalPages: totalPages,
          pageSize: _pageSize,
          pageSizeOptions: _pageSizeOptions,
          totalItems: filtered.length,
          onPageChanged: (p) => setState(() => _currentPage = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _currentPage = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildTableRow(ColorScheme colorScheme, ProcurementOrder order, int index) {
    final id = order.id;
    final isExpanded = id != null && _expandedOrderId == id;
    final isSelected = id != null && _selectedIds.contains(id);
    final steps = _timelineStepsFor(order);
    final statusKind = _statusKindFor(order, steps);
    final progress = order.progressPercent.clamp(0.0, 1.0);
    final netPayable = order.netPayableAmount;
    final currentPrice = order.currentOrderPrice;
    final amountNote = (netPayable != null && currentPrice != null && netPayable != currentPrice)
        ? 'สุทธิ ${formatBaht(netPayable)}'
        : 'ไม่หักภาษี';

    return DsTableRow(
      index: index,
      selected: isSelected,
      warn: _egpRequiredButMissing(order),
      // โหมดเลือกหลายรายการ: กดที่ไหนของแถวก็ได้ (ไม่ใช่แค่ช่องติ๊ก) เพื่อ
      // เลือก/ยกเลิกเลือก แทนที่จะกางไทม์ไลน์ — ปิดการกางไทม์ไลน์ไปเลยระหว่าง
      // อยู่โหมดนี้ กันสับสนว่ากดแล้วจะเลือกหรือจะกาง
      onTap: id == null
          ? null
          : _selectionMode
              ? () => setState(() {
                    if (_selectedIds.contains(id)) {
                      _selectedIds.remove(id);
                    } else {
                      _selectedIds.add(id);
                    }
                  })
              : () => setState(() => _expandedOrderId = isExpanded ? null : id),
      // SizedBox(width:34) เฉยๆ (ไม่มี Center) จะบีบให้ DsCheckbox (ปกติ
      // สี่เหลี่ยมจัตุรัส 15x15) ยืดกว้างเป็น 34x15 กลายเป็นผืนผ้า — ต้อง Center
      // ครอบไว้ให้ DsCheckbox คงขนาดจัตุรัสของตัวเองแล้ว "อยู่กึ่งกลาง" ในพื้นที่
      // ที่กันไว้ 34px แทนที่จะถูกบีบยืดตาม
      leading: _selectionMode
          ? SizedBox(
              width: 34,
              child: Center(
                child: DsCheckbox(
                  value: isSelected,
                  onChanged: id == null
                      ? null
                      : (v) => setState(() {
                            if (v) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          }),
                ),
              ),
            )
          : null,
      cells: [
        DsCell(
          column: _orderColumns[0],
          child: DsTwoLineCell(
            primary: order.procurementNumber ?? '-',
            secondary: formatThaiDateShort(order.dateOrderCreated),
          ),
        ),
        DsCell(
          column: _orderColumns[1],
          child: DsTwoLineCell(
            primary: order.procurementSubject ?? order.activityName ?? '(ไม่มีชื่อกิจกรรม)',
            secondary: order.projectName,
          ),
        ),
        DsCell(
          column: _orderColumns[2],
          child: DsVendorTag(
            name: order.vendorName ?? '(ไม่ระบุร้านค้า)',
            methodLabel: order.procurementMethod,
          ),
        ),
        DsCell(
          column: _orderColumns[3],
          child: DsAmountCell(amount: '${formatBaht(currentPrice ?? 0)}', note: amountNote),
        ),
        DsCell(column: _orderColumns[4], child: Center(child: _statusPillFor(statusKind))),
        DsCell(
          column: _orderColumns[5],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // จำกัดความยาวหลอดไว้ (ไม่ใช้ Expanded ยืดเต็มคอลัมน์เหมือน
                  // เดิม) — สั้นลงให้ดูกระชับ ไม่ยาวเทอะทะจนกินพื้นที่ทั้งคอลัมน์
                  SizedBox(
                    width: 70,
                    child: ProgressBar(
                      progress: progress,
                      height: 4,
                      color: _progressColorFor(progress),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: AppTypography.tiny,
                      fontWeight: AppTypography.weightBold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _progressSubStep(steps),
                style: TextStyle(
                  fontSize: AppTypography.nano,
                  fontWeight: AppTypography.weightSemiBold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DsCell(
          column: _orderColumns[6],
          child: DsActionIconButtons(actions: [
            // ลำดับ/ไอคอนตรงกับ mockup พอดี (visibility, description, copy_all,
            // delete) — ของเดิมใช้ไอคอนดินสอ "แก้ไข" แทนไอคอนตา ซึ่งไม่ตรงกับ
            // mockup แต่ยังใช้ onEditOrder ตัวเดียวกัน เพราะแอปนี้ยังไม่มีหน้า
            // "ดูตัวอย่างอย่างเดียว" แยกจากหน้าแก้ไขจริงๆ
            DsRowAction(
              icon: Icons.visibility_outlined,
              tooltip: 'เปิดเอกสาร',
              onTap: () => widget.onEditOrder(order),
            ),
            DsRowAction(
              icon: Icons.description_outlined,
              tooltip: 'สร้างเอกสาร',
              onTap: () => widget.onGenerateDocument(order),
            ),
            DsRowAction(
              icon: Icons.copy_all_outlined,
              tooltip: 'คัดลอกโครงการ',
              onTap: () => _duplicateOrder(order),
            ),
            DsRowAction(
              icon: Icons.delete_outline,
              tooltip: 'ลบ',
              danger: true,
              onTap: () => _confirmDeleteOrder(order),
            ),
          ]),
        ),
      ],
      expandedContent: isExpanded
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: BrandAccent.surface2(context),
                border: Border(top: BorderSide(color: colorScheme.outline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'ขั้นตอนการจัดซื้อ — ${order.procurementNumber ?? ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.bodySmall,
                            fontWeight: AppTypography.weightBold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => widget.onEditOrder(order),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'เปิดเอกสาร',
                              style: TextStyle(
                                fontSize: AppTypography.bodySmall,
                                fontWeight: AppTypography.weightBold,
                                color: BrandAccent.tealOn(context),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.open_in_new, size: 13, color: BrandAccent.tealOn(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ProcurementTimeline(steps: steps),
                ],
              ),
            )
          : null,
    );
  }


  Widget _buildBudgetChart(ColorScheme colorScheme) {
    final budgetsByDept = _getBudgetByDepartment();
    if (budgetsByDept.isEmpty) return const SizedBox.shrink();
    final usedByDept = _getUsedByDepartment();

    return AppCard(
      title: 'งบประมาณตามฝ่าย/กลุ่มงาน',
      collapsible: true,
      titleAction: InkWell(
        onTap: () => widget.onNavigate('budgets'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ไปหน้าแผนงบประมาณ',
              style: TextStyle(
                fontSize: AppTypography.bodySmall,
                fontWeight: AppTypography.weightBold,
                color: BrandAccent.tealOn(context),
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: BrandAccent.tealOn(context)),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _legendDot(colorScheme, BrandAccent.teal(context).withValues(alpha: 0.2), 'วงเงินที่ได้รับจัดสรร (100%)'),
                const SizedBox(width: 14),
                _legendDot(colorScheme, BrandAccent.teal(context), 'ใช้ไปแล้ว (% ของที่ได้รับจัดสรรแต่ละฝ่าย)'),
                const SizedBox(width: 14),
                _legendDot(colorScheme, BrandAccent.red(context), 'เกินงบที่ได้รับจัดสรร'),
              ],
            ),
          ),
          for (int i = 0; i < budgetsByDept.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _deptBarRow(
              colorScheme,
              label: budgetsByDept[i].key,
              allocated: budgetsByDept[i].value,
              used: usedByDept[budgetsByDept[i].key] ?? 0,
              color: _getDeptColor(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(ColorScheme colorScheme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: AppTypography.caption, color: colorScheme.onSurfaceVariant, fontWeight: AppTypography.weightSemiBold)),
      ],
    );
  }

  Widget _deptBarRow(
    ColorScheme colorScheme, {
    required String label,
    required double allocated,
    required double used,
    required Color color,
  }) {
    final usedPct = allocated > 0 ? (used / allocated * 100) : 0.0;
    // เกินงบ (>100%) → เปลี่ยนสีแท่งเป็นแดงเตือน แทนสีประจำฝ่าย ให้ตรงกับ %
    // ที่แสดงจริง ไม่ใช่แค่หลอดเต็มเฉยๆ แล้วดูเหมือนปกติ
    final overBudget = usedPct > 100;
    final barColor = overBudget ? BrandAccent.red(context) : color;
    return Row(
      children: [
        SizedBox(
          width: 196,
          child: Text(
            label,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightSemiBold, color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ProgressBar(
            progress: usedPct / 100,
            color: barColor,
            backgroundColor: color.withValues(alpha: 0.15),
            height: 15,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text(
            '${usedPct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: AppTypography.micro, fontWeight: AppTypography.weightBold, color: overBudget ? BrandAccent.red(context) : colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 112,
          child: Text(
            formatBaht(allocated),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightBold, color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, double>> _getBudgetByDepartment() {
    final totals = <String, double>{};
    for (final b in _budgets) {
      final dept = (b.groupName?.trim().isNotEmpty ?? false)
          ? b.groupName!
          : 'ไม่ระบุฝ่าย/แผนงาน';
      totals[dept] = (totals[dept] ?? 0) + (b.allocatedAmount ?? 0);
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// ยอดใช้จ่ายจริงต่อฝ่าย — รวมเฉพาะเอกสารที่ "เสร็จสมบูรณ์" แล้ว โดย join
  /// ผ่าน budgetId ของ order ไปหาฝ่าย/แผนงานเจ้าของแผนงบนั้น
  Map<String, double> _getUsedByDepartment() {
    final budgetDept = <int, String>{
      for (final b in _budgets)
        if (b.id != null)
          b.id!: (b.groupName?.trim().isNotEmpty ?? false) ? b.groupName! : 'ไม่ระบุฝ่าย/แผนงาน',
    };
    final totals = <String, double>{};
    for (final o in _orders) {
      if (o.currentStatus != 'COMPLETED') continue;
      final dept = o.budgetId != null ? budgetDept[o.budgetId] : null;
      if (dept == null) continue;
      totals[dept] = (totals[dept] ?? 0) + (o.currentOrderPrice ?? 0);
    }
    return totals;
  }

  Color _getDeptColor(int index) {
    final colors = [
      BrandAccent.teal(context),
      BrandAccent.indigo(context),
      BrandColors.orange, // ไม่มีในชุดโทเค็น mockup (สีเสริมเฉพาะจุดนี้) คงค่าเดียวไว้
      BrandAccent.purple(context),
      BrandAccent.blue(context),
    ];
    return colors[index % colors.length];
  }
}

