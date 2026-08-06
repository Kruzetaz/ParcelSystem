// dashboard_screen.dart
// เนื้อหาหน้าแรกของแอป — แสดงรายการ procurement_orders ทั้งหมด ค้นหาได้
// [AppShell]: ไม่มี Scaffold/AppBar/FAB ของตัวเองแล้ว เพราะถูกวาดอยู่ในพื้นที่ขวา
// ของ AppShell เสมอ — AppBar ย้ายไปอยู่ระดับ shell แทน
// การสร้างใหม่/แก้ไขเอกสาร ใช้ callback ที่ shell ส่งมาให้ แทน Navigator.push เดิม
//
// [Dashboard v2/v3]: มี KPI 4 การ์ด, filter tabs (ทั้งหมด/ร่าง/เสร็จแล้ว),
// progress bar ในการ์ดแต่ละใบ, ธีมน้ำเงิน-ทอง-เทาอ่อน

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../data/procurement_repository.dart';
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import '../models/budget.dart';
import '../models/school_settings.dart';
import 'app_sidebar.dart' show AppMode;
import '../services/toast_service.dart';
import '../services/document_generator.dart';
import '../services/fiscal_year_controller.dart';
import '../utils/money_format.dart';

/// ปุ่มลัดเสริมที่ผู้ใช้เลือกเพิ่ม/ลดเองได้ในเมนูด่วน — แยกจาก 5 ปุ่มพื้นฐาน
/// (สร้างใหม่/แผนงบ/ตั้งค่า/ตั้งค่า AI/รีเฟรช) ที่บังคับแสดงตลอด
class _OptionalQuickAction {
  final String id;
  final IconData icon;
  final String label;
  final AppMode mode;
  const _OptionalQuickAction({required this.id, required this.icon, required this.label, required this.mode});
}

const _optionalQuickActionsCatalog = [
  _OptionalQuickAction(id: 'easy_wizard', icon: Icons.auto_awesome_outlined, label: 'Easy Wizard', mode: AppMode.easyWizard),
  _OptionalQuickAction(id: 'procurement_calendar', icon: Icons.event_note_outlined, label: 'ปฏิทินงานพัสดุ', mode: AppMode.procurementCalendar),
  _OptionalQuickAction(id: 'tor', icon: Icons.description_outlined, label: 'TOR/คุณลักษณะ', mode: AppMode.tor),
  _OptionalQuickAction(id: 'contracts', icon: Icons.article_outlined, label: 'บริหารสัญญา', mode: AppMode.contracts),
  _OptionalQuickAction(id: 'guarantees', icon: Icons.shield_outlined, label: 'หลักประกัน', mode: AppMode.guarantees),
  _OptionalQuickAction(id: 'inspections', icon: Icons.fact_check_outlined, label: 'ตรวจรับพัสดุ', mode: AppMode.inspections),
  _OptionalQuickAction(id: 'installment_contracts', icon: Icons.event_repeat_outlined, label: 'สัญญาต่อเนื่องหลายงวด', mode: AppMode.installmentContracts),
  _OptionalQuickAction(id: 'document_hub', icon: Icons.file_copy_outlined, label: 'สร้างเอกสารราชการ', mode: AppMode.documentHub),
  _OptionalQuickAction(id: 'order_register', icon: Icons.numbers_outlined, label: 'ทะเบียนคุมเลขที่', mode: AppMode.orderRegister),
  _OptionalQuickAction(id: 'control_log', icon: Icons.receipt_long_outlined, label: 'ทะเบียนคุมเลขบันทึก/TOR', mode: AppMode.controlLog),
  _OptionalQuickAction(id: 'fixed_assets', icon: Icons.inventory_2_outlined, label: 'ทะเบียนครุภัณฑ์', mode: AppMode.fixedAssets),
  _OptionalQuickAction(id: 'repair_history', icon: Icons.build_outlined, label: 'ประวัติซ่อมครุภัณฑ์', mode: AppMode.repairHistory),
  _OptionalQuickAction(id: 'materials', icon: Icons.inventory_outlined, label: 'วัสดุ/คลังพัสดุ', mode: AppMode.materials),
  _OptionalQuickAction(id: 'annual_count', icon: Icons.checklist_outlined, label: 'ตรวจนับประจำปี', mode: AppMode.annualCount),
  _OptionalQuickAction(id: 'disposals', icon: Icons.delete_sweep_outlined, label: 'จำหน่ายพัสดุ', mode: AppMode.disposals),
  _OptionalQuickAction(id: 'reports', icon: Icons.bar_chart_outlined, label: 'รายงาน/สตง.', mode: AppMode.reports),
];

const _quickActionsPrefsKey = 'dashboard_quick_actions_v1';

enum _OrderFilter { all, draft, completed, underFiveK, w804UnderFiftyK, missingEgp }

/// แจ้งเตือนแบบคลิกนำทางได้บน Dashboard — เก็บแค่ข้อความ + ตัวกรองที่จะสลับไป
class _DashboardAlert {
  final String message;
  final _OrderFilter filter;
  const _DashboardAlert({required this.message, required this.filter});
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onCreateNew;
  final void Function(ProcurementOrder order) onEditOrder;
  // ให้ quick-action grid สลับไปหน้าแผนงบ/ตั้งค่าโรงเรียนได้ตรงๆ โดยไม่ต้องผ่าน sidebar
  final void Function(AppMode mode) onNavigate;
  // ปุ่มลัด "สร้างเอกสาร" บนการ์ดแต่ละใบ — พาไปหน้ารวมศูนย์เอกสารพร้อมเลือก
  // รายการนี้ไว้ล่วงหน้า
  final void Function(ProcurementOrder order) onGenerateDocument;

  const DashboardScreen({
    super.key,
    required this.onCreateNew,
    required this.onEditOrder,
    required this.onNavigate,
    required this.onGenerateDocument,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ProcurementRepository();
  final _searchCtrl = TextEditingController();

  List<ProcurementOrder> _orders = [];
  List<Budget> _budgets = [];
  SchoolSettings? _school;
  bool _loading = true;
  String _query = '';
  _OrderFilter _filter = _OrderFilter.all;
  // กันกดปุ่ม "ดูตัวอย่าง" ซ้ำตอนกำลังสร้างไฟล์อยู่ — เก็บ id รายการที่กำลังสร้าง
  int? _previewingOrderId;

  // โหมดเลือกหลายรายการ — เปิดแล้วแต่ละการ์ดจะมี checkbox ให้ติ๊กเลือก เพื่อกด
  // "สร้างเอกสาร" ให้หลายรายการพร้อมกันทีเดียว (เช่นตอนต้องออกเอกสารทั้งชุด
  // รายการ ว.804 ≤50,000 บาท จำนวนมากพร้อมกัน)
  bool _selectionMode = false;
  final Set<int> _selectedOrderIds = {};
  bool _bulkGenerating = false;

  // ปุ่มลัดเสริมที่ผู้ใช้เลือกเปิดไว้ในเมนูด่วน — จำไว้ในเครื่องนี้ (ไม่ผูกกับ
  // โรงเรียน/ผู้ใช้คนอื่น) โหลดตอนเปิดหน้าครั้งแรก
  Set<String> _enabledQuickActionIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadQuickActionPrefs();
    // สลับปีงบที่ AppBar (FiscalYearController) ต้องทำให้ Dashboard โหลดใหม่
    // ตามปีที่เลือก — ฟังไว้ตรงนี้แทนอ่านค่าตรงๆ ตอน build กันปัญหาเดียวกับที่
    // เจอมาแล้วกับปุ่มปรับขนาดฟอนต์ (ค่าเปลี่ยนจริงแต่หน้าจอไม่รีเฟรชตาม)
    FiscalYearController.instance.addListener(_onFiscalYearChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    FiscalYearController.instance.removeListener(_onFiscalYearChanged);
    super.dispose();
  }

  void _onFiscalYearChanged() => _load();

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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  for (final label in const ['สร้างใหม่', 'แผนงบ', 'ตั้งค่า', 'ตั้งค่า AI', 'รีเฟรช'])
                    CheckboxListTile(
                      value: true,
                      onChanged: null,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(label, style: const TextStyle(fontSize: 13)),
                    ),
                  const Divider(height: 20),
                  const Text('ปุ่มเสริม (เลือกเพิ่ม/ลดได้ตามต้องการ)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  for (final a in _optionalQuickActionsCatalog)
                    CheckboxListTile(
                      value: draft.contains(a.id),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(a.label, style: const TextStyle(fontSize: 13)),
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final viewingYear = FiscalYearController.instance.viewingYear;
    final orders = _query.trim().isEmpty
        ? await _repo.getAllOrders(fiscalYear: viewingYear)
        : await _repo.searchOrders(_query.trim(), fiscalYear: viewingYear);
    final budgets = await _repo.getAllBudgets(fiscalYear: viewingYear);
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _budgets = budgets;
      _school = school;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(ProcurementOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'ต้องการลบเอกสาร "${order.procurementNumber ?? '(ไม่มีเลขที่)'} '
          '${order.projectName ?? ''}" ใช่หรือไม่?\nรายการพัสดุทั้งหมดในเอกสารนี้จะถูกลบไปด้วย',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && order.id != null) {
      try {
        await _repo.deleteOrder(order.id!);
        if (!mounted) return;
        _load();
      } catch (e) {
        if (!mounted) return;
        showAppToast('ลบเอกสารไม่สำเร็จ: $e', isError: true);
      }
    }
  }

  /// ปุ่มลัด "ดูตัวอย่าง" — สร้างเอกสารหลัก (บันทึกขอใช้งบประมาณ ชุดเต็ม) แล้ว
  /// เปิดด้วย Word ให้ทันที โดยไม่ต้องไปหน้า "สร้างเอกสารราชการ" ก่อน
  Future<void> _previewOrder(ProcurementOrder order) async {
    if (order.id == null) return;
    final school = _school;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    setState(() => _previewingOrderId = order.id);
    try {
      final items = await _repo.getItems(order.id!);
      await DocumentGenerator.generateAndOpen(order: order, school: school, items: items);
      if (!mounted) return;
      showAppToast('เปิดตัวอย่างเอกสารแล้ว');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างตัวอย่างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _previewingOrderId = null);
    }
  }

  // กันกดปุ่ม "คัดลอกโครงการ" ซ้ำตอนกำลังคัดลอกอยู่ — เก็บ id รายการที่กำลังคัดลอก
  int? _duplicatingOrderId;

  /// คัดลอกโครงการทั้งใบ (รวมรายการพัสดุ) เป็นรายการใหม่แยกต่างหาก — คัดลอกทุก
  /// ช่องมาตรงๆ ไม่ล้างอะไรทั้งสิ้น (รวมเลขที่เอกสาร/วันที่/สถานะ) ให้ผู้ใช้เป็น
  /// คนแก้เองว่าช่องไหนต้องเปลี่ยน — เติมแค่ "(สำเนา)" ต่อชื่อโครงการกันสับสนกับ
  /// ต้นฉบับเท่านั้น ไม่พาไปหน้าแก้ไขให้อัตโนมัติ ผู้ใช้กดเข้าไปเองตอนพร้อม
  Future<void> _duplicateOrder(ProcurementOrder order) async {
    if (order.id == null) return;
    setState(() => _duplicatingOrderId = order.id);
    try {
      final items = await _repo.getItems(order.id!);

      final map = order.toMap();
      map.remove('id');
      map['project_name'] =
          '${(order.projectName?.trim().isNotEmpty ?? false) ? order.projectName! : "(ไม่มีชื่อโครงการ)"} (สำเนา)';
      final duplicateOrder = ProcurementOrder.fromMap(map);
      final duplicateItems = items
          .map((it) => ProcurementItem(
                itemName: it.itemName,
                quantity: it.quantity,
                unit: it.unit,
                unitPrice: it.unitPrice,
                totalPrice: it.totalPrice,
              ))
          .toList();

      await _repo.saveOrderWithItems(duplicateOrder, duplicateItems);
      if (!mounted) return;
      showAppToast('คัดลอกโครงการแล้ว');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกโครงการไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _duplicatingOrderId = null);
    }
  }

  /// คัดลอกโครงการของปีงบเก่ามาเริ่มใหม่ในปีงบปัจจุบัน — ต่างจาก
  /// "คัดลอกโครงการ" ธรรมดา (ที่คัดลอกทุกช่องตรงๆ รวมเลขที่/วันที่เดิม)
  /// ตรงที่ตัวนี้ล้างข้อมูลที่เป็น "ของงวดนั้นโดยเฉพาะ" ออกทั้งหมด (เลขที่
  /// เอกสาร/เลขคุมต่างๆ/วันที่ทุกขั้นตอน) เก็บไว้แค่สิ่งที่มักซ้ำกันทุกปี (ผู้ขาย/
  /// คณะกรรมการ/รายการพัสดุ/ราคา/ชื่อโครงการ) ให้ผู้ใช้กรอกแค่เลขที่และวันที่
  /// ใหม่ของปีนี้เอง — ใช้ตอนเปิดดูปีงบเก่าอยู่แล้วเจอโครงการที่อยากทำซ้ำทุกปี
  /// (เช่น จ้างเหมาอาหารกลางวัน, เช่าเน็ตรายปี)
  Future<void> _copyOrderToCurrentYear(ProcurementOrder order) async {
    if (order.id == null) return;
    final currentYear = FiscalYearController.instance.currentRealYear;
    setState(() => _duplicatingOrderId = order.id);
    try {
      final items = await _repo.getItems(order.id!);

      final map = order.toMap();
      map.remove('id');
      map['fiscal_year'] = currentYear;
      // ล้างเลขที่เอกสาร/เลขคุมต่างๆ — เป็นเลขเฉพาะของปีงบเดิม ใช้ซ้ำไม่ได้
      for (final key in [
        'procurement_number',
        'egp_project_id',
        'contract_control_number',
        'inspection_control_number',
      ]) {
        map[key] = null;
      }
      // ล้างวันที่ทุกขั้นตอน — ต้องกรอกใหม่ตามที่เกิดขึ้นจริงของปีนี้
      for (final key in [
        'date_memo_used',
        'date_order_created',
        'date_quotation',
        'date_contract_signed',
        'date_deadline',
        'date_shipping',
        'date_inspection',
        'date_disbursement',
      ]) {
        map[key] = null;
      }
      final duplicateOrder = ProcurementOrder.fromMap(map);
      final duplicateItems = items
          .map((it) => ProcurementItem(
                itemName: it.itemName,
                quantity: it.quantity,
                unit: it.unit,
                unitPrice: it.unitPrice,
                totalPrice: it.totalPrice,
              ))
          .toList();

      await _repo.saveOrderWithItems(duplicateOrder, duplicateItems);
      if (!mounted) return;
      showAppToast('คัดลอกโครงการไปปีงบ $currentYear แล้ว — กรอกเลขที่/วันที่ใหม่ได้เลย');
      FiscalYearController.instance.resetToCurrentYear();
    } catch (e) {
      if (!mounted) return;
      showAppToast('คัดลอกไปปีงบใหม่ไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _duplicatingOrderId = null);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedOrderIds.clear();
    });
  }

  void _toggleOrderSelected(ProcurementOrder order) {
    if (order.id == null) return;
    setState(() {
      if (_selectedOrderIds.contains(order.id)) {
        _selectedOrderIds.remove(order.id);
      } else {
        _selectedOrderIds.add(order.id!);
      }
    });
  }

  /// เลือกทั้งหมด/ยกเลิกทั้งหมดเฉพาะรายการที่กรองอยู่ตอนนี้ (สลับกันไปมา)
  void _toggleSelectAllFiltered() {
    final ids = _filteredOrders.where((o) => o.id != null).map((o) => o.id!).toSet();
    setState(() {
      if (_selectedOrderIds.containsAll(ids) && ids.isNotEmpty) {
        _selectedOrderIds.removeAll(ids);
      } else {
        _selectedOrderIds.addAll(ids);
      }
    });
  }

  /// ปุ่มลัด "สร้างเอกสาร" แบบเลือกหลายรายการ — สร้างเอกสารหลักของทุกรายการที่
  /// ติ๊กไว้รวดเดียว (ไม่เปิด Word ทีละไฟล์เพราะจะเปิดหน้าต่างรัวเกินไปถ้าเลือก
  /// เยอะ) เสร็จแล้วเปิดโฟลเดอร์ที่เก็บไฟล์ให้ครั้งเดียว
  Future<void> _bulkGenerateSelected() async {
    final school = _school;
    if (school == null) {
      showAppToast('กรุณากรอกข้อมูลโรงเรียนในหน้า "ตั้งค่าโรงเรียน" ก่อน', isError: true);
      return;
    }
    final selectedOrders = _orders.where((o) => _selectedOrderIds.contains(o.id)).toList();
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
      _selectedOrderIds.clear();
    });
  }

  // ─────────────────────────────────────────
  // KPI คำนวณจาก _orders + _budgets ที่โหลดไว้แล้ว (ไม่ query ใหม่)
  // ─────────────────────────────────────────

  int get _draftCount => _orders.where((o) => o.currentStatus != 'COMPLETED').length;

  int get _completedCount => _orders.where((o) => o.currentStatus == 'COMPLETED').length;

  double get _totalSpent => _orders
      .where((o) => o.currentStatus == 'COMPLETED')
      .fold(0.0, (sum, o) => sum + (o.currentOrderPrice ?? 0));

  double get _totalRemainingBudget =>
      _budgets.fold(0.0, (sum, b) => sum + (b.remainingAmount ?? 0));

  double get _totalAllocatedBudget =>
      _budgets.fold(0.0, (sum, b) => sum + (b.allocatedAmount ?? 0));

  /// รวมงบตามฝ่าย/กลุ่มงาน (groupName) — เรียงตามลำดับมาตรฐาน budgetDepartmentGroups
  /// เดียวกับ dropdown ตัวกรองฝ่าย/แผนงาน (กลุ่มที่ไม่อยู่ในลิสต์มาตรฐาน หรือ
  /// "ไม่ระบุฝ่าย/แผนงาน" จะเรียงต่อท้ายตามตัวอักษร) ใช้วาดกราฟแท่งใน Dashboard
  List<MapEntry<String, double>> get _budgetByDepartment {
    final totals = <String, double>{};
    for (final b in _budgets) {
      final dept = (b.groupName?.trim().isNotEmpty ?? false) ? b.groupName! : 'ไม่ระบุฝ่าย/แผนงาน';
      totals[dept] = (totals[dept] ?? 0) + (b.allocatedAmount ?? 0);
    }
    int sortRank(String name) {
      final idx = budgetDepartmentGroups.indexOf(name);
      return idx == -1 ? budgetDepartmentGroups.length + 1 : idx;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) {
        final rankCompare = sortRank(a.key).compareTo(sortRank(b.key));
        if (rankCompare != 0) return rankCompare;
        return a.key.compareTo(b.key);
      });
    return entries;
  }

  /// ยอดที่ใช้ไปแล้ว (เฉพาะเอกสารที่ "เสร็จสมบูรณ์") แยกตามฝ่าย/กลุ่มงาน — จับคู่
  /// ออร์เดอร์กับฝ่ายผ่าน budgetId ของออร์เดอร์ที่ผูกกับแผนงบ ใช้วาดซ้อนบนแท่ง
  /// "วงเงินทั้งหมด" ในกราฟ Dashboard เพื่อเทียบใช้ไปเท่าไหร่จากที่ได้รับจัดสรร
  Map<String, double> get _spentByDepartment {
    final budgetsById = {for (final b in _budgets) if (b.id != null) b.id!: b};
    final spent = <String, double>{};
    for (final o in _orders) {
      if (o.currentStatus != 'COMPLETED') continue;
      final budget = o.budgetId != null ? budgetsById[o.budgetId] : null;
      final dept = (budget?.groupName?.trim().isNotEmpty ?? false) ? budget!.groupName! : 'ไม่ระบุฝ่าย/แผนงาน';
      spent[dept] = (spent[dept] ?? 0) + (o.currentOrderPrice ?? 0);
    }
    return spent;
  }

  /// ปีงบประมาณล่าสุด หา mode (ปีที่มีเอกสารเยอะสุด) ถ้าเสมอกันเลือกปีมากสุด
  String? get _currentFiscalYear {
    if (_orders.isEmpty) return null;
    final counts = <String, int>{};
    for (final o in _orders) {
      final y = o.fiscalYear;
      if (y == null || y.isEmpty) continue;
      counts[y] = (counts[y] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final topYears = counts.entries.where((e) => e.value == maxCount).map((e) => e.key).toList()
      ..sort();
    return topYears.last;
  }

  int get _currentFiscalYearCount {
    final year = _currentFiscalYear;
    if (year == null) return 0;
    return _orders.where((o) => o.fiscalYear == year).length;
  }

  List<ProcurementOrder> get _filteredOrders {
    switch (_filter) {
      case _OrderFilter.draft:
        return _orders.where((o) => o.currentStatus != 'COMPLETED').toList();
      case _OrderFilter.completed:
        return _orders.where((o) => o.currentStatus == 'COMPLETED').toList();
      // วิธีเฉพาะเจาะจง วงเงินไม่เกิน 5,000 บาท — ขั้นตอนแบบย่อที่สุดตามระเบียบ
      case _OrderFilter.underFiveK:
        return _orders.where((o) => (o.currentOrderPrice ?? 0) > 0 && o.currentOrderPrice! <= 5000).toList();
      // หนังสือเวียน ว.804 — วงเงินเกิน 5,000 แต่ไม่เกิน 50,000 บาท
      case _OrderFilter.w804UnderFiftyK:
        return _orders
            .where((o) => (o.currentOrderPrice ?? 0) > 5000 && o.currentOrderPrice! <= 50000)
            .toList();
      case _OrderFilter.missingEgp:
        return _orders.where((o) => o.egpProjectId == null || o.egpProjectId!.trim().isEmpty).toList();
      case _OrderFilter.all:
        return _orders;
    }
  }

  int get _missingEgpCount =>
      _orders.where((o) => o.egpProjectId == null || o.egpProjectId!.trim().isEmpty).length;

  /// รายการแจ้งเตือนแบบคลิกนำทางได้ทั้งหมด — แยกออกมาเป็นลิสต์เพื่อจัดวางเป็น
  /// กริด 3 คอลัมน์ต่อแถวได้ (ถ้ามีมากกว่า 3 รายการจะขึ้นแถวใหม่ต่อด้านล่าง)
  List<_DashboardAlert> get _alerts {
    final list = <_DashboardAlert>[];
    if (_missingEgpCount > 0) {
      list.add(_DashboardAlert(
        message: 'พบรายการไม่มีเลขที่ e-GP $_missingEgpCount รายการ — ต้องกรอกตาม ม.23 พ.ร.บ.จัดซื้อจัดจ้างฯ 2560',
        filter: _OrderFilter.missingEgp,
      ));
    }
    if (_draftCount > 0) {
      list.add(_DashboardAlert(
        message: 'มีเอกสารร่างที่ยังไม่เสร็จ $_draftCount รายการ',
        filter: _OrderFilter.draft,
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!FiscalYearController.instance.isViewingCurrentYear) ...[
                        _buildOldYearBanner(colors),
                        const SizedBox(height: 14),
                      ],
                      _buildHeroBanner(colors),
                      if (_alerts.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildAlertGrid(colors),
                      ],
                      const SizedBox(height: 20),
                      _buildKpiRow(colors),
                      if (_budgetByDepartment.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildDepartmentBudgetChart(colors),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFilterTabs(colors),
                                const SizedBox(height: 14),
                                _buildSearchBar(),
                                const SizedBox(height: 10),
                                _buildSelectionBar(colors),
                                const SizedBox(height: 8),
                                _buildList(colors),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(width: 190, child: _buildQuickActionsPanel(colors)),
                        ],
                      ),
                      // เผื่อพื้นที่ด้านล่างไม่ให้ FAB ลอยทับรายการสุดท้าย
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: widget.onCreateNew,
            backgroundColor: colors.tertiary,
            foregroundColor: colors.onTertiary,
            icon: const Icon(Icons.add),
            label: const Text('สร้างใหม่', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // HERO BANNER — ชื่อโรงเรียน + ตัวเลขสรุปใหญ่ + วงกลม % ความคืบหน้ารวม
  // ─────────────────────────────────────────

  /// แบนเนอร์เตือนตอนกำลังดูปีงบที่ไม่ใช่ปีปัจจุบัน (เก่ากว่า/ใหม่กว่าก็ได้) —
  /// กันสับสนคิดว่ากำลังดู/แก้ข้อมูลปีปัจจุบันอยู่ ข้อความปรับตามทิศทาง (ดูปีเก่า
  /// เพื่ออ้างอิง vs วางแผนปีถัดไปล่วงหน้า) มีปุ่มกลับไปปีปัจจุบันเร็วๆ ในตัวเลย
  Widget _buildOldYearBanner(ColorScheme colors) {
    final fy = FiscalYearController.instance;
    final message = fy.isViewingFutureYear
        ? 'กำลังดูปีงบ ${fy.viewingYear} (ยังไม่ถึงปีนี้จริง) — เหมาะสำหรับวางแผนงบประมาณ/สร้างโครงการล่วงหน้า '
            '(ปีปัจจุบันคือ ${fy.currentRealYear})'
        : 'กำลังดูข้อมูลปีงบ ${fy.viewingYear} (ปีเก่า) — สำหรับดูอ้างอิงเท่านั้น ไม่ใช่ปีงบปัจจุบัน '
            '(ปีปัจจุบันคือ ${fy.currentRealYear}) เจอโครงการที่อยากทำซ้ำ กดไอคอน 🔼 ที่การ์ดเพื่อคัดลอกไปปีนี้ได้เลย';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(fy.isViewingFutureYear ? Icons.event_note_outlined : Icons.history_outlined, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade200,
              foregroundColor: Colors.amber.shade900,
            ),
            onPressed: () => fy.resetToCurrentYear(),
            child: const Text('กลับไปปีปัจจุบัน'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(ColorScheme colors) {
    final total = _orders.length;
    final ratio = total == 0 ? 0.0 : _completedCount / total;
    final schoolName = _school?.schoolName?.isNotEmpty == true
        ? _school!.schoolName!
        : 'ยังไม่ได้กรอกชื่อโรงเรียน';
    final fiscalYear = _currentFiscalYear;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(colors.primary, Colors.black, 0.35)!, colors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          final schoolBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, color: colors.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      schoolName,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fiscalYear == null ? 'ยังไม่มีข้อมูลปีงบประมาณ' : 'ปีงบประมาณ $fiscalYear',
                style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.6), fontSize: 12.5),
              ),
              if (_totalAllocatedBudget > 0) ...[
                const SizedBox(height: 16),
                _buildBudgetUsageBar(colors),
              ],
            ],
          );

          // ตัวเลขสรุป (เอกสารทั้งหมด/ร่าง/เสร็จแล้ว/ยอดใช้จ่าย) ถูกตัดออกจากแบนเนอร์นี้
          // แล้ว เพราะซ้ำกับการ์ด KPI 4 ใบด้านล่างทุกตัว — เหลือแค่วงแหวน % ที่เป็น
          // ข้อมูลเดียวที่ไม่มีที่อื่นแสดงซ้ำ
          final ring = _buildProgressRing(colors, ratio);
          final missingSchoolInfo = _school?.schoolName?.isNotEmpty != true;

          final actionButton = missingSchoolInfo
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onNavigate(AppMode.settings),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onPrimary,
                      side: BorderSide(color: colors.onPrimary.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('ไปกรอกข้อมูลโรงเรียน'),
                  ),
                )
              : const SizedBox.shrink();

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: schoolBlock),
                    ring,
                  ],
                ),
                actionButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    schoolBlock,
                    actionButton,
                  ],
                ),
              ),
              const SizedBox(width: 24),
              ring,
            ],
          );
        },
      ),
    );
  }

  /// แถบยอดใช้จ่ายเทียบกับงบประมาณที่ได้รับจัดสรรทั้งหมด (ข้อมูลใหม่ที่ไม่มี
  /// แสดงซ้ำที่ไหนในหน้านี้ — การ์ด KPI ด้านล่างมีแค่ตัวเลข "งบคงเหลือ" เฉยๆ
  /// ไม่มีแถบเทียบสัดส่วนแบบนี้) เติมพื้นที่ว่างใน hero banner ให้ดูมีเนื้อหาขึ้น
  Widget _buildBudgetUsageBar(ColorScheme colors) {
    final allocated = _totalAllocatedBudget;
    final spent = _totalSpent;
    final ratio = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ใช้จ่ายจากงบประมาณ', style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.75), fontSize: 11.5)),
              Text('${(ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: colors.onPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: colors.onPrimary.withValues(alpha: 0.15),
              color: colors.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatBaht(spent)}  จาก  ${_formatBaht(allocated)}',
            style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// วงกลมแสดง % เอกสารที่เสร็จสมบูรณ์เทียบกับทั้งหมด วาดเองด้วย CustomPainter
  /// (ไม่ใช้ CircularProgressIndicator ตรงๆ เพราะต้องคุมความหนาเส้น/ปลายมน/
  /// สีพื้นหลังวงในให้ตรงกับดีไซน์ hero banner)
  Widget _buildProgressRing(ColorScheme colors, double ratio) {
    final pct = (ratio * 100).toStringAsFixed(0);
    return SizedBox(
      width: 84,
      height: 84,
      child: CustomPaint(
        painter: _ProgressRingPainter(ratio: ratio, trackColor: colors.onPrimary, progressColor: Colors.amber.shade300),
        child: Center(
          child: Text(
            '$pct%',
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // QUICK ACTIONS — ทางลัด 4 ปุ่ม (ทำหน้าที่เหมือนเมนูใน sidebar แต่เป็น
  // icon grid ให้กดถึงเร็วกว่าตอนอยู่หน้า dashboard)
  // ─────────────────────────────────────────

  Widget _buildQuickActionsPanel(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'เมนูด่วน',
                  style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _openQuickActionsEditor,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.tune, size: 16, color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              // 5 ปุ่มพื้นฐาน — บังคับแสดงเสมอ แก้ไข/ลบออกจากเมนูด่วนไม่ได้
              _quickActionTile(
                colors: colors,
                icon: Icons.add_circle_outline,
                label: 'สร้างใหม่',
                onTap: widget.onCreateNew,
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.account_balance_wallet_outlined,
                label: 'แผนงบ',
                onTap: () => widget.onNavigate(AppMode.budgets),
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.settings_outlined,
                label: 'ตั้งค่า',
                onTap: () => widget.onNavigate(AppMode.settings),
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.auto_awesome_outlined,
                label: 'ตั้งค่า AI',
                onTap: () => widget.onNavigate(AppMode.aiSettings),
              ),
              _quickActionTile(
                colors: colors,
                icon: Icons.refresh,
                label: 'รีเฟรช',
                onTap: _load,
              ),
              // ปุ่มเสริมที่ผู้ใช้เลือกเปิดไว้เอง (กดไอคอนรูปเฟืองด้านบนเพื่อแก้ไข)
              for (final a in _optionalQuickActionsCatalog)
                if (_enabledQuickActionIds.contains(a.id))
                  _quickActionTile(
                    colors: colors,
                    icon: a.icon,
                    label: a.label,
                    onTap: () => widget.onNavigate(a.mode),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required ColorScheme colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: colors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // กราฟแท่งงบประมาณตามฝ่าย/กลุ่มงาน — แต่ละแท่งซ้อน 2 ชั้นในหลอดเดียวกัน
  // สีอ่อน (ด้านหลัง) = วงเงินที่ได้รับจัดสรรทั้งหมด, สีเข้ม (ด้านหน้า) = ยอดที่
  // ใช้ไปแล้วจริงในเอกสารที่เสร็จสมบูรณ์ — ใช้โทนสีเดียวกับธีมของแอป (primary)
  // ─────────────────────────────────────────

  Widget _legendSwatch(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      );

  /// สีประจำแต่ละฝ่าย — เลือกให้ต่างกันชัดเจนแยกแท่งออกจากกันง่าย (ไม่ยึดโทนเขียว
  /// ของธีมแล้วตามที่ขอ เพราะหมุนเฉดรอบสีเดียวมันใกล้กันเกินไปจนแยกไม่ออก)
  static const _deptColorPalette = [
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
    Colors.purple,
    Colors.blue,
    Colors.brown,
    Colors.pink,
    Colors.green,
    Colors.amber,
    Colors.cyan,
  ];

  Color _deptColor(ColorScheme colors, int index) =>
      _deptColorPalette[index % _deptColorPalette.length];

  Widget _buildDepartmentBudgetChart(ColorScheme colors) {
    final entries = _budgetByDepartment;
    final spentMap = _spentByDepartment;
    final maxValue = entries.map((e) => e.value).fold(0.0, math.max);
    if (maxValue <= 0) return const SizedBox.shrink();

    final trackColor = colors.surfaceContainerHighest;

    // วัดความกว้างจริงของชื่อฝ่ายที่ยาวที่สุด ให้คอลัมน์ชื่อพอดีเห็นเต็มทุกแถว
    // ไม่ตัดคำ (แทนการล็อกความกว้างคงที่แบบเดิมที่ตัดชื่อยาวด้วย ellipsis)
    const labelStyle = TextStyle(fontSize: 12.5);
    var labelColW = 0.0;
    for (final e in entries) {
      final painter = TextPainter(
        text: TextSpan(text: e.key, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > labelColW) labelColW = painter.width;
    }
    labelColW += 8; // กันปัดเศษทำให้ตัวสุดท้ายตกบรรทัดใหม่

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('งบประมาณตามฝ่าย/กลุ่มงาน',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.primary)),
          const SizedBox(height: 4),
          Text('สีอ่อน = วงเงินที่ได้รับจัดสรรทั้งหมด · สีเข้ม = ยอดที่ใช้ไปแล้ว (เอกสารที่เสร็จสมบูรณ์)',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendSwatch(colors.primary.withValues(alpha: 0.28)),
              const SizedBox(width: 6),
              Text('วงเงินทั้งหมด', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
              const SizedBox(width: 16),
              _legendSwatch(colors.primary),
              const SizedBox(width: 6),
              Text('ใช้ไปแล้ว (แต่ละฝ่ายมีสีเฉพาะของตัวเอง)', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < entries.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: labelColW,
                    child: Text(entries[i].key, style: labelStyle, softWrap: false, maxLines: 1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalRatio = entries[i].value / maxValue;
                        final spent = spentMap[entries[i].key] ?? 0;
                        final spentRatio = spent / maxValue;
                        final deptColor = _deptColor(colors, i);
                        return Stack(
                          children: [
                            Container(
                              height: 15,
                              decoration: BoxDecoration(
                                color: trackColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              width: constraints.maxWidth * totalRatio.clamp(0.02, 1.0),
                              height: 15,
                              decoration: BoxDecoration(
                                color: deptColor.withValues(alpha: 0.32),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            if (spent > 0)
                              Container(
                                width: constraints.maxWidth * spentRatio.clamp(0.02, 1.0),
                                height: 15,
                                decoration: BoxDecoration(
                                  color: deptColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: Text('${formatBaht(entries[i].value)} บาท',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // KPI ROW — 4 การ์ด
  // ─────────────────────────────────────────

  Widget _buildKpiRow(ColorScheme colors) {
    if (_loading && _orders.isEmpty) {
      return const SizedBox(height: 96);
    }

    final fiscalYear = _currentFiscalYear;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final cards = [
          _KpiCard(
            icon: Icons.description_outlined,
            iconColor: colors.primary,
            label: 'เอกสารทั้งหมด',
            value: '${_orders.length}',
            subLabel: 'ร่าง $_draftCount · เสร็จ $_completedCount',
          ),
          _KpiCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green.shade700,
            label: 'เสร็จสมบูรณ์',
            value: '$_completedCount',
            subLabel: _orders.isEmpty
                ? '-'
                : '${(_completedCount / _orders.length * 100).toStringAsFixed(0)}% ของทั้งหมด',
          ),
          _KpiCard(
            icon: Icons.payments_outlined,
            iconColor: colors.tertiary,
            label: 'ยอดใช้จ่ายรวม',
            value: _formatBaht(_totalSpent),
            subLabel: 'เฉพาะเอกสารที่เสร็จแล้ว',
            highlight: true,
          ),
          _KpiCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: colors.primary,
            label: 'งบประมาณคงเหลือ',
            value: _formatBaht(_totalRemainingBudget),
            subLabel: fiscalYear == null
                ? 'ปีงบฯ $_currentFiscalYearCount รายการ'
                : 'ปีงบฯ $fiscalYear · $_currentFiscalYearCount รายการ',
          ),
        ];

        if (isNarrow) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < cards.length ? 12 : 0),
                  child: Row(
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: 12),
                      if (i + 1 < cards.length) Expanded(child: cards[i + 1]) else const Spacer(),
                    ],
                  ),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  String _formatBaht(double value) => '${formatBaht(value)} บาท';

  /// จัดแจ้งเตือนทั้งหมดเป็นกริด 3 คอลัมน์ต่อแถว — ถ้ามีมากกว่า 3 รายการจะขึ้น
  /// แถวใหม่ต่อด้านล่างอัตโนมัติ (ไม่ใช่ GridView เพราะจำนวนรายการมีน้อยและไม่
  /// scroll เอง ใช้ Wrap ง่ายกว่าและคำนวณความสูงตามเนื้อหาจริงให้เอง)
  Widget _buildAlertGrid(ColorScheme colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const columns = 3;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final alert in _alerts)
              SizedBox(width: tileWidth, child: _buildAlertTile(colors, alert)),
          ],
        );
      },
    );
  }

  /// แจ้งเตือนแบบคลิกนำทางได้ 1 ใบ — กดแล้วสลับไปตัวกรองที่กำหนดไว้ทันที
  Widget _buildAlertTile(ColorScheme colors, _DashboardAlert alert) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _filter = alert.filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert.message,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: Colors.redAccent, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // FILTER TABS
  // ─────────────────────────────────────────

  Widget _buildFilterTabs(ColorScheme colors) {
    Widget chip(String label, _OrderFilter value) {
      final selected = _filter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        labelStyle: TextStyle(
          color: selected ? colors.onPrimary : colors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: selected ? 2 : 0,
        shadowColor: colors.primary.withValues(alpha: 0.3),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('ทั้งหมด', _OrderFilter.all),
        chip('ร่าง', _OrderFilter.draft),
        chip('เสร็จแล้ว', _OrderFilter.completed),
        chip('เฉพาะเจาะจง ≤5,000 บาท', _OrderFilter.underFiveK),
        chip('ว.804 ≤50,000 บาท', _OrderFilter.w804UnderFiftyK),
        chip('ไม่มีเลข e-GP', _OrderFilter.missingEgp),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'ค้นหาเลขที่ / ชื่อโครงการ / ชื่อกิจกรรม / ชื่อร้านค้า',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    _query = '';
                    _load();
                  },
                ),
        ),
        onSubmitted: (v) {
          _query = v;
          _load();
        },
        onChanged: (v) => _query = v,
      ),
    );
  }

  /// แถบสลับโหมด "เลือกหลายรายการ" — ปิดอยู่โชว์แค่ปุ่มเปิดโหมดเล็กๆ ชิดขวา
  /// เปิดแล้วโชว์เป็นแถบเต็ม บอกจำนวนที่เลือก + ปุ่มเลือกทั้งหมด/สร้างเอกสาร/ยกเลิก
  Widget _buildSelectionBar(ColorScheme colors) {
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
    final filteredIds = _filteredOrders.where((o) => o.id != null).map((o) => o.id!).toSet();
    final allSelected = filteredIds.isNotEmpty && _selectedOrderIds.containsAll(filteredIds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'เลือกแล้ว ${_selectedOrderIds.length} รายการ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: _bulkGenerating ? null : _toggleSelectAllFiltered,
            child: Text(allSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด (${filteredIds.length})'),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: (_selectedOrderIds.isEmpty || _bulkGenerating) ? null : _bulkGenerateSelected,
            icon: _bulkGenerating
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                : const Icon(Icons.description_outlined, size: 18),
            label: Text(_bulkGenerating ? 'กำลังสร้าง...' : 'สร้างเอกสาร'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _bulkGenerating ? null : _toggleSelectionMode,
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme colors) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final filtered = _filteredOrders;

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? 'ไม่พบผลการค้นหา'
                    : _orders.isEmpty
                        ? 'ยังไม่มีเอกสารจัดซื้อจัดจ้าง'
                        : 'ไม่มีเอกสารในหมวดนี้',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // หน้าเลื่อนได้ทั้งหน้าแล้ว (SingleChildScrollView ใน build()) จึงไม่ต้อง
    // ใช้ ListView/RefreshIndicator ซ้อนตรงนี้อีกชั้น — ป้องกันปัญหา nested
    // scrollable ที่เคยทำให้ overflow ตอนหน้าต่างเตี้ย
    return Column(
      children: [
        for (int i = 0; i < filtered.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildOrderCard(colors, filtered[i]),
        ],
      ],
    );
  }

  Widget _buildOrderCard(ColorScheme colors, ProcurementOrder order) {
    final isCompleted = order.currentStatus == 'COMPLETED';
    final progress = order.progressPercent.clamp(0.0, 1.0);
    final progressPct = (progress * 100).toStringAsFixed(0);
    final isNearlyDone = !isCompleted && progress >= 0.7;

    final progressColor = isCompleted
        ? Colors.green.shade600
        : isNearlyDone
            ? colors.tertiary
            : colors.primary;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _selectionMode ? () => _toggleOrderSelected(order) : () => widget.onEditOrder(order),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (_selectionMode) ...[
                      Checkbox(
                        value: order.id != null && _selectedOrderIds.contains(order.id),
                        onChanged: order.id == null ? null : (_) => _toggleOrderSelected(order),
                      ),
                      const SizedBox(width: 4),
                    ],
                    _statusBadge(colors, isCompleted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              order.projectName?.isNotEmpty == true ? order.projectName! : '(ไม่มีชื่อโครงการ)',
                              if (order.activityName?.trim().isNotEmpty ?? false) order.activityName!.trim(),
                            ].join(' › '),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (order.procurementNumber?.isNotEmpty == true) order.procurementNumber,
                              if (order.vendorName?.isNotEmpty == true) order.vendorName,
                              if (order.procurementMethod?.isNotEmpty == true) order.procurementMethod,
                            ].join('  •  '),
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (order.currentOrderPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          '${formatBaht(order.currentOrderPrice)} บาท',
                          style: TextStyle(fontWeight: FontWeight.w600, color: colors.primary),
                        ),
                      ),
                    // ปุ่มลัดใช้งานนอกระบบ 3 ปุ่ม: ดูตัวอย่างเอกสาร / สร้างเอกสาร / ลบ
                    // — ไม่ต้องเปิดการ์ดเข้าไปแก้ไขก่อนถึงจะทำสิ่งเหล่านี้ได้
                    // ซ่อนไว้ตอนอยู่ในโหมดเลือกหลายรายการ กันกดพลาดโดนลบ/สร้าง
                    // เอกสารทีละใบขณะกำลังจะติ๊กเลือกหลายรายการ
                    if (!_selectionMode) ...[
                      _previewingOrderId == order.id
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.visibility_outlined),
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              visualDensity: VisualDensity.compact,
                              color: colors.onSurfaceVariant,
                              tooltip: 'ดูตัวอย่างเอกสาร',
                              onPressed: () => _previewOrder(order),
                            ),
                      IconButton(
                        icon: const Icon(Icons.description_outlined),
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        visualDensity: VisualDensity.compact,
                        color: colors.onSurfaceVariant,
                        tooltip: 'สร้างเอกสาร',
                        onPressed: () => widget.onGenerateDocument(order),
                      ),
                      _duplicatingOrderId == order.id
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.copy_all_outlined),
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              visualDensity: VisualDensity.compact,
                              color: colors.onSurfaceVariant,
                              tooltip: 'คัดลอกโครงการ',
                              onPressed: () => _duplicateOrder(order),
                            ),
                      // ปุ่มนี้โผล่เฉพาะตอนกำลังดูปีงบเก่าอยู่เท่านั้น (ดูปีปัจจุบัน
                      // อยู่แล้ว ใช้ปุ่ม "คัดลอกโครงการ" ปกติด้านบนพอ)
                      if (!FiscalYearController.instance.isViewingCurrentYear)
                        IconButton(
                          icon: const Icon(Icons.move_up_outlined),
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          visualDensity: VisualDensity.compact,
                          color: colors.primary,
                          tooltip: 'คัดลอกไปปีงบปัจจุบัน (${FiscalYearController.instance.currentRealYear})',
                          onPressed: () => _copyOrderToCurrentYear(order),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'ลบ',
                        onPressed: () => _confirmDelete(order),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: colors.outlineVariant,
                          color: progressColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$progressPct%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ปุ่มบอกสถานะแบบมีข้อความอ่านออกชัดเจน (ไม่ใช่แค่จุดสีที่ต้องเดา)
  Widget _statusBadge(ColorScheme colors, bool isCompleted) {
    final color = isCompleted ? Colors.green.shade600 : colors.tertiary;
    final label = isCompleted ? 'เสร็จสิ้น' : 'กำลังดำเนินการ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// KPI CARD widget
// ─────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subLabel;
  final bool highlight;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subLabel,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: highlight ? Border.all(color: colors.tertiary.withValues(alpha: 0.4), width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subLabel,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// วงกลม % ความคืบหน้าบน hero banner — พื้นวงเป็นสีขาวจาง เส้น progress สีทอง
// ปลายมน วาดเริ่มจากตำแหน่ง 12 นาฬิกา ตามเข็มนาฬิกา
// ─────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double ratio;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({required this.ratio, required this.trackColor, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * ratio.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}