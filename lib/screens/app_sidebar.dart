// app_sidebar.dart
// Sidebar widget — ย่อ/ขยายได้, highlight เมนูปัจจุบัน
// ใช้เฉพาะใน AppShell เท่านั้น (ไม่แปะซ้ำในหน้าอื่น)

import 'package:flutter/material.dart';

const _brandColor = Color(0xFF1A3A5C);
const _sidebarExpandedWidth = 200.0;
const _sidebarCollapsedWidth = 64.0;

enum AppMode { dashboard, newOrder, budgets, settings }

class AppSidebar extends StatelessWidget {
  final AppMode currentMode;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(AppMode) onSelect;

  const AppSidebar({
    super.key,
    required this.currentMode,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
      decoration: BoxDecoration(
        color: _brandColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleButton(),
          const SizedBox(height: 8),
          _buildItem(AppMode.dashboard, Icons.dashboard_outlined, 'หน้าหลัก'),
          _buildItem(AppMode.newOrder, Icons.add_circle_outline, 'สร้างใหม่'),
          _buildItem(AppMode.budgets, Icons.account_balance_wallet_outlined, 'แผนงบประมาณ'),
          const Spacer(),
          _buildItem(AppMode.settings, Icons.settings_outlined, 'ตั้งค่าโรงเรียน'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  expanded ? Icons.menu_open : Icons.menu,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'เมนูหลัก',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(AppMode mode, IconData icon, String label) {
    final isSelected = currentMode == mode;
    return Tooltip(
      message: expanded ? '' : label,
      preferBelow: false,
      child: InkWell(
        onTap: () => onSelect(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 22,
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}