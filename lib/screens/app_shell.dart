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

  // ชื่อ AppBar ตาม mode ปัจจุบัน
  String get _appBarTitle {
    switch (_mode) {
      case AppMode.dashboard:
        return 'ระบบจัดซื้อจัดจ้าง';
      case AppMode.newOrder:
        return _editingOrder == null ? 'สร้างเอกสารใหม่' : 'แก้ไขเอกสาร';
      case AppMode.budgets:
        return 'แผนงบประมาณ';
      case AppMode.settings:
        return 'ตั้งค่าโรงเรียน';
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
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