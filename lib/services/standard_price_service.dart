// standard_price_service.dart
// ค้นหาราคากลาง/สเปกครุภัณฑ์จาก "บัญชีราคามาตรฐานครุภัณฑ์" ของสำนักงบประมาณ
// (ฉบับธันวาคม 2568) — ข้อมูลอยู่ใน assets/data/standard_asset_prices_2568.json
// แกะมาจากไฟล์ PDF ต้นฉบับด้วยสคริปต์ (ไม่ได้พิมพ์มือ) จึงอาจมีบางคำเพี้ยน
// เล็กน้อยจากปัญหาการแกะฟอนต์ไทยในไฟล์ PDF — ให้ใช้เป็น "ราคาอ้างอิงเบื้องต้น"
// เท่านั้น ต้องตรวจสอบกับไฟล์ต้นฉบับจริงก่อนใช้อ้างอิงในเอกสารราชการเสมอ

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class StandardPriceItem {
  final String category;
  final String name;
  final int price;

  const StandardPriceItem({required this.category, required this.name, required this.price});

  factory StandardPriceItem.fromJson(Map<String, dynamic> json) => StandardPriceItem(
        category: json['category'] as String,
        name: json['name'] as String,
        price: json['price'] as int,
      );
}

class StandardPriceService {
  StandardPriceService._();
  static final StandardPriceService instance = StandardPriceService._();

  List<StandardPriceItem>? _items;

  Future<List<StandardPriceItem>> _load() async {
    if (_items != null) return _items!;
    final raw = await rootBundle.loadString('assets/data/standard_asset_prices_2568.json');
    final decoded = jsonDecode(raw) as List;
    _items = decoded.map((e) => StandardPriceItem.fromJson(e as Map<String, dynamic>)).toList();
    return _items!;
  }

  /// ค้นหาแบบ substring จากชื่อรายการ (ไม่สนตัวพิมพ์เล็ก/ใหญ่) — ว่างเปล่า = คืนทั้งหมด
  Future<List<StandardPriceItem>> search(String query) async {
    final all = await _load();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  Future<List<String>> get categories async {
    final all = await _load();
    final set = all.map((i) => i.category).toSet().toList();
    set.sort();
    return set;
  }
}
