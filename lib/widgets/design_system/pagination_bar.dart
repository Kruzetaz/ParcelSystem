// pagination_bar.dart
// แถบเลือกจำนวนต่อหน้า + เลขหน้า — ตรงกับ .tft/.ppsel/.pg ใน mockup

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'glass_container.dart';

class PaginationBar extends StatefulWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.totalItems,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final int currentPage; // 1-based
  final int totalPages;
  final int pageSize;
  final List<int> pageSizeOptions;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  // ค่าพิเศษแทนตัวเลือก "กำหนดเอง" ใน dropdown — ไม่ใช่จำนวนต่อหน้าจริง
  // (ไม่มีจำนวนต่อหน้าที่เป็นลบได้อยู่แล้ว ใช้ปลอดภัย ไม่ชนค่าที่ผู้ใช้กรอกเอง)
  static const _customSentinel = -1;

  // เลือก "กำหนดเอง" แล้วโชว์ช่องกรอกเพิ่มขึ้นมาทางซ้ายของ dropdown (ไม่ได้
  // แทนที่ dropdown เหมือนรอบก่อน — dropdown ยังอยู่ให้กดสลับกลับไปตัวเลือก
  // อื่นได้เสมอ) เลือกตัวเลือกอื่นที่ไม่ใช่ "กำหนดเอง" เมื่อไหร่ก็ซ่อนช่องนี้ทันที
  bool _customSelected = false;
  late final TextEditingController _customController =
      TextEditingController(text: '${widget.pageSize}');
  final _customFocusNode = FocusNode();

  @override
  void didUpdateWidget(covariant PaginationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ถ้าค่าปัจจุบันกลายเป็นค่ามาตรฐาน (เช่น โดนเปลี่ยนจากที่อื่น) ซ่อนช่อง
    // กรอกเองทิ้งไปด้วย ไม่ให้ค้างโชว์ทั้งที่ไม่ได้อยู่ในโหมดกำหนดเองแล้ว
    if (_customSelected && widget.pageSizeOptions.contains(widget.pageSize)) {
      _customSelected = false;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocusNode.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final n = int.tryParse(_customController.text.trim());
    if (n != null && n > 0) widget.onPageSizeChanged(n);
  }

  /// เลขหน้าที่จะแสดงเป็นปุ่ม — จำกัดไว้แค่ 5 ปุ่มเสมอ (ไม่ใช่แสดงทุกหน้าแล้ว
  /// ให้เลื่อนแนวนอนเอาเหมือนเดิม) โดยเลื่อนหน้าต่างตามหน้าปัจจุบันให้อยู่
  /// กึ่งกลางเท่าที่ทำได้ ตรงกับตัวอย่างใน mockup ที่โชว์แค่ "1 2 3 4 5"
  List<int> _visiblePages() {
    const maxButtons = 5;
    if (widget.totalPages <= maxButtons) {
      return List.generate(widget.totalPages, (i) => i + 1);
    }
    var start = widget.currentPage - (maxButtons ~/ 2);
    var end = start + maxButtons - 1;
    if (start < 1) {
      end += (1 - start);
      start = 1;
    }
    if (end > widget.totalPages) {
      start -= (end - widget.totalPages);
      end = widget.totalPages;
    }
    start = start < 1 ? 1 : start;
    return List.generate(end - start + 1, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final start = widget.totalItems == 0 ? 0 : (widget.currentPage - 1) * widget.pageSize + 1;
    final end = widget.totalItems == 0 ? 0 : ((widget.currentPage * widget.pageSize).clamp(0, widget.totalItems));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      // Wrap แทน Row+Spacer — Spacer ใช้ไม่ได้ใน Wrap แต่ก็เพราะ Spacer เองคือ
      // ต้นเหตุ overflow เดิม (มันไม่ยอมหด ทำให้กลุ่มขวาถูกดันจนล้นตอนหน้าต่าง
      // แคบ) จัดกลุ่มซ้าย/ขวาแยกกัน ถ้าที่ไม่พอฝั่งขวาจะตกลงบรรทัดล่างแทน
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            // ตรงกับ mockup (#pg-info): "แสดง {start}–{end} จาก {total} รายการ"
            'แสดง $start–$end จาก ${widget.totalItems} รายการ',
            style: TextStyle(
              fontSize: AppTypography.bodySmall,
              fontWeight: AppTypography.weightSemiBold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'แสดง',
                style: TextStyle(
                  fontSize: AppTypography.bodySmall,
                  fontWeight: AppTypography.weightSemiBold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_customSelected)
                SizedBox(
                  width: 70,
                  height: 32,
                  child: TextField(
                    controller: _customController,
                    focusNode: _customFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: AppTypography.bodySmall, color: colorScheme.onSurface),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      hintText: 'จำนวน',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.lg),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusSize.lg),
                        borderSide: BorderSide(color: BrandAccent.teal(context)),
                      ),
                    ),
                    onSubmitted: (_) => _submitCustom(),
                    onTapOutside: (_) => _submitCustom(),
                  ),
                ),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(RadiusSize.lg),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: widget.pageSizeOptions.contains(widget.pageSize) ? widget.pageSize : _customSentinel,
                    isDense: true,
                    icon: Icon(Icons.expand_more, size: 16, color: colorScheme.onSurfaceVariant),
                    borderRadius: BorderRadius.circular(RadiusSize.card),
                    elevation: 6,
                    style: TextStyle(fontSize: AppTypography.bodySmall, color: colorScheme.onSurface),
                    items: [
                      for (final n in widget.pageSizeOptions) DropdownMenuItem(value: n, child: Text('$n / หน้า')),
                      const DropdownMenuItem(value: _customSentinel, child: Text('กำหนดเอง')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      if (v == _customSentinel) {
                        _customController.text = '${widget.pageSize}';
                        setState(() => _customSelected = true);
                        return;
                      }
                      setState(() => _customSelected = false);
                      widget.onPageSizeChanged(v);
                    },
                  ),
                ),
              ),
              // กลุ่มปุ่มเลื่อน+เลขหน้า อยู่ใน Row เดียวกันแน่นๆ (ไม่ใช้ spacing
              // ของ Wrap หลักที่เผื่อระยะห่างไว้กว้างสำหรับกลุ่มอื่น) พร้อมจำกัด
              // ปุ่มเลขหน้าไว้แค่ 5 ปุ่มเสมอ — ของเดิมใช้ SizedBox(180)+เลื่อน
              // แนวนอนซึ่งกว้างเกินจำนวนปุ่มจริงตอนมีน้อยหน้า ทำให้ดูมีช่องว่าง
              // แปลกๆ ระหว่างปุ่มเลื่อนซ้ายกับปุ่มเลขหน้าแรก
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chevronButton(
                    context,
                    icon: Icons.chevron_left,
                    onTap: widget.currentPage > 1 ? () => widget.onPageChanged(widget.currentPage - 1) : null,
                  ),
                  for (final p in _visiblePages())
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _pageButton(context, p, p == widget.currentPage),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _chevronButton(
                      context,
                      icon: Icons.chevron_right,
                      onTap: widget.currentPage < widget.totalPages
                          ? () => widget.onPageChanged(widget.currentPage + 1)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chevronButton(BuildContext context, {required IconData icon, required VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    // SizedBox(30x30) บังคับขนาดตรงๆ ตรงนี้ — ของเดิมพึ่งแค่
    // Container(constraints: BoxConstraints(minWidth:30)) ข้างในเฉยๆ ซึ่งมี
    // แค่ minWidth ไม่มี maxWidth กำกับ พอไปอยู่เป็นลูกโดดๆ ของ Wrap (ไม่ได้
    // แชร์บรรทัดกับตัวอื่นเหมือนปุ่มเลขหน้าที่อยู่ใน Row แคบๆ อีกที) มันเลย
    // ยืดเต็มความกว้างที่ Wrap มีให้แทนที่จะหดตามเนื้อหาไอคอนจริงๆ
    return SizedBox(
      width: 30,
      height: 30,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusSize.lg),
        child: GlassContainer(
          color: colorScheme.surface.withValues(alpha: 0.7),
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(RadiusSize.lg),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: disabled ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35) : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageButton(BuildContext context, int page, bool isActive) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = Text(
      '$page',
      style: TextStyle(
        fontSize: AppTypography.bodySmall,
        fontWeight: AppTypography.weightBold,
        color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
      ),
    );
    // เลขหน้ามีจำนวนจำกัด (ไม่กี่ปุ่ม) — ใส่กระจกฝ้าได้โดยไม่กระทบประสิทธิภาพ
    // ยกเว้นปุ่ม active ที่พื้นทึบอยู่แล้ว ไม่ต้องเบลอ
    return InkWell(
      onTap: () => widget.onPageChanged(page),
      borderRadius: BorderRadius.circular(RadiusSize.lg),
      child: isActive
          ? Container(
              constraints: const BoxConstraints(minWidth: 30),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandAccent.teal(context),
                border: Border.all(color: BrandAccent.teal(context)),
                borderRadius: BorderRadius.circular(RadiusSize.lg),
              ),
              child: label,
            )
          : GlassContainer(
              color: colorScheme.surface.withValues(alpha: 0.7),
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(RadiusSize.lg),
              child: Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: label,
              ),
            ),
    );
  }
}
