// global_omni_search.dart
// ช่องค้นหา omni ที่ topbar แบบ live — พิมพ์แล้วเห็นผลทันที (debounce) ไม่ต้อง
// กด Enter, มีดรอปดาวน์ผลลัพธ์แยกกลุ่ม (เมนู/จัดซื้อจัดจ้าง/TOR/สัญญา/ครุภัณฑ์)
// กดเลือกแล้วพาไปหน้าที่เกี่ยวข้องได้ทันที — แทนที่ OmniSearchBar เดิมที่แค่
// พิมพ์เก็บไว้เฉยๆ รอกด Enter แล้วส่งค่าไปกรองตารางหน้าหลักเท่านั้น

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/search_result.dart';
import '../../theme/design_tokens.dart';
import 'glass_container.dart';

class GlobalOmniSearch extends StatefulWidget {
  const GlobalOmniSearch({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.onSelect,
    this.hintText = 'ค้นหาเลขที่ / ชื่อโครงการ / ชื่อกิจกรรม / ชื่อร้านค้า / เมนู',
    this.shortcutLabel = 'Ctrl K',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<List<SearchResultGroup>> Function(String query) onSearch;
  final void Function(SearchResultItem item) onSelect;
  final String hintText;
  final String shortcutLabel;

  @override
  State<GlobalOmniSearch> createState() => _GlobalOmniSearchState();
}

class _GlobalOmniSearchState extends State<GlobalOmniSearch> {
  final _layerLink = LayerLink();
  final _tapRegionGroupId = Object();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<SearchResultGroup> _groups = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      if (widget.controller.text.trim().isNotEmpty) _showOverlay();
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _groups = [];
        _loading = false;
      });
      _updateOverlay();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _showOverlay();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await widget.onSearch(query);
        if (!mounted) return;
        setState(() {
          _groups = results;
          _loading = false;
        });
      } catch (e) {
        // กันสถานะหมุนค้างตลอดไปถ้าค้นหาแล้ว error — โชว์ข้อความ error แทนที่
        // จะปล่อยให้ผู้ใช้เห็นแค่วงหมุนไม่จบไม่สิ้นโดยไม่รู้สาเหตุ
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
      _updateOverlay();
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(builder: _buildOverlayContent);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectItem(SearchResultItem item) {
    widget.controller.clear();
    setState(() => _groups = []);
    _removeOverlay();
    widget.focusNode.unfocus();
    widget.onSelect(item);
  }

  Widget _buildOverlayContent(BuildContext context) {
    final hasQuery = widget.controller.text.trim().isNotEmpty;
    if (!hasQuery) return const SizedBox.shrink();

    return Positioned(
      width: 420,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 44),
        child: TapRegion(
          groupId: _tapRegionGroupId,
          onTapOutside: (_) {
            widget.focusNode.unfocus();
            _removeOverlay();
          },
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(RadiusSize.card),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'ค้นหาไม่สำเร็จ: $_error',
                            style: TextStyle(fontSize: AppTypography.bodySmall, color: BrandAccent.red(context)),
                          ),
                        )
                      : _groups.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'ไม่พบผลลัพธ์',
                            style: TextStyle(fontSize: AppTypography.bodySmall, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            for (final group in _groups) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                                child: Text(
                                  group.label,
                                  style: TextStyle(
                                    fontSize: AppTypography.mini,
                                    fontWeight: AppTypography.weightBold,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              for (final item in group.items)
                                InkWell(
                                  onTap: () => _selectItem(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(item.icon, size: 16, color: BrandAccent.teal(context)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: AppTypography.bodySmall,
                                                  fontWeight: AppTypography.weightSemiBold,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                              if (item.subtitle != null && item.subtitle!.trim().isNotEmpty)
                                                Text(
                                                  item.subtitle!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: AppTypography.tiny,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          height: Dimensions.buttonHeightLg,
          child: TapRegion(
            groupId: _tapRegionGroupId,
            child: GlassContainer(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(RadiusSize.xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Row(
      children: [
        const SizedBox(width: 12),
        Icon(Icons.search, size: IconSizes.md, color: Colors.white.withValues(alpha: 0.75)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        if (widget.controller.text.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              widget.shortcutLabel,
              style: TextStyle(
                fontSize: AppTypography.micro,
                fontWeight: AppTypography.weightSemiBold,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          )
        else
          InkWell(
            onTap: () {
              widget.controller.clear();
              setState(() => _groups = []);
              _updateOverlay();
            },
            child: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.7)),
          ),
        const SizedBox(width: 12),
      ],
    );
  }
}
