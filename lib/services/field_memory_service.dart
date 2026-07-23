// field_memory_service.dart
// จดจำค่าที่เคยพิมพ์ไว้ในแต่ละช่องกรอกข้อมูล (ต่อ fieldKey) เก็บลง
// shared_preferences เพื่อให้ MemoryTextField เสนอเป็นตัวเลือก autocomplete
// ในครั้งถัดไป ไม่ต้องพิมพ์ซ้ำ

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FieldMemoryService {
  FieldMemoryService._();
  static final instance = FieldMemoryService._();

  static const _prefixKey = 'field_memory_';
  static const _maxPerField = 25;

  final Map<String, List<String>> _cache = {};

  Future<List<String>> getSuggestions(String fieldKey) async {
    if (_cache.containsKey(fieldKey)) return _cache[fieldKey]!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefixKey$fieldKey');
    final list = raw == null ? <String>[] : List<String>.from(jsonDecode(raw) as List);
    _cache[fieldKey] = list;
    return list;
  }

  Future<void> remember(String fieldKey, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final list = await getSuggestions(fieldKey);
    list.remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > _maxPerField) list.removeRange(_maxPerField, list.length);
    _cache[fieldKey] = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefixKey$fieldKey', jsonEncode(list));
  }
}
