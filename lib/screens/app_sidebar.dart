// app_sidebar.dart
// Sidebar widget — ย่อ/ขยายได้, highlight เมนูปัจจุบัน
// ใช้เฉพาะใน AppShell เท่านั้น (ไม่แปะซ้ำในหน้าอื่น)
//
// [อัปเดต]: เพิ่มหัวข้อชื่อระบบ+เครดิตผู้สร้าง ด้านบนสุด และแถบข้อมูลโรงเรียน
// (ดึงจาก school_settings ที่กรอกไว้ในหน้าตั้งค่า) ต่อจากปุ่ม toggle
// ต้องเปลี่ยนจาก StatelessWidget เป็น StatefulWidget เพื่อดึงข้อมูลโรงเรียนเอง

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/school_settings.dart';

const _brandColor = Color(0xFF1A3A5C);
const _sidebarExpandedWidth = 200.0;
const _sidebarCollapsedWidth = 64.0;

enum AppMode { dashboard, newOrder, budgets, settings }

class AppSidebar extends StatefulWidget {
  final AppMode currentMode;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(AppMode) onSelect;

  const AppSidebar({
    super.key,
    required this.currentMode,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
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

  /// เรียกจาก AppShell ไม่ได้ตรงๆ (sidebar ไม่รู้ตอนกลับจากหน้า settings)
  /// แต่ didUpdateWidget จะ trigger ทุกครั้งที่ AppShell rebuild (เช่นตอนสลับ
  /// mode กลับมา) จึง refresh ข้อมูลโรงเรียนให้ทันสมัยเสมอโดยไม่ต้องส่ง callback เพิ่ม
  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode == AppMode.settings && widget.currentMode != AppMode.settings) {
      _loadSchool();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: widget.expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
      decoration: BoxDecoration(
        color: _brandColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.expanded) _buildSchoolInfo(),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 4),
          _buildToggleButton(),
          const SizedBox(height: 8),
          _buildItem(AppMode.dashboard, Icons.dashboard_outlined, 'หน้าหลัก'),
          _buildItem(AppMode.newOrder, Icons.add_circle_outline, 'สร้างใหม่'),
          _buildItem(AppMode.budgets, Icons.account_balance_wallet_outlined, 'แผนงบประมาณ'),
          const Spacer(),
          _buildItem(AppMode.settings, Icons.settings_outlined, 'ตั้งค่าโรงเรียน'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── ชื่อระบบ + เครดิตผู้สร้าง ──────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? 16 : 8,
        vertical: 16,
      ),
      child: widget.expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ระบบจัดซื้อจัดจ้าง',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ban Pa Lao School',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : const Center(
              child: Icon(Icons.account_balance_outlined, color: Colors.white, size: 22),
            ),
    );
  }

  // ── ข้อมูลโรงเรียนที่กรอกไว้ในหน้าตั้งค่า ─────────────────────
  Widget _buildSchoolInfo() {
    final school = _school;
    final hasName = school?.schoolName?.isNotEmpty == true;

    // ประกอบที่อยู่สั้นๆ จาก field ที่มี (ถ้ามี)
    final addressParts = <String>[
      if (school?.schoolAmphoe?.isNotEmpty == true) 'อ.${school!.schoolAmphoe}',
      if (school?.schoolChangwat?.isNotEmpty == true) 'จ.${school!.schoolChangwat}',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school_outlined, color: Colors.white.withOpacity(0.8), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? school!.schoolName! : 'ยังไม่ได้กรอกข้อมูลโรงเรียน',
                    style: TextStyle(
                      color: hasName ? Colors.white : Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (addressParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      addressParts.join(' '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  widget.expanded ? Icons.menu_open : Icons.menu,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            if (widget.expanded) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'เมนูหลัก',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(AppMode mode, IconData icon, String label) {
    final isSelected = widget.currentMode == mode;
    return Tooltip(
      message: widget.expanded ? '' : label,
      preferBelow: false,
      child: InkWell(
        onTap: () => widget.onSelect(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment:
                widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 22,
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}