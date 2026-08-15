// search_field.dart
// ช่องค้นหาพื้นฐาน (แบบใช้ในการ์ดตาราง) — ตรงกับ .sbox ใน mockup
// ช่องค้นหาแบบ omnibar (.omni) ย้ายไปเป็น GlobalOmniSearch
// (global_omni_search.dart) แล้ว เพราะต้องมี state ของตัวเอง (ค้นหาแบบ live +
// ดรอปดาวน์ผลลัพธ์ข้ามหลายหน้า) ซับซ้อนกว่าที่ StatelessWidget ตัวนี้รองรับได้

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// ช่องค้นหาพื้นฐาน (.sbox ใน mockup)
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText = 'ค้นหา...',
    this.onChanged,
    this.onSubmitted,
    this.width = 290,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double width;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _internalController;

  TextEditingController get _controller => widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    // ต้อง rebuild เอง (ไม่มี framework ทำให้อัตโนมัติ) เพื่อโชว์/ซ่อนปุ่ม
    // ล้างค่า (close icon) ตรงกับ mockup ที่ปุ่มนี้โผล่มาเฉพาะตอนมีข้อความ
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onSubmitted?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    // ConstrainedBox (maxWidth) แทน Container(width:) ตรงๆ — mockup กำหนด
    // min-width:290px แต่หน้าจอ Flutter ต้องรองรับหน้าต่างที่ปรับขนาดได้จริง
    // ถ้าบังคับความกว้างคงที่แล้วพื้นที่จริงแคบกว่านั้น (เช่นตอนแผงข้างขยับ) จะ
    // เกิด RenderFlex overflow ทันที — ใช้ maxWidth ให้หดได้แทนตอนพื้นที่ไม่พอ
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.width),
      child: Container(
        height: Dimensions.chipHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(RadiusSize.lg),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          children: [
            const SizedBox(width: 11),
            Icon(
              Icons.search,
              size: IconSizes.md,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: TextStyle(
                  fontSize: AppTypography.bodyMedium,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    fontSize: AppTypography.bodyMedium,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            if (hasText)
              InkWell(
                onTap: _clear,
                borderRadius: BorderRadius.circular(RadiusSize.sm),
                child: Icon(
                  Icons.close,
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 11),
          ],
        ),
      ),
    );
  }
}
