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
import 'app_sidebar.dart';
import 'dashboard_screen.dart';
import 'order_wizard_screen.dart';
import 'easy_wizard_screen.dart';
import 'document_hub_screen.dart';
import 'budget_list_screen.dart';
import 'tor_screen.dart';
import 'contracts_screen.dart';
import 'guarantees_screen.dart';
import 'inspections_screen.dart';
import 'fixed_assets_screen.dart';
import 'materials_screen.dart';
import 'annual_count_screen.dart';
import 'disposals_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'ai_settings_screen.dart';
import '../models/procurement_order.dart';
import '../models/school_settings.dart';
import '../data/procurement_repository.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';
import '../services/theme_controller.dart';

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

  final _repo = ProcurementRepository();
  SchoolSettings? _school;

  @override
  void initState() {
    super.initState();
    _loadSchool();
  }

  Future<void> _loadSchool() async {
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() => _school = school);
  }

  // ─────────────────────────────────────────
  // การสลับ mode — ถ้า wizard dirty จะเด้ง dialog ก่อน
  // ─────────────────────────────────────────

  Future<void> _requestModeChange(AppMode newMode, {ProcurementOrder? editingOrder}) async {
    // ถ้าอยู่หน้า wizard และมีข้อมูลค้าง → ถามก่อน
    if (_mode == AppMode.newOrder && _wizardIsDirty) {
      final confirmed = await _showDirtyDialog();
      if (!confirmed) return;
    }
    final leavingSettings = _mode == AppMode.settings && newMode != AppMode.settings;
    setState(() {
      _mode = newMode;
      _editingOrder = editingOrder;
      _wizardIsDirty = false;
    });
    // กลับมาจากหน้าตั้งค่า → โหลดข้อมูลโรงเรียนใหม่ เผื่อมีการแก้ไข
    if (leavingSettings) _loadSchool();
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

  // ให้ quick-action grid ใน DashboardScreen สลับไป budgets/settings ได้ตรงๆ
  // (แยกจาก onCreateNew/onEditOrder เพราะสองตัวนั้นตั้งใจไปแค่ newOrder เท่านั้น)
  void _onDashboardNavigate(AppMode mode) {
    _requestModeChange(mode);
  }

  Future<void> _onBackupPressed() async {
    final colors = Theme.of(context).colorScheme;
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
              subtitle: const Text('บันทึกไฟล์ .zip ไปที่ BanPaLao_Documents'),
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
  }

  int _refreshKey = 0;

  Future<void> _doBackup() async {
    try {
      final path = await BackupService.instance.backup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('สำรองข้อมูลสำเร็จ\n$path'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('สำรองข้อมูลไม่สำเร็จ: $e'),
        backgroundColor: Colors.redAccent,
      ));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('คืนข้อมูลสำเร็จ กำลังโหลดข้อมูลใหม่...'),
        backgroundColor: Colors.green.shade700,
      ));
      // reload dashboard
      setState(() { _mode = AppMode.dashboard; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('คืนข้อมูลไม่สำเร็จ: $e'),
        backgroundColor: Colors.redAccent,
      ));
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
        return DashboardScreen(
          key: ValueKey(_refreshKey),
          onCreateNew: _onDashboardCreateNew,
          onEditOrder: _onDashboardEditOrder,
          onNavigate: _onDashboardNavigate,
        );
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
      case AppMode.documentHub:
        return const DocumentHubScreen();
      case AppMode.fixedAssets:
        return const FixedAssetsScreen();
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

  // แสดงปีงบประมาณ พ.ศ. ปัจจุบันเฉยๆ (คำนวณจากวันที่เครื่องจริง) — ยังไม่ใช่
  // dropdown เลือกปีงบ เพราะ dashboard ยังไม่รองรับกรองข้อมูลข้ามปีงบ
  Widget _fiscalYearBadge(ColorScheme colors) {
    final buddhistYear = DateTime.now().year + 543;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: colors.onPrimary),
          const SizedBox(width: 6),
          Text(
            'ปีงบฯ $buddhistYear',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.onPrimary),
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

    return Container(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // mainAxisSize เป็นค่า default (max) และห่อลูกทุกตัวด้วย Flexible
        // เพื่อให้ "ยอม" หดตัวเองเมื่อหน้าต่างแคบ แทนที่จะ overflow
        title: Row(
          children: [
            Flexible(
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.onPrimary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'v2.0.1',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.onPrimary),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'พัฒนาโดย Kru.Zetaz',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: colors.onPrimary.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Flexible(child: _schoolInfoBadge(colors)),
          ],
        ),
        toolbarHeight: 64,
        actions: [
          _fiscalYearBadge(colors),
          const SizedBox(width: 8),
          Tooltip(
            message: ThemeController.instance.isDark ? 'สลับเป็นโหมดสว่าง' : 'สลับเป็นโหมดมืด',
            child: IconButton(
              icon: Icon(ThemeController.instance.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => ThemeController.instance.toggle(),
            ),
          ),
          Tooltip(
            message: 'รีเฟรชข้อมูล',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefreshPressed,
            ),
          ),
          Tooltip(
            message: 'สำรองข้อมูล',
            child: IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: _onBackupPressed,
            ),
          ),
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
