import '../core/database/database_helper.dart';
import '../models/procurement_form.dart';

class ProcurementFormRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> insert(ProcurementForm form) async {
    final db = await _dbHelper.database;
    await db.insert('procurement_forms', form.toMap());
  }

  Future<void> update(ProcurementForm form) async {
    final db = await _dbHelper.database;
    await db.update(
      'procurement_forms',
      form.toMap(),
      where: 'procurement_number = ?',
      whereArgs: [form.procurementNumber],
    );
  }

  Future<void> upsert(ProcurementForm form) async {
    final db = await _dbHelper.database;
    await db.insert(
      'procurement_forms',
      form.toMap(),
      conflictAlgorithm: null, // ใช้ REPLACE ด้านล่างแทนเพื่อความชัดเจน
    );
  }

  Future<ProcurementForm?> getByNumber(String procurementNumber) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'procurement_forms',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
    );
    if (result.isEmpty) return null;
    return ProcurementForm.fromMap(result.first);
  }

  Future<List<ProcurementForm>> getAll({String? searchQuery}) async {
    final db = await _dbHelper.database;
    final result = (searchQuery == null || searchQuery.isEmpty)
        ? await db.query('procurement_forms', orderBy: 'procurement_number DESC')
        : await db.query(
            'procurement_forms',
            where: 'project_name LIKE ? OR vendor_name LIKE ? OR procurement_number LIKE ?',
            whereArgs: ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%'],
            orderBy: 'procurement_number DESC',
          );
    return result.map((e) => ProcurementForm.fromMap(e)).toList();
  }

  Future<void> delete(String procurementNumber) async {
    final db = await _dbHelper.database;
    await db.delete(
      'procurement_forms',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
    );
  }
}