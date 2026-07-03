import "package:sqflite_common_ffi/sqflite_ffi.dart";
import '../models/procurement_form.dart';
import '../models/procurement_item.dart';
import 'database.dart';

class ProcurementRepository {
  final _db = AppDatabase.instance;

  // ─────────────────────────────────────────
  // PROCUREMENT FORMS
  // ─────────────────────────────────────────

  /// บันทึกฟอร์มใหม่
  Future<void> insertForm(ProcurementForm form) async {
    final db = await _db.database;
    await db.insert('procurement_forms', form.toMap());
  }

  /// อัปเดตฟอร์มที่มีอยู่
  Future<void> updateForm(ProcurementForm form) async {
    final db = await _db.database;
    await db.update(
      'procurement_forms',
      form.toMap(),
      where: 'procurement_number = ?',
      whereArgs: [form.procurementNumber],
    );
  }

  /// บันทึก หรือ อัปเดตอัตโนมัติ (upsert)
  Future<void> saveForm(ProcurementForm form) async {
    final db = await _db.database;
    await db.insert(
      'procurement_forms',
      form.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ดึงฟอร์มทั้งหมด (สำหรับ Dashboard)
  Future<List<ProcurementForm>> getAllForms() async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_forms',
      orderBy: 'rowid DESC', // ล่าสุดขึ้นก่อน
    );
    return rows.map(ProcurementForm.fromMap).toList();
  }

  /// ดึงฟอร์มตามเลขที่
  Future<ProcurementForm?> getForm(String procurementNumber) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_forms',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProcurementForm.fromMap(rows.first);
  }

  /// ค้นหาฟอร์มจากชื่อโปรเจกต์ หรือ เลขที่
  Future<List<ProcurementForm>> searchForms(String query) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_forms',
      where: 'procurement_number LIKE ? OR project_name LIKE ? OR vendor_name LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'rowid DESC',
    );
    return rows.map(ProcurementForm.fromMap).toList();
  }

  /// ลบฟอร์ม (items จะถูกลบอัตโนมัติจาก ON DELETE CASCADE)
  Future<void> deleteForm(String procurementNumber) async {
    final db = await _db.database;
    await db.delete(
      'procurement_forms',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
    );
  }

  // ─────────────────────────────────────────
  // PROCUREMENT ITEMS
  // ─────────────────────────────────────────

  /// เพิ่ม item เดียว
  Future<int> insertItem(ProcurementItem item) async {
    final db = await _db.database;
    return await db.insert('procurement_items', item.toMap());
  }

  /// ดึง items ทั้งหมดของฟอร์มนั้น
  Future<List<ProcurementItem>> getItems(String procurementNumber) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_items',
      where: 'procurement_number = ?',
      whereArgs: [procurementNumber],
      orderBy: 'id ASC',
    );
    return rows.map(ProcurementItem.fromMap).toList();
  }

  /// อัปเดต item
  Future<void> updateItem(ProcurementItem item) async {
    final db = await _db.database;
    await db.update(
      'procurement_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// ลบ item เดียว
  Future<void> deleteItem(int id) async {
    final db = await _db.database;
    await db.delete(
      'procurement_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ลบ items ทั้งหมดของฟอร์มนั้น แล้ว insert ใหม่ทั้งชุด
  /// ใช้ตอนกด Save ใน Tab 4
  Future<void> replaceItems(
    String procurementNumber,
    List<ProcurementItem> items,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // ลบของเก่าทั้งหมด
      await txn.delete(
        'procurement_items',
        where: 'procurement_number = ?',
        whereArgs: [procurementNumber],
      );
      // insert ใหม่ทั้งชุด
      for (final item in items) {
        await txn.insert(
          'procurement_items',
          item.copyWith(procurementNumber: procurementNumber).toMap(),
        );
      }
    });
  }

  // ─────────────────────────────────────────
  // SAVE FORM + ITEMS พร้อมกัน (ใช้ตอน Submit)
  // ─────────────────────────────────────────

  Future<void> saveFormWithItems(
    ProcurementForm form,
    List<ProcurementItem> items,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // upsert form
      await txn.insert(
        'procurement_forms',
        form.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // ลบ items เก่า แล้ว insert ใหม่
      await txn.delete(
        'procurement_items',
        where: 'procurement_number = ?',
        whereArgs: [form.procurementNumber],
      );
      for (final item in items) {
        await txn.insert(
          'procurement_items',
          item.copyWith(procurementNumber: form.procurementNumber).toMap(),
        );
      }
    });
  }
}
