import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final Directory appDir = await getApplicationSSupportDirectory();
    final String dbPath = p.join(appDir.path, 'procurement.db');

    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE procurement_forms (
        procurement_number TEXT PRIMARY KEY,
        school_name TEXT,
        school_address_no TEXT,
        school_subdistrict TEXT,
        school_amphoe TEXT,
        school_changwat TEXT,
        project_name TEXT,
        activity_name TEXT,
        allocated_amount REAL,
        used_budget REAL,
        remaining_amount REAL,
        purpose_reason TEXT,
        purpose_objective TEXT,
        owner_name TEXT,
        owner_position TEXT,
        finance_officer TEXT,
        spec_creator_name TEXT,
        procurement_officer TEXT,
        procurement_head TEXT,
        director_name TEXT,
        inspector_title_group TEXT,
        inspector_1 TEXT,
        inspector_1_pos TEXT,
        inspector_2 TEXT,
        inspector_2_pos TEXT,
        inspector_3 TEXT,
        inspector_3_pos TEXT,
        vendor_name TEXT,
        vendor_owner TEXT,
        vendor_address_no TEXT,
        vendor_subdistrict TEXT,
        vendor_district TEXT,
        vendor_province TEXT,
        vendor_phone TEXT,
        vendor_tax_id TEXT,
        current_order_price REAL,
        total_price_th TEXT,
        subtotal_before_vat REAL,
        vat_amount REAL,
        tax_withholding_amount REAL,
        net_payable_amount REAL,
        shipping_days INTEGER,
        penalty_rate REAL,
        warranty_period TEXT,
        egp_project_id TEXT,
        contract_control_number TEXT,
        inspection_control_number TEXT,
        date_memo_used TEXT,
        date_order_created TEXT,
        date_announcement TEXT,
        date_quotation TEXT,
        date_contract_signed TEXT,
        date_deadline TEXT,
        date_shipping TEXT,
        date_inspection TEXT,
        date_disbursement TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE procurement_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        procurement_number TEXT NOT NULL,
        item_name TEXT,
        quantity TEXT,
        unit_price REAL,
        total_price REAL,
        FOREIGN KEY (procurement_number)
          REFERENCES procurement_forms (procurement_number)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
