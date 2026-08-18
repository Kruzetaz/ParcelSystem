// app_sidebar.dart
// Sidebar widget — ย่อ/ขยายได้, highlight เมนูปัจจุบัน
// ใช้เฉพาะใน AppShell เท่านั้น (ไม่แปะซ้ำในหน้าอื่น)
//
// [ธีมใหม่ — rail ตาม mockup dashboard-finalv2]: พื้นหลังเป็นสีเขียวเข้ม
// (BrandColors.tealDark) คงที่เสมอ ไม่ขึ้นกับโหมดสว่าง/มืดของแอป (มockup เองก็
// กำหนด --rail เป็นค่าเดียวกันทั้งสองธีม) ตัวหนังสือ/ไอคอนเป็นสีขาวโปร่งแสง
// ต่างระดับกัน รายการที่เลือกอยู่กลายเป็นพื้นขาวตัดกับพื้นเข้ม (.it.sel ใน
// mockup) แทนที่จะดึงสีจาก ColorScheme ของแอปเหมือนเดิม
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
import '../theme/design_tokens.dart';

// เดิม 212 กว้างเกินไปสำหรับป้ายสั้นๆ (เหลือพื้นที่ว่างขวามือเยอะ) แต่ 196
// แคบไปสำหรับป้ายยาวสุด ("ทะเบียนคุมเลขบันทึก/TOR", "สัญญาต่อเนื่องหลายงวด")
// ทำให้ตัวหนังสือโดนตัดกลางคำ — 210 คือจุดกลางที่พอดีกับป้ายยาวสุดจริงๆ
// (ป้ายที่ยังยาวเกินกว่านี้จะขึ้น "…" แทนแทนที่จะตัดกลางคำแบบเดิม)
const _sidebarExpandedWidth = 210.0;
// เดิม 64 — ไอคอน (18px) + padding(6+6) + margin(7+7) ต้องการแค่ ~44px ทำให้
// เหลือพื้นที่ว่างรอบไอคอนเยอะเกินไปตอนพับ ลดลงมาให้กระชับขึ้นแต่ยังเผื่อ
// ระยะกดสบายๆ ไว้บ้าง
const _sidebarCollapsedWidth = 52.0;
const _sidebarLabelWidth = 156.0;
const _sidebarAnimDuration = Duration(milliseconds: 220);
const _sidebarAnimCurve = Curves.easeInOut;
const _sidebarOrderPrefsKey = 'sidebar_item_order_v1';

enum AppMode { dashboard, procurementCalendar, newOrder, easyWizard, budgets, tor, contracts, guarantees, inspections, installmentContracts, documentHub, orderRegister, controlLog, documentChecklist, learningMaterials, fixedAssets, repairHistory, materials, annualCount, disposals, reports, settings, aiSettings }

/// ไอคอน+ชื่อเมนูของแต่ละ AppMode — แยกออกมาจากลำดับการแสดงผล เพื่อให้ลำดับ
/// ที่ผู้ใช้ลากจัดเองแล้ว ยังหาไอคอน/ชื่อที่ถูกต้องมาแสดงได้เสมอไม่ว่าจะสลับ
/// ตำแหน่งกันแบบไหนก็ตาม
const Map<AppMode, (IconData, String)> modeMeta = {
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
  AppMode.documentChecklist: (Icons.fact_check_outlined, 'ทะเบียนตรวจสอบเอกสาร'),
  AppMode.learningMaterials: (Icons.menu_book_outlined, 'หนังสือเรียน/อุปกรณ์การเรียน'),
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
    AppMode.documentChecklist,
  ]),
  _SidebarSection('assets', 'ทรัพย์สินและพัสดุ', [
    AppMode.fixedAssets,
    AppMode.repairHistory,
    AppMode.materials,
    AppMode.learningMaterials,
    AppMode.annualCount,
    AppMode.disposals,
  ]),
  _SidebarSection('reports', 'รายงานและตรวจสอบ', [AppMode.reports]),
];

/// ชุดสีของ rail — คงที่ตลอด ไม่ขึ้นกับ ColorScheme/โหมดสว่าง-มืดของแอป
/// (ตรงกับที่ mockup กำหนด --rail เป็นค่าเดียวกันทั้ง light/dark theme)
class _RailColors {
  _RailColors._();
  static const bg = BrandColors.tealDark;
  static Color divider = Colors.white.withValues(alpha: 0.12);
  static Color text = Colors.white.withValues(alpha: 0.78);
  static Color textDim = Colors.white.withValues(alpha: 0.45);
  static Color hoverBg = Colors.white.withValues(alpha: 0.1);
  static const selectedBg = Colors.white;
  static const selectedText = BrandColors.tealDark;
  static const selectedAccent = BrandColors.tealLight;
  static Color footerBg = Colors.white.withValues(alpha: 0.08);
  static Color footerText = Colors.white.withValues(alpha: 0.55);
}

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
    return ClipRect(
      child: AnimatedContainer(
        duration: _sidebarAnimDuration,
        curve: _sidebarAnimCurve,
        width: widget.expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
        decoration: const BoxDecoration(color: _RailColors.bg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildToggleButton(),
            const SizedBox(height: 8),
            // หมวด "ภาพรวม" (หน้าหลัก/ปฏิทินงานพัสดุ) ปักหมุดไว้นอกส่วนเลื่อน
            // ตลอด — เป็นเมนูที่กดกลับบ่อยที่สุด ถ้าปล่อยให้เลื่อนหายไปพร้อม
            // เมนูอื่นตอนลิสต์ยาว ต้องเลื่อนขึ้นไปหาทุกครั้งกว่าจะกลับหน้าหลักได้
            _buildSectionHeader(_sections[0].title, first: true),
            _buildSectionList(_sections[0]),
            // เส้นแบ่งจางๆ คั่นระหว่างส่วนที่ปักหมุดกับส่วนที่เลื่อนได้ — ไม่งั้น
            // พื้นหลังสีเดียวกันทั้งแถบ มองแวบแรกแยกไม่ออกว่าเป็นคนละส่วนกัน
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Divider(height: 1, thickness: 1, color: _RailColors.divider),
            ),
            // เมนูที่เหลือมีเยอะขึ้นเรื่อยๆ ตามฟีเจอร์ที่เพิ่ม — ห่อด้วย Expanded +
            // SingleChildScrollView กันไม่ให้ล้นจอตอนหน้าต่างเตี้ย/เมนูเยอะเกินพื้นที่
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 1; i < _sections.length; i++) ...[
                      _buildSectionHeader(_sections[i].title),
                      _buildSectionList(_sections[i]),
                    ],
                  ],
                ),
              ),
            ),
            _buildSectionHeader('ตั้งค่า'),
            _buildItem(AppMode.aiSettings),
            _buildItem(AppMode.settings),
            _buildWhtFooter(),
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
  Widget _buildSectionList(_SidebarSection section) {
    final items = _order[section.key]!;
    return ReorderableListView(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (oldIndex, newIndex) => _onReorder(section.key, oldIndex, newIndex),
      children: [
        for (var i = 0; i < items.length; i++)
          _buildItem(items[i], key: ValueKey(items[i]), dragIndex: i),
      ],
    );
  }

  Widget _buildToggleButton() {
    return _SidebarToggleTile(expanded: widget.expanded, onTap: widget.onToggle);
  }

  /// หัวข้อคั่นหมวดหมู่เมนู — ตอนขยายโชว์เป็นข้อความตัวเล็กพิมพ์ใหญ่แบบ mockup
  /// (.sec) ตอนพับเหลือแค่เส้นแบ่งบางๆ (ไม่มีที่พอใส่ข้อความ) กัน sidebar ยาวๆ
  /// ดูเป็น list เดียวรวด
  Widget _buildSectionHeader(String label, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 4, left: 16, right: 16),
      child: widget.expanded
          ? Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _RailColors.textDim,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            )
          : Divider(height: 1, color: _RailColors.divider),
    );
  }

  /// แถบอ้างอิงอัตราหัก ณ ที่จ่ายค้างไว้ท้าย sidebar ตลอด — ช่วยเจ้าหน้าที่ไม่ต้อง
  /// เปิดหาอัตราภาษีทุกครั้งที่กรอกบิล ตอนพับ sidebar เหลือแค่ไอคอนกดดู tooltip
  static const _whtText = 'ซื้อสินค้า = ไม่หัก (0%)\nจ้างทำของ/บริการ = 3%\nค่าเช่า = 5%';

  Widget _buildWhtFooter() {
    final collapsedIcon = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: 'อัตราหัก ณ ที่จ่าย (ประมวลรัษฎากร)\n$_whtText',
        preferBelow: false,
        child: Icon(Icons.percent_outlined, size: 18, color: _RailColors.textDim),
      ),
    );
    if (!widget.expanded) return collapsedIcon;
    // ใช้ LayoutBuilder เช็คพื้นที่จริงที่มีก่อนตัดสินใจโชว์เวอร์ชันขยาย —
    // เฟรม transient ระหว่างพับ sidebar ที่ widget.expanded ยังไม่ทันอัปเดตตาม
    // ความกว้าง Container จริง (ดูเหตุผลแบบเดียวกับ _SidebarItemTile) อาจทำให้
    // Row นี้ถูกขอให้วาดในพื้นที่แคบกว่าที่ไอคอน+ข้อความต้องการจริง —
    // fallback กลับไปโชว์แค่ไอคอนถ้าพื้นที่ไม่พอ กันล้น
    return LayoutBuilder(
      builder: (context, constraints) {
        const minExpandedWidth = 80.0;
        if (constraints.maxWidth < minExpandedWidth) return collapsedIcon;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _RailColors.footerBg,
              borderRadius: BorderRadius.circular(RadiusSize.lg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.percent_outlined, size: 13, color: _RailColors.footerText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'หัก ณ ที่จ่าย\nซื้อ=0% | จ้าง=3% | เช่า=5%',
                    style: TextStyle(fontSize: 9, color: _RailColors.footerText, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// แถวเมนูหนึ่งรายการ — ใส่ [dragIndex] เฉพาะรายการที่อยู่ใน
  /// ReorderableListView (หมวดที่ลากจัดลำดับได้) เพื่อผูกด้ามจับลากด้วย
  /// ReorderableDragStartListener; รายการในหมวด "ตั้งค่า" ที่ปักหมุดไว้ท้ายสุด
  /// จะไม่ส่งพารามิเตอร์นี้มา จึงไม่มีด้ามจับ/ลากไม่ได้ตามที่ตั้งใจ
  Widget _buildItem(AppMode mode, {Key? key, int? dragIndex}) {
    final meta = modeMeta[mode]!;
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

/// ปุ่มพับ/กางเมนูหลัก — จงใจใช้กรอบ hover เดียวกับ _SidebarItemTile ทุก
/// ประการ (margin/padding/borderRadius/สี) แทนที่จะพึ่ง InkWell.hoverColor
/// เฉยๆ เพราะของเดิมกดแล้วไม่รู้ว่าเมาส์ชี้โดนหรือไม่โดน ("กดยาก") หน้าตา
/// ไม่เหมือนปุ่มเมนูรายการด้านล่างเลย ทำให้ผู้ใช้แยกไม่ออกว่าอันนี้คือปุ่มด้วย
class _SidebarToggleTile extends StatefulWidget {
  const _SidebarToggleTile({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_SidebarToggleTile> createState() => _SidebarToggleTileState();
}

class _SidebarToggleTileState extends State<_SidebarToggleTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    // ต่างจากปุ่มเมนูรายการ (ซึ่งถูกบังคับกว้างเต็มแถวโดย ReorderableListView
    // อยู่แล้วโดยอัตโนมัติ) ปุ่มนี้อยู่ใน Column เฉยๆ ไม่มีอะไรบังคับความกว้าง
    // ให้ — ถ้าไม่ใส่ width: infinity พื้นที่กดได้จริงจะแคบแค่เท่าเนื้อหา
    // (ไอคอน+ป้าย) เท่านั้น ทั้งที่หน้าตากล่อง hover ดูเหมือนกว้างเต็มแถว
    // เหมือนปุ่มเมนูด้านล่าง ผู้ใช้เลยกดโดนไม่ทุกจุด — เคยลองใส่ OverflowBox
    // เพิ่มเพื่อกัน Row ล้นตอนแอนิเมชัน แต่กลับทำให้พื้นที่กดเพี้ยน/กดไม่ติด
    // (ขนาดปลอมที่ OverflowBox รายงานปนกับ hit-test) ตัดออกแล้ว ใช้โครงสร้าง
    // เดียวกับ _SidebarItemTile เป๊ะๆ (พิสูจน์แล้วว่าไม่มีปัญหา) มีแค่ width
    // infinity เพิ่มมาอันเดียวเพราะไม่ได้อยู่ใน ReorderableListView ที่ยืดให้เอง
    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _sidebarAnimDuration,
            curve: _sidebarAnimCurve,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            padding: const EdgeInsets.only(left: 6, right: 6, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _hovering ? _RailColors.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(RadiusSize.lg),
            ),
            // ดูเหตุผลที่ _SidebarItemTile (โครงสร้างเดียวกัน — LayoutBuilder
            // วัดพื้นที่จริง กัน overflow ตอน Container กับป้ายข้างในไม่ sync กัน)
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxLabelWidth = (constraints.maxWidth - 18 /* icon */).clamp(0.0, double.infinity);
                final labelWidth = (widget.expanded ? _sidebarLabelWidth : 0.0).clamp(0.0, maxLabelWidth);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      widget.expanded ? Icons.menu_open : Icons.menu,
                      color: _RailColors.text,
                      size: 18,
                    ),
                    ClipRect(
                      child: AnimatedContainer(
                        duration: _sidebarAnimDuration,
                        curve: _sidebarAnimCurve,
                        height: 20,
                        width: labelWidth,
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: Text(
                            'ซ่อนเมนูหลัก',
                            maxLines: 1,
                            softWrap: false,
                            // ellipsis แทน clip — ป้ายยาวสุด (เช่น "ทะเบียนคุมเลข
                            // บันทึก/TOR") บางจอ/สเกลฟอนต์อาจยังไม่พอดีเป๊ะ ขึ้น "…"
                            // ให้ดูตั้งใจแทนที่จะตัดกลางคำแบบสุ่มดูเหมือนบั๊ก
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _RailColors.textDim,
                              fontSize: 12,
                              letterSpacing: 0.5,
                              height: 1,
                              fontWeight: _hovering ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
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
    final fg = widget.isSelected ? _RailColors.selectedText : _RailColors.text;
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
            // เดิมพึ่ง ReorderableListView ยืดความกว้างให้เฉยๆ ไม่ได้ระบุ width
            // ตรงๆ — ใช้ได้ปกติตอนอยู่ในลิสต์ที่เลื่อนได้ แต่หมวด "ภาพรวม" ย้าย
            // ออกมาปักหมุดนอก SingleChildScrollView แล้ว ReorderableListView
            // ที่ไม่มี Scrollable ห่ออยู่คำนวณความกว้างให้ลูกเพี้ยนได้ (อ้างอิง
            // ขนาดตอนกางแทนที่จะเป็นขนาดที่บีบอยู่จริงตอนพับ) ระบุ width ตรงๆ
            // กันไว้ เหมือนที่แก้ปุ่มพับ/กางไปแล้ว
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            // ซ้าย 9 ไม่ใช่ 12 — เพราะเส้นขอบซ้าย (border) ด้านล่างกินพื้นที่ไป
            // อีก 3px เสมอ (แม้เป็นสีใส/transparent ก็ยังนับความกว้างอยู่ดี)
            // ถ้าใช้ 12 เท่ากันทุกด้าน รวมแล้วจะเกินพื้นที่จริง 3px ทำให้ล้นตอนพับ
            padding: const EdgeInsets.only(left: 6, right: 6, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? _RailColors.selectedBg
                  : (_hovering ? _RailColors.hoverBg : Colors.transparent),
              borderRadius: BorderRadius.circular(RadiusSize.lg),
              border: Border(
                left: BorderSide(
                  color: widget.isSelected ? _RailColors.selectedAccent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            // เดิมคำนวณความกว้างป้ายจากค่าคงที่ล้วนๆ (ไม่สนใจพื้นที่จริงที่มี) —
            // Container นี้กับป้ายข้างในต่างก็มี AnimatedContainer/animation
            // controller แยกกันเอง แม้ duration/curve เท่ากันก็ไม่การันตีว่าจะขยับ
            // พร้อมกันทุกเฟรมเป๊ะๆ ตอนพับ/กางเร็วๆ ซ้ำๆ ทำให้บางเฟรม Row ขอพื้นที่
            // (ไอคอน+ป้ายเต็ม+ด้ามจับ) มากกว่าที่ Container ให้จริงชั่วขณะ แล้ว
            // Flutter โยน RenderFlex overflow assertion ออกมาทันที (การ clip ที่
            // Container ไม่ช่วย เพราะ assertion เกิดตอน layout ไม่ใช่ตอน paint) —
            // ใช้ LayoutBuilder วัดพื้นที่ที่มีจริง ณ เฟรมนั้นแทน แล้ว clamp
            // เป้าหมายความกว้างป้ายไม่ให้เกินพื้นที่จริงเด็ดขาด ไม่ว่าอนิเมชันจะ
            // sync กันพอดีหรือไม่ก็ตาม
            child: LayoutBuilder(
              builder: (context, constraints) {
                const iconWidth = 18.0;
                const dragHandleReserve = 16.0;
                // ก่อนหน้านี้เช็คแค่ widget.expanded อย่างเดียวว่าจะโชว์ด้ามจับ
                // ลากไหม แต่ระหว่างเฟรม transient ที่ Container ยังไม่ทันขยับตาม
                // widget.expanded ตัวใหม่ (พื้นที่จริง constraints.maxWidth ยัง
                // แคบแบบตอนพับอยู่) การไปโชว์ด้ามจับตามค่า flag เฉยๆ ทำให้แค่
                // ไอคอนหลัก + ด้ามจับ (18+16=34) ก็ล้นพื้นที่จริงที่แคบกว่านั้น
                // (เช่น 23px) ได้แล้ว ทั้งที่ยังไม่ได้นับป้ายชื่อเมนูเลยด้วยซ้ำ —
                // เช็คพื้นที่จริงที่มีประกอบด้วย ไม่ใช่เชื่อ flag อย่างเดียว
                final hasDragHandle = widget.dragIndex != null &&
                    widget.expanded &&
                    constraints.maxWidth >= iconWidth + dragHandleReserve + 4;
                final dragHandleWidth = hasDragHandle ? dragHandleReserve : 0.0;
                final maxLabelWidth =
                    (constraints.maxWidth - iconWidth - dragHandleWidth).clamp(0.0, double.infinity);
                final desiredLabelWidth = widget.expanded
                    ? (widget.dragIndex != null ? _sidebarLabelWidth - 16 : _sidebarLabelWidth)
                    : 0.0;
                final labelWidth = desiredLabelWidth.clamp(0.0, maxLabelWidth);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: fg, size: 18),
                    ClipRect(
                      child: AnimatedContainer(
                        duration: _sidebarAnimDuration,
                        curve: _sidebarAnimCurve,
                        height: 20,
                        width: labelWidth,
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            // ellipsis แทน clip — ป้ายยาวสุด (เช่น "ทะเบียนคุมเลข
                            // บันทึก/TOR") บางจอ/สเกลฟอนต์อาจยังไม่พอดีเป๊ะ ขึ้น "…"
                            // ให้ดูตั้งใจแทนที่จะตัดกลางคำแบบสุ่มดูเหมือนบั๊ก
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              // ตัวหนาเฉพาะตอนเลือกอยู่/ชี้เมาส์อยู่ — ปกติเป็นตัว
                              // ธรรมดา (w400) กันดูหนาเกินไปทั้งแถบเวลาไม่มีอะไรทำ
                              fontWeight: (widget.isSelected || _hovering) ? FontWeight.w700 : FontWeight.w400,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasDragHandle)
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
