// money_format.dart
// ฟอร์แมตตัวเลขจำนวนเงินให้สมบูรณ์ทุกที่ในแอป — มีจุลภาคคั่นหลักพัน + ทศนิยม 2
// ตำแหน่งเสมอ เช่น 70000 -> "70,000.00" ใช้แทน .toStringAsFixed(2) เปล่าๆ
// ทุกจุดที่แสดงผลจำนวนเงินให้ผู้ใช้ดู (ไม่ใช้กับช่องกรอกตัวเลขที่ยังแก้ไขอยู่
// เพราะจุลภาคจะรบกวนตอนพิมพ์/แปลงกลับเป็นตัวเลข)

import 'package:intl/intl.dart';

final NumberFormat _bahtFormat = NumberFormat('#,##0.00', 'en_US');

String formatBaht(num? value) => _bahtFormat.format(value ?? 0);
