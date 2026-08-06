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
//
// [เพิ่ม ลากจัดลำดับเมนู]: ผู้ใช้แต่ละคนใช้เมนูถี่ไม่เท่ากัน — เพิ่มด้ามจับลาก
// (⠿) ท้ายแต่ละรายการ (โชว์เฉพาะตอนกางออก มีที่พอ) ลากขึ้น/ลงเพื่อจัดลำดับ
// ภายในหมวดเดียวกันได้เอง ลำดับที่จัดถูกจำไว้ด้วย SharedPreferences แยกตาม
// เครื่อง ไม่กระทบผู้ใช้คนอื่น/เครื่องอื่น — ลากแค่ด้ามจับเท่านั้น ส่วนอื่นของ
// แถวยังกดนำทางได้ตามปกติไม่ชนกัน

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sidebarExpandedWidth = 200.0;
const _sidebarCollapsedWidth = 64.0;
const _sidebarLabelWidth = 130.0;
const _sidebarAnimDuration = Duration(milliseconds: 220);
const _sidebarAnimCurve = Curves.easeInOut;
const _sidebarOrderPrefsKey = 'sidebar_item_order_v1';

enum AppMode { dashboard, procurementCalendar, newOrder, easyWizard, budgets, tor, contracts, guarantees, inspections, installmentContracts, documentHub, orderRegister, controlLog, fixedAssets, repairHistory, materials, annualCount, disposals, reports, settings, aiSettings }

/// ไอคอน+ชื่อเมนูของแต่ละ AppMode — แยกออกมาจากลำดับการแสดงผล เพื่อให้ลำดับ
/// ที่ผู้ใช้ลากจัดเองแล้ว ยังหาไอคอน/ชื่อที่ถูกต้องมาแสดงได้เสมอไม่ว่าจะสลับ
/// ตำแหน่งกันแบบไหนก็ตาม
const Map<AppMode, (IconData, String)> _modeMeta = {
  AppMode.dashboard: (Icons.dashboard_outlined, 'หน้าหลัก'),
  AppMode.procurementCalendar: (Icons.event_note_outlined, 'ปฏิทินงานพัสดุ'),
  AppMode.newOrder: (Icons.add_circle_outline, 'สร้างใหม่'),
  AppMode.easyWizard: (Icons.auto_awesome_outlined, 'Easy Wizard'),
  AppMode.budgets: (Icons.account_balance_wallet_outlined, 'แผนงบประมาณ'),
  AppMode.tor: (Icons.description_outlined, 'TOR/คุณลักษณะ'),
  AppMode.contracts: (Icons.article_outlined, 'บริหารสัญญา'),
  AppMode.guarantees: (Icons.shield_outlined, 'หลักประกัน'),
  AppMode.inspections: (Icons.fact_check_outlined, 'ตรวจรับพัสดุ'),
  AppMode.installmentContracts: (Icons.event_repeat_outlined, 'สัญญาต่อเนื่องหลายงวด'),
  AppMode.documentHub: (Icons.file_copy_outlined, 'สร้างเอกสารราชการ'),
  AppMode.orderRegister: (Icons.numbers_outlined, 'ทะเบียนคุมเลขที่'),
  AppMode.controlLog: (Icons.receipt_long_outlined, 'ทะเบียนคุมเลขบันทึก/TOR'),
  AppMode.fixedAssets: (Icons.inventory_2_outlined, 'ทะเบียนครุภัณฑ์'),
  AppMode.repairHistory: (Icons.build_outlined, 'ประวัติซ่อมครุภัณฑ์'),
  AppMode.materials: (Icons.inventory_outlined, 'วัสดุ/คลังพัสดุ'),
  AppMode.annualCount: (Icons.checklist_outlined, 'ตรวจนับประจำปี'),
  AppMode.disposals: (Icons.delete_sweep_outlined, 'จำหน่ายพัสดุ'),
  AppMode.reports: (Icons.bar_chart_outlined, 'รายงาน/สตง.'),
  AppMode.aiSettings: (Icons.auto_awesome_outlined, 'ตั้งค่า AI'),
  AppMode.settings: (Icons.settings_outlined, 'ตั้งค่าโรงเรียน'),
};

class _SidebarSection {
  final String key;
  final String title;
  final List<AppMode> defaultOrder;
  const _SidebarSection(this.key, this.title, this.defaultOrder);
}

// หมวด "ตั้งค่า" (aiSettings/settings) ตั้งใจไม่ใส่ในนี้ — ปักหมุดไว้ท้าย
// sidebar เสมอ ไม่ให้ลากปนกับเมนูใช้งานหลัก ตามพฤติกรรมเดิม
//
// [จัดหมวดใหม่]: เดิมหมวด "กระบวนการจัดซื้อจัดจ้าง" ยัดรวมกันไว้ 9 รายการ
// (ตั้งแต่วางแผนงบไปจนถึงทะเบียนคุมเลขที่) กลายเป็นลิ้นชักรวมที่หาเมนูยาก —
// แยกตามลำดับขั้นตอนงานจริงแทน: วางแผน/จัดเตรียมเอกสารก่อนซื้อ →
// ดำเนินการจัดซื้อจัดจ้าง (มีคู่สัญญาแล้ว) → ทะเบียน/เลขที่เอกสารอ้างอิง
// (งานเอกสารคุมเลขที่ ทำแยกจังหวะกับงานหลักอยู่แล้ว)
const _sections = [
  _SidebarSection('overview', 'ภาพรวม', [AppMode.dashboard, AppMode.procurementCalendar]),
  _SidebarSection('create', 'สร้างเอกสาร', [
    AppMode.newOrder,
    AppMode.easyWizard,
    AppMode.documentHub,
  ]),
  _SidebarSection('prepare', 'วางแผน/จัดเตรียมการจัดซื้อ', [
    AppMode.budgets,
    AppMode.tor,
  ]),
  _SidebarSection('execute', 'ดำเนินการจัดซื้อจัดจ้าง', [
    AppMode.contracts,
    AppMode.guarantees,
    AppMode.inspections,
    AppMode.installmentContracts,
  ]),
  _SidebarSection('registers', 'ทะเบียน/เลขที่เอกสาร', [
    AppMode.orderRegister,
    AppMode.controlLog,
  ]),
  _SidebarSection('assets', 'ทรัพย์สินและพัสดุ', [
    AppMode.fixedAssets,
    AppMode.repairHistory,
    AppMode.materials,
    AppMode.annualCount,
    AppMode.disposals,
  ]),
  _SidebarSection('reports', 'รายงานและตรวจสอบ', [AppMode.reports]),
];

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
  // ลำดับปัจจุบันของแต่ละหมวด (key ของ _SidebarSection -> ลิสต์ AppMode) —
  // เริ่มด้วยลำดับ default ไปก่อน แล้วค่อยทับด้วยค่าที่จำไว้ตอนโหลดเสร็จ
  // กันจอกระพริบ/ว่างเปล่าระหว่างรออ่าน SharedPreferences (async)
  late final Map<String, List<AppMode>> _order = {
    for (final s in _sections) s.key: List.of(s.defaultOrder),
  };

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sidebarOrderPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final next = <String, List<AppMode>>{};
      for (final s in _sections) {
        final savedNames = (saved[s.key] as List<dynamic>?)?.cast<String>() ?? const [];
        final byName = {for (final m in s.defaultOrder) m.name: m};
        final ordered = <AppMode>[
          for (final name in savedNames)
            if (byName.containsKey(name)) byName[name]!,
        ];
        // เมนูใหม่ที่เพิ่งเพิ่มเข้ามาทีหลัง (ยังไม่เคยอยู่ในลำดับที่จำไว้) —
        // ต่อท้ายตามลำดับ default เดิม กันเมนูหายไปจาก sidebar เงียบๆ
        for (final m in s.defaultOrder) {
          if (!ordered.contains(m)) ordered.add(m);
        }
        next[s.key] = ordered;
      }
      if (mounted) setState(() => _order.addAll(next));
    } catch (_) {
      // ค่าที่จำไว้เพี้ยน/อ่านไม่ออก — ปล่อยผ่าน ใช้ลำดับ default ต่อไปเงียบๆ
      // ไม่ต้องรบกวนผู้ใช้ด้วย error ของแค่การจัดลำดับเมนู
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final asNames = {
      for (final entry in _order.entries) entry.key: [for (final m in entry.value) m.name],
    };
    await prefs.setString(_sidebarOrderPrefsKey, jsonEncode(asNames));
  }

  void _onReorder(String sectionKey, int oldIndex, int newIndex) {
    setState(() {
      final list = _order[sectionKey]!;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
    _saveOrder();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      child: AnimatedContainer(
        duration: _sidebarAnimDuration,
        curve: _sidebarAnimCurve,
        width: widget.expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
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
                    for (var i = 0; i < _sections.length; i++) ...[
                      _buildSectionHeader(colors, _sections[i].title, first: i == 0),
                      _buildSectionList(colors, _sections[i]),
                    ],
                  ],
                ),
              ),
            ),
            _buildSectionHeader(colors, 'ตั้งค่า'),
            _buildItem(colors, AppMode.aiSettings),
            _buildItem(colors, AppMode.settings),
            _buildWhtFooter(colors),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// รายการเมนูของหนึ่งหมวด — ใช้ ReorderableListView ซ้อนอยู่ใน
  /// SingleChildScrollView หลักอีกที (ปิด scroll ของตัวเอง/ยุบตามเนื้อหาจริง
  /// ด้วย shrinkWrap) เพื่อให้ลากสลับตำแหน่งได้เฉพาะภายในหมวดเดียวกัน โดยยังอยู่
  /// ใต้หัวข้อหมวดเดิม ไม่ทำให้โครงสร้างเมนูสับสน
  Widget _buildSectionList(ColorScheme colors, _SidebarSection section) {
    final items = _order[section.key]!;
    return ReorderableListView(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (oldIndex, newIndex) => _onReorder(section.key, oldIndex, newIndex),
      children: [
        for (var i = 0; i < items.length; i++)
          _buildItem(colors, items[i], key: ValueKey(items[i]), dragIndex: i),
      ],
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
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  widget.expanded ? Icons.menu_open : Icons.menu,
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
                width: widget.expanded ? _sidebarLabelWidth : 0,
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
      child: widget.expanded
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

  /// แถบอ้างอิงอัตราหัก ณ ที่จ่ายค้างไว้ท้าย sidebar ตลอด — ช่วยเจ้าหน้าที่ไม่ต้อง
  /// เปิดหาอัตราภาษีทุกครั้งที่กรอกบิล ตอนพับ sidebar เหลือแค่ไอคอนกดดู tooltip
  static const _whtText = 'ซื้อสินค้า = ไม่หัก (0%)\nจ้างทำของ/บริการ = 3%\nค่าเช่า = 5%';

  Widget _buildWhtFooter(ColorScheme colors) {
    if (!widget.expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Tooltip(
          message: 'อัตราหัก ณ ที่จ่าย (ประมวลรัษฎากร)\n$_whtText',
          preferBelow: false,
          child: Icon(Icons.percent_outlined, size: 18, color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.percent_outlined, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'หัก ณ ที่จ่าย\nซื้อ=0% | จ้าง=3% | เช่า=5%',
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// แถวเมนูหนึ่งรายการ — ใส่ [dragIndex] เฉพาะรายการที่อยู่ใน
  /// ReorderableListView (หมวดที่ลากจัดลำดับได้) เพื่อผูกด้ามจับลากด้วย
  /// ReorderableDragStartListener; รายการในหมวด "ตั้งค่า" ที่ปักหมุดไว้ท้ายสุด
  /// จะไม่ส่งพารามิเตอร์นี้มา จึงไม่มีด้ามจับ/ลากไม่ได้ตามที่ตั้งใจ
  Widget _buildItem(ColorScheme colors, AppMode mode, {Key? key, int? dragIndex}) {
    final meta = _modeMeta[mode]!;
    final row = _SidebarItemTile(
      icon: meta.$1,
      label: meta.$2,
      isSelected: widget.currentMode == mode,
      expanded: widget.expanded,
      dragIndex: dragIndex,
      onTap: () => widget.onSelect(mode),
    );
    return key != null ? KeyedSubtree(key: key, child: row) : row;
  }
}

/// แยกเป็น widget ของตัวเองต่างหาก (แทนที่จะเป็นแค่ method) เพราะต้องมี state
/// ของตัวเอง (hover) — ด้ามจับลาก ⠿ เดิมโชว์ติดอยู่ตลอดข้างชื่อเมนูทุกรายการ
/// ทำให้ sidebar ดูรก/แน่นเกินไปทั้งที่ปกติผู้ใช้ไม่ได้ลากบ่อย — เปลี่ยนให้
/// โผล่มาเฉพาะตอนเอาเมาส์ชี้ (hover) เท่านั้น เหมือน sidebar ของโปรแกรมทั่วไป
/// (VS Code/Notion) กันตาลาย ส่วนพื้นที่ยังกันไว้เท่าเดิมตลอด (แค่โปร่งใส/ทึบ
/// สลับกัน) ไม่ให้ชื่อเมนูขยับตำแหน่งเวลาเมาส์เข้า-ออก
class _SidebarItemTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool expanded;
  final int? dragIndex;
  final VoidCallback onTap;

  const _SidebarItemTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.expanded,
    required this.dragIndex,
    required this.onTap,
  });

  @override
  State<_SidebarItemTile> createState() => _SidebarItemTileState();
}

class _SidebarItemTileState extends State<_SidebarItemTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = widget.isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.expanded ? '' : widget.label,
        preferBelow: false,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _sidebarAnimDuration,
            curve: _sidebarAnimCurve,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            // ซ้าย 9 ไม่ใช่ 12 — เพราะเส้นขอบซ้าย (border) ด้านล่างกินพื้นที่ไป
            // อีก 3px เสมอ (แม้เป็นสีใส/transparent ก็ยังนับความกว้างอยู่ดี)
            // ถ้าใช้ 12 เท่ากันทุกด้าน รวมแล้วจะเกินพื้นที่จริง 3px ทำให้ล้นตอนพับ
            padding: const EdgeInsets.only(left: 9, right: 8, top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: widget.isSelected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: widget.isSelected
                  ? Border(left: BorderSide(color: colors.primary, width: 3))
                  : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: fg, size: 22),
                ClipRect(
                  child: AnimatedContainer(
                    duration: _sidebarAnimDuration,
                    curve: _sidebarAnimCurve,
                    height: 22,
                    // กันพื้นที่ด้ามจับไว้เท่ากันตลอดไม่ว่าจะ hover อยู่หรือไม่
                    // (แค่ซ่อน/โชว์ด้วยความโปร่งใส) กันชื่อเมนูขยับตำแหน่งเวลา
                    // เมาส์เข้า-ออก
                    width: widget.expanded
                        ? (widget.dragIndex != null ? _sidebarLabelWidth - 16 : _sidebarLabelWidth)
                        : 0,
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: fg,
                          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.dragIndex != null && widget.expanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: _hovering ? 1 : 0,
                      child: ReorderableDragStartListener(
                        index: widget.dragIndex!,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Icon(Icons.drag_indicator, size: 14, color: fg.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
