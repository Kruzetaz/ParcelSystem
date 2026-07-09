// app_shell.dart
// Scaffold หลักของแอป — ถือ AppBar + Sidebar + สลับ content 4 โหมด
// dirty-check dialog เตือนก่อนสลับเมื่อ wizard ยังไม่ได้บันทึก

import 'package:flutter/material.dart';
import 'app_sidebar.dart';
import 'dashboard_screen.dart';
import 'order_wizard_screen.dart';
import 'budget_list_screen.dart';
import 'settings_screen.dart';
import '../models/procurement_order.dart';

const _brandColor = Color(0xFF1A3A5C);
const _goldAccent = Color(0xFFC9A227);

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

  // ─────────────────────────────────────────
  // การสลับ mode — ถ้า wizard dirty จะเด้ง dialog ก่อน
  // ─────────────────────────────────────────

  Future<void> _requestModeChange(AppMode newMode, {ProcurementOrder? editingOrder}) async {
    // ถ้าอยู่หน้า wizard และมีข้อมูลค้าง → ถามก่อน
    if (_mode == AppMode.newOrder && _wizardIsDirty) {
      final confirmed = await _showDirtyDialog();
      if (!confirmed) return;
    }
    setState(() {
      _mode = newMode;
      _editingOrder = editingOrder;
      _wizardIsDirty = false;
    });
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

  // ให้ quick-action grid ใน DashboardScreen สลับไป budgets/settings ได้ตรงๆ
  // (แยกจาก onCreateNew/onEditOrder เพราะสองตัวนั้นตั้งใจไปแค่ newOrder เท่านั้น)
  void _onDashboardNavigate(AppMode mode) {
    _requestModeChange(mode);
  }

  // ปุ่มสำรองข้อมูลใน AppBar — ยังไม่ได้ทำฟีเจอร์จริง (อยู่ใน backlog "Backup/Export")
  // ใส่ปุ่มไว้ก่อนตามที่ตกลงกันไว้ตอนออกแบบ UI แต่บอกตรงๆ ว่ายังใช้งานไม่ได้จริง
  void _onBackupPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์สำรองข้อมูลยังไม่เปิดใช้งาน (อยู่ระหว่างพัฒนา)')),
    );
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
      case AppMode.budgets:
        return const BudgetListScreen();
      case AppMode.settings:
        return const SettingsScreen();
    }
  }

  // แสดงปีงบประมาณ พ.ศ. ปัจจุบันเฉยๆ (คำนวณจากวันที่เครื่องจริง) — ยังไม่ใช่
  // dropdown เลือกปีงบ เพราะ dashboard ยังไม่รองรับกรองข้อมูลข้ามปีงบ
  Widget _fiscalYearBadge() {
    final buddhistYear = DateTime.now().year + 543;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: _goldAccent),
          const SizedBox(width: 6),
          Text(
            'ปีงบฯ $buddhistYear',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ระบบจัดซื้อจัดจ้าง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _goldAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _goldAccent.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'v1.0',
                    style: TextStyle(color: _goldAccent, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Text(
              'พัฒนาโดย Kru.Zetaz',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        actions: [
          _fiscalYearBadge(),
          const SizedBox(width: 8),
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