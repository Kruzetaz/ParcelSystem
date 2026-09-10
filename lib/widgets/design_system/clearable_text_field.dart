// clearable_text_field.dart
// แทนที่ TextField/TextFormField ตรงๆ ได้เลย (รับพารามิเตอร์ชุดเดียวกัน) —
// เพิ่มปุ่ม (x) ท้ายช่องแบบวงกลมพื้นเทาจางๆ ให้อัตโนมัติทุกช่องทั้งแอป โผล่
// เฉพาะตอนเอาเมาส์ไปชี้ที่ช่อง "และ" ช่องมีข้อความอยู่แล้วเท่านั้น — ช่อง
// readOnly (เช่นวันที่แบบแตะเลือก/ค่าที่คำนวณอัตโนมัติ) จะไม่มีปุ่มนี้เลย
// เพราะผู้ใช้ไม่ได้พิมพ์เอง ไม่ควรมีทางลบข้อความทิ้งจากตรงนี้

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hover_clear_button.dart';

class ClearableTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;

  const ClearableTextField({
    super.key,
    this.controller,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.focusNode,
    this.onTap,
    this.validator,
    this.autovalidateMode,
    this.inputFormatters,
    this.initialValue,
  });

  @override
  State<ClearableTextField> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<ClearableTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant ClearableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      (widget.controller ?? _controller).addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _clear() {
    final ctrl = widget.controller ?? _controller;
    ctrl.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller ?? _controller;
    if (widget.readOnly) {
      // ช่อง readonly (วันที่แบบแตะเลือก, ค่าที่คำนวณอัตโนมัติ) ไม่มีปุ่มล้าง
      return TextFormField(
        controller: ctrl,
        decoration: widget.decoration,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        enabled: widget.enabled,
        readOnly: true,
        obscureText: widget.obscureText,
        autofocus: widget.autofocus,
        textAlign: widget.textAlign,
        style: widget.style,
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        inputFormatters: widget.inputFormatters,
      );
    }
    return HoverBuilder(
      builder: (context, hovering) => TextFormField(
        controller: ctrl,
        decoration: (widget.decoration ?? const InputDecoration()).copyWith(
          suffixIcon: hovering && ctrl.text.isNotEmpty ? clearIconButton(context, _clear) : (widget.decoration?.suffixIcon),
        ),
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        autofocus: widget.autofocus,
        textAlign: widget.textAlign,
        style: widget.style,
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        inputFormatters: widget.inputFormatters,
      ),
    );
  }
}
