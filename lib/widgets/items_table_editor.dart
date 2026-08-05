// items_table_editor.dart
// Tab 4: ตารางรายการพัสดุแบบ dynamic — เพิ่ม/ลบแถวอิสระ ไม่ล็อกจำนวน
// คำนวณ total ต่อแถว (quantity x unit_price) และยอดรวมทั้งหมดแบบ real-time
//
// ใช้ ProcurementItem (schema v2: quantity เป็น double, unit แยกต่างหาก)
// เป็น source of truth — widget นี้แค่จัดการ TextEditingController ของแต่ละ
// แถว แล้วแปลงกลับเป็น ProcurementItem ทุกครั้งที่มีการแก้ไข

import 'package:flutter/material.dart';
import '../models/procurement_item.dart';
import '../utils/money_format.dart';
import 'memory_text_field.dart';

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

/// ควบคุม ItemsTableEditor จากภายนอกได้ (เช่นเพิ่มแถวจากผลลัพธ์ AI อ่านใบเสร็จ)
/// โดยไม่ต้องรื้อ initialItems/onChanged เดิม — ผูกกับ instance เดียวผ่าน
/// _attach/_detach ตอน widget mount/unmount
class ItemsTableEditorController {
  _ItemsTableEditorState? _state;
  void _attach(_ItemsTableEditorState state) => _state = state;
  void _detach() => _state = null;

  /// เพิ่มรายการต่อท้ายตารางที่มีอยู่ — ใช้ตอนยืนยันนำเข้าจากใบเสร็จที่ AI อ่านให้
  void addItems(List<ProcurementItem> items) => _state?._addItems(items);
}

class ItemsTableEditor extends StatefulWidget {
  /// รายการเริ่มต้น (กรณีแก้ไข order เดิม) — ปล่อยว่างสำหรับ order ใหม่
  final List<ProcurementItem> initialItems;

  /// เรียกทุกครั้งที่ข้อมูลในตารางเปลี่ยน (พิมพ์/เพิ่ม/ลบแถว)
  /// ส่งกลับ items ที่ valid ทั้งหมด + ยอดรวมของ items (ราคาต่อหน่วยที่กรอก
  /// ถือว่า "รวม VAT ไว้แล้ว" เสมอ ตรงกับที่ร้านค้าคิดในบิลจริง — CalcEngine
  /// จะเป็นคนแยก VAT ออกจากยอดนี้ตอนบันทึก ไม่ใช่บวก VAT เพิ่มเข้าไปอีก)
  final void Function(List<ProcurementItem> items, double subtotal) onChanged;

  final ItemsTableEditorController? controller;

  const ItemsTableEditor({
    super.key,
    this.initialItems = const [],
    required this.onChanged,
    this.controller,
  });

  @override
  State<ItemsTableEditor> createState() => _ItemsTableEditorState();
}

class _ItemsTableEditorState extends State<ItemsTableEditor> {
  final List<_ItemRowControllers> _rows = [];

  // โหมดเลือกหลายรายการ — เปิดแล้วคอลัมน์ "ลำดับ" จะกลายเป็น checkbox ให้ติ๊ก
  // เลือกได้ทีละหลายแถว เพื่อลบพร้อมกันทีเดียว แทนการกดถังขยะทีละแถว
  bool _selectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
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

  /// เรียกจาก ItemsTableEditorController.addItems — เพิ่มแถวต่อท้าย ไม่ล้างของเดิม
  /// (ถ้าแถวแรกสุดยังว่างเปล่าอยู่ ให้ใช้แถวนั้นแทนแถวใหม่แถวแรก)
  void _addItems(List<ProcurementItem> items) {
    if (items.isEmpty) return;
    setState(() {
      if (_rows.length == 1 && _rows[0].itemName.text.trim().isEmpty) {
        _rows[0].dispose();
        _rows.removeAt(0);
      }
      for (final item in items) {
        _rows.add(_ItemRowControllers(
          itemName: item.itemName,
          quantity: _formatNum(item.quantity),
          unit: item.unit ?? '',
          unitPrice: _formatNum(item.unitPrice),
        ));
      }
    });
    _notifyChanged();
  }

  static String _formatNum(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  void dispose() {
    widget.controller?._detach();
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

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIndices.clear();
    });
  }

  void _toggleRowSelected(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _rows.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices
          ..clear()
          ..addAll(List.generate(_rows.length, (i) => i));
      }
    });
  }

  Future<bool> _confirmBulkDelete(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// ลบเฉพาะแถวที่ติ๊กเลือกไว้ — เหลืออย่างน้อย 1 แถวว่างเสมอถ้าลบจนหมด
  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;
    final confirmed = await _confirmBulkDelete('ต้องการลบ ${_selectedIndices.length} รายการที่เลือกไว้ใช่หรือไม่?');
    if (!confirmed) return;
    setState(() {
      final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final i in sorted) {
        _rows[i].dispose();
        _rows.removeAt(i);
      }
      if (_rows.isEmpty) _rows.add(_ItemRowControllers());
      _selectedIndices.clear();
      _selectionMode = false;
    });
    _notifyChanged();
  }

  /// ลบรายการทั้งหมดในตารางรวดเดียว ไม่ต้องเลือกทีละแถว — เหลือแถวว่างไว้ 1 แถว
  Future<void> _deleteAllRows() async {
    final hasContent = _rows.any((r) => r.itemName.text.trim().isNotEmpty);
    if (!hasContent) return;
    final confirmed = await _confirmBulkDelete('ต้องการลบรายการพัสดุทั้งหมด ${_rows.length} รายการใช่หรือไม่?');
    if (!confirmed) return;
    setState(() {
      for (final r in _rows) {
        r.dispose();
      }
      _rows.clear();
      _rows.add(_ItemRowControllers());
      _selectedIndices.clear();
      _selectionMode = false;
    });
    _notifyChanged();
  }

  double get _grandTotal =>
      _rows.fold<double>(0, (sum, r) => sum + (r.itemName.text.trim().isEmpty ? 0 : r.total));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbarRow(colors),
        const SizedBox(height: 6),
        _buildHeaderRow(colors),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildDataRow(colors, index),
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
                '${formatBaht(_grandTotal)} บาท',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// แถบเครื่องมือเหนือตาราง — สลับโหมดเลือกหลายรายการ + ปุ่มลบที่เลือก/ลบทั้งหมด
  Widget _buildToolbarRow(ColorScheme colors) {
    final hasContent = _rows.any((r) => r.itemName.text.trim().isNotEmpty) || _rows.length > 1;
    if (!_selectionMode) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: _rows.isEmpty ? null : _toggleSelectionMode,
            icon: const Icon(Icons.checklist_outlined, size: 18),
            label: const Text('เลือกหลายรายการ'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: hasContent ? _deleteAllRows : null,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
            label: const Text('ลบทั้งหมด', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      );
    }
    final allSelected = _rows.isNotEmpty && _selectedIndices.length == _rows.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Checkbox(value: allSelected, onChanged: (_) => _toggleSelectAll()),
          Text('เลือกแล้ว ${_selectedIndices.length} รายการ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant)),
          const Spacer(),
          TextButton(
            onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
            child: const Text('ลบที่เลือก', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: _toggleSelectionMode, child: const Text('ยกเลิก')),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(ColorScheme colors) {
    final style = TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: _selectionMode
                ? Text('เลือก', style: style, softWrap: false, overflow: TextOverflow.visible)
                : Text('ลำดับ', style: style, softWrap: false, overflow: TextOverflow.visible),
          ),
          Expanded(flex: 4, child: Text('ชื่อรายการ', style: style)),
          SizedBox(width: 90, child: Text('จำนวน', style: style)),
          SizedBox(width: 80, child: Text('หน่วย', style: style)),
          SizedBox(width: 110, child: Text('ราคา/หน่วย', style: style)),
          SizedBox(width: 120, child: Text('รวม', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDataRow(ColorScheme colors, int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            child: _selectionMode
                ? Checkbox(
                    value: _selectedIndices.contains(index),
                    onChanged: (_) => _toggleRowSelected(index),
                  )
                : Text('${index + 1}', style: TextStyle(color: colors.onSurfaceVariant)),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MemoryTextField(
                fieldKey: 'item.name',
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
              child: MemoryTextField(
                fieldKey: 'item.unit',
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
              row.itemName.text.trim().isEmpty ? '-' : formatBaht(row.total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 40,
            child: _selectionMode
                ? null
                : IconButton(
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