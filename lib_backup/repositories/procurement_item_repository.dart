import '../core/database/database_helper.dart';
import '../models/procurement_item.dart';

class ProcurementItemRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(ProcurementItem item) async {
    final db = await _dbHelper.database;
    return await db.insert('procurement_items', item.toMap());
  }

  Future<void> insertBatch(List<ProcurementItem> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('procurement_items', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<ProcurementItem>> getByProcurementNumber(String procurementNumber) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'procurement_items',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
      orderBy: 'id ASC',
    );
    return result.map((e) => ProcurementItem.fromMap(e)).toList();
  }

  Future<void> deleteAllForForm(String procurementNumber) async {
    final db = await _dbHelper.database;
    await db.delete(
      'procurement_items',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
    );
  }

  /// ใช้ตอน save ฟอร์ม: ลบของเก่าทั้งหมดแล้วใส่ใหม่ทั้งชุด (ปลอดภัยกับ dynamic add/remove rows)
  Future<void> replaceAllForForm(String procurementNumber, List<ProcurementItem> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'procurement_items',
        where: 'procurement_number = ?',
        whereArgs: [procurementNumber],
      );
      final batch = txn.batch();
      for (final item in items) {
        batch.insert('procurement_items', item.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}