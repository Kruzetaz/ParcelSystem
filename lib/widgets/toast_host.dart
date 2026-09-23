// toast_host.dart
// วางครอบแอปทั้งหมดใน main.dart — แสดงรายการแจ้งเตือนจาก ToastController เป็น
// การ์ดลอยมุมล่างขวา ไอคอนวงกลมตามประเภท (สำเร็จ/ผิดพลาด/คำเตือน/ข้อมูล/
// กำลังทำงาน) เลื่อนเข้าจากขวา+จางเข้าตอนโผล่ขึ้นมา — แต่ละอันปิดตัวเองอัตโนมัติ
// (ยกเว้นแบบ "กำลังทำงาน" ที่ลอยค้างจนกว่าจะเรียก completeAppToast) หรือกด
// กากบาทปิดเองได้

import 'package:flutter/material.dart';
import '../services/toast_service.dart';

class ToastHost extends StatelessWidget {
  final Widget child;
  const ToastHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(
            ignoring: false,
            child: ListenableBuilder(
              listenable: ToastController.instance,
              builder: (context, _) {
                final items = ToastController.instance.items;
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in items) ...[
                      SizedBox(
                          width: 360,
                          child:
                              _ToastCard(key: ValueKey(item.id), item: item)),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

const _ToastVisual _successVisual =
    _ToastVisual(icon: Icons.check, color: Color(0xFF16A34A));
const _ToastVisual _errorVisual =
    _ToastVisual(icon: Icons.close, color: Color(0xFFDC2626));
const _ToastVisual _warningVisual =
    _ToastVisual(icon: Icons.priority_high, color: Color(0xFFD97706));
const _ToastVisual _infoVisual =
    _ToastVisual(icon: Icons.info_outline, color: Color(0xFF2563EB));
const _ToastVisual _loadingVisual =
    _ToastVisual(icon: null, color: Color(0xFF0D9488));

class _ToastVisual {
  final IconData? icon;
  final Color color;
  const _ToastVisual({required this.icon, required this.color});
}

_ToastVisual _visualFor(ToastType type) {
  switch (type) {
    case ToastType.success:
      return _successVisual;
    case ToastType.error:
      return _errorVisual;
    case ToastType.warning:
      return _warningVisual;
    case ToastType.info:
      return _infoVisual;
    case ToastType.loading:
      return _loadingVisual;
  }
}

class _ToastCard extends StatefulWidget {
  final ToastItem item;
  const _ToastCard({super.key, required this.item});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _slide = Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visual = _visualFor(item.type);
    final colors = Theme.of(context).colorScheme;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: item.removing ? 0 : 1,
          child: Material(
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            color: colors.surface,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: visual.color, shape: BoxShape.circle),
                    child: item.type == ToastType.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(visual.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text(item.message,
                            style: TextStyle(
                                fontSize: 13, color: colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => ToastController.instance.dismiss(item.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(Icons.close,
                        color: colors.onSurfaceVariant, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
