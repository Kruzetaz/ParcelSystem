// delivery_note_register_screen.dart
// ทะเบียนคุมใบส่งของ — บันทึกใบส่งของที่ผู้ขาย/ผู้รับจ้างส่งมอบให้โรงเรียน ใช้
// เป็นหลักฐานประกอบการตรวจรับ 1 โครงการอาจมีหลายใบส่งของ (ส่งมอบหลายรอบ) จึง
// แยกเป็นทะเบียนของตัวเอง ไม่ใช่แค่ช่องเดียวในฟอร์มสร้างโครงการเหมือนเดิม

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/delivery_note.dart';
import '../models/procurement_order.dart';
import '../services/fiscal_year_controller.dart';
import '../widgets/guide_panel.dart';
import '../widgets/thai_date_picker.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/data_table_shell.dart'
    show DsActionIconButtons, DsRowAction;
import '../widgets/design_system/hover_clear_button.dart';
import '../widgets/design_system/clearable_text_field.dart';

const _dialogTitleStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
const _dialogContentStyle = TextStyle(fontSize: 15, height: 1.4);
const _dialogButtonTextStyle =
    TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700);
const _dialogButtonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
const _dialogFieldStyle = TextStyle(fontSize: 17);
const _dialogLabelStyle = TextStyle(fontSize: 15);

InputDecoration _dialogFieldDecoration(BuildContext context,
    {required String label, String? hint}) {
  final colors = Theme.of(context).colorScheme;
  final borderColor = colors.outline;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: _dialogLabelStyle.copyWith(
        color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: borderColor, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusSize.md),
      borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
    ),
  );
}

const _thaiMonths = [
  '',
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];
String _formatThai(DateTime d) =>
    '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';

class DeliveryNoteRegisterScreen extends StatefulWidget {
  const DeliveryNoteRegisterScreen({super.key});
  @override
  State<DeliveryNoteRegisterScreen> createState() =>
      _DeliveryNoteRegisterScreenState();
}

class _DeliveryNoteRegisterScreenState
    extends State<DeliveryNoteRegisterScreen> {
  final _repo = ProcurementRepository();
  List<DeliveryNote> _notes = [];
  Map<int, ProcurementOrder> _ordersById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    FiscalYearController.instance.addListener(_onFiscalYearChanged);
  }

  @override
  void dispose() {
    FiscalYearController.instance.removeListener(_onFiscalYearChanged);
    super.dispose();
  }

  void _onFiscalYearChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final notes = await _repo.getAllDeliveryNotes(
        fiscalYear: FiscalYearController.instance.viewingYear);
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _ordersById = {
        for (final o in orders)
          if (o.id != null) o.id!: o
      };
      _loading = false;
    });
  }

  Future<void> _openForm({DeliveryNote? existing}) async {
    final orders = await _repo.getAllOrders();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DeliveryNoteFormDialog(existing: existing, orders: orders),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(DeliveryNote n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: _dialogTitleStyle),
        content: Text('ต้องการลบใบส่งของ "${n.docNumber ?? "-"}" ใช่หรือไม่?',
            style: _dialogContentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: _dialogButtonPadding,
                textStyle: _dialogButtonTextStyle),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true && n.id != null) {
      await _repo.deleteDeliveryNote(n.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้ทะเบียนคุมใบส่งของ',
      icon: Icons.local_shipping_outlined,
      corner: Alignment.bottomLeft,
      steps: const [
        'บันทึกใบส่งของ/เอกสารหลักฐานที่ผู้ขายหรือผู้รับจ้างส่งมอบให้โรงเรียน ใช้ประกอบการตรวจรับพัสดุ',
        '1 โครงการสามารถมีได้หลายใบส่งของ ถ้าส่งมอบหลายรอบ — เลือกผูกกับโครงการที่เกี่ยวข้องได้จากรายการที่มีอยู่แล้ว',
        'กด "เพิ่มใบส่งของ" มุมขวาล่างเพื่อเริ่มบันทึกรายการใหม่',
      ],
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  color: BrandAccent.tealOn(context), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('ทะเบียนคุมใบส่งของ',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppTypography.heading2,
                                        fontWeight:
                                            AppTypography.weightExtraBold,
                                        color: colors.onSurface)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _notes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.local_shipping_outlined,
                                            size: 64,
                                            color: colors.onSurfaceVariant),
                                        const SizedBox(height: 12),
                                        Text(
                                            'ยังไม่มีใบส่งของ\nกด "เพิ่มใบส่งของ" เพื่อเริ่มต้น',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: colors.onSurfaceVariant,
                                                fontSize:
                                                    AppTypography.heading4)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _notes.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (_, i) =>
                                        _buildCard(context, colors, _notes[i]),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'delivery_note_add_fab',
              onPressed: () => _openForm(),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มใบส่งของ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme colors, DeliveryNote n) {
    final order = n.orderId != null ? _ordersById[n.orderId] : null;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusSize.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        onTap: () => _openForm(existing: n),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              BrandAccent.teal(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(RadiusSize.sm),
                        ),
                        child: Text(n.docType ?? 'ใบส่งของ',
                            style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: BrandAccent.tealOn(context),
                                fontWeight: AppTypography.weightSemiBold)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                        n.docNumber?.trim().isNotEmpty == true
                            ? n.docNumber!
                            : '(ไม่มีเลขที่ใบส่งของ)',
                        style: TextStyle(
                            fontWeight: AppTypography.weightBold,
                            fontSize: AppTypography.heading4,
                            color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (order != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          '${order.projectName ?? order.procurementSubject ?? "-"} · ผู้ส่งมอบ: ${order.vendorName ?? "-"}',
                          style: TextStyle(
                              fontSize: AppTypography.bodySmall,
                              color: colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (n.itemsDescription?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text('รายการที่ส่งมอบ: ${n.itemsDescription}',
                          style: TextStyle(
                              fontSize: AppTypography.caption,
                              color: colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 2),
                    Text(
                        'วันที่ส่งมอบ: ${n.deliveryDate ?? "-"}${n.receivedBy?.trim().isNotEmpty == true ? "  ·  ผู้รับ: ${n.receivedBy}" : ""}',
                        style: TextStyle(
                            fontSize: AppTypography.caption,
                            color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              DsActionIconButtons(
                actions: [
                  DsRowAction(
                      icon: Icons.delete_outline,
                      tooltip: 'ลบ',
                      onTap: () => _confirmDelete(n),
                      danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryNoteFormDialog extends StatefulWidget {
  final DeliveryNote? existing;
  final List<ProcurementOrder> orders;
  const _DeliveryNoteFormDialog({this.existing, required this.orders});
  @override
  State<_DeliveryNoteFormDialog> createState() =>
      _DeliveryNoteFormDialogState();
}

class _DeliveryNoteFormDialogState extends State<_DeliveryNoteFormDialog> {
  final _repo = ProcurementRepository();
  late final TextEditingController _docNumberCtrl;
  late final TextEditingController _itemsCtrl;
  late final TextEditingController _receivedByCtrl;
  late final TextEditingController _noteCtrl;
  String _docType = deliveryDocTypes.first;
  int? _orderId;
  String? _deliveryDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final n = widget.existing;
    _docNumberCtrl = TextEditingController(text: n?.docNumber ?? '');
    _itemsCtrl = TextEditingController(text: n?.itemsDescription ?? '');
    _receivedByCtrl = TextEditingController(text: n?.receivedBy ?? '');
    _noteCtrl = TextEditingController(text: n?.note ?? '');
    _docType = deliveryDocTypes.contains(n?.docType)
        ? n!.docType!
        : deliveryDocTypes.first;
    _orderId = n?.orderId;
    _deliveryDate = n?.deliveryDate;
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _itemsCtrl.dispose();
    _receivedByCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryDate() async {
    final colors = Theme.of(context).colorScheme;
    final initial = DateTime.now();
    final picked = await pickThaiDate(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 1),
      helpText: 'วันที่ส่งมอบ',
      primaryColor: colors.primary,
      onPrimaryColor: colors.onPrimary,
    );
    if (picked == null) return;
    setState(() => _deliveryDate = _formatThai(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final n = DeliveryNote(
      id: widget.existing?.id,
      orderId: _orderId,
      docType: _docType,
      docNumber: _docNumberCtrl.text.trim().isEmpty
          ? null
          : _docNumberCtrl.text.trim(),
      deliveryDate: _deliveryDate,
      itemsDescription:
          _itemsCtrl.text.trim().isEmpty ? null : _itemsCtrl.text.trim(),
      receivedBy: _receivedByCtrl.text.trim().isEmpty
          ? null
          : _receivedByCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (widget.existing == null) {
      await _repo.insertDeliveryNote(n);
    } else {
      await _repo.updateDeliveryNote(n);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขใบส่งของ' : 'เพิ่มใบส่งของ',
          style: _dialogTitleStyle),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: HoverBuilder(
                  builder: (context, hovering) => DropdownButtonFormField<int?>(
                    initialValue: _orderId,
                    isExpanded: true,
                    style: _dialogFieldStyle.copyWith(color: colors.onSurface),
                    decoration: _dialogFieldDecoration(context,
                            label: 'ผูกกับโครงการจัดซื้อจัดจ้าง')
                        .copyWith(
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      suffixIcon: hovering && _orderId != null
                          ? clearIconButton(
                              context, () => setState(() => _orderId = null))
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('(ไม่ผูกกับโครงการ)')),
                      ...widget.orders
                          .where((o) => o.id != null)
                          .map((o) => DropdownMenuItem<int?>(
                                value: o.id,
                                child: Text(
                                    o.projectName ??
                                        o.procurementSubject ??
                                        'เอกสาร #${o.id}',
                                    overflow: TextOverflow.ellipsis),
                              )),
                    ],
                    onChanged: (v) => setState(() => _orderId = v),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: DropdownButtonFormField<String>(
                        initialValue: _docType,
                        isExpanded: true,
                        style:
                            _dialogFieldStyle.copyWith(color: colors.onSurface),
                        decoration: _dialogFieldDecoration(context,
                                label: 'ประเภทเอกสาร')
                            .copyWith(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto),
                        items: deliveryDocTypes
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child:
                                    Text(t, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _docType = v ?? deliveryDocTypes.first),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: ClearableTextField(
                        controller: _docNumberCtrl,
                        style: _dialogFieldStyle,
                        decoration: _dialogFieldDecoration(context,
                            label: 'เลขที่เอกสาร', hint: 'เช่น INV-0012'),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: InkWell(
                  onTap: _pickDeliveryDate,
                  borderRadius: BorderRadius.circular(RadiusSize.md),
                  child: InputDecorator(
                    decoration: _dialogFieldDecoration(context,
                            label: 'วันที่ส่งมอบ')
                        .copyWith(
                            floatingLabelBehavior: FloatingLabelBehavior.auto),
                    child: Text(_deliveryDate ?? 'เลือกวันที่',
                        style: _dialogFieldStyle),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ClearableTextField(
                  controller: _itemsCtrl,
                  style: _dialogFieldStyle,
                  maxLines: 2,
                  decoration: _dialogFieldDecoration(context,
                      label: 'รายการที่ส่งมอบ (ถ้าส่งบางส่วน)',
                      hint: 'เช่น กระดาษ A4 50 รีม (ส่งครบ)'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ClearableTextField(
                  controller: _receivedByCtrl,
                  style: _dialogFieldStyle,
                  decoration: _dialogFieldDecoration(context,
                      label: 'ผู้รับมอบ', hint: 'เช่น นางสาว...'),
                ),
              ),
              ClearableTextField(
                controller: _noteCtrl,
                style: _dialogFieldStyle,
                maxLines: 2,
                decoration: _dialogFieldDecoration(context, label: 'หมายเหตุ'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
              padding: _dialogButtonPadding, textStyle: _dialogButtonTextStyle),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: _dialogButtonPadding,
              textStyle: _dialogButtonTextStyle),
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.onPrimary))
              : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
        ),
      ],
    );
  }
}
