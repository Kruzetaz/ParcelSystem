// search_result.dart
// โครงสร้างผลลัพธ์ของช่องค้นหา omni ที่ topbar — ใช้ร่วมกันระหว่าง
// GlobalSearchService (หาผลลัพธ์) และ AppShell (ตัดสินใจว่ากดแล้วพาไปไหน)

import 'package:flutter/material.dart';
import '../models/procurement_order.dart';
import '../screens/app_sidebar.dart' show AppMode;

enum SearchResultType { menu, order, tor, contract, fixedAsset }

class SearchResultItem {
  final SearchResultType type;
  final String title;
  final String? subtitle;
  final IconData icon;
  // payload — มีค่าเฉพาะบาง type ตามที่ต้องใช้ตอนกดเลือก
  final AppMode? mode; // menu
  final ProcurementOrder? order; // order
  final int? fixedAssetId; // fixedAsset

  const SearchResultItem({
    required this.type,
    required this.title,
    this.subtitle,
    required this.icon,
    this.mode,
    this.order,
    this.fixedAssetId,
  });
}

class SearchResultGroup {
  final String label;
  final List<SearchResultItem> items;
  const SearchResultGroup({required this.label, required this.items});
}
