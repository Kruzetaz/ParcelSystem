// travel_reimbursement_wizard_screen.dart
// วิซาร์ด 4 แท็บสำหรับโมดูล "เบิกจ่ายค่าใช้จ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)"
// มิเรอร์โครงสร้าง TabController ของ order_wizard_screen.dart — draft state
// เดียวใน State นี้ ส่งลงแท็บผ่าน callback
//
// จัดกลุ่มแท็บตาม "ใช้ที่ไหน" แทนลำดับขั้นตอนเฉยๆ กันสับสนว่าช่องไหนไปโผล่
// เอกสารใบไหน:
// Tab 1: ข้อมูลทั่วไป — ใช้ร่วมกันทุกเอกสารทั้ง 3 ใบ (โครงการ, เลขที่หนังสือ,
//        เรื่อง, สถานที่, ช่วงวันที่)
// Tab 2: ผู้เดินทางและค่าใช้จ่าย — ตารางในหลักฐานการจ่ายเงิน ส่วนที่ 2 โดยตรง
// Tab 3: ใบเบิกฯ ส่วนที่ 1 — ทุกช่องในนี้กระทบแค่เอกสารใบนี้ใบเดียว (สถานที่
//        ออกเดินทาง, ผู้ขอเบิกคนเดียว/และคณะ, ผู้ตรวจสอบ, อัตราการเบิกแต่ละหมวด,
//        ไกด์เอกสารแนบ) — ปุ่มบันทึก/สร้างเอกสารอยู่แถบล่างค้างทุกแท็บ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/budget.dart';
import '../models/personnel.dart';
import '../models/school_settings.dart';
import '../models/travel_reimbursement.dart';
import '../models/travel_participant.dart';
import '../services/travel_document_generator.dart';
import '../services/toast_service.dart';
import '../theme/design_tokens.dart';
import '../utils/calc_engine.dart';
import '../utils/money_format.dart';
import '../utils/thai_date.dart';
import '../widgets/design_system/status_badge.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';

class TravelReimbursementWizardScreen extends StatefulWidget {
  final TravelReimbursement? existingReimbursement;
  final VoidCallback? onSaved;

  const TravelReimbursementWizardScreen({
    super.key,
    this.existingReimbursement,
    this.onSaved,
  });

  @override
  State<TravelReimbursementWizardScreen> createState() => _TravelReimbursementWizardScreenState();
}

class _TravelReimbursementWizardScreenState extends State<TravelReimbursementWizardScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProcurementRepository();
  late final TabController _tabController;

  late TravelReimbursement _draft;
  List<TravelParticipant> _participants = [];
  List<Budget> _budgets = [];
  List<Personnel> _personnel = [];
  SchoolSettings _school = const SchoolSettings();

  bool _loading = true;
  bool _saving = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _draft = widget.existingReimbursement ?? const TravelReimbursement();
    _load();
  }

  Future<void> _load() async {
    final budgets = await _repo.getAllBudgets();
    final personnel = await _repo.getAllPersonnel(activeOnly: true);
    final school = await _repo.getSchoolSettings();
    List<TravelParticipant> participants = [];
    if (_draft.id != null) {
      participants = await _repo.getTravelParticipants(_draft.id!);
    }
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _personnel = personnel;
      _school = school ?? const SchoolSettings();
      _participants = participants;
      _loading = false;
    });
  }

  void _updateDraft(TravelReimbursement Function(TravelReimbursement) update) {
    setState(() => _draft = update(_draft));
  }

  Personnel? _findPersonnel(int? id) {
    if (id == null) return null;
    for (final p in _personnel) {
      if (p.id == id) return p;
    }
    return null;
  }

  double get _totalAmount => TravelDocumentGenerator.sumTotal(_participants);

  Future<TravelReimbursement> _save() async {
    setState(() => _saving = true);
    try {
      final total = _totalAmount;
      final toSave = _draft.copyWith(
        totalAmount: total,
        totalAmountTh: CalcEngine.bahtText(total),
        createdAt: _draft.createdAt ?? DateTime.now().toIso8601String(),
      );
      final id = await _repo.saveTravelReimbursementWithParticipants(toSave, _participants);
      final saved = toSave.copyWith(id: id);
      setState(() => _draft = saved);
      return saved;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOnly() async {
    await _save();
    if (!mounted) return;
    ToastController.instance.show('บันทึกแล้ว');
    widget.onSaved?.call();
  }

  Future<void> _generateDocuments() async {
    if (_participants.isEmpty) {
      ToastController.instance.show('ยังไม่มีรายชื่อผู้เดินทาง — เพิ่มอย่างน้อย 1 คนก่อน', isError: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final saved = await _save();
      // "ผู้ขอเบิก/ผู้รับเงิน" มาจากคนละช่องกันตามตัวเลือก: ติ๊ก "และคณะ" ใช้
      // advancePayerPersonnelId, ติ๊ก "คนเดียว" ใช้ requesterPersonnelId — เช็ค
      // isAdvancePayer ก่อนเสมอ กัน advancePayerPersonnelId ค้างจากตอนเคยติ๊ก
      // "และคณะ" ไว้ก่อนแล้วสลับกลับมา (copyWith เคลียร์เป็น null ตรงๆ ไม่ได้)
      final payee = saved.isAdvancePayer
          ? _findPersonnel(saved.advancePayerPersonnelId)
          : _findPersonnel(saved.requesterPersonnelId);
      final checker = _findPersonnel(saved.checkerPersonnelId);
      final files = await TravelDocumentGenerator.generateAll(
        reimbursement: saved,
        participants: _participants,
        school: _school,
        payee: payee,
        checker: checker,
      );
      if (!mounted) return;
      ToastController.instance.show('สร้างเอกสารสำเร็จ ${files.length} ไฟล์');
      if (files.isNotEmpty) {
        await TravelDocumentGenerator.openFile(files.first.path);
      }
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ToastController.instance.show('สร้างเอกสารไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.outline)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            splashBorderRadius: BorderRadius.circular(RadiusSize.full),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: Colors.transparent,
            indicator: BoxDecoration(
              color: BrandAccent.teal(context),
              borderRadius: BorderRadius.circular(RadiusSize.full),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: colors.onSurfaceVariant,
            labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            tabs: [
              _wizardStepTab(1, 'ข้อมูลทั่วไป'),
              _wizardStepTab(2, 'ผู้เดินทางและค่าใช้จ่าย'),
              _wizardStepTab(3, 'ใบเบิกฯ ส่วนที่ 1'),
            ],
          ),
        ),
        Expanded(
          child: GuideFabOverlay(
            title: 'วิธีใช้เบิกจ่ายเดินทางไปราชการ (แบบ ๘๗๐๘)',
            icon: Icons.card_travel_outlined,
            steps: const [
              'แท็บ 1 (ใช้ร่วมทุกเอกสาร) — เลือกแผนงบประมาณ กรอกเลขที่หนังสือ เรื่อง สถานที่ และช่วงวันที่เดินทาง',
              'แท็บ 2 (หลักฐานการจ่ายเงิน ส่วนที่ 2) — กดปุ่ม "เพิ่มจากทำเนียบบุคลากร" เพื่อเลือกผู้เดินทางแต่ละคน แล้วกรอกยอดค่าเบี้ยเลี้ยง/ที่พัก/พาหนะ/ค่าใช้จ่ายอื่นต่อคน ดูยอดรวมท้ายรายการ',
              'แท็บ 3 (เฉพาะใบเบิกฯ ส่วนที่ 1) — เลือกสถานที่ออกเดินทาง, ผู้ขอเบิก (คนเดียว/และคณะ), ผู้ตรวจสอบ, อัตราการเบิกแต่ละหมวด และไกด์เอกสารแนบ',
              'กด "สร้างเอกสาร Word" ครั้งเดียว ระบบจะสร้างให้ครบ 3 ใบ (บันทึกข้อความ, ใบเบิกฯ ส่วนที่ 1, หลักฐานการจ่ายเงิน ส่วนที่ 2) พร้อมกัน',
            ],
            corner: Alignment.bottomRight,
            child: TabBarView(
              controller: _tabController,
              children: [
                _Tab1Info(draft: _draft, budgets: _budgets, onChanged: _updateDraft),
                _Tab2Participants(
                  participants: _participants,
                  personnel: _personnel,
                  onChanged: (p) => setState(() => _participants = p),
                ),
                _Tab3Form1Details(
                  draft: _draft,
                  personnel: _personnel,
                  onChanged: _updateDraft,
                ),
              ],
            ),
          ),
        ),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_saving || _generating) ? null : _saveOnly,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_saving || _generating) ? null : _generateDocuments,
                    icon: _generating
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                        : const Icon(Icons.description_outlined),
                    label: Text(_generating ? 'กำลังสร้าง...' : 'สร้างเอกสาร Word'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// แท็บขั้นตอนแบบมีเลขกำกับ (1-3) — ใช้สี currentColor ที่ TabBar กำหนดให้
  /// ผ่าน DefaultTextStyle รอบๆ tab นี้อยู่แล้ว ตรงกับ pattern เดียวกับ
  /// order_wizard_screen.dart (_wizardStepTab)
  Widget _wizardStepTab(int step, String label) {
    return Tab(
      child: Builder(builder: (context) {
        final fg = DefaultTextStyle.of(context).style.color ?? Colors.white;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: fg, width: 1.3)),
                child: Text('$step', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg, height: 1)),
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        );
      }),
    );
  }
}

// ปักหัวข้อ (labelText) ให้ลอยค้างอยู่บนกรอบตลอด (ไม่ใช่แค่ตอนโฟกัส) เพื่อให้
// มีที่ว่างในกรอบไว้โชว์ hintText เป็นตัวอย่างข้อความจางๆ ได้พร้อมกันเสมอ —
// ใช้ hint ทุกที่ที่ค่าที่ต้องกรอกไม่ชัดเจนในตัวเอง (เช่น trip_subject ที่ใน
// เทมเพลตมีข้อความนำหน้าอยู่แล้ว "ขอเบิกค่าใช้จ่ายในการเดินทางไปราชการ (...)")
InputDecoration _inputDecoration(BuildContext context, String label, {String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    hintStyle: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md), borderSide: BorderSide(color: borderColor, width: 1.3)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md), borderSide: BorderSide(color: borderColor, width: 1.3)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md), borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.6)),
  );
}

// ปุ่ม (x) ท้ายช่อง dropdown ที่ไม่บังคับ — โชว์เฉพาะตอนมีค่าเลือกไว้แล้ว
// กดแล้วล้างกลับเป็นว่างทันทีโดยไม่ต้องเปิด dropdown ไปเลือก "(ไม่ระบุ)" เอง
Widget? _clearButton(bool hasValue, VoidCallback onClear) => hasValue
    ? IconButton(
        icon: const Icon(Icons.clear, size: 18),
        tooltip: 'ล้างค่าที่เลือก',
        onPressed: onClear,
      )
    : null;

// หัวข้อหมวดในแต่ละแท็บ — สไตล์เดียวกับ _sectionTitle ของ order_wizard_screen.dart
// (หน้า "สร้างใหม่") ตัวหนา ไม่มีกรอบ/พื้นหลัง ให้ทั้งสองหน้าดูเป็นชุดเดียวกัน
Widget _sectionTitle(ColorScheme colors, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: AppTypography.weightExtraBold,
          fontSize: AppTypography.heading4,
          color: colors.onSurface,
        ),
      ),
    );

// ─────────────────────────────────────────────────────────────────
// Tab 1: ข้อมูลโครงการและคำสั่ง
// ─────────────────────────────────────────────────────────────────
class _Tab1Info extends StatefulWidget {
  final TravelReimbursement draft;
  final List<Budget> budgets;
  final void Function(TravelReimbursement Function(TravelReimbursement)) onChanged;

  const _Tab1Info({required this.draft, required this.budgets, required this.onChanged});

  @override
  State<_Tab1Info> createState() => _Tab1InfoState();
}

class _Tab1InfoState extends State<_Tab1Info> {
  late final TextEditingController _docNumberCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _destinationCtrl;
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;

  @override
  void initState() {
    super.initState();
    _docNumberCtrl = TextEditingController(text: widget.draft.documentNumber);
    _subjectCtrl = TextEditingController(text: widget.draft.subject);
    _destinationCtrl = TextEditingController(text: widget.draft.destination);
    _startDateCtrl = TextEditingController(text: widget.draft.startDate);
    _endDateCtrl = TextEditingController(text: widget.draft.endDate);
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _subjectCtrl.dispose();
    _destinationCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl, void Function(String) setValue) async {
    final colors = Theme.of(context).colorScheme;
    final initial = parseThaiDate(ctrl.text) ?? DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    final y = picked.year + 543;
    final formatted = '${picked.day} ${thaiMonthsAbbrev.isNotEmpty ? _fullMonth(picked.month) : ''} $y';
    setState(() => ctrl.text = formatted);
    setValue(formatted);
  }

  static String _fullMonth(int m) => const [
        '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
        'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
      ][m];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(colors, 'ข้อมูลโครงการและเอกสาร'),
            DropdownButtonFormField<int?>(
              initialValue: widget.draft.budgetId,
              isExpanded: true,
              decoration: _inputDecoration(context, 'แผนงบประมาณ/โครงการ', hint: 'ไม่บังคับ ถ้าไม่เกี่ยวกับแผนงบใดเลยเว้นว่างได้').copyWith(
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                suffixIcon: _clearButton(widget.draft.budgetId != null, () => widget.onChanged((d) => d.copyWith(budgetId: null))),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('(ไม่ระบุแผนงบ)')),
                for (final b in widget.budgets)
                  DropdownMenuItem(
                    value: b.id,
                    child: Text(b.projectName ?? '(ไม่มีชื่อโครงการ)', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => widget.onChanged((d) => d.copyWith(budgetId: v)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _docNumberCtrl,
              decoration: _inputDecoration(context, 'เลขที่หนังสือ', hint: 'เช่น ศธ 0000/0000'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(documentNumber: v)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectCtrl,
              maxLines: 2,
              decoration: _inputDecoration(context, 'เรื่อง/วัตถุประสงค์การไปราชการ', hint: 'เช่น เข้าร่วมอบรม/ประชุม/สัมมนา...'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(subject: v)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _destinationCtrl,
              decoration: _inputDecoration(context, 'สถานที่ไปปฏิบัติราชการ', hint: 'เช่น โรงแรม/สถานที่จัดงาน จังหวัด...'),
              onChanged: (v) => widget.onChanged((d) => d.copyWith(destination: v)),
            ),
            const SizedBox(height: 28),
            _sectionTitle(colors, 'ช่วงเวลาเดินทาง'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startDateCtrl,
                    readOnly: true,
                    decoration: _inputDecoration(context, 'วันที่เริ่มเดินทาง').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    onTap: () => _pickDate(_startDateCtrl, (v) => widget.onChanged((d) => d.copyWith(startDate: v))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _endDateCtrl,
                    readOnly: true,
                    decoration: _inputDecoration(context, 'วันที่สิ้นสุดการเดินทาง').copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
                    onTap: () => _pickDate(_endDateCtrl, (v) => widget.onChanged((d) => d.copyWith(endDate: v))),
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
}

// ─────────────────────────────────────────────────────────────────
// Tab 2: ผู้เดินทางและค่าใช้จ่าย
// ─────────────────────────────────────────────────────────────────
class _Tab2Participants extends StatelessWidget {
  final List<TravelParticipant> participants;
  final List<Personnel> personnel;
  final void Function(List<TravelParticipant>) onChanged;

  const _Tab2Participants({required this.participants, required this.personnel, required this.onChanged});

  Future<void> _addPersonnel(BuildContext context) async {
    final alreadyAddedIds = participants.map((p) => p.personnelId).whereType<int>().toSet();
    final candidates = personnel.where((p) => !alreadyAddedIds.contains(p.id)).toList();
    final selected = await showDialog<List<Personnel>>(
      context: context,
      builder: (ctx) => _PersonnelPickerDialog(candidates: candidates),
    );
    if (selected == null || selected.isEmpty) return;
    final next = [...participants];
    for (final p in selected) {
      next.add(TravelParticipant(personnelId: p.id, participantName: p.name, position: p.position));
    }
    onChanged(next);
  }

  static const _headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _headerRow(ColorScheme colors) {
    final style = _headerStyle.copyWith(color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('ลำดับ', style: style)),
          Expanded(flex: 3, child: Text('ชื่อ-ตำแหน่ง', style: style)),
          SizedBox(width: 110, child: Text('เบี้ยเลี้ยง', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text('ที่พัก', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text('พาหนะ', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text('ค่าใช้จ่ายอื่น', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text('รวม', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final grandTotal = TravelDocumentGenerator.sumTotal(participants);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _sectionTitle(colors, 'รายชื่อผู้เดินทาง (${participants.length} คน)')),
                FilledButton.icon(
                  onPressed: () => _addPersonnel(context),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('เพิ่มจากทำเนียบบุคลากร'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                    textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: participants.isEmpty ? 32 : 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(RadiusSize.card),
                border: Border.all(color: colors.outline),
                boxShadow: AppShadows.light1,
              ),
              child: participants.isEmpty
                  ? Center(child: Text('ยังไม่มีผู้เดินทาง', style: TextStyle(color: colors.onSurfaceVariant)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _headerRow(colors),
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: participants.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _ParticipantRow(
                            index: i,
                            participant: participants[i],
                            onChanged: (updated) {
                              final next = [...participants];
                              next[i] = updated;
                              onChanged(next);
                            },
                            onRemove: () {
                              final next = [...participants]..removeAt(i);
                              onChanged(next);
                            },
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('รวมทั้งสิ้น: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '${formatBaht(grandTotal)} บาท',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(RadiusSize.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ยอดรวมสุทธิ', style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                  Text('${formatBaht(grandTotal)} บาท',
                      style: TextStyle(fontSize: AppTypography.heading1, fontWeight: AppTypography.weightBold)),
                  Text('(${CalcEngine.bahtText(grandTotal)})',
                      style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatefulWidget {
  final int index;
  final TravelParticipant participant;
  final ValueChanged<TravelParticipant> onChanged;
  final VoidCallback onRemove;

  const _ParticipantRow({required this.index, required this.participant, required this.onChanged, required this.onRemove});

  @override
  State<_ParticipantRow> createState() => _ParticipantRowState();
}

class _ParticipantRowState extends State<_ParticipantRow> {
  late final TextEditingController _allowanceCtrl;
  late final TextEditingController _accommodationCtrl;
  late final TextEditingController _transportCtrl;
  late final TextEditingController _registrationCtrl;

  @override
  void initState() {
    super.initState();
    _allowanceCtrl = TextEditingController(text: widget.participant.allowanceAmount == 0 ? '' : widget.participant.allowanceAmount.toString());
    _accommodationCtrl = TextEditingController(text: widget.participant.accommodationAmount == 0 ? '' : widget.participant.accommodationAmount.toString());
    _transportCtrl = TextEditingController(text: widget.participant.transportAmount == 0 ? '' : widget.participant.transportAmount.toString());
    _registrationCtrl = TextEditingController(text: widget.participant.registrationFee == 0 ? '' : widget.participant.registrationFee.toString());
  }

  @override
  void dispose() {
    _allowanceCtrl.dispose();
    _accommodationCtrl.dispose();
    _transportCtrl.dispose();
    _registrationCtrl.dispose();
    super.dispose();
  }

  static InputDecoration _cellDecoration() => const InputDecoration(
        isDense: true,
        hintText: '0.00',
        border: OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 36, child: Text('${widget.index + 1}', style: TextStyle(color: colors.onSurfaceVariant))),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.participant.participantName, style: TextStyle(fontWeight: AppTypography.weightSemiBold)),
                  if (widget.participant.position?.isNotEmpty ?? false)
                    Text(widget.participant.position!, style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _allowanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _cellDecoration(),
              onChanged: (v) => widget.onChanged(widget.participant.copyWith(allowanceAmount: double.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _accommodationCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _cellDecoration(),
              onChanged: (v) => widget.onChanged(widget.participant.copyWith(accommodationAmount: double.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _transportCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _cellDecoration(),
              onChanged: (v) => widget.onChanged(widget.participant.copyWith(transportAmount: double.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _registrationCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _cellDecoration(),
              onChanged: (v) => widget.onChanged(widget.participant.copyWith(registrationFee: double.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(formatBaht(widget.participant.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'ลบรายการ',
              onPressed: widget.onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelPickerDialog extends StatefulWidget {
  final List<Personnel> candidates;
  const _PersonnelPickerDialog({required this.candidates});

  @override
  State<_PersonnelPickerDialog> createState() => _PersonnelPickerDialogState();
}

class _PersonnelPickerDialogState extends State<_PersonnelPickerDialog> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เลือกผู้เดินทาง'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: widget.candidates.isEmpty
            ? const Center(child: Text('ไม่มีบุคลากรให้เลือกเพิ่มแล้ว'))
            : ListView(
                children: [
                  for (final p in widget.candidates)
                    CheckboxListTile(
                      value: _selected.contains(p.id),
                      title: Text(p.name),
                      subtitle: p.position != null ? Text(p.position!) : null,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(p.id!);
                          } else {
                            _selected.remove(p.id);
                          }
                        });
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () {
            final chosen = widget.candidates.where((p) => _selected.contains(p.id)).toList();
            Navigator.pop(context, chosen);
          },
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tab 3: สรุป/ผู้สำรองจ่าย/ผู้ตรวจสอบ/สร้างเอกสาร
// ─────────────────────────────────────────────────────────────────
class _Tab3Form1Details extends StatefulWidget {
  final TravelReimbursement draft;
  final List<Personnel> personnel;
  final void Function(TravelReimbursement Function(TravelReimbursement)) onChanged;

  const _Tab3Form1Details({
    required this.draft,
    required this.personnel,
    required this.onChanged,
  });

  @override
  State<_Tab3Form1Details> createState() => _Tab3Form1DetailsState();
}

class _Tab3Form1DetailsState extends State<_Tab3Form1Details> {
  late final TextEditingController _allowanceTypeCtrl;
  late final TextEditingController _accommodationTypeCtrl;
  late final TextEditingController _transportTypeCtrl;
  late final TextEditingController _otherExpenseTypeCtrl;

  static const _checklistItems = [
    'สำเนาคำสั่งไปราชการ / หนังสือเชิญอบรม (จากหน่วยงานจัด)',
    'ใบเสร็จรับเงินค่าลงทะเบียน (ตัวจริง ออกในนามโรงเรียน)',
    'ใบเสร็จรับเงินค่าที่พัก + Folio/รายละเอียดห้องพัก (ตัวจริง)',
    'ตั๋วเดินทาง / ใบเสร็จค่าน้ำมันเชื้อเพลิง (ถ้ามี)',
    'ตารางคำนวณระยะทาง / ใบรับรองแทนใบเสร็จรับเงิน (แบบ ๘๘๐๘)',
    'สรุปรายงานผลการเข้าร่วมอบรม/ไปปฏิบัติราชการ',
  ];

  @override
  void initState() {
    super.initState();
    _allowanceTypeCtrl = TextEditingController(text: widget.draft.allowanceType);
    _accommodationTypeCtrl = TextEditingController(text: widget.draft.accommodationType);
    _transportTypeCtrl = TextEditingController(text: widget.draft.transportType);
    _otherExpenseTypeCtrl = TextEditingController(text: widget.draft.otherExpenseType);
  }

  @override
  void dispose() {
    _allowanceTypeCtrl.dispose();
    _accommodationTypeCtrl.dispose();
    _transportTypeCtrl.dispose();
    _otherExpenseTypeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(colors, 'สถานที่ออกเดินทาง'),
            Row(
              children: [
                DSFilterChip(
                  label: 'ที่พัก',
                  isSelected: widget.draft.departsFromHome,
                  onTap: () => widget.onChanged((d) => d.copyWith(departsFromHome: true)),
                ),
                const SizedBox(width: 12),
                DSFilterChip(
                  label: 'สำนักงาน',
                  isSelected: !widget.draft.departsFromHome,
                  onTap: () => widget.onChanged((d) => d.copyWith(departsFromHome: false)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _sectionTitle(colors, 'ผู้ขอเบิก (ติ๊ก ☑ ข้าพเจ้า/และคณะ ในเอกสารตามตัวเลือกนี้)'),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DSFilterChip(
                  label: 'ข้าพเจ้าคนเดียว',
                  isSelected: !widget.draft.isAdvancePayer,
                  onTap: () => widget.onChanged((d) => d.copyWith(isAdvancePayer: false, advancePayerPersonnelId: null)),
                ),
                DSFilterChip(
                  label: 'ข้าพเจ้าและคณะ (มีผู้สำรองจ่ายเงินแทน)',
                  isSelected: widget.draft.isAdvancePayer,
                  onTap: () => widget.onChanged((d) => d.copyWith(isAdvancePayer: true)),
                ),
              ],
            ),
            if (widget.draft.isAdvancePayer) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: widget.draft.advancePayerPersonnelId,
                isExpanded: true,
                decoration: _inputDecoration(context, 'ผู้สำรองจ่าย/หัวหน้าคณะ').copyWith(
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  suffixIcon: _clearButton(widget.draft.advancePayerPersonnelId != null, () => widget.onChanged((d) => d.copyWith(advancePayerPersonnelId: null))),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('(ยังไม่เลือก)')),
                  for (final p in widget.personnel) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => widget.onChanged((d) => d.copyWith(advancePayerPersonnelId: v)),
              ),
            ] else ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: widget.draft.requesterPersonnelId,
                isExpanded: true,
                decoration: _inputDecoration(context, 'ผู้ขอเบิก/ผู้รับเงิน').copyWith(
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  suffixIcon: _clearButton(widget.draft.requesterPersonnelId != null, () => widget.onChanged((d) => d.copyWith(requesterPersonnelId: null))),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('(ยังไม่เลือก — ใช้ผู้เดินทางคนแรกในตาราง)')),
                  for (final p in widget.personnel) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => widget.onChanged((d) => d.copyWith(requesterPersonnelId: v)),
              ),
            ],
            const SizedBox(height: 28),
            _sectionTitle(colors, 'ผู้ตรวจสอบหลักฐาน'),
            DropdownButtonFormField<int?>(
              initialValue: widget.draft.checkerPersonnelId,
              isExpanded: true,
              decoration: _inputDecoration(context, 'ผู้ตรวจสอบหลักฐานการเบิกจ่าย').copyWith(
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                suffixIcon: _clearButton(widget.draft.checkerPersonnelId != null, () => widget.onChanged((d) => d.copyWith(checkerPersonnelId: null))),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('(ยังไม่เลือก)')),
                for (final p in widget.personnel) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => widget.onChanged((d) => d.copyWith(checkerPersonnelId: v)),
            ),
            const SizedBox(height: 28),
            _sectionTitle(colors, 'อัตราการเบิก (ประเภท) แต่ละหมวด'),
            Text('ตามแบบ ๘๗๐๘ ส่วนที่ 1 — เว้นว่างช่องไหนได้ ถ้าจะปริ้นเอกสารแล้วเขียนกรอกเองด้วยมือ',
                style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allowanceTypeCtrl,
                    decoration: _inputDecoration(context, 'ประเภทค่าเบี้ยเลี้ยง', hint: 'เช่น ระดับชำนาญการ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(allowanceType: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _accommodationTypeCtrl,
                    decoration: _inputDecoration(context, 'ประเภทค่าเช่าที่พัก', hint: 'เช่น ระดับชำนาญการ'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(accommodationType: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _transportTypeCtrl,
                    decoration: _inputDecoration(context, 'ประเภทค่าพาหนะ', hint: 'เช่น รถยนต์ส่วนตัว'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(transportType: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _otherExpenseTypeCtrl,
                    decoration: _inputDecoration(context, 'ประเภทค่าใช้จ่ายอื่น', hint: 'เช่น ค่าลงทะเบียน'),
                    onChanged: (v) => widget.onChanged((d) => d.copyWith(otherExpenseType: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _sectionTitle(colors, '📌 ไกด์แนะนำเอกสารประกอบชุดเบิกจ่าย'),
            Text(
              'นอกจากเอกสารที่ระบบสร้างให้ ต้องรวบรวมเอกสารเหล่านี้มาแนบเย็บเล่มเพิ่ม:',
              style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final item in _checklistItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('☐ '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

