// standard_price_picker_dialog.dart
// กล่องค้นหาราคากลาง/ชื่อรายการจากบัญชีราคามาตรฐานครุภัณฑ์ (สำนักงบประมาณ)
// เลือกแล้วคืนค่า StandardPriceItem กลับไปให้ฟอร์มเติมชื่อ+ราคาให้อัตโนมัติ

import 'package:flutter/material.dart';
import '../services/standard_price_service.dart';
import '../utils/money_format.dart';

Future<StandardPriceItem?> showStandardPricePickerDialog(BuildContext context) {
  return showDialog<StandardPriceItem>(
    context: context,
    builder: (_) => const _StandardPricePickerDialog(),
  );
}

class _StandardPricePickerDialog extends StatefulWidget {
  const _StandardPricePickerDialog();
  @override
  State<_StandardPricePickerDialog> createState() => _StandardPricePickerDialogState();
}

class _StandardPricePickerDialogState extends State<_StandardPricePickerDialog> {
  final _searchCtrl = TextEditingController();
  List<StandardPriceItem> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runSearch('');
    _searchCtrl.addListener(() => _runSearch(_searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final results = await StandardPriceService.instance.search(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.price_change_outlined, color: colors.primary),
                  const SizedBox(width: 8),
                  const Text('ค้นหาราคากลางครุภัณฑ์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'จากบัญชีราคามาตรฐานครุภัณฑ์ สำนักงบประมาณ (ฉบับ ธ.ค. 2568) '
                'เป็นราคาประมาณการเบื้องต้นเท่านั้น ควรตรวจสอบราคากลางจริง ณ วันที่จัดซื้อก่อนใช้อ้างอิงในเอกสารราชการเสมอ',
                style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'พิมพ์ชื่อครุภัณฑ์ เช่น โปรเจคเตอร์, โต๊ะทำงาน, เครื่องปรับอากาศ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('ไม่พบรายการที่ตรงกับคำค้นหา', style: TextStyle(color: colors.onSurfaceVariant)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final item = _results[i];
                              return ListTile(
                                dense: true,
                                title: Text(item.name, style: const TextStyle(fontSize: 13)),
                                subtitle: Text(item.category, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                                trailing: Text('${formatBaht(item.price)} บาท',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: colors.primary)),
                                onTap: () => Navigator.pop(context, item),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
