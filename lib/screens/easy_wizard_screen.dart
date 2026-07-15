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
                _buildHeroBanner(colors),
                const SizedBox(height: 20),
                _buildStepIndicator(colors),
                const SizedBox(height: 24),
                Expanded(child: SingleChildScrollView(child: _buildStepBody(colors))),
                const SizedBox(height: 16),
                _buildNavButtons(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: 0.75)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: colors.onPrimary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Easy Wizard — สร้างเอกสารจัดซื้อจัดจ้างแบบง่าย',
                  style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('ตอบ 3-4 คำถามง่ายๆ ระบบเลือกวิธีจัดซื้อจัดจ้างที่ถูกต้องให้อัตโนมัติจากวงเงิน',
                  style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.9), fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colors) {
    return Row(
      children: [
        for (var i = 0; i < _stepTitles.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(height: 2, color: i <= _step ? colors.primary : colors.outlineVariant),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: i <= _step ? colors.primary : colors.surfaceContainerHighest,
                child: Text('${i + 1}',
                  style: TextStyle(color: i <= _step ? colors.onPrimary : colors.onSurfaceVariant, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(_stepTitles[i],
                style: TextStyle(
                  fontSize: 11.5,
                  color: i <= _step ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: i == _step ? FontWeight.w600 : FontWeight.normal,
                )),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStepBody(ColorScheme colors) {
    switch (_step) {
      case 0:
        return _buildStep0(colors);
      case 1:
        return _buildStep1(colors);
      case 2:
        return _buildStep2(colors);
      default:
        return _buildStep3(colors);
    }
  }

  Widget _buildStep0(ColorScheme colors) {
    Widget typeCard(String type, IconData icon, String label, String hint) {
      final selected = _orderType == type;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _orderType = type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
              color: selected ? colors.primary.withValues(alpha: 0.08) : null,
            ),
            child: Column(
              children: [
                Icon(icon, size: 32, color: selected ? colors.primary : colors.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? colors.primary : null)),
                const SizedBox(height: 4),
                Text(hint, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ขั้นที่ 1: รายการที่ต้องการจัดหาคืออะไร?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        const Text('ประเภท *', style: TextStyle(fontWeight: FontWeight.w600)),
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
          decoration: const InputDecoration(
            labelText: 'ชื่อรายการ/งาน *', border: OutlineInputBorder(), isDense: true,
            hintText: 'เช่น "จัดซื้อกระดาษ A4" หรือ "จ้างซ่อมเครื่องปรับอากาศ"',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'จำนวน *', border: OutlineInputBorder(), isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(labelText: 'หน่วยนับ', border: OutlineInputBorder(), isDense: true, hintText: 'เช่น ชิ้น, เครื่อง'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unitPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ราคาต่อหน่วย (บาท) *', border: OutlineInputBorder(), isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ขั้นที่ 2: วงเงินและวิธีจัดซื้อจัดจ้างที่แนะนำ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text('วงเงินรวม', style: TextStyle(color: colors.onPrimaryContainer, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${formatBaht(_total)} บาท',
                style: TextStyle(color: colors.onPrimaryContainer, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('($_quantity x $_unitPrice บาท)', style: TextStyle(color: colors.onPrimaryContainer, fontSize: 11.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('วิธีจัดซื้อจัดจ้างที่แนะนำ', style: TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              Text(_method, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'คำแนะนำนี้อ้างอิงจากเกณฑ์วงเงินทั่วไปเท่านั้น ไม่ใช่การรับรองความถูกต้องทางกฎหมาย '
                'โปรดตรวจสอบระเบียบจริงของหน่วยงานอีกครั้งก่อนดำเนินการ',
                style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ขั้นที่ 3: ผู้ขาย/ผู้รับจ้างคือใคร?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        TextField(
          controller: _vendorNameCtrl,
          decoration: const InputDecoration(labelText: 'ชื่อร้านค้า/บริษัท *', border: OutlineInputBorder(), isDense: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vendorOwnerCtrl,
          decoration: const InputDecoration(labelText: 'ชื่อเจ้าของ/ผู้ติดต่อ (ถ้ามี)', border: OutlineInputBorder(), isDense: true),
        ),
      ],
    );
  }

  Widget _buildStep3(ColorScheme colors) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 140, child: Text(label, style: TextStyle(color: colors.onSurfaceVariant))),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ขั้นที่ 4: ตรวจสอบและสร้างเอกสาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(10)),
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
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildNavButtons(ColorScheme colors) {
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(onPressed: _saving ? null : _back, child: const Text('ย้อนกลับ')),
        const Spacer(),
        if (_step < _stepTitles.length - 1)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            onPressed: _next,
            child: const Text('ถัดไป'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
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
