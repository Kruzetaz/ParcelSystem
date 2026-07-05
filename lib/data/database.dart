// database.dart
// SQLite schema v3 — budgets + procurement_orders + procurement_items
//
// เปลี่ยนจาก schema เดิม (procurement_forms แบบ PK = procurement_number TEXT)
// มาเป็นโครงสร้างใหม่ตาม spec: แยกตาราง budgets (แผนงบประมาณ) ออกจาก
// procurement_orders (เอกสารจัดซื้อจัดจ้างแต่ละใบ) แบบ 1-to-many
// และแก้บั๊ก quantity เดิม โดยแยก quantity (REAL) ออกจาก unit (TEXT)
//
// [อัปเดตล่าสุด 2026]: เพิ่มฟิลด์เอกสารสำหรับตรวจรับ delivery_doc_type และ delivery_doc_number

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 5;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'procurement.db');
    await Directory(dbPath).create(recursive: true);

    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        // ต้องเปิด foreign key constraint เองใน SQLite (ปิดโดย default)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS procurement_items');
          await db.execute('DROP TABLE IF EXISTS procurement_forms');
          await db.execute('DROP TABLE IF EXISTS procurement_orders');
          await db.execute('DROP TABLE IF EXISTS budgets');
          await db.execute('DROP TABLE IF EXISTS school_settings');
          await _createSchema(db);
        }
        if (oldVersion < 4) {
          // ใช้ try/catch เผื่อ column มีอยู่แล้วจาก schema เดิม
          try {
            await db.execute(
              'ALTER TABLE procurement_orders ADD COLUMN delivery_doc_type TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE procurement_orders ADD COLUMN delivery_doc_number TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 5) {
          // เลิกใช้ market_price_check แล้ว (ย้ายไปใช้ unit_price ระดับรายการแทน)
          // ต้องใช้ SQLite >= 3.35 ถึงจะรองรับ DROP COLUMN — ถ้าเวอร์ชันเก่ากว่า
          // จะ error เงียบๆ แล้วเหลือ column ไว้เฉยๆ ไม่กระทบการทำงาน (แค่ไม่ใช้)
          try {
            await db.execute(
              'ALTER TABLE procurement_orders DROP COLUMN market_price_check',
            );
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    // ── ตารางแผนงบประมาณปฏิบัติการประจำปี (Master Budget) ──────────────
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fiscal_year TEXT NOT NULL,
        group_name TEXT,
        project_name TEXT,
        activity_name TEXT,
        egp_number TEXT,
        allocated_amount REAL,
        remaining_amount REAL,
        responsible_person TEXT
      )
    ''');

    // ── ตารางหลัก: เอกสารการจัดซื้อจัดจ้างแต่ละใบ ────────────────────
    await db.execute('''
      CREATE TABLE procurement_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER,
        fiscal_year TEXT,
        order_type TEXT CHECK(order_type IN ('ซื้อ', 'จ้าง')),

        -- เลขที่เอกสาร (คนละความหมายกัน อย่าทับกัน)
        procurement_number TEXT,   -- {{procurement_number}} เลขที่หนังสือพัสดุ/ใบสั่งซื้อ
        order_number TEXT,         -- {{order_number}} เลขที่คำสั่งแต่งตั้งกรรมการตรวจรับ

        project_name TEXT,
        activity_name TEXT,
        purpose_reason TEXT,
        purpose_objective TEXT,

        allocated_amount REAL,
        allocated_amount_th TEXT,
        used_budget REAL,
        remaining_amount REAL,

        owner_name TEXT,
        owner_position TEXT,
        finance_officer TEXT,
        spec_creator_name TEXT,
        spec_creator_position TEXT,
        procurement_officer TEXT,
        procurement_head TEXT,
        director_name TEXT,

        inspector_title_group TEXT CHECK(
          inspector_title_group IN ('ผู้ตรวจรับพัสดุ', 'คณะกรรมการตรวจรับ')
        ),
        inspector_1 TEXT, inspector_1_pos TEXT,
        inspector_2 TEXT, inspector_2_pos TEXT,
        inspector_3 TEXT, inspector_3_pos TEXT,

        vendor_name TEXT,
        vendor_owner TEXT,
        vendor_address_no TEXT,
        vendor_subdistrict TEXT,
        vendor_district TEXT,
        vendor_province TEXT,
        vendor_phone TEXT,
        vendor_tax_id TEXT,

        -- ข้อมูลเอกสารหลักฐานที่ใช้ส่งมอบเพื่อการตรวจรับ (เพิ่มใหม่ปี 2026)
        delivery_doc_type TEXT,    -- {{delivery_doc_type}} เช่น ใบส่งของ, ใบกำกับภาษี
        delivery_doc_number TEXT,  -- {{delivery_doc_number}} เลขที่ใบส่งของ/หลักฐาน

        current_order_price REAL,
        total_price_th TEXT,
        subtotal_before_vat REAL,
        vat_rate REAL DEFAULT 0.07,
        vat_amount REAL,
        withholding_tax_rate REAL DEFAULT 0.01,
        tax_withholding_amount REAL,
        net_payable_amount REAL,

        shipping_days INTEGER,
        penalty_rate REAL DEFAULT 0.20,
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
        date_disbursement TEXT,

        progress_percent REAL DEFAULT 0.0,
        current_status TEXT DEFAULT 'DRAFT' CHECK(current_status IN ('DRAFT', 'COMPLETED')),

        FOREIGN KEY (budget_id) REFERENCES budgets(id)
      )
    ''');

    // ── ตารางรายการพัสดุ (1 order มีได้หลายแถว ไม่จำกัดจำนวน) ────────
    await db.execute('''
      CREATE TABLE procurement_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        item_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES procurement_orders(id) ON DELETE CASCADE
      )
    ''');

    // ── ตารางข้อมูลโรงเรียน (มีแถวเดียวเสมอ id คงที่ = 1) ─────────────
    // เก็บข้อมูลที่ไม่เปลี่ยนบ่อย กรอกครั้งเดียวใช้ซ้ำได้ทุกเอกสาร
    await db.execute('''
      CREATE TABLE school_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        school_name TEXT,
        school_address_no TEXT,
        school_subdistrict TEXT,
        school_amphoe TEXT,
        school_changwat TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_orders_budget_id ON procurement_orders(budget_id)',
    );
    await db.execute(
      'CREATE INDEX idx_items_order_id ON procurement_items(order_id)',
    );
  }
}