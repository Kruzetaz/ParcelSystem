import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/budget.dart';
import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/school_settings.dart';
import 'database.dart';

class ProcurementRepository {
  final _db = AppDatabase.instance;

  // ─────────────────────────────────────────
  // BUDGETS (แผนงบประมาณ)
  // ─────────────────────────────────────────

  Future<int> insertBudget(Budget budget) async {
    final db = await _db.database;
    return db.insert('budgets', budget.toMap());
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await _db.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<List<Budget>> getAllBudgets({String? fiscalYear}) async {
    final db = await _db.database;
    final rows = await db.query(
      'budgets',
      where: fiscalYear != null ? 'fiscal_year = ?' : null,
      whereArgs: fiscalYear != null ? [fiscalYear] : null,
      orderBy: 'id DESC',
    );
    return rows.map(Budget.fromMap).toList();
  }

  Future<Budget?> getBudget(int id) async {
    final db = await _db.database;
    final rows = await db.query('budgets', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  Future<void> deleteBudget(int id) async {
    final db = await _db.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // PROCUREMENT ORDERS
  // ─────────────────────────────────────────

  /// บันทึกออร์เดอร์ใหม่ คืนค่า id ที่ SQLite generate ให้ (ใช้ผูก items ต่อ)
  Future<int> insertOrder(ProcurementOrder order) async {
    final db = await _db.database;
    return db.insert('procurement_orders', order.toMap());
  }

  Future<void> updateOrder(ProcurementOrder order) async {
    final db = await _db.database;
    await db.update(
      'procurement_orders',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  /// ดึงออร์เดอร์ทั้งหมด (สำหรับ Dashboard) เรียงล่าสุดขึ้นก่อน
  Future<List<ProcurementOrder>> getAllOrders() async {
    final db = await _db.database;
    final rows = await db.query('procurement_orders', orderBy: 'id DESC');
    return rows.map(ProcurementOrder.fromMap).toList();
  }

  Future<ProcurementOrder?> getOrder(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProcurementOrder.fromMap(rows.first);
  }

  /// ค้นหาออร์เดอร์จากเลขที่/ชื่อโครงการ/ชื่อร้านค้า
  Future<List<ProcurementOrder>> searchOrders(String query) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_orders',
      where:
          'procurement_number LIKE ? OR order_number LIKE ? OR project_name LIKE ? OR vendor_name LIKE ?',
      whereArgs: List.filled(4, '%$query%'),
      orderBy: 'id DESC',
    );
    return rows.map(ProcurementOrder.fromMap).toList();
  }

  /// ลบออร์เดอร์ (items จะถูกลบอัตโนมัติจาก ON DELETE CASCADE)
  Future<void> deleteOrder(int id) async {
    final db = await _db.database;
    await db.delete('procurement_orders', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // PROCUREMENT ITEMS
  // ─────────────────────────────────────────

  Future<int> insertItem(ProcurementItem item) async {
    final db = await _db.database;
    return db.insert('procurement_items', item.toMap());
  }

  Future<List<ProcurementItem>> getItems(int orderId) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
    return rows.map(ProcurementItem.fromMap).toList();
  }

  Future<void> updateItem(ProcurementItem item) async {
    final db = await _db.database;
    await db.update(
      'procurement_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await _db.database;
    await db.delete('procurement_items', where: 'id = ?', whereArgs: [id]);
  }

  /// ลบ items ทั้งหมดของออร์เดอร์นั้น แล้ว insert ใหม่ทั้งชุด (ใช้ตอนกด Save ใน Tab 4)
  Future<void> replaceItems(int orderId, List<ProcurementItem> items) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('procurement_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        await txn.insert('procurement_items', item.copyWith(orderId: orderId).toMap());
      }
    });
  }

  // ─────────────────────────────────────────
  // SAVE ORDER + ITEMS พร้อมกัน (ใช้ตอน Submit ท้าย Wizard)
  // คืนค่า id ของ order (ทั้ง insert ใหม่ หรือ update ของเดิม)
  // ─────────────────────────────────────────

  Future<int> saveOrderWithItems(
    ProcurementOrder order,
    List<ProcurementItem> items,
  ) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      late final int orderId;

      if (order.id != null) {
        // update ของเดิม
        await txn.update(
          'procurement_orders',
          order.toMap(),
          where: 'id = ?',
          whereArgs: [order.id],
        );
        orderId = order.id!;
      } else {
        // insert ใหม่
        orderId = await txn.insert('procurement_orders', order.toMap());
      }

      await txn.delete('procurement_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        await txn.insert(
          'procurement_items',
          item.copyWith(orderId: orderId).toMap(),
        );
      }

      return orderId;
    });
  }

  // ─────────────────────────────────────────
  // SCHOOL SETTINGS (ข้อมูลโรงเรียน — มีแถวเดียวเสมอ)
  // ─────────────────────────────────────────

  /// ดึงข้อมูลโรงเรียน คืนค่า null ถ้ายังไม่เคยกรอก (ยังไม่มีแถวในตาราง)
  Future<SchoolSettings?> getSchoolSettings() async {
    final db = await _db.database;
    final rows = await db.query('school_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return SchoolSettings.fromMap(rows.first);
  }

  /// บันทึกข้อมูลโรงเรียน — insert ถ้ายังไม่มีแถว, update ถ้ามีอยู่แล้ว (upsert)
  Future<void> saveSchoolSettings(SchoolSettings settings) async {
    final db = await _db.database;
    await db.insert(
      'school_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}