// memory_text_field.dart
// ช่องกรอกข้อความที่จดจำค่าที่เคยพิมพ์ไว้ก่อนหน้า (ต่อ fieldKey เฉพาะของแต่ละช่อง)
// แล้วเสนอเป็น dropdown ให้เลือกซ้ำได้ทั้งตอนพิมพ์ (กรองตามคำที่พิมพ์) และตอนคลิก
// เข้าช่องว่างๆ (โชว์รายการที่ใช้ล่าสุดก่อน) ใช้แทน TextFormField ตรงๆ ได้เลย
// (รับ controller/decoration/onChanged เหมือนกัน)

import 'package:flutter/material.dart';
import '../services/field_memory_service.dart';

class MemoryTextField extends StatefulWidget {
  final String fieldKey;
  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;

  /// ตัวเลือกที่ตรึงไว้ให้เห็นเสมอ (ขึ้นก่อนประวัติที่เคยพิมพ์) เช่น รายการ
  /// ตำแหน่งมาตรฐานของครู — ยังพิมพ์เองนอกเหนือจากนี้ได้ตามปกติ ไม่ได้ล็อกเป็น
  /// dropdown บังคับ
  final List<String> presetOptions;

  const MemoryTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.decoration,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.presetOptions = const [],
  });

  @override
  State<MemoryTextField> createState() => _MemoryTextFieldState();
}

class _MemoryTextFieldState extends State<MemoryTextField> {
  List<String> _suggestions = [];
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final history = await FieldMemoryService.instance.getSuggestions(widget.fieldKey);
    if (!mounted) return;
    setState(() {
      _suggestions = [
        ...widget.presetOptions,
        ...history.where((s) => !widget.presetOptions.contains(s)),
      ];
    });
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      FieldMemoryService.instance.remember(widget.fieldKey, widget.controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return _suggestions.take(8);
        return _suggestions.where((s) => s.toLowerCase().contains(q)).take(8);
      },
      onSelected: (v) {
        widget.controller.text = v;
        widget.controller.selection = TextSelection.collapsed(offset: v.length);
        widget.onChanged?.call(v);
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: widget.decoration,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final colors = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: colors.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 240, maxWidth: 500),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
