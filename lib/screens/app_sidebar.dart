// app_sidebar.dart
// Sidebar widget — ย่อ/ขยายได้, highlight เมนูปัจจุบัน
// ใช้เฉพาะใน AppShell เท่านั้น (ไม่แปะซ้ำในหน้าอื่น)
//
// [อัปเดต ธีมใหม่]: เลิกใช้สีกรมท่า/ทองแบบเดิม เปลี่ยนไปดึงสีจาก Theme
// (colorScheme) แทนทั้งหมด เพื่อให้รองรับโหมดสว่าง/มืด และใช้สีเขียวหัวเป็ด
// (teal) เป็นสีเน้นเดียวของทั้งแอปตามที่ตกลงกันไว้
//
// [ย้ายออก]: กล่องข้อมูลโรงเรียนย้ายไปแสดงที่ AppBar ด้านบนแทน (อยู่ข้างๆ
// ชื่อระบบ) sidebar จึงเหลือแค่เมนูนำทางล้วนๆ
//
// [แก้บัค พับ/ยืดแล้ว overflow]: จุดที่พังคือใช้ Expanded ใส่ label ข้างใน Row
// ที่อยู่ใน container ซึ่งความกว้างกำลังเล่นแอนิเมชันอยู่ — เลขที่ Flutter
// คำนวณพื้นที่ให้ Expanded ระหว่างเฟรมเปลี่ยนความกว้างบางจังหวะได้ค่าติดลบ/ไม่พอ
// ทำให้ overflow เปลี่ยนวิธีใหม่: ไม่ใช้ Expanded/Flexible เลย ให้ Row มีขนาด
// เท่าที่จำเป็นจริง (mainAxisSize.min) แล้วควบคุมความกว้างของ label ด้วย
// AnimatedContainer(width: ...) ตรงๆ แทน — คำนวณง่าย ไม่มีทาง overflow

import 'package:flutter/material.dart';

const _sidebarExpandedWidth = 200.0;
const _sidebarCollapsedWidth = 64.0;
const _sidebarLabelWidth = 130.0;
const _sidebarAnimDuration = Duration(milliseconds: 220);
const _sidebarAnimCurve = Curves.easeInOut;

enum AppMode { dashboard, newOrder, easyWizard, budgets, tor, contracts, guarantees, inspections, documentHub, orderRegister, controlLog, fixedAssets, materials, annualCount, disposals, reports, settings, aiSettings }

class AppSidebar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      child: AnimatedContainer(
        duration: _sidebarAnimDuration,
        curve: _sidebarAnimCurve,
        width: expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildToggleButton(colors),
            const SizedBox(height: 8),
            // เมนูมีเยอะขึ้นเรื่อยๆ ตามฟีเจอร์ที่เพิ่ม — ห่อด้วย Expanded +
            // SingleChildScrollView กันไม่ให้ล้นจอตอนหน้าต่างเตี้ย/เมนูเยอะเกินพื้นที่
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(colors, 'ภาพรวม', first: true),
                    _buildItem(colors, AppMode.dashboard, Icons.dashboard_outlined, 'หน้าหลัก'),

                    _buildSectionHeader(colors, 'สร้างเอกสาร'),
                    _buildItem(colors, AppMode.newOrder, Icons.add_circle_outline, 'สร้างใหม่'),
                    _buildItem(colors, AppMode.easyWizard, Icons.auto_awesome_outlined, 'Easy Wizard'),

                    _buildSectionHeader(colors, 'กระบวนการจัดซื้อจัดจ้าง'),
                    _buildItem(colors, AppMode.budgets, Icons.account_balance_wallet_outlined, 'แผนงบประมาณ'),
                    _buildItem(colors, AppMode.tor, Icons.description_outlined, 'TOR/คุณลักษณะ'),
                    _buildItem(colors, AppMode.contracts, Icons.article_outlined, 'บริหารสัญญา'),
                    _buildItem(colors, AppMode.guarantees, Icons.shield_outlined, 'หลักประกัน'),
                    _buildItem(colors, AppMode.inspections, Icons.fact_check_outlined, 'ตรวจรับพัสดุ'),
                    _buildItem(colors, AppMode.documentHub, Icons.file_copy_outlined, 'สร้างเอกสารราชการ'),
                    _buildItem(colors, AppMode.orderRegister, Icons.numbers_outlined, 'ทะเบียนคุมเลขที่'),
                    _buildItem(colors, AppMode.controlLog, Icons.receipt_long_outlined, 'ทะเบียนคุมเลขบันทึก/TOR'),

                    _buildSectionHeader(colors, 'ทรัพย์สินและพัสดุ'),
                    _buildItem(colors, AppMode.fixedAssets, Icons.inventory_2_outlined, 'ทะเบียนครุภัณฑ์'),
                    _buildItem(colors, AppMode.materials, Icons.inventory_outlined, 'วัสดุ/คลังพัสดุ'),
                    _buildItem(colors, AppMode.annualCount, Icons.checklist_outlined, 'ตรวจนับประจำปี'),
                    _buildItem(colors, AppMode.disposals, Icons.delete_sweep_outlined, 'จำหน่ายพัสดุ'),

                    _buildSectionHeader(colors, 'รายงานและตรวจสอบ'),
                    _buildItem(colors, AppMode.reports, Icons.bar_chart_outlined, 'รายงาน/สตง.'),
                  ],
                ),
              ),
            ),
            _buildSectionHeader(colors, 'ตั้งค่า'),
            _buildItem(colors, AppMode.aiSettings, Icons.auto_awesome_outlined, 'ตั้งค่า AI'),
            _buildItem(colors, AppMode.settings, Icons.settings_outlined, 'ตั้งค่าโรงเรียน'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(ColorScheme colors) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  expanded ? Icons.menu_open : Icons.menu,
                  color: colors.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
            ClipRect(
              child: AnimatedContainer(
                duration: _sidebarAnimDuration,
                curve: _sidebarAnimCurve,
                height: 22,
                width: expanded ? _sidebarLabelWidth : 0,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    'เมนูหลัก',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// หัวข้อคั่นหมวดหมู่เมนู — ตอนขยายโชว์เป็นข้อความตัวเล็ก, ตอนพับเหลือแค่
  /// เส้นแบ่งบางๆ (ไม่มีที่พอใส่ข้อความ) กัน sidebar ยาวๆ ดูเป็น list เดียวรวด
  Widget _buildSectionHeader(ColorScheme colors, String label, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 6, left: 16, right: 16),
      child: expanded
          ? Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            )
          : Divider(height: 1, color: colors.outlineVariant),
    );
  }

  Widget _buildItem(ColorScheme colors, AppMode mode, IconData icon, String label) {
    final isSelected = currentMode == mode;
    return Tooltip(
      message: expanded ? '' : label,
      preferBelow: false,
      child: InkWell(
        onTap: () => onSelect(mode),
        child: AnimatedContainer(
          duration: _sidebarAnimDuration,
          curve: _sidebarAnimCurve,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          // ซ้าย 9 ไม่ใช่ 12 — เพราะเส้นขอบซ้าย (border) ด้านล่างกินพื้นที่ไป
          // อีก 3px เสมอ (แม้เป็นสีใส/transparent ก็ยังนับความกว้างอยู่ดี)
          // ถ้าใช้ 12 เท่ากันทุกด้าน รวมแล้วจะเกินพื้นที่จริง 3px ทำให้ล้นตอนพับ
          padding: const EdgeInsets.only(left: 9, right: 12, top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border(left: BorderSide(color: colors.primary, width: 3))
                : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                size: 22,
              ),
              ClipRect(
                child: AnimatedContainer(
                  duration: _sidebarAnimDuration,
                  curve: _sidebarAnimCurve,
                  height: 22,
                  width: expanded ? _sidebarLabelWidth : 0,
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
