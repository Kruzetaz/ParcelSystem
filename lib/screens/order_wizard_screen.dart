// order_wizard_screen.dart
// Wizard เต็มรูปแบบ — TabBar 5 แท็บ, ใช้ draft state เดียวใน State ของ wizard เอง
// แล้วส่งลงไปให้แต่ละแท็บแก้ผ่าน callback (ไม่ใช้ Provider เพื่อให้ยังง่ายต่อการอ่าน)
//
// สถานะตอนนี้:
//   Tab 1 (ข้อมูลโรงเรียน/งบประมาณ/วัตถุประสงค์) — ทำงานจริงแล้ว
//   Tab 4 (รายการพัสดุ) — ต่อกับ ItemsTableEditor ที่มีอยู่แล้วจริง
//   Tab 2, 3, 5 — placeholder ที่ compile ผ่านและเก็บ layout ไว้ รอเติมเนื้อหาจริงรอบหน้า

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget.dart';
import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../utils/calc_engine.dart';
import '../widgets/items_table_editor.dart';

const _brandColor = Color(0xFF1A3A5C);

class OrderWizardScreen extends StatefulWidget {
  final ProcurementOrder? existingOrder;

  const OrderWizardScreen({super.key, this.existingOrder});

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

  bool _saving = false;

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
    setState(() => _draft = update(_draft));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // คำนวณยอดสุดท้ายจาก items ก่อนบันทึก ป้องกันกรณี user แก้ Tab4 แล้วไม่ได้กลับมาดู
      final calc = CalcEngine.calcAll(_itemsSubtotal);
      final bahtText = CalcEngine.bahtText(calc['current_order_price']!);

      final orderToSave = _draft.copyWith(
        currentOrderPrice: calc['current_order_price'],
        totalPriceTh: bahtText,
        subtotalBeforeVat: calc['subtotal_before_vat'],
        vatAmount: calc['vat_amount'],
        taxWithholdingAmount: calc['tax_withholding_amount'],
        netPayableAmount: calc['net_payable_amount'],
      );

      await _repo.saveOrderWithItems(orderToSave, _items);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกเอกสารสำเร็จ')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(widget.existingOrder == null ? 'สร้างเอกสารใหม่' : 'แก้ไขเอกสาร'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '1. โรงเรียน/งบประมาณ'),
            Tab(text: '2. ผู้ปฏิบัติงาน'),
            Tab(text: '3. ร้านค้า/เงื่อนไข'),
            Tab(text: '4. รายการพัสดุ'),
            Tab(text: '5. กำหนดการ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _Tab1SchoolBudget(draft: _draft, onChanged: _updateDraft, repo: _repo),
          _Tab2Officers(draft: _draft, onChanged: _updateDraft),
          _Tab3VendorTerms(draft: _draft, onChanged: _updateDraft),
          _Tab4Items(
            initialItems: _items,
            onChanged: (items, subtotal) {
              setState(() {
                _items = items;
                _itemsSubtotal = subtotal;
              });
            },
          ),
          const _PlaceholderTab(
            label: 'กำหนดการ (Tab 5)\nไทม์ไลน์วันที่สำคัญของกระบวนการจัดซื้อจัดจ้าง',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกเอกสาร'),
            style: FilledButton.styleFrom(
              backgroundColor: _brandColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
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
  late final TextEditingController _orderNumberCtrl;
  late final TextEditingController _projectNameCtrl;
  late final TextEditingController _activityNameCtrl;
  late final TextEditingController _purposeReasonCtrl;
  late final TextEditingController _purposeObjectiveCtrl;

  @override
  void initState() {
    super.initState();
    _procurementNumberCtrl = TextEditingController(text: widget.draft.procurementNumber);
    _orderNumberCtrl = TextEditingController(text: widget.draft.orderNumber);
    _projectNameCtrl = TextEditingController(text: widget.draft.projectName);
    _activityNameCtrl = TextEditingController(text: widget.draft.activityName);
    _purposeReasonCtrl = TextEditingController(text: widget.draft.purposeReason);
    _purposeObjectiveCtrl = TextEditingController(text: widget.draft.purposeObjective);
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

  @override
  void dispose() {
    _procurementNumberCtrl.dispose();
    _orderNumberCtrl.dispose();
    _projectNameCtrl.dispose();
    _activityNameCtrl.dispose();
    _purposeReasonCtrl.dispose();
    _purposeObjectiveCtrl.dispose();
    super.dispose();
  }

  // เลือกแผนงบ -> auto-fill project/activity/allocated/remaining/egp มาให้ทันที
  void _onBudgetSelected(Budget? budget) {
    if (budget == null) return;
    widget.onChanged((d) => d.copyWith(
          budgetId: budget.id,
          fiscalYear: budget.fiscalYear,
          allocatedAmount: budget.allocatedAmount,
          remainingAmount: budget.remainingAmount,
          egpProjectId: budget.egpNumber,
          projectName: budget.projectName,
          activityName: budget.activityName,
        ));
    setState(() {
      _projectNameCtrl.text = budget.projectName ?? '';
      _activityNameCtrl.text = budget.activityName ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
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
            _sectionTitle('เลือกแผนงบประมาณ'),
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
            _sectionTitle('ข้อมูลเอกสาร'),
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
            _sectionTitle('เหตุผลความจำเป็น'),
            TextFormField(
              controller: _purposeReasonCtrl,
              decoration: _inputDecoration('เหตุผลความจำเป็น'),
              maxLines: 4,
              onChanged: (v) => widget.onChanged((d) => d.copyWith(purposeReason: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle('งบประมาณ'),
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _brandColor),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _readonlyMoneyField(String label, double? value) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      readOnly: true,
      initialValue: value == null ? '-' : '${value.toStringAsFixed(2)} บาท',
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
  late final TextEditingController _directorNameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _ownerPositionCtrl;
  late final TextEditingController _financeOfficerCtrl;
  late final TextEditingController _specCreatorNameCtrl;
  late final TextEditingController _specCreatorPositionCtrl;
  late final TextEditingController _procurementOfficerCtrl;
  late final TextEditingController _procurementHeadCtrl;

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
    _directorNameCtrl = TextEditingController(text: d.directorName);
    _ownerNameCtrl = TextEditingController(text: d.ownerName);
    _ownerPositionCtrl = TextEditingController(text: d.ownerPosition);
    _financeOfficerCtrl = TextEditingController(text: d.financeOfficer);
    _specCreatorNameCtrl = TextEditingController(text: d.specCreatorName);
    _specCreatorPositionCtrl = TextEditingController(text: d.specCreatorPosition);
    _procurementOfficerCtrl = TextEditingController(text: d.procurementOfficer);
    _procurementHeadCtrl = TextEditingController(text: d.procurementHead);

    _inspector1Ctrl = TextEditingController(text: d.inspector1);
    _inspector1PosCtrl = TextEditingController(text: d.inspector1Pos);
    _inspector2Ctrl = TextEditingController(text: d.inspector2);
    _inspector2PosCtrl = TextEditingController(text: d.inspector2Pos);
    _inspector3Ctrl = TextEditingController(text: d.inspector3);
    _inspector3PosCtrl = TextEditingController(text: d.inspector3Pos);

    _inspectorTitleGroup = d.inspectorTitleGroup ?? 'ผู้ตรวจรับพัสดุ';
  }

  @override
  void dispose() {
    _directorNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerPositionCtrl.dispose();
    _financeOfficerCtrl.dispose();
    _specCreatorNameCtrl.dispose();
    _specCreatorPositionCtrl.dispose();
    _procurementOfficerCtrl.dispose();
    _procurementHeadCtrl.dispose();
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
    final isCommittee = _inspectorTitleGroup == 'คณะกรรมการตรวจรับ';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('ผู้บริหาร'),
            TextFormField(
              controller: _directorNameCtrl,
              decoration: _inputDecoration('ผู้อำนวยการโรงเรียน'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(directorName: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle('เจ้าของงบ / ผู้จัดทำสเปค'),
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
            _sectionTitle('เจ้าหน้าที่พัสดุ / การเงิน'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _procurementOfficerCtrl,
                    decoration: _inputDecoration('เจ้าหน้าที่พัสดุ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(procurementOfficer: v)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _procurementHeadCtrl,
                    decoration: _inputDecoration('หัวหน้าเจ้าหน้าที่พัสดุ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(procurementHead: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _financeOfficerCtrl,
              decoration: _inputDecoration('เจ้าหน้าที่การเงิน'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(financeOfficer: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle('คณะกรรมการ/ผู้ตรวจรับพัสดุ'),
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

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _brandColor),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
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
  late final TextEditingController _marketPriceCheckCtrl;
  late final TextEditingController _shippingDaysCtrl;
  late final TextEditingController _warrantyPeriodCtrl;
  late final TextEditingController _contractControlNumberCtrl;
  late final TextEditingController _inspectionControlNumberCtrl;

  late double _penaltyRate;

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
    _marketPriceCheckCtrl = TextEditingController(text: d.marketPriceCheck);
    _shippingDaysCtrl = TextEditingController(text: d.shippingDays?.toString());
    _warrantyPeriodCtrl = TextEditingController(text: d.warrantyPeriod);
    _contractControlNumberCtrl = TextEditingController(text: d.contractControlNumber);
    _inspectionControlNumberCtrl = TextEditingController(text: d.inspectionControlNumber);
    _penaltyRate = d.penaltyRate;
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
    _marketPriceCheckCtrl.dispose();
    _shippingDaysCtrl.dispose();
    _warrantyPeriodCtrl.dispose();
    _contractControlNumberCtrl.dispose();
    _inspectionControlNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('ข้อมูลร้านค้า'),
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
            _sectionTitle('การตรวจสอบราคาตลาด'),
            TextFormField(
              controller: _marketPriceCheckCtrl,
              decoration: _inputDecoration('ผลการสืบราคา/ตรวจสอบราคาตลาด'),
              maxLines: 2,
              onChanged: (v) => widget.onChanged((d) => d.copyWith(marketPriceCheck: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle('เงื่อนไขการส่งมอบ / ค่าปรับ / ประกัน'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shippingDaysCtrl,
                    decoration: _inputDecoration('ระยะเวลาส่งมอบ (วัน)'),
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
            Text('อัตราค่าปรับ (% ต่อวัน)', style: TextStyle(color: Colors.grey.shade700)),
            Slider(
              value: _penaltyRate,
              min: 0,
              max: 1.0,
              divisions: 100,
              label: '${(_penaltyRate * 100).toStringAsFixed(2)}%',
              onChanged: (v) {
                setState(() => _penaltyRate = v);
                widget.onChanged((d) => d.copyWith(penaltyRate: v));
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(_penaltyRate * 100).toStringAsFixed(2)}% ต่อวัน',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _brandColor),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('เลขที่ควบคุมเอกสาร'),
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

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _brandColor),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

// ─────────────────────────────────────────────────────────────────
// Tab 4: รายการพัสดุ — ต่อกับ ItemsTableEditor ที่มีอยู่แล้วจริง
// ─────────────────────────────────────────────────────────────────

class _Tab4Items extends StatelessWidget {
  final List<ProcurementItem> initialItems;
  final void Function(List<ProcurementItem> items, double subtotal) onChanged;

  const _Tab4Items({required this.initialItems, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ItemsTableEditor(
              initialItems: initialItems,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Placeholder ใช้ชั่วคราวสำหรับ Tab 2 / 3 / 5
// ─────────────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}