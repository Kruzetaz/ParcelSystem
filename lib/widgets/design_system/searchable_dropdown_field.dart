// searchable_dropdown_field.dart
// dropdown เลือกจากรายการที่ "พิมพ์ค้นหากรองได้" เหมือนแถบค้นหาหลักบนแถบบน —
// ใช้แทน DropdownButtonFormField ตรงจุดที่ตัวเลือกมีเยอะจนเลื่อนหายาก (เช่น
// เลือกแผนงบประมาณที่มีเป็นสิบ-ร้อยรายการ) รับ type ทั่วไปได้ ไม่ผูกกับโมเดล
// ใดโมเดลหนึ่ง — แสดงตัวเลือกแบบ rich widget (itemBuilder) แต่กรองด้วยข้อความ
// ล้วนๆ (labelOf/matcher)

import 'package:flutter/material.dart';

class SearchableDropdownField<T extends Object> extends StatefulWidget {
  final T? value;
  final List<T> options;
  // ข้อความของตัวเลือกนี้ — ใช้ทั้งโชว์ในช่องตอนเลือกแล้ว และกรองแบบ contains
  // เริ่มต้นถ้าไม่ได้ระบุ [matcher] เอง
  final String Function(T option) labelOf;
  // widget ที่ใช้แสดงแต่ละตัวเลือกในรายการแบบ dropdown (จะได้ตกแต่งได้อิสระ
  // เหมือน DropdownMenuItem เดิม)
  final Widget Function(BuildContext context, T option) itemBuilder;
  final bool Function(T option, String query)? matcher;
  final ValueChanged<T?> onChanged;
  final InputDecoration? decoration;
  final bool enabled;

  const SearchableDropdownField({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.itemBuilder,
    required this.onChanged,
    this.matcher,
    this.decoration,
    this.enabled = true,
  });

  @override
  State<SearchableDropdownField<T>> createState() =>
      _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T extends Object>
    extends State<SearchableDropdownField<T>> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _labelForValue());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  String _labelForValue() =>
      widget.value != null ? widget.labelOf(widget.value as T) : '';

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // เลือกข้อความทั้งหมดไว้ พิมพ์ทับได้เลยทันทีแบบ combobox ทั่วไป
      _ctrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    } else {
      // ออกจากช่องโดยไม่ได้เลือกอะไรใหม่ (แค่พิมพ์ค้นหาทิ้งไว้) — คืนข้อความ
      // กลับเป็นค่าที่เลือกจริงอยู่เดิม กันข้อความค้างเป็นคำค้นหาที่ไม่ตรงกับ
      // ค่าที่เลือกจริง
      final label = _labelForValue();
      if (_ctrl.text != label) _ctrl.text = label;
    }
  }

  @override
  void didUpdateWidget(covariant SearchableDropdownField<T> old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focusNode.hasFocus) {
      _ctrl.text = _labelForValue();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // ต้องรู้ความกว้างจริงของช่องกรอกก่อน ถึงจะบังคับให้กล่องตัวเลือกด้านล่าง
    // กว้างเท่ากันเป๊ะได้ — RawAutocomplete เองไม่ทำให้อัตโนมัติ (ปล่อยให้กล่อง
    // ตัวเลือกหดตามความกว้างของเนื้อหาแทน ทำให้แคบ/กว้างไม่เท่าช่องกรอกเดิม)
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return RawAutocomplete<T>(
          textEditingController: _ctrl,
          focusNode: _focusNode,
          displayStringForOption: widget.labelOf,
          optionsBuilder: (textValue) {
            final q = textValue.text.trim().toLowerCase();
            if (q.isEmpty) return widget.options;
            final matcher = widget.matcher ??
                (option, query) =>
                    widget.labelOf(option).toLowerCase().contains(query);
            return widget.options.where((o) => matcher(o, q));
          },
          onSelected: (selected) {
            _ctrl.text = widget.labelOf(selected);
            widget.onChanged(selected);
          },
          fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textCtrl,
              focusNode: focusNode,
              enabled: widget.enabled,
              decoration: widget.decoration,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optionsList = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: colors.surfaceContainerHigh,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: 320,
                      minWidth: fieldWidth,
                      maxWidth: fieldWidth),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: optionsList.length,
                    itemBuilder: (context, index) {
                      final option = optionsList[index];
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: widget.itemBuilder(context, option),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
