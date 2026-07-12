// receipt_ocr_dialog.dart
// หน้าต่างพรีวิว/แก้ไขรายการที่ AI อ่านได้จากใบเสร็จ ก่อนนำเข้าตารางจริง
// ผู้ใช้ตรวจสอบ/แก้ไขตัวเลขหรือชื่อที่พิมพ์ผิดได้ก่อนกด "ยืนยันนำเข้าข้อมูล"
// ถ้า AI สงสัยว่ามีสินค้าจากหลายโครงการปนกันในใบเสร็จเดียว จะมีแถบเตือนสีเหลือง
// (ไม่แยกรายการอัตโนมัติ — ผู้ใช้ลบแถวที่ไม่เกี่ยวเองถ้าจำเป็น)

import 'package:flutter/material.dart';
import '../models/procurement_item.dart';

class OcrParsedItem {
  final TextEditingController itemName;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;
  final bool multiProjectHint;

  OcrParsedItem({
    required String itemName,
    required String quantity,
    required String unit,
    required String unitPrice,
    this.multiProjectHint = false,
  })  : itemName = TextEditingController(text: itemName),
        quantity = TextEditingController(text: quantity),
        unit = TextEditingController(text: unit),
        unitPrice = TextEditingController(text: unitPrice);

  void dispose() {
    itemName.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
  }

  ProcurementItem toItem() => ProcurementItem(
        itemName: itemName.text.trim(),
        quantity: double.tryParse(quantity.text.trim()) ?? 0,
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        unitPrice: double.tryParse(unitPrice.text.trim()) ?? 0,
      );

  factory OcrParsedItem.fromJson(Map<String, dynamic> json) {
    String numToStr(dynamic v) {
      if (v == null) return '';
      if (v is num) return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
      return v.toString();
    }

    return OcrParsedItem(
      itemName: (json['item_name'] ?? '').toString(),
      quantity: numToStr(json['quantity']),
      unit: (json['unit'] ?? '').toString(),
      unitPrice: numToStr(json['unit_price']),
      multiProjectHint: json['multi_project_hint'] == true,
    );
  }
}

/// แสดง dialog พรีวิว — คืนค่า List<ProcurementItem> ที่ยืนยันแล้ว หรือ null ถ้ายกเลิก
Future<List<ProcurementItem>?> showReceiptOcrPreviewDialog(
  BuildContext context,
  List<OcrParsedItem> parsedItems,
) {
  return showDialog<List<ProcurementItem>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReceiptOcrPreviewDialog(parsedItems: parsedItems),
  );
}

class _ReceiptOcrPreviewDialog extends StatefulWidget {
  final List<OcrParsedItem> parsedItems;
  const _ReceiptOcrPreviewDialog({required this.parsedItems});

  @override
  State<_ReceiptOcrPreviewDialog> createState() => _ReceiptOcrPreviewDialogState();
}

class _ReceiptOcrPreviewDialogState extends State<_ReceiptOcrPreviewDialog> {
  late List<OcrParsedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.parsedItems);
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _removeAt(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasMultiProjectHint = _items.any((i) => i.multiProjectHint);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: colors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'ตรวจสอบรายการที่อ่านได้จากใบเสร็จ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ตรวจสอบและแก้ไขตัวเลข/ชื่อที่ผิดได้ก่อนนำเข้า',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
              ),
              if (hasMultiProjectHint) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'พบว่าอาจมีพัสดุจากหลายโครงการปนกันในใบเสร็จนี้ (ทำเครื่องหมาย ⚠ ไว้ให้) '
                          'กรุณาตรวจสอบและลบรายการที่ไม่เกี่ยวข้องกับโครงการนี้ก่อนยืนยัน',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('ไม่พบรายการ', style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++) _buildRow(colors, i),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _items.isEmpty
                        ? null
                        : () => Navigator.pop(
                              context,
                              _items.map((i) => i.toItem()).toList(),
                            ),
                    icon: const Icon(Icons.check),
                    label: Text('ยืนยันนำเข้าข้อมูล (${_items.length} รายการ)'),
                    style: FilledButton.styleFrom(backgroundColor: colors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme colors, int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (item.multiProjectHint)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
            ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: item.itemName,
                decoration: const InputDecoration(isDense: true, hintText: 'ชื่อรายการ'),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: item.quantity,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, hintText: 'จำนวน'),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: item.unit,
                decoration: const InputDecoration(isDense: true, hintText: 'หน่วย'),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: item.unitPrice,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, hintText: 'ราคา/หน่วย'),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _removeAt(index),
          ),
        ],
      ),
    );
  }
}
