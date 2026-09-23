// budget_spending.dart
// ผลรวมยอดใช้จ่ายจริงต่อแผนงบ 1 ใบ — view model ล้วนๆ ไม่ใช่ตารางแยก
// ("ยอดใช้จริง" คิดจากออร์เดอร์ที่ผูกกับแผนงบนี้และมีสถานะ "เสร็จสมบูรณ์"
// เท่านั้น ตามตรรกะเดียวกับที่ budget_list_screen.dart/dashboard ใช้อยู่แล้ว)

import 'budget.dart';
import 'procurement_order.dart';

class BudgetSpending {
  final Budget budget;
  final double spentAmount;
  final List<ProcurementOrder> orders;

  const BudgetSpending({
    required this.budget,
    required this.spentAmount,
    required this.orders,
  });

  int get orderCount => orders.length;

  /// คงเหลือจริง = วงเงินที่ได้รับจัดสรร − ยอดที่ใช้ไปแล้ว — ไม่ clamp ทิ้ง
  /// เพราะติดลบหมายถึงใช้เกินงบจริง เป็นสัญญาณที่อยากให้เห็นชัด
  double get remainingAmount => (budget.allocatedAmount ?? 0) - spentAmount;
}
