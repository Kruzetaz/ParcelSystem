// easy_wizard_screen.dart
// Easy Wizard — สร้างเอกสารจัดซื้อจัดจ้างแบบง่าย 4 ขั้นตอน (รายการ → วงเงิน →
// ผู้ขาย → สรุป+สร้าง) เหมาะสำหรับผู้เริ่มต้น/งานเร่งด่วนที่ไม่อยากจำเองว่า
// วงเงินเท่าไรต้องใช้วิธีจัดซื้อจัดจ้างแบบไหน — ระบบเลือกวิธีให้อัตโนมัติจาก
// วงเงินที่กรอก (บันทึกลง procurement_method จริง)
//
// เมื่อกด "สร้างเอกสาร" จะบันทึกเป็น ProcurementOrder + ProcurementItem (แบบร่าง)
// แล้วส่งต่อไปหน้า "สร้างใหม่" (wizard เต็ม) ให้กรอกรายละเอียดที่เหลือ (ชื่อผู้อำนวยการ,
// คณะกรรมการตรวจรับ ฯลฯ) ต่อได้ทันที — Easy Wizard ไม่ได้แทนที่ฟอร์มเต็ม แค่ช่วยเริ่มต้นเร็วขึ้น
//
// [คำเตือนสำคัญ]: วิธีจัดซื้อจัดจ้างที่แนะนำเป็นเพียงคำแนะนำเบื้องต้นตามเกณฑ์วงเงิน
// ทั่วไปเท่านั้น ไม่ใช่การรับรองความถูกต้องทางกฎหมาย ผู้ใช้ควรตรวจสอบระเบียบจริงอีกครั้ง

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_item.dart';
import '../models/procurement_order.dart';
import '../services/toast_service.dart';
import '../utils/money_format.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';

class EasyWizardScreen extends StatefulWidget {
  final void Function(ProcurementOrder order) onCreated;
  const EasyWizardScreen({super.key, required this.onCreated});

  @override
  State<EasyWizardScreen> createState() => _EasyWizardScreenState();
}

class _EasyWizardScreenState extends State<EasyWizardScreen> {
  final _repo = ProcurementRepository();
  int _step = 0;
  bool _saving = false;

  String? _orderType; // 'ซื้อ' | 'จ้าง'
  final _itemNameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController();
  final _unitPriceCtrl = TextEditingController();
  final _vendorNameCtrl = TextEditingController();
  final _vendorOwnerCtrl = TextEditingController();

  static const _stepTitles = ['รายการ', 'วงเงิน', 'ผู้ขาย', 'สรุป+สร้าง'];

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _unitPriceCtrl.dispose();
    _vendorNameCtrl.dispose();
    _vendorOwnerCtrl.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityCtrl.text.trim()) ?? 0;
  double get _unitPrice => double.tryParse(_unitPriceCtrl.text.trim()) ?? 0;
  double get _total => _quantity * _unitPrice;
  String get _method => procurementMethodForAmount(_total);

  bool get _canProceedFromStep0 =>
      _orderType != null && _itemNameCtrl.text.trim().isNotEmpty && _quantity > 0 && _unitPrice > 0;
  bool get _canProceedFromStep2 => _vendorNameCtrl.text.trim().isNotEmpty;

  void _next() {
    if (_step == 0 && !_canProceedFromStep0) {
      _showValidationError('กรุณาเลือกประเภท กรอกชื่อรายการ/งาน จำนวน และราคาต่อหน่วยให้ครบก่อน');
      return;
    }
    if (_step == 2 && !_canProceedFromStep2) {
      _showValidationError('กรุณากรอกชื่อผู้ขาย/ผู้รับจ้างก่อน');
      return;
    }
    setState(() => _step = (_step + 1).clamp(0, _stepTitles.length - 1));
  }

  void _back() => setState(() => _step = (_step - 1).clamp(0, _stepTitles.length - 1));

  void _showValidationError(String message) {
    showAppToast(message, isError: true);
  }

  Future<void> _createOrder() async {
    setState(() => _saving = true);
    try {
      final order = ProcurementOrder(
        orderType: _orderType,
        procurementMethod: _method,
        procurementSubject: _itemNameCtrl.text.trim(),
        projectName: _itemNameCtrl.text.trim(),
        vendorName: _vendorNameCtrl.text.trim(),
        vendorOwner: _vendorOwnerCtrl.text.trim().isEmpty ? null : _vendorOwnerCtrl.text.trim(),
        currentOrderPrice: _total,
      );
      final item = ProcurementItem(
        itemName: _itemNameCtrl.text.trim(),
        quantity: _quantity,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        unitPrice: _unitPrice,
      );
      final orderId = await _repo.saveOrderWithItems(order, [item]);
      if (!mounted) return;
      widget.onCreated(order.copyWith(id: orderId));
    } catch (e) {
      if (!mounted) return;
      _showValidationError('สร้างเอกสารไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GuideFabOverlay(
      title: 'วิธีใช้ Easy Wizard',
      icon: Icons.auto_awesome,
      steps: const [
        'ตอบ 3-4 คำถามง่ายๆ (รายการ, วงเงิน, ผู้ขาย) ระบบจะแนะนำ "วิธีจัดซื้อจัดจ้าง" ที่เหมาะสมให้อัตโนมัติจากวงเงินรวม',
        'เกณฑ์ที่ใช้แนะนำ: ไม่เกิน 5,000 บาท = เฉพาะเจาะจง, ไม่เกิน 50,000 บาท = เฉพาะเจาะจงตาม ว.804, ไม่เกิน 500,000 บาท = เฉพาะเจาะจง, เกินกว่านั้น = e-bidding',
        'คำแนะนำนี้เป็นเกณฑ์วงเงินทั่วไปเท่านั้น ไม่ใช่การรับรองทางกฎหมาย ควรตรวจสอบระเบียบพัสดุที่ใช้บังคับจริงอีกครั้งก่อนดำเนินการ',
        'พอกด "สร้าง" เสร็จ ระบบจะพาไปหน้า "สร้างใหม่" (wizard เต็ม) ให้กรอกรายละเอียดที่เหลือต่อทันที',
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroBanner(context, colors),
                const SizedBox(height: 20),
                _buildStepIndicator(context, colors),
                const SizedBox(height: 24),
                Expanded(child: SingleChildScrollView(child: _buildStepBody(context, colors))),
                const SizedBox(height: 16),
                _buildNavButtons(context, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [BrandAccent.teal(context), BrandAccent.tealLight(context)]),
        borderRadius: BorderRadius.circular(RadiusSize.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Easy Wizard — สร้างเอกสารจัดซื้อจัดจ้างแบบง่าย',
                  style: TextStyle(color: Colors.white, fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading3)),
                const SizedBox(height: 2),
                Text('ตอบ 3-4 คำถามง่ายๆ ระบบเลือกวิธีจัดซื้อจัดจ้างที่ถูกต้องให้อัตโนมัติจากวงเงิน',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: AppTypography.bodyMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        for (var i = 0; i < _stepTitles.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(height: 2, color: i <= _step ? BrandAccent.teal(context) : colors.outlineVariant),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: i <= _step ? BrandAccent.teal(context) : colors.surfaceContainerHighest,
                child: Text('${i + 1}',
                  style: TextStyle(color: i <= _step ? Colors.white : colors.onSurfaceVariant, fontWeight: AppTypography.weightBold)),
              ),
              const SizedBox(height: 4),
              Text(_stepTitles[i],
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  color: i <= _step ? BrandAccent.tealOn(context) : colors.onSurfaceVariant,
                  fontWeight: i == _step ? AppTypography.weightSemiBold : AppTypography.weightRegular,
                )),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStepBody(BuildContext context, ColorScheme colors) {
    switch (_step) {
      case 0:
        return _buildStep0(context, colors);
      case 1:
        return _buildStep1(context, colors);
      case 2:
        return _buildStep2(context, colors);
      default:
        return _buildStep3(colors);
    }
  }

  InputDecoration _fieldDecoration(BuildContext context, {required String label, String? hint}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.md),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.md),
        borderSide: BorderSide(color: colors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusSize.md),
        borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5),
      ),
    );
  }

  Widget _buildStep0(BuildContext context, ColorScheme colors) {
    Widget typeCard(String type, IconData icon, String label, String hint) {
      final selected = _orderType == type;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _orderType = type),
          borderRadius: BorderRadius.circular(RadiusSize.card),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? BrandAccent.teal(context) : colors.outline, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(RadiusSize.card),
              color: selected ? BrandAccent.teal(context).withValues(alpha: 0.08) : colors.surface,
            ),
            child: Column(
              children: [
                Icon(icon, size: 32, color: selected ? BrandAccent.tealOn(context) : colors.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body, color: selected ? BrandAccent.tealOn(context) : colors.onSurface)),
                const SizedBox(height: 4),
                Text(hint, textAlign: TextAlign.center, style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ขั้นที่ 1: รายการที่ต้องการจัดหาคืออะไร?', style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading4, color: colors.onSurface)),
        const SizedBox(height: 12),
        Text('ประเภท *', style: TextStyle(fontWeight: AppTypography.weightSemiBold, fontSize: AppTypography.body, color: colors.onSurface)),
        const SizedBox(height: 8),
        Row(
          children: [
            typeCard('ซื้อ', Icons.shopping_cart_outlined, 'จัดซื้อวัสดุ/ครุภัณฑ์', 'ซื้อสิ่งของ อุปกรณ์'),
            const SizedBox(width: 12),
            typeCard('จ้าง', Icons.build_outlined, 'จัดจ้าง/ซ่อม/บริการ', 'งานจ้าง ซ่อมแซม บริการ'),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _itemNameCtrl,
          style: TextStyle(fontSize: AppTypography.body),
          decoration: _fieldDecoration(context,
            label: 'ชื่อรายการ/งาน *',
            hint: 'เช่น "จัดซื้อกระดาษ A4" หรือ "จ้างซ่อมเครื่องปรับอากาศ"',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quantityCtrl,
                style: TextStyle(fontSize: AppTypography.body),
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(context, label: 'จำนวน *'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unitCtrl,
                style: TextStyle(fontSize: AppTypography.body),
                decoration: _fieldDecoration(context, label: 'หน่วยนับ', hint: 'เช่น ชิ้น, เครื่อง'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unitPriceCtrl,
                style: TextStyle(fontSize: AppTypography.body),
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(context, label: 'ราคาต่อหน่วย (บาท) *'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1(BuildContext context, ColorScheme colors) {
    final amberBg = Color.alphaBlend(BrandColors.amber.withValues(alpha: 0.12), colors.surface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ขั้นที่ 2: วงเงินและวิธีจัดซื้อจัดจ้างที่แนะนำ', style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading4, color: colors.onSurface)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BrandAccent.teal(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            border: Border.all(color: BrandAccent.teal(context).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text('วงเงินรวม', style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium)),
              const SizedBox(height: 4),
              Text('${formatBaht(_total)} บาท',
                style: TextStyle(color: colors.onSurface, fontSize: AppTypography.display1, fontWeight: AppTypography.weightExtraBold)),
              const SizedBox(height: 4),
              Text('($_quantity x $_unitPrice บาท)', style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodySmall)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: amberBg,
            borderRadius: BorderRadius.circular(RadiusSize.md),
            border: Border.all(color: BrandColors.amber.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lightbulb_outline, color: BrandAccent.tertiary(context), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('วิธีจัดซื้อจัดจ้างที่แนะนำ', style: TextStyle(fontWeight: AppTypography.weightBold, fontSize: AppTypography.body, color: colors.onSurface))),
              ]),
              const SizedBox(height: 8),
              Text(_method, style: TextStyle(fontSize: AppTypography.heading3, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
              const SizedBox(height: 8),
              Text(
                'คำแนะนำนี้อ้างอิงจากเกณฑ์วงเงินทั่วไปเท่านั้น ไม่ใช่การรับรองความถูกต้องทางกฎหมาย '
                'โปรดตรวจสอบระเบียบจริงของหน่วยงานอีกครั้งก่อนดำเนินการ',
                style: TextStyle(fontSize: AppTypography.bodySmall, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(BuildContext context, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ขั้นที่ 3: ผู้ขาย/ผู้รับจ้างคือใคร?', style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading4, color: colors.onSurface)),
        const SizedBox(height: 16),
        TextField(
          controller: _vendorNameCtrl,
          style: TextStyle(fontSize: AppTypography.body),
          decoration: _fieldDecoration(context, label: 'ชื่อร้านค้า/บริษัท *'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _vendorOwnerCtrl,
          style: TextStyle(fontSize: AppTypography.body),
          decoration: _fieldDecoration(context, label: 'ชื่อเจ้าของ/ผู้ติดต่อ (ถ้ามี)'),
        ),
      ],
    );
  }

  Widget _buildStep3(ColorScheme colors) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: AppTypography.bodyMedium, color: colors.onSurfaceVariant))),
              Expanded(child: Text(value, style: TextStyle(fontSize: AppTypography.body, fontWeight: AppTypography.weightSemiBold, color: colors.onSurface))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ขั้นที่ 4: ตรวจสอบและสร้างเอกสาร', style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading4, color: colors.onSurface)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(RadiusSize.card),
            boxShadow: AppShadows.light1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('ประเภท', _orderType == 'ซื้อ' ? 'จัดซื้อวัสดุ/ครุภัณฑ์' : 'จัดจ้าง/ซ่อม/บริการ'),
              row('รายการ/งาน', _itemNameCtrl.text.trim()),
              row('จำนวน', '$_quantity ${_unitCtrl.text.trim()}'),
              row('ราคาต่อหน่วย', '${formatBaht(_unitPrice)} บาท'),
              row('วงเงินรวม', '${formatBaht(_total)} บาท'),
              row('วิธีจัดซื้อจัดจ้าง', _method),
              row('ผู้ขาย/ผู้รับจ้าง', _vendorNameCtrl.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'กด "สร้างเอกสาร" เพื่อบันทึกเป็นร่างเอกสารจัดซื้อจัดจ้าง แล้วไปกรอกรายละเอียดที่เหลือ '
          '(ผู้อำนวยการ, คณะกรรมการตรวจรับ ฯลฯ) ต่อในหน้า "สร้างใหม่"',
          style: TextStyle(fontSize: AppTypography.caption, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildNavButtons(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(
            onPressed: _saving ? null : _back,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: BorderSide(color: colors.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: const Text('ย้อนกลับ'),
          ),
        const Spacer(),
        if (_step < _stepTitles.length - 1)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            onPressed: _next,
            child: const Text('ถัดไป'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            onPressed: _saving ? null : _createOrder,
            icon: _saving
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                : const Icon(Icons.check),
            label: Text(_saving ? 'กำลังสร้าง...' : 'สร้างเอกสาร'),
          ),
      ],
    );
  }
}
