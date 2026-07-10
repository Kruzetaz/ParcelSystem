// toast_host.dart
// วางครอบแอปทั้งหมดใน main.dart — แสดงรายการแจ้งเตือนจาก ToastController
// ซ้อนกันเป็นตั้งที่มุมล่าง แต่ละอันปิดตัวเองอัตโนมัติ หรือกดกากบาทปิดเองได้

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
          left: 16,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items) ...[
                      _ToastCard(item: item),
                      const SizedBox(height: 8),
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

class _ToastCard extends StatelessWidget {
  final ToastItem item;
  const _ToastCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: item.removing ? 0 : 1,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        color: item.isError ? Colors.redAccent : Colors.green.shade700,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => ToastController.instance.dismiss(item.id),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
