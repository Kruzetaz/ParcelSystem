// global_search_service.dart
// ค้นหาแบบรวมศูนย์สำหรับช่อง omni search ที่ topbar — ค้นทั้งเมนู (กันหาไม่เจอ
// ตอนเลื่อน sidebar ไม่เจอ) และข้อมูลจริงข้าม 4 หน้า (จัดซื้อจัดจ้าง/TOR/สัญญา/
// ครุภัณฑ์) พร้อมกันในครั้งเดียว — เรียกทุกครั้งที่พิมพ์ (debounce ทำที่ฝั่ง UI)

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/search_result.dart';
import '../screens/app_sidebar.dart' show modeMeta;

class GlobalSearchService {
  GlobalSearchService._();

  static const _perGroupLimit = 5;

  static Future<List<SearchResultGroup>> search(
    ProcurementRepository repo,
    String query, {
    String? fiscalYear,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final lowerQ = q.toLowerCase();

    final groups = <SearchResultGroup>[];

    // เมนู — เผื่อผู้ใช้เลื่อนหา sidebar ไม่เจอ
    final menuMatches = modeMeta.entries
        .where((e) => e.value.$2.toLowerCase().contains(lowerQ))
        .take(_perGroupLimit)
        .map((e) => SearchResultItem(
              type: SearchResultType.menu,
              title: e.value.$2,
              icon: e.value.$1,
              mode: e.key,
            ))
        .toList();
    if (menuMatches.isNotEmpty) {
      groups.add(SearchResultGroup(label: 'เมนู', items: menuMatches));
    }

    // รายการจัดซื้อจัดจ้าง
    final orders = await repo.searchOrders(q, fiscalYear: fiscalYear);
    if (orders.isNotEmpty) {
      groups.add(SearchResultGroup(
        label: 'รายการจัดซื้อจัดจ้าง',
        items: orders.take(_perGroupLimit).map((o) {
          return SearchResultItem(
            type: SearchResultType.order,
            title: o.procurementSubject ?? o.projectName ?? '(ไม่มีชื่อโครงการ)',
            subtitle: [
              if (o.procurementNumber?.trim().isNotEmpty ?? false) o.procurementNumber,
              if (o.vendorName?.trim().isNotEmpty ?? false) o.vendorName,
            ].join(' · '),
            icon: SearchResultType.order.defaultIcon,
            order: o,
          );
        }).toList(),
      ));
    }

    // TOR/คุณลักษณะ
    final tors = await repo.getAllTorDocuments();
    final torMatches = tors
        .where((t) =>
            t.title.toLowerCase().contains(lowerQ) ||
            (t.documentNumber?.toLowerCase().contains(lowerQ) ?? false))
        .take(_perGroupLimit)
        .toList();
    if (torMatches.isNotEmpty) {
      groups.add(SearchResultGroup(
        label: 'TOR/คุณลักษณะ',
        items: torMatches
            .map((t) => SearchResultItem(
                  type: SearchResultType.tor,
                  title: t.title,
                  subtitle: t.documentNumber,
                  icon: SearchResultType.tor.defaultIcon,
                ))
            .toList(),
      ));
    }

    // บริหารสัญญา
    final contracts = await repo.getAllContracts();
    final contractMatches = contracts
        .where((c) =>
            (c.contractNumber?.toLowerCase().contains(lowerQ) ?? false) ||
            (c.vendorName?.toLowerCase().contains(lowerQ) ?? false))
        .take(_perGroupLimit)
        .toList();
    if (contractMatches.isNotEmpty) {
      groups.add(SearchResultGroup(
        label: 'บริหารสัญญา',
        items: contractMatches
            .map((c) => SearchResultItem(
                  type: SearchResultType.contract,
                  title: c.vendorName ?? '(ไม่ระบุคู่สัญญา)',
                  subtitle: c.contractNumber,
                  icon: SearchResultType.contract.defaultIcon,
                ))
            .toList(),
      ));
    }

    // ทะเบียนครุภัณฑ์
    final assets = await repo.getAllFixedAssets();
    final assetMatches = assets
        .where((a) =>
            a.name.toLowerCase().contains(lowerQ) ||
            (a.assetNumber?.toLowerCase().contains(lowerQ) ?? false))
        .take(_perGroupLimit)
        .toList();
    if (assetMatches.isNotEmpty) {
      groups.add(SearchResultGroup(
        label: 'ทะเบียนครุภัณฑ์',
        items: assetMatches
            .map((a) => SearchResultItem(
                  type: SearchResultType.fixedAsset,
                  title: a.name,
                  subtitle: a.assetNumber,
                  icon: SearchResultType.fixedAsset.defaultIcon,
                  fixedAssetId: a.id,
                ))
            .toList(),
      ));
    }

    return groups;
  }
}

extension on SearchResultType {
  // ไอคอนเริ่มต้นต่อประเภทผลลัพธ์ — แยกออกมาเพื่อไม่ต้องพิมพ์ import
  // material ซ้ำในทุกจุดที่สร้าง SearchResultItem
  IconData get defaultIcon {
    switch (this) {
      case SearchResultType.menu:
        return Icons.apps_outlined;
      case SearchResultType.order:
        return Icons.description_outlined;
      case SearchResultType.tor:
        return Icons.article_outlined;
      case SearchResultType.contract:
        return Icons.handshake_outlined;
      case SearchResultType.fixedAsset:
        return Icons.inventory_2_outlined;
    }
  }
}
