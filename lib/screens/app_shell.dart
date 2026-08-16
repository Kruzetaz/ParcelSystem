// app_shell.dart
// Scaffold หลักของแอป — ถือ AppBar + Sidebar + สลับ content 4 โหมด
// dirty-check dialog เตือนก่อนสลับเมื่อ wizard ยังไม่ได้บันทึก
//
// [อัปเดต ธีมใหม่]: เลิกใช้สีกรมท่า/ทองคงที่ (_brandColor / _goldAccent)
// เปลี่ยนไปดึงสีจาก Theme.of(context).colorScheme ทั้งหมด เพื่อรองรับ
// โหมดสว่าง/มืด และเพิ่มปุ่มสลับธีม (ไอคอนพระอาทิตย์/พระจันทร์) ใน AppBar
//
// [ย้ายมาจาก sidebar]: กล่องข้อมูลโรงเรียน (ชื่อ+ที่อยู่) ย้ายมาแสดงตรงนี้
// ในแถบบนสุด อยู่ข้างๆ ชื่อระบบ แทนที่จะอยู่ใน sidebar เหมือนเดิม

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'app_sidebar.dart';
import 'dashboard_screen_v2.dart';
import 'order_wizard_screen.dart';
import 'easy_wizard_screen.dart';
import 'document_hub_screen.dart';
import 'order_register_screen.dart';
import 'control_log_screen.dart';
import 'budget_list_screen.dart';
import 'tor_screen.dart';
import 'contracts_screen.dart';
import 'guarantees_screen.dart';
import 'installment_contracts_screen.dart';
import 'inspections_screen.dart';
import 'fixed_assets_screen.dart';
import 'repair_history_screen.dart';
import 'procurement_calendar_screen.dart';
import 'materials_screen.dart';
import 'annual_count_screen.dart';
import 'disposals_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'ai_settings_screen.dart';
import '../models/procurement_order.dart';
import '../models/inspection.dart';
import '../models/school_settings.dart';
import '../models/search_result.dart';
import '../data/procurement_repository.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';
import '../services/theme_controller.dart';
import '../theme/design_tokens.dart' show BrandColors, RadiusSize;
import '../services/font_scale_controller.dart';
import '../services/fiscal_year_controller.dart';
import '../utils/thai_date.dart';
import '../services/global_search_service.dart';
import '../services/toast_service.dart';
import '../utils/app_folder_name.dart';
import '../widgets/design_system/design_system.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppMode _mode = AppMode.dashboard;
  bool _sidebarExpanded = true;

  // dirty tracking — wizard set ค่านี้ผ่าน callback
  bool _wizardIsDirty = false;

  // existingOrder สำหรับกรณีกดแก้ไขจาก dashboard
  ProcurementOrder? _editingOrder;

  // รายการที่เลือกไว้ล่วงหน้าตอนกดปุ่มลัด "สร้างเอกสาร" จากการ์ดใน Dashboard —
  // ให้หน้า "สร้างเอกสารราชการ" เปิดมาพร้อมเลือกรายการนี้ไว้แล้วเลย
  int? _docHubInitialOrderId;

  // ครุภัณฑ์ที่เลือกไว้ล่วงหน้าตอนกดปุ่มลัด "ดูครุภัณฑ์" จากหน้าประวัติซ่อม
  int? _fixedAssetsInitialSelectedId;

  final _repo = ProcurementRepository();
  SchoolSettings? _school;
  // ปีงบที่มีโครงการอยู่จริงในระบบ (สำหรับ dropdown สลับปีงบใน AppBar) — โหลด
  // ตอนเปิดแอปครั้งแรก และรีเฟรชอีกทีตอนกดปุ่ม "รีเฟรชข้อมูล" (พอมีโครงการแรก
  // ของปีงบใหม่ถูกสร้างขึ้น ปีนั้นจะโผล่มาในตัวเลือกให้เอง)
  List<String> _fiscalYears = [];
  // ค่าปลอมใน PopupMenuButton<String> แทนตัวเลือก "เพิ่ม/สลับไปปีงบใหม่..."
  // (ไม่ใช่ปีงบจริง แค่ใช้แยกแยะว่าเลือกอันนี้ ไม่ใช่ปีที่มีอยู่แล้ว)
  static const _addNewYearSentinel = '__add_new_fiscal_year__';

  // ข้อมูลสำหรับปุ่มระฆังแจ้งเตือน — โหลดแยกจากหน้าแดชบอร์ด เพราะ AppShell
  // อยู่คงที่ทุกหน้า ต้องมีข้อมูลของตัวเองไม่พึ่งพาหน้าแดชบอร์ดที่อาจไม่ได้ถูก
  // mount อยู่ตอนนั้น
  List<ProcurementOrder> _notifOrders = [];
  List<Inspection> _notifInspections = [];

  @override
  void initState() {
    super.initState();
    _loadSchool();
    _loadFiscalYears();
    _loadNotifData();
    FiscalYearController.instance.addListener(_loadNotifData);
  }

  @override
  void dispose() {
    _omniSearchCtrl.dispose();
    _omniSearchFocusNode.dispose();
    FiscalYearController.instance.removeListener(_loadNotifData);
    super.dispose();
  }

  Future<void> _loadNotifData() async {
    final year = FiscalYearController.instance.viewingYear;
    final orders = await _repo.getAllOrders(fiscalYear: year);
    final inspections = await _repo.getAllInspections(fiscalYear: year);
    if (!mounted) return;
    setState(() {
      _notifOrders = orders;
      _notifInspections = inspections;
    });
  }

  /// ไม่มีเลข e-GP "จริงๆ" ต้องรีบแก้ — ไม่นับรายการที่ได้รับยกเว้นตามกฎหมาย
  /// (จัดซื้อจัดจ้างวงเงินไม่เกิน 5,000 บาท) เหมือนตรรกะเดียวกับหน้าแดชบอร์ด
  bool _egpRequiredButMissing(ProcurementOrder o) {
    final hasEgp = o.egpProjectId?.trim().isNotEmpty ?? false;
    if (hasEgp) return false;
    final exempt = (o.currentOrderPrice ?? 0) > 0 && o.currentOrderPrice! <= 5000;
    return !exempt;
  }

  int get _notifMissingEgpCount => _notifOrders.where(_egpRequiredButMissing).length;
  int get _notifDraftCount => _notifOrders.where((o) => o.currentStatus != 'COMPLETED').length;
  int get _notifPendingInspectionCount =>
      _notifInspections.where((i) => i.actualDeliveryDate == null || i.actualDeliveryDate!.trim().isEmpty).length;

  /// ใกล้ครบกำหนด/เกินกำหนดแล้ว — ใช้ตรรกะเดียวกับ "ครบกำหนดเร็วๆ นี้" ใน
  /// แดชบอร์ด แต่นับเฉพาะจำนวน ไม่ต้องประกอบข้อความรายละเอียดที่นี่
  int get _notifDeadlineCount {
    var count = 0;
    for (final o in _notifOrders) {
      if (o.currentStatus == 'COMPLETED') continue;
      if (parseThaiDate(o.dateDeadline) != null) count++;
    }
    for (final i in _notifInspections) {
      if ((i.actualDeliveryDate ?? '').trim().isNotEmpty) continue;
      if (parseThaiDate(i.dueDate) != null) count++;
    }
    return count;
  }

  int get _notifTotalCount =>
      _notifMissingEgpCount + _notifDraftCount + _notifPendingInspectionCount + _notifDeadlineCount;

  Future<void> _loadSchool() async {
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() => _school = school);
  }

  Future<void> _loadFiscalYears() async {
    final years = await _repo.getDistinctFiscalYears();
    if (!mounted) return;
    setState(() => _fiscalYears = years);
  }

  // ─────────────────────────────────────────
  // การสลับ mode — ถ้า wizard dirty จะเด้ง dialog ก่อน
  // ─────────────────────────────────────────

  // ตัวกรองที่จะส่งให้แดชบอร์ดใช้ตอนเปิดขึ้นมา — ตั้งไว้เฉพาะตอนกดรายการใน
  // ปุ่มกระดิ่งแจ้งเตือน (ผ่านพารามิเตอร์ dashboardFilter ของ _requestModeChange
  // ด้านล่าง) ทุกทางเข้าอื่นที่ไม่ได้ส่งพารามิเตอร์นี้มา จะเคลียร์ค่านี้เป็น
  // null ให้อัตโนมัติ กันตัวกรองเก่าค้างตอนกดเข้าแดชบอร์ดทางปกติภายหลัง
  String? _pendingDashboardFilter;

  Future<void> _requestModeChange(AppMode newMode, {ProcurementOrder? editingOrder, String? dashboardFilter}) async {
    // ถ้าอยู่หน้า wizard และมีข้อมูลค้าง → ถามก่อน
    if (_mode == AppMode.newOrder && _wizardIsDirty) {
      final confirmed = await _showDirtyDialog();
      if (!confirmed) return;
    }
    final leavingSettings = _mode == AppMode.settings && newMode != AppMode.settings;
    setState(() {
      _mode = newMode;
      _editingOrder = editingOrder;
      _pendingDashboardFilter = dashboardFilter;
      _wizardIsDirty = false;
      // เคลียร์รายการที่เลือกล่วงหน้าไว้ทุกครั้งที่ไม่ได้ไปหน้าเอกสารโดยตรง กัน
      // ค่าเก่าค้างจากปุ่มลัดครั้งก่อนไปโผล่ตอนเข้าเมนู "สร้างเอกสารราชการ" ปกติ
      if (newMode != AppMode.documentHub) _docHubInitialOrderId = null;
      if (newMode != AppMode.fixedAssets) _fixedAssetsInitialSelectedId = null;
    });
    // กลับมาจากหน้าตั้งค่า → โหลดข้อมูลโรงเรียนใหม่ เผื่อมีการแก้ไข
    if (leavingSettings) _loadSchool();
    // รีเฟรชรายการปีงบที่มีข้อมูลจริงทุกครั้งที่สลับหน้า — กันปีงบใหม่ที่เพิ่ง
    // เพิ่มแผนงบ/สร้างโครงการแรกไป (เช่น 2570) ไม่โผล่ใน dropdown ปีงบมุมขวาบน
    // จนกว่าจะกดปุ่ม "รีเฟรชข้อมูล" เอง — จุดนี้ query เบามาก (แค่ DISTINCT ปีงบ
    // สองตาราง) ไม่กระทบ performance ที่สลับหน้าบ่อยๆ
    _loadFiscalYears();
  }

  Future<bool> _showDirtyDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('มีข้อมูลที่ยังไม่ได้บันทึก'),
            content: const Text(
              'ต้องการออกจากหน้านี้โดยไม่บันทึกหรือไม่?\n'
              'ข้อมูลที่แก้ไขไว้จะหายไป',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ออกโดยไม่บันทึก'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─────────────────────────────────────────
  // Callbacks ส่งลงไปให้ DashboardScreen
  // ─────────────────────────────────────────

  void _onDashboardCreateNew() {
    _requestModeChange(AppMode.newOrder, editingOrder: null);
  }

  void _onDashboardEditOrder(ProcurementOrder order) {
    _requestModeChange(AppMode.newOrder, editingOrder: order);
  }

  // Easy Wizard สร้างร่างเอกสารเสร็จแล้ว → พาไปหน้า "สร้างใหม่" (wizard เต็ม)
  // ให้กรอกรายละเอียดที่เหลือต่อทันที
  void _onEasyWizardCreated(ProcurementOrder order) {
    _requestModeChange(AppMode.newOrder, editingOrder: order);
  }

  // Wrapper for DashboardScreenV2 that expects String instead of AppMode
  void _onDashboardNavigateV2(String modeStr) {
    final modeMap = {
      'dashboard': AppMode.dashboard,
      'budgets': AppMode.budgets,
      'settings': AppMode.settings,
      'ai_settings': AppMode.aiSettings,
      'tor': AppMode.tor,
      'contracts': AppMode.contracts,
      'reports': AppMode.reports,
      'inspections': AppMode.inspections,
      'document_hub': AppMode.documentHub,
      'easy_wizard': AppMode.easyWizard,
      'procurement_calendar': AppMode.procurementCalendar,
      'guarantees': AppMode.guarantees,
      'installment_contracts': AppMode.installmentContracts,
      'order_register': AppMode.orderRegister,
      'control_log': AppMode.controlLog,
      'fixed_assets': AppMode.fixedAssets,
      'repair_history': AppMode.repairHistory,
      'materials': AppMode.materials,
      'annual_count': AppMode.annualCount,
      'disposals': AppMode.disposals,
    };
    final mode = modeMap[modeStr];
    if (mode != null) {
      _requestModeChange(mode);
    }
  }

  // ปุ่มลัด "สร้างเอกสาร" บนการ์ดรายการใน Dashboard/ทะเบียนคุมเลขบันทึก — พาไป
  // หน้ารวมศูนย์เอกสารพร้อมเลือกรายการนี้ไว้ล่วงหน้าให้เลย
  void _onGenerateDocumentForOrder(int? orderId) {
    _docHubInitialOrderId = orderId;
    _requestModeChange(AppMode.documentHub);
  }

  void _onDashboardGenerateDocument(ProcurementOrder order) => _onGenerateDocumentForOrder(order.id);

  // ปุ่มลัด "ดูครุภัณฑ์" ในหน้าประวัติซ่อม — พาไปหน้าทะเบียนครุภัณฑ์พร้อมเลือก
  // ชิ้นนี้ไว้ล่วงหน้า
  void _onViewAssetFromRepairHistory(int assetId) {
    _fixedAssetsInitialSelectedId = assetId;
    _requestModeChange(AppMode.fixedAssets);
  }

  Future<void> _onBackupPressed() async {
    final colors = Theme.of(context).colorScheme;
    final folderName = await getSchoolDocumentsFolderName();
    if (!mounted) return;
    // แสดง bottom sheet เลือก Backup หรือ Restore
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'สำรองข้อมูล',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.cloud_upload_outlined, color: colors.primary),
              title: const Text('สำรองข้อมูล (Backup)'),
              subtitle: Text('บันทึกไฟล์ .zip ไปที่ $folderName'),
              onTap: () { Navigator.pop(ctx); _doBackup(); },
            ),
            ListTile(
              leading: Icon(Icons.cloud_download_outlined, color: colors.tertiary),
              title: const Text('คืนข้อมูล (Restore)'),
              subtitle: const Text('เลือกไฟล์ .zip เพื่อคืนข้อมูลเดิมกลับมา'),
              onTap: () { Navigator.pop(ctx); _doRestore(); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onRefreshPressed() {
    setState(() {
      final current = _mode;
      _mode = AppMode.dashboard;
      if (current == AppMode.dashboard) {
        _refreshKey++;
      }
    });
    _loadFiscalYears();
  }

  int _refreshKey = 0;

  Future<void> _doBackup() async {
    try {
      final path = await BackupService.instance.backup();
      if (!mounted) return;
      showAppToast('สำรองข้อมูลสำเร็จ\n$path');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สำรองข้อมูลไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _doRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการคืนข้อมูล'),
        content: const Text(
          'ข้อมูลปัจจุบันทั้งหมดจะถูกแทนที่ด้วยไฟล์ backup\n'
          'แนะนำให้สำรองข้อมูลก่อนดำเนินการ\n\n'
          'ต้องการดำเนินการต่อหรือไม่?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('คืนข้อมูล'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'เลือกไฟล์ backup (.zip)',
    );
    if (result == null || result.files.single.path == null) return;

    try {
      await BackupService.instance.restore(result.files.single.path!);
      if (!mounted) return;
      showAppToast('คืนข้อมูลสำเร็จ กำลังโหลดข้อมูลใหม่...');
      // reload dashboard
      setState(() { _mode = AppMode.dashboard; });
    } catch (e) {
      if (!mounted) return;
      showAppToast('คืนข้อมูลไม่สำเร็จ: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────
  // Callbacks ส่งลงไปให้ OrderWizardScreen
  // ─────────────────────────────────────────

  void _onWizardDirtyChanged(bool isDirty) {
    if (_wizardIsDirty != isDirty) {
      setState(() => _wizardIsDirty = isDirty);
    }
  }

  void _onWizardSaved() {
    setState(() {
      _wizardIsDirty = false;
      _mode = AppMode.dashboard;
      _editingOrder = null;
    });
  }

  // ─────────────────────────────────────────
  // Content ตาม mode
  // ─────────────────────────────────────────

  Widget _buildContent() {
    switch (_mode) {
      case AppMode.dashboard:
        return DashboardScreenV2(
          // ต่อท้าย key ด้วยตัวกรองจากกระดิ่งแจ้งเตือนด้วย (ไม่ใช่แค่
          // _refreshKey) กัน Flutter มองว่าเป็น widget เดิม (เพราะ key/type
          // เท่ากัน) แล้วข้าม initState ตอนกดกระดิ่งซ้ำระหว่างที่ยังอยู่หน้า
          // แดชบอร์ดอยู่แล้ว — ซึ่งจะทำให้ initialFilter ใหม่ไม่มีผลอะไรเลย
          key: ValueKey('$_refreshKey|${_pendingDashboardFilter ?? ''}'),
          onCreateNew: _onDashboardCreateNew,
          onEditOrder: _onDashboardEditOrder,
          onNavigate: _onDashboardNavigateV2,
          onGenerateDocument: _onDashboardGenerateDocument,
          initialFilter: _pendingDashboardFilter,
        );
      case AppMode.procurementCalendar:
        return const ProcurementCalendarScreen();
      case AppMode.newOrder:
        return OrderWizardScreen(
          existingOrder: _editingOrder,
          onDirtyChanged: _onWizardDirtyChanged,
          onSaved: _onWizardSaved,
        );
      case AppMode.easyWizard:
        return EasyWizardScreen(onCreated: _onEasyWizardCreated);
      case AppMode.budgets:
        return const BudgetListScreen();
      case AppMode.tor:
        return const TorScreen();
      case AppMode.contracts:
        return const ContractsScreen();
      case AppMode.guarantees:
        return const GuaranteesScreen();
      case AppMode.inspections:
        return const InspectionsScreen();
      case AppMode.installmentContracts:
        return const InstallmentContractsScreen();
      case AppMode.documentHub:
        return DocumentHubScreen(
          key: ValueKey('doc_hub_$_docHubInitialOrderId'),
          initialOrderId: _docHubInitialOrderId,
        );
      case AppMode.orderRegister:
        return const OrderRegisterScreen();
      case AppMode.controlLog:
        return ControlLogScreen(onGenerateDocument: _onGenerateDocumentForOrder);
      case AppMode.fixedAssets:
        return FixedAssetsScreen(
          key: ValueKey('fixed_assets_$_fixedAssetsInitialSelectedId'),
          initialSelectedId: _fixedAssetsInitialSelectedId,
        );
      case AppMode.repairHistory:
        return RepairHistoryScreen(onViewAsset: _onViewAssetFromRepairHistory);
      case AppMode.materials:
        return const MaterialsScreen();
      case AppMode.annualCount:
        return const AnnualCountScreen();
      case AppMode.disposals:
        return const DisposalsScreen();
      case AppMode.reports:
        return const ReportsScreen();
      case AppMode.settings:
        return const SettingsScreen();
      case AppMode.aiSettings:
        return const AiSettingsScreen();
    }
  }

  /// ป้ายปีงบฯ ที่ AppBar — เดิมกดแล้วพาไปหน้าแผนงบประมาณตรงๆ ตอนนี้เปลี่ยนเป็น
  /// dropdown สลับ "ปีงบที่กำลังดูอยู่" แทน (ฟีเจอร์ดูโครงการปีงบเก่าย้อนหลัง) —
  /// ไม่ลบ/ย้ายข้อมูลปีเก่าออกจากระบบเลย แค่กรองมุมมองที่เห็นในหน้าจอ (ดูใน
  /// FiscalYearController) ตัวเลือกไปหน้าแผนงบยังกดเข้าถึงได้ตามปกติจาก
  /// sidebar/เมนูด่วน Dashboard เหมือนเดิม ไม่ได้หายไปไหน
  ///
  /// ครอบ ListenableBuilder ของตัวเองเหมือน _fontScaleControls — กันบั๊ค
  /// เดียวกัน (ค่าเปลี่ยนจริงแต่ป้ายไม่รีเฟรชตาม) ตั้งแต่ต้น
  /// เปิดกล่องกรอกปีงบใหม่ (เช่น 2570 ตอนยังไม่ถึงปีงบนั้นจริงตามปฏิทิน) —
  /// ใช้ตอนอยากเริ่มวางแผนงบประมาณของปีถัดไปล่วงหน้าก่อนปีงบจริงจะมาถึง สลับ
  /// ไปดู "ปีงบใหม่ที่ยังไม่มีข้อมูลอะไรเลย" (ว่างเปล่าเป็นปกติ) แล้วเข้าไปกด
  /// "เพิ่มแผนงบ" ที่หน้าแผนงบประมาณได้เลย ระบบจะแท็กปีงบให้ถูกต้องอัตโนมัติ
  /// (ดูช่อง _fiscalYear ในกล่องเพิ่มแผนงบ ที่ default มาจากปีที่กำลังดูอยู่แล้ว)
  Future<void> _promptAddFiscalYear() async {
    final ctrl = TextEditingController(
      text: (int.tryParse(FiscalYearController.instance.currentRealYear) ?? 0) > 0
          ? (int.parse(FiscalYearController.instance.currentRealYear) + 1).toString()
          : '',
    );
    final year = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่ม/สลับไปปีงบใหม่'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ปีงบประมาณ (พ.ศ.)',
              hintText: 'เช่น 2570',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('สลับไปดูปีนี้'),
          ),
        ],
      ),
    );
    if (year == null || year.isEmpty) return;
    FiscalYearController.instance.setViewingYear(year);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('สลับไปดูปีงบ $year แล้ว — ยังไม่มีข้อมูลอะไรเลย ไปเพิ่มแผนงบ/สร้างโครงการแรกได้เลย')),
    );
  }

  /// แก้ไขปีงบที่พิมพ์ผิด — เปลี่ยนเลขปีของ "โครงการ" และ "แผนงบ" ทั้งหมดที่
  /// ติดอยู่กับปีเก่าไปเป็นปีใหม่ทีเดียว ไม่ต้องลบแล้วสร้างใหม่ทุกรายการ
  Future<void> _promptEditFiscalYear(String oldYear) async {
    final counts = await _repo.countFiscalYearData(oldYear);
    if (!mounted) return;
    final ctrl = TextEditingController(text: oldYear);
    final newYear = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('แก้ไขปีงบ $oldYear'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'มีอยู่ ${counts.orderCount} โครงการ และ ${counts.budgetCount} แผนงบ — '
                'เปลี่ยนปีงบให้ทุกรายการที่มีอยู่นี้พร้อมกัน',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ปีงบประมาณใหม่ (พ.ศ.)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (newYear == null || newYear.isEmpty || newYear == oldYear) return;
    await _repo.renameFiscalYear(oldYear, newYear);
    if (!mounted) return;
    // ถ้ากำลังดูปีที่เพิ่งเปลี่ยนชื่ออยู่ ต้องสลับตามไปด้วย ไม่งั้นจะค้างดูปีที่
    // ไม่มีอยู่แล้ว (มุมมองจะว่างเปล่าดูเหมือนข้อมูลหาย ทั้งที่จริงแค่เปลี่ยนชื่อ)
    if (FiscalYearController.instance.viewingYear == oldYear) {
      FiscalYearController.instance.setViewingYear(newYear);
    }
    await _loadFiscalYears();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เปลี่ยนปีงบ $oldYear เป็น $newYear แล้ว')),
    );
  }

  /// ลบปีงบทั้งปีทิ้งถาวร (โครงการ+แผนงบทั้งหมดของปีนั้น) — ใช้ตอนเผลอสร้างปีงบ
  /// ผิดไปเลยแล้วอยากล้างทิ้งไปเริ่มใหม่ ย้ำเตือนแรงเพราะกู้คืนไม่ได้
  Future<void> _promptDeleteFiscalYear(String year) async {
    final counts = await _repo.countFiscalYearData(year);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ลบปีงบ $year ทิ้งถาวร?'),
        content: Text(
          'จะลบ ${counts.orderCount} โครงการ และ ${counts.budgetCount} แผนงบของปีงบ $year ทิ้งทั้งหมด\n\n'
          'การลบนี้กู้คืนไม่ได้ ต้องการดำเนินการต่อหรือไม่?',
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
    if (confirmed != true) return;
    await _repo.deleteFiscalYear(year);
    if (!mounted) return;
    // ถ้ากำลังดูปีที่เพิ่งลบไปอยู่ ต้องสลับกลับปีปัจจุบันทันที กันค้างมองปีที่
    // ไม่มีข้อมูลอะไรเหลือแล้ว
    if (FiscalYearController.instance.viewingYear == year) {
      FiscalYearController.instance.resetToCurrentYear();
    }
    await _loadFiscalYears();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ลบปีงบ $year ทิ้งแล้ว')),
    );
  }

  /// ปุ่มไอคอนเดี่ยวบน topbar (โหมดมืด/แจ้งเตือน/รีเฟรช/สำรองข้อมูล) — ตรงกับ
  /// .tb-ic ใน mockup (กล่องมน 32x32 พื้นหลังขาวโปร่งแสงจางๆ) ของเดิมเป็น
  /// IconButton เปล่าๆ ลอยอยู่บนพื้นเขียวเข้มโดยไม่มีกรอบ/พื้นหลังอะไรเลย
  Widget _topbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Widget? badge,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.22),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
                if (badge != null) badge,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fiscalYearBadge(ColorScheme colors) {
    return ListenableBuilder(
      listenable: FiscalYearController.instance,
      builder: (context, _) {
        final fy = FiscalYearController.instance;
        final isCurrent = fy.isViewingCurrentYear;
        // รวมปีที่มีข้อมูลจริง + ปีปัจจุบัน (ต้องมีให้เลือกเสมอแม้ยังไม่มี
        // โครงการเลยก็ตาม) แล้วเรียงใหม่ไปเก่า ไม่ซ้ำ
        final years = {fy.currentRealYear, ..._fiscalYears}.toList()
          ..sort((a, b) => b.compareTo(a));

        return PopupMenuButton<String>(
          tooltip: 'สลับดูปีงบประมาณ',
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusSize.card),
            side: BorderSide(color: colors.outline),
          ),
          elevation: 6,
          onSelected: (year) {
            if (year == _addNewYearSentinel) {
              _promptAddFiscalYear();
            } else {
              fy.setViewingYear(year);
            }
          },
          itemBuilder: (context) => [
            for (final year in years)
              PopupMenuItem(
                value: year,
                child: Row(
                  children: [
                    Icon(
                      year == fy.viewingYear ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: year == fy.viewingYear ? colors.primary : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text('ปีงบฯ $year'),
                          if (year == fy.currentRealYear)
                            Text('(ปัจจุบัน)', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    // ปีงบปัจจุบันจริง (คำนวณจากปฏิทินเครื่อง) แก้ไข/ลบไม่ได้ —
                    // ไม่ใช่ข้อมูลที่ "สร้างขึ้น" ให้แก้ แถมลบไปก็จะกลับมาเองอยู่
                    // ดี เพราะคำนวณสดทุกครั้ง ปล่อยว่างไว้กันสับสน
                    if (year != fy.currentRealYear) ...[
                      // ใส่พื้นหลังวงกลมให้ไอคอนชัดเจน — เดิมเป็นไอคอนลอยๆ สี
                      // เทา/แดงอ่อนบนพื้นป็อปอัพสีขาว กลืนจนแทบมองไม่เห็นว่า
                      // เป็นปุ่มกดได้
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.edit_outlined, size: 16, color: colors.onSurfaceVariant),
                          tooltip: 'แก้ไขปีงบ $year',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.of(context).pop();
                            _promptEditFiscalYear(year);
                          },
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          tooltip: 'ลบปีงบ $year',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.of(context).pop();
                            _promptDeleteFiscalYear(year);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _addNewYearSentinel,
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: colors.primary),
                  const SizedBox(width: 10),
                  Text('เพิ่ม/สลับไปปีงบใหม่...', style: TextStyle(color: colors.primary)),
                ],
              ),
            ),
          ],
          // ตรงกับ .tb-pill / .tb-pill.amb ใน mockup — กรอบมน 8px (ไม่ใช่ทรง
          // ยาแคปซูล 20px แบบเดิม) มีเส้นขอบจางๆ ด้วยเสมอ
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.white.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent ? Colors.white.withValues(alpha: 0.25) : Colors.amber.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCurrent ? Icons.calendar_today_outlined : Icons.history_outlined,
                  size: 14,
                  color: isCurrent ? colors.onPrimary : const Color(0xFFFEF3C7),
                ),
                const SizedBox(width: 6),
                Text(
                  'ปีงบฯ ${fy.viewingYear}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? colors.onPrimary : const Color(0xFFFEF3C7),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 18, color: isCurrent ? colors.onPrimary : const Color(0xFFFEF3C7)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ปุ่มระฆังแจ้งเตือน — รวม 4 หมวดจากข้อมูลที่ _loadNotifData โหลดไว้ (ไม่ขาด
  /// เลข e-GP, ยังไม่เสร็จ, รอตรวจรับ, ใกล้/เกินกำหนด) กดแต่ละหมวดพาไปหน้าที่
  /// เกี่ยวข้องเลย (ตรวจรับ → หน้าตรวจรับพัสดุ, ที่เหลือ → แดชบอร์ด)
  Widget _notifBellButton(ColorScheme colors) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'แจ้งเตือน',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        side: BorderSide(color: colors.outline),
      ),
      elevation: 6,
      onSelected: (action) => action(),
      itemBuilder: (context) {
        final items = <_NotifItem>[
          _NotifItem(
            icon: Icons.error_outline,
            color: Colors.redAccent,
            label: 'ไม่มีเลข e-GP',
            count: _notifMissingEgpCount,
            onTap: () => _requestModeChange(AppMode.dashboard, dashboardFilter: 'missing_egp'),
          ),
          _NotifItem(
            icon: Icons.edit_note,
            color: Colors.amber.shade800,
            label: 'ยังไม่เสร็จสิ้น (ร่าง)',
            count: _notifDraftCount,
            onTap: () => _requestModeChange(AppMode.dashboard, dashboardFilter: 'draft'),
          ),
          _NotifItem(
            icon: Icons.assignment_late_outlined,
            color: Colors.indigo,
            label: 'รอตรวจรับพัสดุ',
            count: _notifPendingInspectionCount,
            onTap: () => _requestModeChange(AppMode.inspections),
          ),
          _NotifItem(
            icon: Icons.schedule,
            color: Colors.deepOrange,
            label: 'ใกล้/เกินกำหนด',
            count: _notifDeadlineCount,
            onTap: () => _requestModeChange(AppMode.dashboard, dashboardFilter: 'deadline'),
          ),
        ];
        if (_notifTotalCount == 0) {
          return [
            PopupMenuItem<VoidCallback>(
              enabled: false,
              child: Text('ไม่มีรายการแจ้งเตือน', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
          ];
        }
        return [
          for (final item in items)
            if (item.count > 0)
              PopupMenuItem<VoidCallback>(
                value: item.onTap,
                child: Row(
                  children: [
                    Icon(item.icon, size: 17, color: item.color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.label)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(RadiusSize.xxl),
                      ),
                      child: Text(
                        '${item.count}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: item.color),
                      ),
                    ),
                  ],
                ),
              ),
        ];
      },
      // ไม่ใช้ _topbarIconButton (มี InkWell/GestureDetector ของตัวเอง) เป็น
      // child ตรงนี้ — ซ้อน GestureDetector สองชั้นแย่งกันกับของ PopupMenuButton
      // เอง ทำให้บางทีกดแล้วเมนูไม่เด้ง ใช้ Container ธรรมดาแทนเหมือนปุ่มปีงบ
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)),
            if (_notifTotalCount > 0)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                    border: Border.all(color: BrandColors.tealDark, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ปุ่ม A-/A+ ปรับขนาดตัวอักษรทั้งระบบ (มีผลกับทุกหน้าจอ ผ่าน MediaQuery.
  /// textScaler ที่ครอบไว้ระดับ MaterialApp ใน main.dart) — กดค้างที่ตัวเลข
  /// เปอร์เซ็นต์ตรงกลางเพื่อรีเซ็ตกลับ 100% ได้เร็วๆ ไม่ต้องกด A- ไล่ทีละขั้น
  ///
  /// [แก้บัค เลข % ค้าง]: เดิมอ่านค่า FontScaleController.instance.scale
  /// ตรงๆ แบบไม่ subscribe ทำให้กดปุ่มแล้วค่าเปลี่ยนจริง (ฟอนต์ทั้งแอปใหญ่ขึ้น
  /// จริง — เพราะ MediaQuery ที่ main.dart ครอบทั้งแอปไว้อีกที) แต่ตัวเลข % ที่
  /// ปุ่มนี้ไม่ขยับ เพราะ widget นี้ไม่มีกลไกบอกให้ rebuild เองเมื่อค่าเปลี่ยน
  /// (การ rebuild จาก ListenableBuilder ชั้นบนสุดใน main.dart ไปไม่ถึงจุดนี้
  /// เสมอไป เพราะ Flutter/Navigator เก็บ cache หน้าที่ยังไม่เปลี่ยนไว้) ครอบ
  /// ด้วย ListenableBuilder ของตัวเองตรงนี้เลย รับประกันว่า rebuild แน่นอน
  Widget _fontScaleControls(ColorScheme colors) {
    return ListenableBuilder(
      listenable: FontScaleController.instance,
      builder: (context, _) => _fontScaleControlsBody(colors),
    );
  }

  Widget _fontScaleControlsBody(ColorScheme colors) {
    final scale = FontScaleController.instance.scale;
    final percent = (scale * 100).round();
    // ตรงกับ .tb-pill ใน mockup — กรอบมน 8px + เส้นขอบจางๆ (เดิม 20px ทรง
    // แคปซูลไม่มีขอบ)
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'ลดขนาดตัวอักษร',
            child: IconButton(
              icon: const Icon(Icons.text_decrease, size: 18),
              color: colors.onPrimary,
              disabledColor: colors.onPrimary.withValues(alpha: 0.3),
              splashRadius: 18,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: scale <= minFontScale ? null : () => FontScaleController.instance.decrease(),
            ),
          ),
          Tooltip(
            message: 'กดเพื่อรีเซ็ตขนาดตัวอักษร',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => FontScaleController.instance.reset(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$percent%',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.onPrimary),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'เพิ่มขนาดตัวอักษร',
            child: IconButton(
              icon: const Icon(Icons.text_increase, size: 18),
              color: colors.onPrimary,
              disabledColor: colors.onPrimary.withValues(alpha: 0.3),
              splashRadius: 18,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: scale >= maxFontScale ? null : () => FontScaleController.instance.increase(),
            ),
          ),
        ],
      ),
    );
  }

  // ── กล่องข้อมูลโรงเรียน — ย้ายมาจาก sidebar ให้อยู่ข้างชื่อระบบแทน ──
  Widget _schoolInfoBadge(ColorScheme colors) {
    final school = _school;
    final hasName = school?.schoolName?.isNotEmpty == true;
    if (!hasName) return const SizedBox.shrink();

    final addressParts = <String>[
      if (school?.schoolAmphoe?.isNotEmpty == true) 'อ.${school!.schoolAmphoe}',
      if (school?.schoolChangwat?.isNotEmpty == true) 'จ.${school!.schoolChangwat}',
    ];

    return InkWell(
      onTap: () => _requestModeChange(AppMode.settings),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.onPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.onPrimary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 15, color: colors.onPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    school!.schoolName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (addressParts.isNotEmpty)
                    Text(
                      addressParts.join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.75), fontSize: 10.5),
                    ),
                ],
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: colors.onPrimary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  final _omniSearchCtrl = TextEditingController();
  final _omniSearchFocusNode = FocusNode();

  /// ค้นหา (.omni ใน mockup) — อยู่ที่ topbar กลาง เป็นของกลางทั้งแอปโครง
  /// สร้างแค่ครั้งเดียวตรงนี้ (ไม่ใช่ในแต่ละหน้าเหมือนก่อนหน้านี้ที่ Dashboard
  /// เคยมี omnibar ของตัวเองซ้ำซ้อนกับแถบนี้ — ทำให้เห็นแถบเขียว 2 อันซ้อนกัน)
  /// ตอนนี้ค้นหาแบบ live ข้ามหลายหน้า (เมนู/จัดซื้อจัดจ้าง/TOR/สัญญา/ครุภัณฑ์)
  /// พร้อมกดเลือกผลลัพธ์เพื่อนำทางไปหน้านั้นได้ตรงๆ ผ่าน GlobalSearchService +
  /// GlobalOmniSearch (ก่อนหน้านี้แค่พิมพ์เก็บไว้รอกด Enter ไปกรองตารางหน้าหลัก
  /// เท่านั้น — ยังคงพฤติกรรมนั้นไว้ด้วยผ่าน DashboardSearchController เผื่อ
  /// ผู้ใช้อยู่หน้าหลักแล้วกด Enter ตรงๆ)
  Widget _buildOmniSearch(ColorScheme colors) {
    return GlobalOmniSearch(
      controller: _omniSearchCtrl,
      focusNode: _omniSearchFocusNode,
      hintText: 'ค้นหาเลขที่ / ชื่อโครงการ / ชื่อกิจกรรม / ชื่อร้านค้า / เมนู',
      shortcutLabel: 'Ctrl K',
      onSearch: (q) => GlobalSearchService.search(
        _repo,
        q,
        fiscalYear: FiscalYearController.instance.viewingYear,
      ),
      onSelect: _handleSearchResultSelected,
    );
  }

  void _handleSearchResultSelected(SearchResultItem item) {
    switch (item.type) {
      case SearchResultType.menu:
        _requestModeChange(item.mode!);
        break;
      case SearchResultType.order:
        _onDashboardEditOrder(item.order!);
        break;
      case SearchResultType.fixedAsset:
        _onViewAssetFromRepairHistory(item.fixedAssetId!);
        break;
      case SearchResultType.tor:
        _requestModeChange(AppMode.tor);
        break;
      case SearchResultType.contract:
        _requestModeChange(AppMode.contracts);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Ctrl+K (Windows/Linux) / Cmd+K (macOS) โฟกัสช่องค้นหาทันทีจากทุกหน้า —
    // ป้าย "Ctrl K" ข้างช่องค้นหาเคยเป็นแค่ตัวหนังสือ ไม่ได้ผูก shortcut จริง
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _omniSearchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _omniSearchFocusNode.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: _buildScaffold(colors),
      ),
    );
  }

  Widget _buildScaffold(ColorScheme colors) {
    return Scaffold(
      appBar: AppBar(
        // mainAxisSize เป็นค่า default (max) และห่อลูกทุกตัวด้วย Flexible
        // เพื่อให้ "ยอม" หดตัวเองเมื่อหน้าต่างแคบ แทนที่จะ overflow
        // LayoutBuilder เพราะความกว้างที่ title area ได้จริงขึ้นกับพื้นที่ที่เหลือ
        // จาก actions/sidebar/right panel — ตอนหน้าต่างแคบมากๆ พื้นที่นี้อาจ
        // เหลือน้อยกว่าที่ badge เวอร์ชัน + คำบรรยายต้องการ ถ้าไม่ซ่อนเงื่อนไข
        // พวกนี้ออกไปก่อน Text ที่ Flexible ก็ช่วยไม่ได้เพราะ badge เองไม่ยอมหด
        // ต่ำกว่าขนาดจริง จึงยังล้นอยู่ดี — ซ่อน badge/คำบรรยายตอนแคบมากแทน
        title: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            return Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'ระบบเจ้าหน้าที่พัสดุ-จัดซื้อจัดจ้าง',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onPrimary),
                            ),
                          ),
                          if (!narrow) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.onPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.onPrimary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'v3.2 Retamp',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.onPrimary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!narrow)
                        Text(
                          'พัฒนาโดย Acha Srangkannork',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: colors.onPrimary.withValues(alpha: 0.7)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Flexible(flex: 3, child: _buildOmniSearch(colors)),
              ],
            );
          },
        ),
        toolbarHeight: 64,
        actions: [
          _fiscalYearBadge(colors),
          const SizedBox(width: 8),
          _fontScaleControls(colors),
          const SizedBox(width: 4),
          // ครอบ ListenableBuilder เฉพาะจุดเหมือน _fontScaleControls ด้านบน —
          // กันบั๊คเดียวกัน (ไอคอนค้างไม่สลับ) เผื่อไว้ แม้ตอนนี้จะดูเหมือน
          // ทำงานถูกอยู่แล้วก็ตาม เพราะพึ่งพา timing ของ Navigator/route cache
          // ที่ไม่รับประกันเสมอไป
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) => _topbarIconButton(
              icon: ThemeController.instance.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              tooltip: ThemeController.instance.isDark ? 'สลับเป็นโหมดสว่าง' : 'สลับเป็นโหมดมืด',
              onPressed: () => ThemeController.instance.toggle(),
            ),
          ),
          const SizedBox(width: 4),
          _notifBellButton(colors),
          const SizedBox(width: 4),
          _topbarIconButton(
            icon: Icons.refresh,
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: _onRefreshPressed,
          ),
          const SizedBox(width: 4),
          _topbarIconButton(
            icon: Icons.cloud_upload_outlined,
            tooltip: 'สำรองข้อมูล',
            onPressed: _onBackupPressed,
          ),
          if (_school?.schoolName?.isNotEmpty == true) ...[
            const SizedBox(width: 4),
            _schoolInfoBadge(colors),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          AppSidebar(
            currentMode: _mode,
            expanded: _sidebarExpanded,
            onToggle: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            onSelect: (mode) => _requestModeChange(mode),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
}

/// รายการเดียวในเมนูดรอปดาวน์ปุ่มระฆัง
class _NotifItem {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final VoidCallback onTap;

  _NotifItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.onTap,
  });
}
