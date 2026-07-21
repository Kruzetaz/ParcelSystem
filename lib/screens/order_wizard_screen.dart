// order_wizard_screen.dart
// Wizard เต็มรูปแบบ — TabBar 5 แท็บ, ใช้ draft state เดียวใน State ของ wizard เอง
// แล้วส่งลงไปให้แต่ละแท็บแก้ผ่าน callback (ไม่ใช้ Provider เพื่อให้ยังง่ายต่อการอ่าน)
//
// สถานะตอนนี้: Tab 1-5 ทำงานจริงครบทุกแท็บแล้ว
//   Tab 1 (ข้อมูลโรงเรียน/งบประมาณ/วัตถุประสงค์) — [อัปเดต 2026]: เพิ่มปุ่มสร้างแผนงบประมาณด่วน แก้ปัญหา Dropdown ว่าง
//   Tab 2 (ผู้ปฏิบัติงาน/คณะกรรมการตรวจรับ)
//   Tab 3 (ร้านค้า/เงื่อนไข/ค่าปรับ/ประกัน) — [อัปเดต 2026]: เพิ่มฟิลด์เลือกประเภทเอกสารตรวจรับ และเลขที่เอกสาร
//   Tab 4 (รายการพัสดุ) — ต่อกับ ItemsTableEditor
//   Tab 5 (กำหนดการ) — 9 ช่องวันที่ เลือกผ่าน date picker เก็บเป็น dd/MM/yyyy พ.ศ.

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget.dart';
import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/school_settings.dart';
import '../services/document_generator.dart';
import '../services/gemini_service.dart';
import '../services/toast_service.dart';
import '../utils/calc_engine.dart';
import '../utils/money_format.dart';
import '../widgets/items_table_editor.dart';
import '../widgets/guide_panel.dart';
import '../widgets/receipt_ocr_dialog.dart';
import '../widgets/thai_date_picker.dart';
import 'settings_screen.dart';

class OrderWizardScreen extends StatefulWidget {
  final ProcurementOrder? existingOrder;

  // [อัปเดต — AppShell integration]: แจ้ง shell ทุกครั้งที่ข้อมูลในฟอร์มถูกแก้
  // (สำหรับเด้ง dialog เตือนก่อนสลับเมนู) และแจ้งเมื่อกด "บันทึก" สำเร็จ
  // (shell จะสลับกลับไป dashboard ให้)
  final void Function(bool isDirty) onDirtyChanged;
  final VoidCallback onSaved;

  const OrderWizardScreen({
    super.key,
    this.existingOrder,
    required this.onDirtyChanged,
    required this.onSaved,
  });

  @override
  State<OrderWizardScreen> createState() => _OrderWizardScreenState();
}

class _OrderWizardScreenState extends State<OrderWizardScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProcurementRepository();
  late final TabController _tabController;

  // draft ทั้งก้อน — ทุกแท็บแก้ตัวเดียวกันนี้ผ่าน copyWith
  late ProcurementOrder _draft;
  List<ProcurementItem> _items = [];
  double _itemsSubtotal = 0;
  final _itemsTableController = ItemsTableEditorController();

  bool _saving = false;
  bool _generatingDoc = false;

  // true ทันทีที่มีการแก้ฟอร์ม/รายการพัสดุ จนกว่าจะกด "บันทึก" หรือ
  // "สร้างเอกสาร Word" สำเร็จ — ใช้แจ้ง AppShell ผ่าน widget.onDirtyChanged
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _draft = widget.existingOrder ?? const ProcurementOrder();
    if (widget.existingOrder?.id != null) {
      _loadItems(widget.existingOrder!.id!);
    }
  }

  Future<void> _loadItems(int orderId) async {
    final items = await _repo.getItems(orderId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _itemsSubtotal = items.fold<double>(0, (sum, i) => sum + i.computedTotal);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateDraft(ProcurementOrder Function(ProcurementOrder) update) {
    setState(() {
      final prev = _draft;
      var next = update(prev);
      // วันครบกำหนดส่งมอบ = วันที่ลงนามสัญญา/ใบสั่งซื้อ + ระยะเวลาส่งมอบ (วัน)
      // คำนวณอัตโนมัติเฉพาะตอนที่ 2 ค่านี้เปลี่ยน — ถ้าผู้ใช้เคยเลือกวันครบกำหนด
      // เองด้วยมือ (ผ่าน date picker) โดยไม่ได้แตะ 2 ค่านี้ จะไม่ถูกเขียนทับ
      final signedChanged = next.dateContractSigned != prev.dateContractSigned;
      final shippingChanged = next.shippingDays != prev.shippingDays;
      if (signedChanged || shippingChanged) {
        final autoDeadline =
            _calcDeadlineThai(next.dateContractSigned, next.shippingDays);
        if (autoDeadline != null) next = next.copyWith(dateDeadline: autoDeadline);
      }
      _draft = next;
    });
    _markDirty();
  }

  static const _thaiMonthNames = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  /// รับวันที่ลงนามสัญญา (dd/MM/yyyy พ.ศ.) + จำนวนวันส่งมอบ คืนวันครบกำหนด
  /// เป็นสตริงรูปแบบเดียวกัน หรือ null ถ้าข้อมูลไม่ครบ/แปลงไม่ได้
  static String? _calcDeadlineThai(String? signedText, int? shippingDays) {
    if (signedText == null || signedText.isEmpty || shippingDays == null) return null;
    final parts = signedText.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final buddhistYear = int.tryParse(parts[2]);
    if (day == null || month == null || buddhistYear == null) return null;
    late final DateTime signedDate;
    try {
      signedDate = DateTime(buddhistYear - 543, month, day);
    } catch (_) {
      return null;
    }
    final deadline = signedDate.add(Duration(days: shippingDays));
    final y = deadline.year + 543;
    return '${deadline.day} ${_thaiMonthNames[deadline.month]} $y';
  }

  /// ตั้งค่า dirty เป็น true และแจ้ง shell (ถ้ายังไม่ dirty อยู่แล้ว)
  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
    widget.onDirtyChanged(true);
  }

  /// ล้างสถานะ dirty หลังบันทึกสำเร็จ และแจ้ง shell
  void _clearDirty() {
    setState(() => _isDirty = false);
    widget.onDirtyChanged(false);
  }

  /// นับว่า "ผ่าน" กี่ tab จาก 5 tab แล้ว (เกณฑ์: กรอก field หลักของ tab นั้นครบ)
  /// คืนค่าเป็นสัดส่วน 0.0-1.0 (เช่น 3/5 = 0.6) เก็บลง progressPercent
  double _computeProgress() {
    int done = 0;

    // Tab 1: เลือกแผนงบ + เลขที่จัดซื้อ + ชื่อโครงการ
    if (_draft.budgetId != null &&
        (_draft.procurementNumber?.trim().isNotEmpty ?? false) &&
        (_draft.projectName?.trim().isNotEmpty ?? false)) {
      done++;
    }

    // Tab 2: ผู้อำนวยการ + เจ้าของงบ + ผู้ตรวจรับคนแรก
    if ((_draft.directorName?.trim().isNotEmpty ?? false) &&
        (_draft.ownerName?.trim().isNotEmpty ?? false) &&
        (_draft.inspector1?.trim().isNotEmpty ?? false)) {
      done++;
    }

    // Tab 3: ชื่อร้านค้า + ระยะเวลาส่งมอบ
    if ((_draft.vendorName?.trim().isNotEmpty ?? false) && _draft.shippingDays != null) {
      done++;
    }

    // Tab 4: มีรายการพัสดุอย่างน้อย 1 รายการ
    if (_items.isNotEmpty) {
      done++;
    }

    // Tab 5: กรอกวันที่ครบทั้ง 9 ช่อง
    final dates = [
      _draft.dateMemoUsed,
      _draft.dateOrderCreated,
      _draft.dateAnnouncement,
      _draft.dateQuotation,
      _draft.dateContractSigned,
      _draft.dateDeadline,
      _draft.dateShipping,
      _draft.dateInspection,
      _draft.dateDisbursement,
    ];
    if (dates.every((d) => d?.trim().isNotEmpty ?? false)) {
      done++;
    }

    return done / 5;
  }

  /// คำนวณยอดสุดท้ายจาก items แล้วบันทึกลง DB — ใช้ร่วมกันทั้งปุ่ม
  /// "บันทึก" และปุ่ม "สร้างเอกสาร Word" (ต้องบันทึกก่อนสร้างเอกสารเสมอ)
  /// คืนค่า ProcurementOrder ที่บันทึกแล้ว (พร้อมยอดคำนวณล่าสุด)
  Future<ProcurementOrder> _calcAndSaveOrder() async {
    // คำนวณยอดสุดท้ายจาก items ก่อนบันทึก ป้องกันกรณี user แก้ Tab4 แล้วไม่ได้กลับมาดู
    final calc = CalcEngine.calcAllWithRates(
      _itemsSubtotal,
      vatRate: _draft.vatRate,
      withholdingRate: _draft.withholdingTaxRate,
    );
    final bahtText = CalcEngine.bahtText(calc['current_order_price']!);

    // คำนวณ allocatedAmountTh ถ้ายังไม่มี (กรณีโหลดของเก่าจาก DB)
    final allocatedTh = _draft.allocatedAmountTh?.isNotEmpty == true
        ? _draft.allocatedAmountTh
        : (_draft.allocatedAmount != null
            ? CalcEngine.bahtText(_draft.allocatedAmount!)
            : null);

    final progress = _computeProgress();

    final orderToSave = _draft.copyWith(
      currentOrderPrice: calc['current_order_price'],
      totalPriceTh: bahtText,
      subtotalBeforeVat: calc['subtotal_before_vat'],
      vatAmount: calc['vat_amount'],
      taxWithholdingAmount: calc['tax_withholding_amount'],
      netPayableAmount: calc['net_payable_amount'],
      allocatedAmountTh: allocatedTh,
      progressPercent: progress,
      // เดิม currentStatus ไม่เคยถูกตั้งค่าที่ไหนเลย ค้างเป็น 'DRAFT' ตลอด
      // แม้กรอกครบ 100% แล้ว ทำให้ KPI "เสร็จสมบูรณ์" นับไม่ตรงกับ progress bar
      currentStatus: progress >= 1.0 ? 'COMPLETED' : 'DRAFT',
    );

    await _repo.saveOrderWithItems(orderToSave, _items);
    setState(() => _draft = orderToSave);
    return orderToSave;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _calcAndSaveOrder();
      _clearDirty();

      if (!mounted) return;
      showAppToast('บันทึกเอกสารสำเร็จ');
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      showAppToast('บันทึกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ปุ่ม "สร้างเอกสาร Word": บันทึกลง DB ก่อนเสมอ แล้วค่อยสร้าง .docx
  /// จาก master template + เปิดด้วย Word อัตโนมัติ ไม่ปิดหน้าจอ wizard
  /// เผื่อผู้ใช้ต้องการแก้ไขต่อหรือสร้างเอกสารซ้ำ
  Future<void> _saveAndGenerateDocument() async {
    setState(() => _generatingDoc = true);
    try {
      final orderToSave = await _calcAndSaveOrder();
      _clearDirty();

      final schoolSettings = await _repo.getSchoolSettings();

      await DocumentGenerator.generateAndOpen(
        order: orderToSave,
        school: schoolSettings ?? const SchoolSettings(),
        items: _items,
      );

      if (!mounted) return;
      showAppToast('สร้างเอกสาร Word สำเร็จ กำลังเปิดไฟล์...');
    } catch (e) {
      if (!mounted) return;
      showAppToast('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingDoc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // TabBar เดิมเคยอยู่ใน AppBar.bottom — ย้ายมาไว้บนสุดของเนื้อหาแทน
        // เพราะ AppBar ตอนนี้อยู่ที่ระดับ AppShell แล้ว
        Container(
          color: colors.primary,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: colors.onPrimary,
            labelColor: colors.onPrimary,
            unselectedLabelColor: colors.onPrimary.withValues(alpha: 0.7),
            tabs: const [
              Tab(text: '1. โรงเรียน/งบประมาณ'),
              Tab(text: '2. ผู้ปฏิบัติงาน'),
              Tab(text: '3. ร้านค้า/เงื่อนไข'),
              Tab(text: '4. รายการพัสดุ'),
              Tab(text: '5. กำหนดการ'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _Tab1SchoolBudget(draft: _draft, onChanged: _updateDraft, repo: _repo),
              _Tab2Officers(draft: _draft, onChanged: _updateDraft),
              _Tab3VendorTerms(draft: _draft, onChanged: _updateDraft),
              _Tab4Items(
                initialItems: _items,
                itemsController: _itemsTableController,
                onChanged: (items, subtotal) {
                  setState(() {
                    _items = items;
                    _itemsSubtotal = subtotal;
                  });
                  _markDirty();
                },
              ),
              _Tab5Timeline(draft: _draft, onChanged: _updateDraft),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_saving || _generatingDoc) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_saving || _generatingDoc) ? null : _saveAndGenerateDocument,
                  icon: _generatingDoc
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                        )
                      : const Icon(Icons.description),
                  label: Text(_generatingDoc ? 'กำลังสร้าง...' : 'สร้างเอกสาร Word'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tab 1: โรงเรียน / งบประมาณ / วัตถุประสงค์
// ─────────────────────────────────────────────────────────────────

class _Tab1SchoolBudget extends StatefulWidget {
  final ProcurementOrder draft;
  final void Function(ProcurementOrder Function(ProcurementOrder)) onChanged;
  final ProcurementRepository repo;

  const _Tab1SchoolBudget({
    required this.draft,
    required this.onChanged,
    required this.repo,
  });

  @override
  State<_Tab1SchoolBudget> createState() => _Tab1SchoolBudgetState();
}

class _Tab1SchoolBudgetState extends State<_Tab1SchoolBudget> {
  List<Budget> _budgets = [];
  bool _loadingBudgets = true;

  late final TextEditingController _procurementNumberCtrl;
  late final TextEditingController _procurementSubjectCtrl;
  late final TextEditingController _orderNumberCtrl;
  late final TextEditingController _egpProjectIdCtrl;
  late final TextEditingController _projectNumberCtrl;
  late final TextEditingController _projectNameCtrl;
  late final TextEditingController _activityNameCtrl;
  late final TextEditingController _purposeReasonCtrl;
  String? _orderType; // 'ซื้อ' | 'จ้าง'
  String? _fundType;
  bool _generatingReason = false;

  @override
  void initState() {
    super.initState();
    _procurementNumberCtrl = TextEditingController(text: widget.draft.procurementNumber);
    _procurementSubjectCtrl = TextEditingController(text: widget.draft.procurementSubject);
    _orderNumberCtrl = TextEditingController(text: widget.draft.orderNumber);
    _egpProjectIdCtrl = TextEditingController(text: widget.draft.egpProjectId);
    _projectNumberCtrl = TextEditingController(text: widget.draft.projectNumber);
    _projectNameCtrl = TextEditingController(text: widget.draft.projectName);
    _activityNameCtrl = TextEditingController(text: widget.draft.activityName);
    _purposeReasonCtrl = TextEditingController(text: widget.draft.purposeReason);
    _orderType = widget.draft.orderType;
    _fundType = orderFundTypes.contains(widget.draft.fundType) ? widget.draft.fundType : null;
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final budgets = await widget.repo.getAllBudgets();
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _loadingBudgets = false;
    });
  }

  // ฟังก์ชันเพิ่มแผนงบประมาณเร่งด่วนในกรณี Dropdown ว่างเปล่า
  Future<void> _showQuickAddBudgetDialog() async {
    final colors = Theme.of(context).colorScheme;
    final yearCtrl = TextEditingController(text: DateTime.now().year + 543 >= 2569 ? '2569' : '2568');
    final projCtrl = TextEditingController();
    final actCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    final result = await showDialog<Budget?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เพิ่มแผนงบประมาณแบบด่วน', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'ปีงบประมาณ (พ.ศ.)')),
              const SizedBox(height: 12),
              TextField(controller: projCtrl, decoration: const InputDecoration(labelText: 'ชื่อโครงการ')),
              const SizedBox(height: 12),
              TextField(controller: actCtrl, decoration: const InputDecoration(labelText: 'ชื่อกิจกรรม')),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'งบประมาณจัดสรร (บาท)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () async {
              final allocated = double.tryParse(amountCtrl.text) ?? 0.0;
              final newBudget = Budget(
                fiscalYear: yearCtrl.text.isEmpty ? '-' : yearCtrl.text,
                projectName: projCtrl.text,
                activityName: actCtrl.text,
                allocatedAmount: allocated,
                remainingAmount: allocated,
              );

              // สมมติว่ามีฟังก์ชันบันทึกงบประมาณใน repo เช่น saveBudget
              // หากใน repo ตัวแปรใช้ saveBudget หรือเพิ่มเข้าไปตรงๆ สามารถเรียกตรงนี้ได้เลย
              // เพื่อความปลอดภัยเราใช้ฟังก์ชันผ่านตัวแปรกลางหรือส่งกลับไปประมวลผลภายนอก
              Navigator.pop(ctx, newBudget);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _loadingBudgets = true);
      try {
        // บันทึกลงฐานข้อมูลพัสดุ
        await widget.repo.insertBudget(result);
        await _loadBudgets(); // โหลดรายการงบประมาณใหม่ทั้งหมด

        // ค้นหา ID ตัวที่พึ่งเพิ่มเข้าไปล่าสุดมาผูกเช็คอินเข้าหน้าฟอร์ม
        if (_budgets.isNotEmpty) {
          final newest = _budgets.last;
          _onBudgetSelected(newest);
        }
      } catch (e) {
        if (!mounted) return;
        showAppToast('เกิดข้อผิดพลาด: $e', isError: true);
        setState(() => _loadingBudgets = false);
      }
    }
  }

  @override
  void dispose() {
    _procurementNumberCtrl.dispose();
    _procurementSubjectCtrl.dispose();
    _orderNumberCtrl.dispose();
    _egpProjectIdCtrl.dispose();
    _projectNumberCtrl.dispose();
    _projectNameCtrl.dispose();
    _activityNameCtrl.dispose();
    _purposeReasonCtrl.dispose();
    super.dispose();
  }

  // Feature C: AI ช่วยเขียน "เหตุผลความจำเป็น" จากข้อมูลที่กรอกไว้แล้วใน Tab 1
  Future<void> _generateReason() async {
    if (_projectNameCtrl.text.trim().isEmpty && _procurementSubjectCtrl.text.trim().isEmpty) {
      showAppToast('กรุณากรอกหัวเรื่องหรือชื่อโครงการก่อน ให้ AI มีข้อมูลพอเขียนเหตุผลได้', isError: true);
      return;
    }
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      showAppToast('กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน', isError: true);
      return;
    }

    setState(() => _generatingReason = true);
    try {
      final prompt = '''
คุณเป็นเจ้าหน้าที่พัสดุโรงเรียนไทย จงเขียน "เหตุผลความจำเป็น" สำหรับการจัดซื้อจัดจ้างนี้
ให้กระชับ 1-2 บรรทัด เหมาะสมตามระเบียบพัสดุราชการ ตอบเป็นข้อความเหตุผลอย่างเดียว
ห้ามมีคำนำ คำอธิบาย หรือเครื่องหมายคำพูดครอบ

ข้อมูลที่มี:
ประเภทงาน: ${_orderType ?? 'ไม่ระบุ'}
หัวเรื่อง: ${_procurementSubjectCtrl.text.trim().isEmpty ? 'ไม่ระบุ' : _procurementSubjectCtrl.text.trim()}
ชื่อโครงการ: ${_projectNameCtrl.text.trim().isEmpty ? 'ไม่ระบุ' : _projectNameCtrl.text.trim()}
ชื่อกิจกรรม: ${_activityNameCtrl.text.trim().isEmpty ? 'ไม่ระบุ' : _activityNameCtrl.text.trim()}
''';
      final result = await GeminiService.instance.generateText(prompt);
      if (!mounted) return;
      final reason = result.trim();
      setState(() {
        _purposeReasonCtrl.text = reason;
        _generatingReason = false;
      });
      widget.onChanged((d) => d.copyWith(purposeReason: reason));
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingReason = false);
      showAppToast('AI เขียนเหตุผลไม่สำเร็จ: $e', isError: true);
    }
  }

  // เลือกแผนงบ -> auto-fill project/activity/allocated/remaining/egp มาให้ทันที
  void _onBudgetSelected(Budget? budget) {
    if (budget == null) return;
    final allocatedTh = budget.allocatedAmount != null
        ? CalcEngine.bahtText(budget.allocatedAmount!)
        : null;
    widget.onChanged((d) => d.copyWith(
          budgetId: budget.id,
          fiscalYear: budget.fiscalYear,
          allocatedAmount: budget.allocatedAmount,
          allocatedAmountTh: allocatedTh,
          remainingAmount: budget.remainingAmount,
          egpProjectId: budget.egpNumber,
          projectName: budget.projectName,
          activityName: budget.activityName,
        ));
    setState(() {
      _projectNameCtrl.text = budget.projectName ?? '';
      _activityNameCtrl.text = budget.activityName ?? '';
      _egpProjectIdCtrl.text = budget.egpNumber ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Budget? selectedBudget;
    for (final b in _budgets) {
      if (b.id == widget.draft.budgetId) {
        selectedBudget = b;
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(colors, 'เลือกแผนงบประมาณ'),
                TextButton.icon(
                  onPressed: _showQuickAddBudgetDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่มแผนด่วน'),
                  style: TextButton.styleFrom(foregroundColor: colors.primary),
                ),
              ],
            ),
            _loadingBudgets
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<Budget>(
                    initialValue: selectedBudget,
                    decoration: _inputDecoration('แผนงบประมาณ (ปี / กลุ่มงาน / โครงการ)'),
                    isExpanded: true,
                    items: _budgets
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(
                                '${b.fiscalYear} • ${b.projectName ?? "-"} '
                                '(คงเหลือ ${b.remainingAmount?.toStringAsFixed(0) ?? "-"} บาท)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: _onBudgetSelected,
                  ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'ประเภทเอกสาร'),
            DropdownButtonFormField<String>(
              initialValue: _orderType,
              decoration: _inputDecoration('จัดซื้อ หรือ จัดจ้าง'),
              items: const [
                DropdownMenuItem(value: 'ซื้อ', child: Text('จัดซื้อ')),
                DropdownMenuItem(value: 'จ้าง', child: Text('จัดจ้าง')),
              ],
              onChanged: (v) {
                setState(() => _orderType = v);
                widget.onChanged((d) => d.copyWith(orderType: v));
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'ข้อมูลเอกสาร'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _procurementNumberCtrl,
                    decoration: _inputDecoration('เลขที่จัดซื้อ (เช่น ซ.1/2569)'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(procurementNumber: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _orderNumberCtrl,
                    decoration: _inputDecoration('เลขที่คำสั่ง'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(orderNumber: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _egpProjectIdCtrl,
              decoration: _inputDecoration('เลขที่โครงการ e-GP (auto-fill จากแผนงบ แก้ไขเองได้)'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(egpProjectId: v)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _fundType,
                    isExpanded: true,
                    decoration: _inputDecoration('ประเภทของเงิน'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('(ไม่ระบุ)')),
                      ...orderFundTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (v) {
                      setState(() => _fundType = v);
                      widget.onChanged((d) => d.copyWith(fundType: v));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _projectNumberCtrl,
                    decoration: _inputDecoration('เลขที่โครงการ (ทะเบียนคุมภายใน)'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(projectNumber: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _procurementSubjectCtrl,
              decoration: _inputDecoration(
                'หัวเรื่อง (เช่น จัดซื้อวัสดุแข่งขันทักษะทางวิชาการระดับเครือข่าย)',
              ),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(procurementSubject: v)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _projectNameCtrl,
              decoration: _inputDecoration('ชื่อโครงการ'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(projectName: v)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _activityNameCtrl,
              decoration: _inputDecoration('ชื่อกิจกรรม'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(activityName: v)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(colors, 'เหตุผลความจำเป็น'),
                TextButton.icon(
                  onPressed: _generatingReason ? null : _generateReason,
                  icon: _generatingReason
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(_generatingReason ? 'กำลังเขียน...' : '✨ ช่วยเขียนเหตุผล'),
                ),
              ],
            ),
            TextFormField(
              controller: _purposeReasonCtrl,
              decoration: _inputDecoration('เหตุผลความจำเป็น'),
              maxLines: 4,
              onChanged: (v) => widget.onChanged((d) => d.copyWith(purposeReason: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'งบประมาณ'),
            Row(
              children: [
                Expanded(
                  child: _readonlyMoneyField('งบจัดสรร', widget.draft.allocatedAmount),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _readonlyMoneyField('งบคงเหลือ', widget.draft.remainingAmount),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ยอดงบประมาณดึงมาจากแผนงบที่เลือกด้านบนโดยอัตโนมัติ (แก้ที่หน้าจัดการแผนงบ)',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ColorScheme colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.primary),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _readonlyMoneyField(String label, double? value) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      readOnly: true,
      initialValue: value == null ? '-' : '${formatBaht(value)} บาท',
      decoration: _inputDecoration(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tab 2: ผู้ปฏิบัติงาน — ผู้อำนวยการ/เจ้าหน้าที่พัสดุ/การเงิน/ผู้จัดทำสเปค
// และคณะกรรมการตรวจรับพัสดุ (เลือกได้ว่าเป็น "ผู้ตรวจรับคนเดียว" หรือ "คณะกรรมการ")
// ─────────────────────────────────────────────────────────────────

class _Tab2Officers extends StatefulWidget {
  final ProcurementOrder draft;
  final void Function(ProcurementOrder Function(ProcurementOrder)) onChanged;

  const _Tab2Officers({required this.draft, required this.onChanged});

  @override
  State<_Tab2Officers> createState() => _Tab2OfficersState();
}

class _Tab2OfficersState extends State<_Tab2Officers> {
  final _repo = ProcurementRepository();
  SchoolSettings? _schoolInfo;
  bool _loadingSchoolInfo = true;

  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _ownerPositionCtrl;
  late final TextEditingController _specCreatorNameCtrl;
  late final TextEditingController _specCreatorPositionCtrl;

  late final TextEditingController _inspector1Ctrl;
  late final TextEditingController _inspector1PosCtrl;
  late final TextEditingController _inspector2Ctrl;
  late final TextEditingController _inspector2PosCtrl;
  late final TextEditingController _inspector3Ctrl;
  late final TextEditingController _inspector3PosCtrl;

  // 'ผู้ตรวจรับพัสดุ' | 'คณะกรรมการตรวจรับ'
  late String _inspectorTitleGroup;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _ownerNameCtrl = TextEditingController(text: d.ownerName);
    _ownerPositionCtrl = TextEditingController(text: d.ownerPosition);
    _specCreatorNameCtrl = TextEditingController(text: d.specCreatorName);
    _specCreatorPositionCtrl = TextEditingController(text: d.specCreatorPosition);

    _inspector1Ctrl = TextEditingController(text: d.inspector1);
    _inspector1PosCtrl = TextEditingController(text: d.inspector1Pos);
    _inspector2Ctrl = TextEditingController(text: d.inspector2);
    _inspector2PosCtrl = TextEditingController(text: d.inspector2Pos);
    _inspector3Ctrl = TextEditingController(text: d.inspector3);
    _inspector3PosCtrl = TextEditingController(text: d.inspector3Pos);

    _inspectorTitleGroup = d.inspectorTitleGroup ?? 'ผู้ตรวจรับพัสดุ';
    _loadSchoolInfo();
  }

  Future<void> _loadSchoolInfo() async {
    final school = await _repo.getSchoolSettings();
    if (!mounted) return;
    setState(() {
      _schoolInfo = school;
      _loadingSchoolInfo = false;
    });
    // เติมชื่อผู้บริหาร/เจ้าหน้าที่ลง draft อัตโนมัติจาก settings เผื่อเอกสาร
    // ใหม่ที่ยังไม่เคยตั้งค่า (เอกสารเก่าที่เคยบันทึกค่าไว้ก่อนหน้าจะไม่ถูก
    // เขียนทับ — ใช้ค่าที่บันทึกไว้ในเอกสารนั้นต่อไป)
    if (school != null && widget.draft.directorName == null) {
      widget.onChanged((d) => d.copyWith(
            directorName: school.directorName,
            procurementOfficer: school.procurementOfficer,
            procurementHead: school.procurementHead,
            financeOfficer: school.financeOfficer,
          ));
    }
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _ownerPositionCtrl.dispose();
    _specCreatorNameCtrl.dispose();
    _specCreatorPositionCtrl.dispose();
    _inspector1Ctrl.dispose();
    _inspector1PosCtrl.dispose();
    _inspector2Ctrl.dispose();
    _inspector2PosCtrl.dispose();
    _inspector3Ctrl.dispose();
    _inspector3PosCtrl.dispose();
    super.dispose();
  }

  void _onGroupChanged(String? value) {
    if (value == null) return;
    setState(() => _inspectorTitleGroup = value);
    widget.onChanged((d) => d.copyWith(inspectorTitleGroup: value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCommittee = _inspectorTitleGroup == 'คณะกรรมการตรวจรับ';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(colors, 'ผู้บริหารและเจ้าหน้าที่ประจำโรงเรียน'),
            _buildSchoolOfficersCard(colors),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'เจ้าของงบ / ผู้จัดทำสเปค'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ownerNameCtrl,
                    decoration: _inputDecoration('ชื่อเจ้าของงบ/โครงการ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(ownerName: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _ownerPositionCtrl,
                    decoration: _inputDecoration('ตำแหน่ง'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(ownerPosition: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _specCreatorNameCtrl,
                    decoration: _inputDecoration('ผู้จัดทำรายละเอียดคุณลักษณะ (สเปค)'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(specCreatorName: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _specCreatorPositionCtrl,
                    decoration: _inputDecoration('ตำแหน่ง'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(specCreatorPosition: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'คณะกรรมการ/ผู้ตรวจรับพัสดุ'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ผู้ตรวจรับพัสดุ', label: Text('ผู้ตรวจรับคนเดียว')),
                ButtonSegment(value: 'คณะกรรมการตรวจรับ', label: Text('คณะกรรมการ (สูงสุด 3 คน)')),
              ],
              selected: {_inspectorTitleGroup},
              onSelectionChanged: (s) => _onGroupChanged(s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _inspector1Ctrl,
                    decoration: _inputDecoration(isCommittee ? 'กรรมการคนที่ 1' : 'ผู้ตรวจรับพัสดุ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(inspector1: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _inspector1PosCtrl,
                    decoration: _inputDecoration('ตำแหน่ง'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(inspector1Pos: v)),
                  ),
                ),
              ],
            ),
            if (isCommittee) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _inspector2Ctrl,
                      decoration: _inputDecoration('กรรมการคนที่ 2'),
                      onChanged: (v) => widget.onChanged((d) => d.copyWith(inspector2: v)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _inspector2PosCtrl,
                      decoration: _inputDecoration('ตำแหน่ง'),
                      onChanged: (v) => widget.onChanged((d) => d.copyWith(inspector2Pos: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _inspector3Ctrl,
                      decoration: _inputDecoration('กรรมการคนที่ 3'),
                      onChanged: (v) => widget.onChanged((d) => d.copyWith(inspector3: v)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _inspector3PosCtrl,
                      decoration: _inputDecoration('ตำแหน่ง'),
                      onChanged: (v) => widget.onChanged((d) => d.copyWith(inspector3Pos: v)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolOfficersCard(ColorScheme colors) {
    if (_loadingSchoolInfo) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    final school = _schoolInfo;
    final hasData = school?.directorName?.isNotEmpty == true ||
        school?.procurementOfficer?.isNotEmpty == true ||
        school?.procurementHead?.isNotEmpty == true ||
        school?.financeOfficer?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ดึงจากข้อมูลประจำโรงเรียน ใช้ค่าเดียวกันทุกเอกสาร',
                  style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('ตั้งค่าโรงเรียน'),
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                        ),
                        body: const SettingsScreen(),
                      ),
                    ),
                  );
                  _loadSchoolInfo(); // รีเฟรชหลังกลับจากหน้าตั้งค่า
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('แก้ไข'),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
              ),
            ],
          ),
          if (!hasData) ...[
            const SizedBox(height: 4),
            Text(
              'ยังไม่ได้กรอกข้อมูลผู้บริหาร/เจ้าหน้าที่ กดปุ่ม "แก้ไข" ด้านบนเพื่อกรอก',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
            ),
          ] else ...[
            const Divider(height: 20),
            _officerRow(colors, 'ผู้อำนวยการโรงเรียน', school?.directorName),
            _officerRow(colors, 'เจ้าหน้าที่พัสดุ', school?.procurementOfficer),
            _officerRow(colors, 'หัวหน้าเจ้าหน้าที่พัสดุ', school?.procurementHead),
            _officerRow(colors, 'เจ้าหน้าที่การเงิน', school?.financeOfficer),
          ],
        ],
      ),
    );
  }

  Widget _officerRow(ColorScheme colors, String label, String? value) {
    final hasValue = value?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              hasValue ? value! : '(ยังไม่ได้กรอก)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                color: hasValue ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.primary),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

// ─────────────────────────────────────────────────────────────────
// Tab 3: ร้านค้า / เงื่อนไขใบเสนอราคา / ค่าปรับ / ประกัน
// ─────────────────────────────────────────────────────────────────

class _Tab3VendorTerms extends StatefulWidget {
  final ProcurementOrder draft;
  final void Function(ProcurementOrder Function(ProcurementOrder)) onChanged;

  const _Tab3VendorTerms({required this.draft, required this.onChanged});

  @override
  State<_Tab3VendorTerms> createState() => _Tab3VendorTermsState();
}

class _Tab3VendorTermsState extends State<_Tab3VendorTerms> {
  late final TextEditingController _vendorNameCtrl;
  late final TextEditingController _vendorOwnerCtrl;
  late final TextEditingController _vendorAddressNoCtrl;
  late final TextEditingController _vendorSubdistrictCtrl;
  late final TextEditingController _vendorDistrictCtrl;
  late final TextEditingController _vendorProvinceCtrl;
  late final TextEditingController _vendorPhoneCtrl;
  late final TextEditingController _vendorTaxIdCtrl;
  late final TextEditingController _shippingDaysCtrl;
  late final TextEditingController _warrantyPeriodCtrl;
  late final TextEditingController _contractControlNumberCtrl;
  late final TextEditingController _inspectionControlNumberCtrl;
  late final TextEditingController _penaltyRateCtrl;
  late final TextEditingController _vatRateCtrl;
  late final TextEditingController _withholdingRateCtrl;

  // เพิ่มคอนโทรลเลอร์สำหรับตัวแปรเลขที่เอกสารส่งมอบ
  late final TextEditingController _deliveryDocNumberCtrl;
  final List<String> _docTypes = ['ใบส่งของ', 'ใบกำกับภาษี/ใบส่งของ', 'ใบเสร็จรับเงิน', 'บิลเงินสด'];

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _vendorNameCtrl = TextEditingController(text: d.vendorName);
    _vendorOwnerCtrl = TextEditingController(text: d.vendorOwner);
    _vendorAddressNoCtrl = TextEditingController(text: d.vendorAddressNo);
    _vendorSubdistrictCtrl = TextEditingController(text: d.vendorSubdistrict);
    _vendorDistrictCtrl = TextEditingController(text: d.vendorDistrict);
    _vendorProvinceCtrl = TextEditingController(text: d.vendorProvince);
    _vendorPhoneCtrl = TextEditingController(text: d.vendorPhone);
    _vendorTaxIdCtrl = TextEditingController(text: d.vendorTaxId);
    _shippingDaysCtrl = TextEditingController(text: d.shippingDays?.toString());
    _warrantyPeriodCtrl = TextEditingController(text: d.warrantyPeriod);
    _contractControlNumberCtrl = TextEditingController(text: d.contractControlNumber);
    _inspectionControlNumberCtrl = TextEditingController(text: d.inspectionControlNumber);
    _penaltyRateCtrl = TextEditingController(
      text: d.penaltyRate.toStringAsFixed(2),
    );
    _vatRateCtrl = TextEditingController(
      text: (d.vatRate * 100).toStringAsFixed(0),
    );
    _withholdingRateCtrl = TextEditingController(
      text: (d.withholdingTaxRate * 100).toStringAsFixed(0),
    );
    _deliveryDocNumberCtrl = TextEditingController(text: d.deliveryDocNumber);
  }

  @override
  void dispose() {
    _vendorNameCtrl.dispose();
    _vendorOwnerCtrl.dispose();
    _vendorAddressNoCtrl.dispose();
    _vendorSubdistrictCtrl.dispose();
    _vendorDistrictCtrl.dispose();
    _vendorProvinceCtrl.dispose();
    _vendorPhoneCtrl.dispose();
    _vendorTaxIdCtrl.dispose();
    _shippingDaysCtrl.dispose();
    _warrantyPeriodCtrl.dispose();
    _contractControlNumberCtrl.dispose();
    _inspectionControlNumberCtrl.dispose();
    _penaltyRateCtrl.dispose();
    _vatRateCtrl.dispose();
    _withholdingRateCtrl.dispose();
    _deliveryDocNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String? currentDocType = widget.draft.deliveryDocType;
    if (currentDocType != null && !_docTypes.contains(currentDocType)) {
      currentDocType = null; // ป้องกันบั๊กกรณีค่าจากเบสไม่ตรงกับ List ในแอป
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(colors, 'ข้อมูลร้านค้า'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _vendorNameCtrl,
                    decoration: _inputDecoration('ชื่อร้านค้า/บริษัท'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorName: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _vendorOwnerCtrl,
                    decoration: _inputDecoration('เจ้าของร้าน'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorOwner: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vendorAddressNoCtrl,
                    decoration: _inputDecoration('เลขที่ตั้ง/ที่อยู่'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorAddressNo: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _vendorSubdistrictCtrl,
                    decoration: _inputDecoration('ตำบล/แขวง'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorSubdistrict: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vendorDistrictCtrl,
                    decoration: _inputDecoration('อำเภอ/เขต'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorDistrict: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _vendorProvinceCtrl,
                    decoration: _inputDecoration('จังหวัด'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorProvince: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vendorPhoneCtrl,
                    decoration: _inputDecoration('เบอร์โทรศัพท์'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorPhone: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _vendorTaxIdCtrl,
                    decoration: _inputDecoration('เลขประจำตัวผู้เสียภาษี'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(vendorTaxId: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'ข้อมูลหลักฐาน/เอกสารที่ใช้ตรวจรับพัสดุ'),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: currentDocType,
                    decoration: _inputDecoration('ใช้เอกสารอะไรตรวจรับ'),
                    items: _docTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(deliveryDocType: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _deliveryDocNumberCtrl,
                    decoration: _inputDecoration('เลขที่เอกสารหลักฐาน (เช่น เลขที่ 001)'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(deliveryDocNumber: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'ภาษี / ค่าธรรมเนียม'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vatRateCtrl,
                    decoration: _inputDecoration('VAT (%)').copyWith(
                      suffixText: '%',
                      hintText: '0 หรือ 7',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final pct = double.tryParse(v);
                      if (pct != null) {
                        widget.onChanged((d) => d.copyWith(vatRate: pct / 100));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _withholdingRateCtrl,
                    decoration: _inputDecoration('หัก ณ ที่จ่าย (%)').copyWith(
                      suffixText: '%',
                      hintText: '0, 1 หรือ 3',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final pct = double.tryParse(v);
                      if (pct != null) {
                        widget.onChanged((d) => d.copyWith(withholdingTaxRate: pct / 100));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'กรอก 0 ถ้าไม่มีภาษีในบิลนี้',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'เงื่อนไขการส่งมอบ / ค่าปรับ / ประกัน'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shippingDaysCtrl,
                    decoration: _inputDecoration('ระยะเวลาส่งมอบ (วัน)').copyWith(
                      helperText: 'ระบบจะคำนวณ "วันครบกำหนดส่งมอบ" ในแท็บ 5 ให้อัตโนมัติ',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.onChanged(
                      (d) => d.copyWith(shippingDays: int.tryParse(v)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _warrantyPeriodCtrl,
                    decoration: _inputDecoration('ระยะเวลาประกัน (เช่น 1 ปี)'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(warrantyPeriod: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _penaltyRateCtrl,
              decoration: _inputDecoration('อัตราค่าปรับต่อวัน').copyWith(
                hintText: 'เช่น 0.10 หรือ 0.20',
                suffixText: 'ต่อวัน',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final rate = double.tryParse(v);
                if (rate != null) {
                  widget.onChanged((d) => d.copyWith(penaltyRate: rate));
                }
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle(colors, 'เลขที่ควบคุมเอกสาร'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _contractControlNumberCtrl,
                    decoration: _inputDecoration('เลขที่ควบคุมสัญญา'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(contractControlNumber: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _inspectionControlNumberCtrl,
                    decoration: _inputDecoration('เลขที่ควบคุมการตรวจรับ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(inspectionControlNumber: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ColorScheme colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.primary),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

// ─────────────────────────────────────────────────────────────────
// Tab 4: รายการพัสดุ — ต่อกับ ItemsTableEditor ที่มีอยู่แล้วจริง
// ─────────────────────────────────────────────────────────────────

class _Tab4Items extends StatefulWidget {
  final List<ProcurementItem> initialItems;
  final ItemsTableEditorController itemsController;
  final void Function(List<ProcurementItem> items, double subtotal) onChanged;

  const _Tab4Items({
    required this.initialItems,
    required this.itemsController,
    required this.onChanged,
  });

  @override
  State<_Tab4Items> createState() => _Tab4ItemsState();
}

class _Tab4ItemsState extends State<_Tab4Items> {
  bool _readingReceipt = false;

  // prompt สั่งให้ Gemini ตอบเป็น JSON array ล้วนๆ ไม่มีข้อความอื่นปน และเดา
  // หน่วยนับให้เหมาะสมถ้าใบเสร็จไม่ได้ระบุ — ถ้าพบว่าอาจมีของหลายโครงการปนกัน
  // ให้ทำเครื่องหมาย multi_project_hint:true ไว้ในแถวที่สงสัย (ไม่ต้องแยกเอง)
  static const _ocrPrompt = '''
คุณเป็นผู้ช่วยอ่านใบเสร็จ/ใบกำกับภาษีภาษาไทย จงแกะรายการสินค้าทั้งหมดจากไฟล์ที่แนบมา
ตอบกลับเป็น JSON array เท่านั้น ห้ามมีข้อความอื่นใดนอกเหนือ JSON และห้ามใช้ ```
แต่ละ item มี field ดังนี้:
- item_name: ชื่อสินค้า (string)
- quantity: จำนวน (ตัวเลขล้วน)
- unit: หน่วยนับ เช่น ชิ้น, กล่อง, ชุด, รีม (เดาให้เหมาะสมถ้าใบเสร็จไม่ได้ระบุ)
- unit_price: ราคาต่อหน่วย (ตัวเลขล้วน)
- total_price: ราคารวมของรายการนั้น (ตัวเลขล้วน)
- multi_project_hint: true เฉพาะแถวที่ดูเหมือนเป็นสินค้าคนละประเภท/วัตถุประสงค์กับแถวอื่นอย่างชัดเจน
  (เช่น ปนกันระหว่างของใช้สำนักงานกับอุปกรณ์ไฟฟ้า) ถ้าไม่แน่ใจไม่ต้องใส่ field นี้

ตัวอย่าง: [{"item_name":"กระดาษ A4","quantity":5,"unit":"รีม","unit_price":120,"total_price":600}]
''';

  Future<void> _pickAndReadReceipt() async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null) {
      showAppToast('กรุณาตั้งค่า Gemini API Key ในหน้า "ตั้งค่า AI" ก่อน', isError: true);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // heic/heif คือรูปแบบที่ iPhone/Mac ถ่ายรูปแล้วเซฟเป็นค่าเริ่มต้น
      // Gemini รองรับ mime type นี้โดยตรง ไม่ต้องแปลงไฟล์ก่อนส่ง
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif', 'pdf'],
      dialogTitle: 'เลือกรูปหรือไฟล์ใบเสร็จ',
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final ext = path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };

    setState(() => _readingReceipt = true);
    try {
      final bytes = await File(path).readAsBytes();
      final responseText = await GeminiService.instance.generateFromFile(
        prompt: _ocrPrompt,
        fileBytes: bytes,
        mimeType: mimeType,
      );
      final parsed = _parseOcrResponse(responseText);
      if (!mounted) return;
      setState(() => _readingReceipt = false);

      if (parsed.isEmpty) {
        showAppToast('AI ไม่พบรายการสินค้าในไฟล์นี้', isError: true);
        return;
      }

      final confirmed = await showReceiptOcrPreviewDialog(context, parsed);
      if (confirmed != null && confirmed.isNotEmpty) {
        widget.itemsController.addItems(confirmed);
        showAppToast('นำเข้า ${confirmed.length} รายการจากใบเสร็จแล้ว');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _readingReceipt = false);
      showAppToast('อ่านใบเสร็จไม่สำเร็จ: $e', isError: true);
    }
  }

  /// Gemini บางทีตอบมาพร้อม ```json ... ``` ครอบ ต้องแกะออกก่อน jsonDecode
  List<OcrParsedItem> _parseOcrResponse(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'```\s*$'), '');
    }
    final decoded = jsonDecode(text.trim());
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(OcrParsedItem.fromJson)
        .where((i) => i.itemName.text.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีกรอกรายการพัสดุ + ใช้ AI ช่วย',
      icon: Icons.auto_awesome,
      steps: const [
        'กรอกเองทีละแถวได้เลย: ชื่อรายการ, จำนวน, หน่วยนับ, ราคาต่อหน่วย — ระบบคำนวณยอดรวมแต่ละแถวและยอดรวมทั้งหมดให้อัตโนมัติ',
        'หรือกดปุ่ม "📷 อ่านจากใบเสร็จ" มุมขวาบน แล้วเลือกรูปถ่าย/ไฟล์ใบเสร็จ ให้ AI อ่านและแยกรายการให้ทันที',
        'รองรับไฟล์ .jpg .png .heic (รูปจาก iPhone/Mac) และ .pdf',
        'AI จะแสดงรายการที่อ่านได้ให้ตรวจสอบความถูกต้องก่อน กดยืนยันแล้วค่อยนำเข้าจริง ไม่เพิ่มอัตโนมัติทันที',
        'ถ้ายังไม่ได้ตั้งค่า Gemini API Key จะมีข้อความแจ้งให้ไปตั้งค่าที่หน้า "ตั้งค่า AI" ก่อน',
      ],
      corner: Alignment.bottomRight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _readingReceipt ? null : _pickAndReadReceipt,
                icon: _readingReceipt
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(_readingReceipt ? 'กำลังอ่านใบเสร็จ...' : '📷 อ่านจากใบเสร็จ'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ItemsTableEditor(
                  initialItems: widget.initialItems,
                  controller: widget.itemsController,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tab 5: กำหนดการ / ไทม์ไลน์วันที่สำคัญของกระบวนการจัดซื้อจัดจ้าง
// เก็บวันที่เป็น String รูปแบบ dd/MM/yyyy (ปี พ.ศ.) ให้ตรงกับเอกสารราชการไทย
// ─────────────────────────────────────────────────────────────────

class _DateFieldSpec {
  final String label;
  final String Function(ProcurementOrder) getValue;
  final ProcurementOrder Function(ProcurementOrder, String?) setValue;
  const _DateFieldSpec({
    required this.label,
    required this.getValue,
    required this.setValue,
  });
}

class _Tab5Timeline extends StatefulWidget {
  final ProcurementOrder draft;
  final void Function(ProcurementOrder Function(ProcurementOrder)) onChanged;

  const _Tab5Timeline({required this.draft, required this.onChanged});

  @override
  State<_Tab5Timeline> createState() => _Tab5TimelineState();
}

class _Tab5TimelineState extends State<_Tab5Timeline> {
  static final List<_DateFieldSpec> _fields = [
    _DateFieldSpec(
      label: 'วันที่บันทึกขออนุมัติใช้เงิน',
      getValue: (d) => d.dateMemoUsed ?? '',
      setValue: (d, v) => d.copyWith(dateMemoUsed: v),
    ),
    _DateFieldSpec(
      label: 'รายงานขอซื้อ/ขอจ้าง',
      getValue: (d) => d.dateOrderCreated ?? '',
      setValue: (d, v) => d.copyWith(dateOrderCreated: v),
    ),
    _DateFieldSpec(
      label: 'วันที่ประกาศ',
      getValue: (d) => d.dateAnnouncement ?? '',
      setValue: (d, v) => d.copyWith(dateAnnouncement: v),
    ),
    _DateFieldSpec(
      label: 'วันที่เสนอราคา',
      getValue: (d) => d.dateQuotation ?? '',
      setValue: (d, v) => d.copyWith(dateQuotation: v),
    ),
    _DateFieldSpec(
      label: 'วันที่ลงนามสัญญา/ใบสั่งซื้อ',
      getValue: (d) => d.dateContractSigned ?? '',
      setValue: (d, v) => d.copyWith(dateContractSigned: v),
    ),
    _DateFieldSpec(
      label: 'วันครบกำหนดส่งมอบ',
      getValue: (d) => d.dateDeadline ?? '',
      setValue: (d, v) => d.copyWith(dateDeadline: v),
    ),
    _DateFieldSpec(
      label: 'วันที่ส่งมอบจริง',
      getValue: (d) => d.dateShipping ?? '',
      setValue: (d, v) => d.copyWith(dateShipping: v),
    ),
    _DateFieldSpec(
      label: 'วันที่ตรวจรับ',
      getValue: (d) => d.dateInspection ?? '',
      setValue: (d, v) => d.copyWith(dateInspection: v),
    ),
    _DateFieldSpec(
      label: 'วันที่เบิกจ่ายเงิน',
      getValue: (d) => d.dateDisbursement ?? '',
      setValue: (d, v) => d.copyWith(dateDisbursement: v),
    ),
  ];

  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _fields
        .map((f) => TextEditingController(text: f.getValue(widget.draft)))
        .toList();
  }

  @override
  void didUpdateWidget(covariant _Tab5Timeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ซิงก์ค่ากลับเข้า controller เมื่อ draft เปลี่ยนจากภายนอก (เช่น วันครบกำหนด
    // ส่งมอบที่คำนวณอัตโนมัติจาก Tab 3) — ปลอดภัยเพราะทุกช่องในแท็บนี้เป็น
    // readOnly (แก้ผ่าน date picker เท่านั้น) ไม่มีการพิมพ์อิสระที่จะโดนเขียนทับ
    for (var i = 0; i < _fields.length; i++) {
      final newValue = _fields[i].getValue(widget.draft);
      if (_controllers[i].text != newValue) {
        _controllers[i].text = newValue;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // แปลง String วันที่เดิม (dd/MM/yyyy พ.ศ.) กลับเป็น DateTime (ค.ศ.)
  // เพื่อใช้เป็นค่าเริ่มต้นตอนเปิดปฏิทิน
  DateTime? _parseThaiDate(String text) {
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final buddhistYear = int.tryParse(parts[2]);
    if (day == null || month == null || buddhistYear == null) return null;
    return DateTime(buddhistYear - 543, month, day);
  }

  static const _thaiMonths = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  String _formatThaiDate(DateTime date) {
    final y = date.year + 543;
    return '${date.day} ${_thaiMonths[date.month]} $y';
  }

  Future<void> _pickDate(int index) async {
    final colors = Theme.of(context).colorScheme;
    final initial = _parseThaiDate(_controllers[index].text) ?? DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
      helpText: _fields[index].label,
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    final formatted = _formatThaiDate(picked);
    setState(() => _controllers[index].text = formatted);
    widget.onChanged((d) => _fields[index].setValue(d, formatted));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(colors, 'ไทม์ไลน์วันที่สำคัญ (พ.ศ.)'),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              // ปรับจำนวนคอลัมน์ตามความกว้างที่มีจริง กันหน้าจอแคบแล้วช่องบี้เกินไป
              final columns = constraints.maxWidth >= 950
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 16,
                children: [
                  for (int i = 0; i < _fields.length; i++)
                    SizedBox(
                      width: itemWidth,
                      child: TextFormField(
                        controller: _controllers[i],
                        readOnly: true,
                        decoration: _inputDecoration(_fields[i].label).copyWith(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: colors.primary,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today, size: 20),
                          helperText: _fields[i].label == 'วันครบกำหนดส่งมอบ'
                              ? 'คำนวณอัตโนมัติจากวันที่ลงนามสัญญา + ระยะเวลาส่งมอบ (แตะเพื่อแก้เองได้)'
                              : null,
                          helperMaxLines: 2,
                        ),
                        onTap: () => _pickDate(i),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          _buildGuideCard(colors),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static const _guideItems = [
    'บันทึกขออนุมัติใช้เงินจากผู้บริหารก่อนเริ่มกระบวนการจัดซื้อจัดจ้าง',
    'จัดทำรายงานขอซื้อ/ขอจ้างเสนอผู้มีอำนาจอนุมัติ',
    'ประกาศเชิญชวน (กรณีเป็นวิธีประกาศเชิญชวนทั่วไป/e-bidding)',
    'ผู้ขาย/ผู้รับจ้างเสนอราคา',
    'ลงนามในสัญญาหรือใบสั่งซื้อ/สั่งจ้าง',
    'กำหนดวันครบกำหนดส่งมอบตามที่ระบุในสัญญา',
    'ผู้ขาย/ผู้รับจ้างส่งมอบพัสดุจริง',
    'คณะกรรมการตรวจรับพัสดุดำเนินการตรวจรับ',
    'เบิกจ่ายเงินให้ผู้ขาย/ผู้รับจ้างหลังตรวจรับผ่านแล้ว',
  ];

  Widget _buildGuideCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'คำแนะนำลำดับการกรอกวันที่ (ตัวเลขตรงกับช่องด้านบน)',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _guideItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: colors.primary,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontSize: 11, color: colors.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_guideItems[i], style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.primary),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}