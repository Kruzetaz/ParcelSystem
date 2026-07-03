// items_table_editor.dart
// Tab 4: ตารางรายการพัสดุแบบ dynamic — เพิ่ม/ลบแถวอิสระ ไม่ล็อกจำนวน
// คำนวณ total ต่อแถว (quantity x unit_price) และยอดรวมทั้งหมดแบบ real-time
//
// ใช้ ProcurementItem (schema v2: quantity เป็น double, unit แยกต่างหาก)
// เป็น source of truth — widget นี้แค่จัดการ TextEditingController ของแต่ละ
// แถว แล้วแปลงกลับเป็น ProcurementItem ทุกครั้งที่มีการแก้ไข

import 'package:flutter/material.dart';
import '../models/procurement_item.dart';

/// แถวหนึ่งในตาราง — ผูก TextEditingController ของแต่ละ field ไว้ในตัวเดียว
/// เพื่อไม่ให้ cursor กระโดดตอนพิมพ์ (ปัญหาคลาสสิกของ dynamic form ใน Flutter)
class _ItemRowControllers {
  final int? existingId; // id เดิมใน DB ถ้าเป็นแถวที่โหลดมาแก้ไข (null = แถวใหม่)
  final TextEditingController itemName;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;

  _ItemRowControllers({
    this.existingId,
    String itemName = '',
    String quantity = '',
    String unit = '',
    String unitPrice = '',
  })  : itemName = TextEditingController(text: itemName),
        quantity = TextEditingController(text: quantity),
        unit = TextEditingController(text: unit),
        unitPrice = TextEditingController(text: unitPrice);

  double get parsedQuantity => double.tryParse(quantity.text.trim()) ?? 0;
  double get parsedUnitPrice => double.tryParse(unitPrice.text.trim()) ?? 0;
  double get total => parsedQuantity * parsedUnitPrice;

  bool get quantityInvalid =>
      quantity.text.trim().isNotEmpty && double.tryParse(quantity.text.trim()) == null;
  bool get unitPriceInvalid =>
      unitPrice.text.trim().isNotEmpty && double.tryParse(unitPrice.text.trim()) == null;

  ProcurementItem toItem({int? orderId}) => ProcurementItem(
        id: existingId,
        orderId: orderId,
        itemName: itemName.text.trim(),
        quantity: parsedQuantity,
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        unitPrice: parsedUnitPrice,
      );

  void dispose() {
    itemName.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
  }
}

class ItemsTableEditor extends StatefulWidget {
  /// รายการเริ่มต้น (กรณีแก้ไข order เดิม) — ปล่อยว่างสำหรับ order ใหม่
  final List<ProcurementItem> initialItems;

  /// เรียกทุกครั้งที่ข้อมูลในตารางเปลี่ยน (พิมพ์/เพิ่ม/ลบแถว)
  /// ส่งกลับ items ที่ valid ทั้งหมด + ยอดรวมสุทธิของ items (ก่อน VAT)
  final void Function(List<ProcurementItem> items, double subtotal) onChanged;

  const ItemsTableEditor({
    super.key,
    this.initialItems = const [],
    required this.onChanged,
  });

  @override
  State<ItemsTableEditor> createState() => _ItemsTableEditorState();
}

class _ItemsTableEditorState extends State<ItemsTableEditor> {
  final List<_ItemRowControllers> _rows = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialItems.isEmpty) {
      _rows.add(_ItemRowControllers());
    } else {
      for (final item in widget.initialItems) {
        _rows.add(_ItemRowControllers(
          existingId: item.id,
          itemName: item.itemName,
          quantity: _formatNum(item.quantity),
          unit: item.unit ?? '',
          unitPrice: _formatNum(item.unitPrice),
        ));
      }
    }
    // แจ้ง parent ด้วยค่าตั้งต้นตั้งแต่แรก จะได้ sync กันตั้งแต่เปิดหน้า
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChanged());
  }

  static String _formatNum(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    // ไม่ส่งแถวที่ยังไม่กรอกชื่อสินค้าเลย (แถวว่างระหว่างพิมพ์) กลับไปคำนวณ
    final validRows = _rows.where((r) => r.itemName.text.trim().isNotEmpty);
    final items = validRows.map((r) => r.toItem()).toList();
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.computedTotal);
    widget.onChanged(items, subtotal);
  }

  void _addRow() {
    setState(() => _rows.add(_ItemRowControllers()));
    _notifyChanged();
  }

  void _removeRow(int index) {
    if (_rows.length == 1) {
      // อย่างน้อยต้องเหลือ 1 แถวไว้เสมอ (เคลียร์ค่าแทนการลบทิ้งหมด)
      setState(() {
        _rows[0].dispose();
        _rows[0] = _ItemRowControllers();
      });
    } else {
      setState(() {
        _rows[index].dispose();
        _rows.removeAt(index);
      });
    }
    _notifyChanged();
  }

  double get _grandTotal =>
      _rows.fold<double>(0, (sum, r) => sum + (r.itemName.text.trim().isEmpty ? 0 : r.total));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildDataRow(index),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มรายการ'),
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
                '${_grandTotal.toStringAsFixed(2)} บาท',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A3A5C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: const [
          SizedBox(width: 32, child: Text('ลำดับ', style: style)),
          Expanded(flex: 4, child: Text('ชื่อรายการ', style: style)),
          SizedBox(width: 90, child: Text('จำนวน', style: style)),
          SizedBox(width: 80, child: Text('หน่วย', style: style)),
          SizedBox(width: 110, child: Text('ราคา/หน่วย', style: style)),
          SizedBox(width: 120, child: Text('รวม', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDataRow(int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: row.itemName,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'เช่น โต๊ะนักเรียน',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(_notifyChanged),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: row.quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: row.quantityInvalid ? 'ไม่ใช่ตัวเลข' : null,
                ),
                onChanged: (_) => setState(_notifyChanged),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: row.unit,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'ตัว/ชุด',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(_notifyChanged),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: row.unitPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: row.unitPriceInvalid ? 'ไม่ใช่ตัวเลข' : null,
                ),
                onChanged: (_) => setState(_notifyChanged),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              row.itemName.text.trim().isEmpty ? '-' : row.total.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'ลบรายการ',
              onPressed: () => _removeRow(index),
            ),
          ),
        ],
      ),
    );
  }
}