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
import '../models/budget.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 30;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// reset _db = null เพื่อให้ getter เปิด connection ใหม่ครั้งถัดไป
  /// เรียกหลัง db.close() เสมอ (ใช้ใน BackupService)
  void resetDatabase() {
    _db = null;
  }

  /// ปิด connection และ reset ให้ getter เปิดใหม่อัตโนมัติตอน query ครั้งถัดไป
  /// ใช้ตอน backup/restore เพื่อปลด lock บน .db file
  Future<void> closeAndReset() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
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
        if (oldVersion < 6) {
          // เพิ่มหัวเรื่องเอกสาร "ซ." — {{procurement_subject}} คนละความหมายกับ
          // project_name (ชื่อโครงการเต็มในระบบ e-GP) เป็นข้อความสั้นสำหรับขึ้นหัว
          // เอกสารโดยเฉพาะ เช่น "จัดซื้อวัสดุแข่งขันทักษะทางวิชาการระดับเครือข่าย..."
          try {
            await db.execute(
              'ALTER TABLE procurement_orders ADD COLUMN procurement_subject TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 7) {
          // เพิ่มเบอร์โทรโรงเรียน — {{school_phone}}
          try {
            await db.execute(
              'ALTER TABLE school_settings ADD COLUMN school_phone TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 8) {
          // ย้ายผู้บริหาร/เจ้าหน้าที่พัสดุ/การเงิน มาเป็นค่าประจำโรงเรียน
          // (ไม่เปลี่ยนบ่อยเหมือนชื่อ/ที่อยู่โรงเรียน) กรอกครั้งเดียวใช้ซ้ำ
          // ทุกเอกสาร แทนที่จะกรอกซ้ำทุกใบใน Tab 2 ของ wizard
          for (final col in [
            'director_name',
            'procurement_officer',
            'procurement_head',
            'finance_officer',
          ]) {
            try {
              await db.execute(
                'ALTER TABLE school_settings ADD COLUMN $col TEXT',
              );
            } catch (_) {}
          }
        }
        if (oldVersion < 9) {
          // เพิ่มตาราง TOR / ข้อมูลคุณลักษณะเฉพาะ (blueprint หน้าที่ 4)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tor_documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              document_number TEXT,
              title TEXT NOT NULL,
              category TEXT CHECK(category IN ('ครุภัณฑ์', 'วัสดุ', 'จ้าง')),
              estimated_amount REAL,
              created_date TEXT,
              status TEXT CHECK(status IN ('ร่าง', 'อนุมัติ')) DEFAULT 'ร่าง',
              specification_text TEXT
            )
          ''');
        }
        if (oldVersion < 10) {
          // คลัง TOR Template — เก็บสเปกที่ใช้ซ้ำบ่อย (เช่นสเปกมาตรฐาน สพฐ.)
          // ไว้ดึงมาใช้ตอนสร้าง TOR ใหม่ แทนการพิมพ์ซ้ำทุกครั้ง
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tor_templates (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              category TEXT CHECK(category IN ('ครุภัณฑ์', 'วัสดุ', 'จ้าง')),
              specification_text TEXT
            )
          ''');
        }
        if (oldVersion < 11) {
          // บริหารสัญญา/ใบสั่งซื้อ/สั่งจ้าง (blueprint หน้าที่ 5)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS contracts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              contract_number TEXT,
              egp_number TEXT,
              order_id INTEGER,
              contract_type TEXT CHECK(contract_type IN ('สัญญาซื้อขาย', 'สัญญาจ้าง', 'ใบสั่งซื้อ', 'ใบสั่งจ้าง')),
              contract_amount REAL,
              vendor_name TEXT,
              start_date TEXT,
              end_date TEXT,
              installment_count INTEGER,
              status TEXT CHECK(status IN ('กำลังดำเนินการ', 'ครบกำหนดแล้ว', 'ยกเลิก')) DEFAULT 'กำลังดำเนินการ',
              FOREIGN KEY (order_id) REFERENCES procurement_orders(id)
            )
          ''');
        }
        if (oldVersion < 12) {
          // ทะเบียนหลักประกัน (blueprint หน้าที่ 6)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS guarantees (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              guarantee_type TEXT CHECK(guarantee_type IN ('หลักประกันซอง', 'หลักประกันสัญญา', 'เงินสด', 'หนังสือค้ำประกันธนาคาร')),
              counterparty_name TEXT,
              amount REAL,
              start_date TEXT,
              expiry_date TEXT,
              contract_id INTEGER,
              status TEXT CHECK(status IN ('ถืออยู่', 'คืนแล้ว')) DEFAULT 'ถืออยู่',
              returned_date TEXT,
              FOREIGN KEY (contract_id) REFERENCES contracts(id)
            )
          ''');
        }
        if (oldVersion < 13) {
          // ตรวจรับพัสดุ (blueprint หน้าที่ 7) — ผูกกับ procurement_orders
          // เพื่อดึงชื่อผู้ส่งมอบ (vendor_name) และวงเงิน/อัตราค่าปรับมาใช้คำนวณ
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inspections (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              inspection_number TEXT,
              order_id INTEGER,
              due_date TEXT,
              actual_delivery_date TEXT,
              result TEXT CHECK(result IN ('ผ่าน', 'ไม่ผ่าน')),
              penalty_amount REAL,
              notes TEXT,
              FOREIGN KEY (order_id) REFERENCES procurement_orders(id)
            )
          ''');
        }
        if (oldVersion < 14) {
          // ทะเบียนครุภัณฑ์ (blueprint หน้าที่ 8) + ประวัติซ่อมแซม/โอนย้าย
          // photo_path เก็บ path ไฟล์ในเครื่อง (local storage) ตามที่ตกลงกันไว้
          // — ไม่อัปโหลดขึ้น cloud
          await db.execute('''
            CREATE TABLE IF NOT EXISTS fixed_assets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              asset_number TEXT,
              name TEXT NOT NULL,
              quantity REAL DEFAULT 1,
              unit_price REAL,
              location TEXT,
              acquired_date TEXT,
              photo_path TEXT,
              status TEXT CHECK(status IN ('ใช้งานปกติ', 'ชำรุด', 'รอจำหน่าย')) DEFAULT 'ใช้งานปกติ'
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS asset_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              asset_id INTEGER NOT NULL,
              event_type TEXT CHECK(event_type IN ('ซ่อมแซม', 'โอนย้าย', 'จำหน่าย')),
              event_date TEXT,
              description TEXT,
              FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 15) {
          // วัสดุ/คลังพัสดุ (blueprint หน้าที่ 9) — ของสิ้นเปลือง คงเหลือคำนวณจาก
          // stock_in - stock_out เสมอ (ไม่เก็บ remaining แยก กันข้อมูลเพี้ยน)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS materials (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              material_code TEXT,
              name TEXT NOT NULL,
              category TEXT,
              unit TEXT,
              stock_in REAL DEFAULT 0,
              stock_out REAL DEFAULT 0,
              unit_price REAL
            )
          ''');
        }
        if (oldVersion < 16) {
          // ตรวจนับพัสดุประจำปี (blueprint หน้าที่ 10)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS annual_counts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fiscal_year TEXT NOT NULL,
              start_date TEXT,
              responsible_persons TEXT,
              total_items INTEGER,
              found_items INTEGER,
              damaged_lost_items INTEGER,
              status TEXT CHECK(status IN ('กำลังดำเนินการ', 'เสร็จสิ้น')) DEFAULT 'กำลังดำเนินการ',
              summary_notes TEXT
            )
          ''');
        }
        if (oldVersion < 17) {
          // จำหน่ายพัสดุ (blueprint หน้าที่ 11) — ผูกกับ fixed_assets แบบไม่บังคับ
          await db.execute('''
            CREATE TABLE IF NOT EXISTS disposals (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              asset_id INTEGER,
              item_name TEXT,
              disposal_method TEXT CHECK(disposal_method IN ('ขายทอดตลาด', 'โอนให้หน่วยงานอื่น', 'ทำลาย')),
              approved_date TEXT,
              approver_name TEXT,
              status TEXT CHECK(status IN ('รอดำเนินการ', 'ตัดยอดแล้ว')) DEFAULT 'รอดำเนินการ',
              FOREIGN KEY (asset_id) REFERENCES fixed_assets(id)
            )
          ''');
        }
        if (oldVersion < 18) {
          // Audit Trail (blueprint หน้าที่ 13) — log เฉพาะ สร้าง/แก้ไข/ลบ
          // ไม่ log การเปิดดู ตามที่ตกลงกันไว้
          await db.execute('''
            CREATE TABLE IF NOT EXISTS audit_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              action TEXT CHECK(action IN ('สร้าง', 'แก้ไข', 'ลบ')),
              table_label TEXT,
              description TEXT,
              user_name TEXT
            )
          ''');
        }
        if (oldVersion < 19) {
          // ผูก TOR กับรายการจัดซื้อจัดจ้าง — ใช้ export เอกสาร .docx และ
          // auto-create TOR ตอนสร้างเอกสารจัดซื้อจัดจ้างใหม่
          try {
            await db.execute('ALTER TABLE tor_documents ADD COLUMN order_id INTEGER');
          } catch (_) {}
        }
        if (oldVersion < 20) {
          // เก็บ "วิธีจัดซื้อจัดจ้าง" จริงลงฐานข้อมูล (เดิมไม่มีฟิลด์นี้เลย) —
          // ใช้กับฟีเจอร์ Easy Wizard ที่แนะนำวิธีให้อัตโนมัติจากวงเงิน
          try {
            await db.execute('ALTER TABLE procurement_orders ADD COLUMN procurement_method TEXT');
          } catch (_) {}
        }
        if (oldVersion < 21) {
          // เติมฟิลด์ให้ทะเบียนครุภัณฑ์ตรงกับแบบฟอร์ม "ทะเบียนคุมครุภัณฑ์/ทรัพย์สิน"
          // ของราชการ (ผู้ขาย, ประเภทเงิน, วิธีการได้มา, อายุการใช้งาน) — ใช้คำนวณ
          // ค่าเสื่อมราคาแบบเส้นตรงในแอปเพิ่มเติม
          for (final stmt in [
            'ALTER TABLE fixed_assets ADD COLUMN vendor_name TEXT',
            'ALTER TABLE fixed_assets ADD COLUMN fund_type TEXT',
            'ALTER TABLE fixed_assets ADD COLUMN procurement_method TEXT',
            'ALTER TABLE fixed_assets ADD COLUMN useful_life_years INTEGER',
          ]) {
            try {
              await db.execute(stmt);
            } catch (_) {}
          }
        }
        if (oldVersion < 22) {
          // เติม "ประเภทของเงิน" และ "เลขที่โครงการ" ให้ procurement_orders
          // ตรงกับทะเบียนคุมเลขที่จัดซื้อจัดจ้างของจริงที่โรงเรียนใช้อยู่
          for (final stmt in [
            'ALTER TABLE procurement_orders ADD COLUMN fund_type TEXT',
            'ALTER TABLE procurement_orders ADD COLUMN project_number TEXT',
          ]) {
            try {
              await db.execute(stmt);
            } catch (_) {}
          }
        }
        if (oldVersion < 23) {
          // แยกงบที่อยู่ในแผนโรงเรียน กับงบเขต/หน่วยเหนือที่จัดสรรตรงมา (นอกแผน)
          try {
            await db.execute(
              "ALTER TABLE budgets ADD COLUMN budget_source TEXT NOT NULL DEFAULT 'ในแผนงบโรงเรียน'",
            );
          } catch (_) {}
          // จำข้อมูลร้านค้า/คู่ค้าที่เคยกรอกไว้ ให้เลือกใช้ซ้ำได้ในครั้งถัดไป
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS vendors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                owner TEXT,
                address_no TEXT,
                subdistrict TEXT,
                district TEXT,
                province TEXT,
                phone TEXT,
                tax_id TEXT,
                updated_at TEXT
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 24) {
          // ทำเนียบบุคลากรกลาง — ให้ทุกช่องกรอกชื่อ-ตำแหน่งทั่วแอปเลือกใช้ซ้ำได้
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS personnel (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                position TEXT,
                phone TEXT,
                email TEXT,
                active INTEGER NOT NULL DEFAULT 1
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 25) {
          // กลุ่มงาน/ฝ่าย เป็นตารางจัดการได้จริง แทนค่าคงที่ 5 กลุ่มเดิมในโค้ด
          // — เติมค่าเดิม 5 กลุ่มให้อัตโนมัติกันผู้ใช้เก่าเห็นตัวเลือกหายไป
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS work_groups (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                head_name TEXT,
                active INTEGER NOT NULL DEFAULT 1
              )
            ''');
            for (final g in budgetDepartmentGroups) {
              await db.insert(
                'work_groups',
                {'name': g, 'active': 1},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          } catch (_) {}
        }
        if (oldVersion < 26) {
          // ขยายข้อมูลร้านค้า/ผู้รับจ้างให้เต็มรูปแบบ (ประเภทนิติบุคคล, หมู่ที่,
          // รหัสไปรษณีย์, สถานะใช้งาน) รองรับหน้าจัดการร้านค้าแยกในตั้งค่า
          for (final stmt in [
            "ALTER TABLE vendors ADD COLUMN vendor_type TEXT NOT NULL DEFAULT 'บุคคลธรรมดา'",
            'ALTER TABLE vendors ADD COLUMN moo_number TEXT',
            'ALTER TABLE vendors ADD COLUMN postal_code TEXT',
            'ALTER TABLE vendors ADD COLUMN active INTEGER NOT NULL DEFAULT 1',
          ]) {
            try {
              await db.execute(stmt);
            } catch (_) {}
          }
        }
        if (oldVersion < 27) {
          // บัญชีวัสดุแบบบัตรคุมสต๊อกจริง — เพิ่มฟิลด์ที่แบบฟอร์มราชการต้องใช้
          // (จำนวนอย่างสูง/ต่ำ, ที่เก็บ, ขนาด/ลักษณะ) และตารางประวัติรับ-จ่ายทีละ
          // รายการ (ก่อนหน้านี้เก็บแค่ยอดรวมสะสม stock_in/stock_out ไม่มีประวัติ)
          for (final stmt in [
            'ALTER TABLE materials ADD COLUMN min_stock REAL',
            'ALTER TABLE materials ADD COLUMN max_stock REAL',
            'ALTER TABLE materials ADD COLUMN storage_location TEXT',
            'ALTER TABLE materials ADD COLUMN size_spec TEXT',
          ]) {
            try {
              await db.execute(stmt);
            } catch (_) {}
          }
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS material_transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                material_id INTEGER NOT NULL,
                transaction_date TEXT,
                transaction_type TEXT CHECK(transaction_type IN ('รับเข้า', 'เบิกจ่าย')),
                quantity REAL NOT NULL,
                unit_price REAL,
                ref_document TEXT,
                counterparty TEXT,
                note TEXT,
                FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE CASCADE
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 28) {
          // งวดการเบิกจ่ายสำหรับสัญญาแบบต่อเนื่องหลายเดือน (เช่น จ้างเหมา
          // ประกอบอาหารกลางวัน) — 1 order สร้างชุดเอกสารซ้ำได้หลายงวด
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS procurement_installments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                period_no INTEGER NOT NULL,
                period_label TEXT,
                amount REAL,
                amount_th TEXT,
                date_delivery TEXT,
                date_inspection TEXT,
                date_disbursement TEXT,
                inspection_result TEXT,
                has_penalty INTEGER NOT NULL DEFAULT 0,
                penalty_amount REAL,
                control_number_inspection TEXT,
                FOREIGN KEY (order_id) REFERENCES procurement_orders(id) ON DELETE CASCADE
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 29) {
          // ธงบอกว่าโครงการนี้เป็น "สัญญาต่อเนื่องหลายเดือน" (เช่น อาหาร
          // กลางวัน) — ตั้งจาก Tab 1 ของ wizard แล้วให้ไปโผล่อัตโนมัติในหน้า
          // "สัญญาต่อเนื่อง/อาหารกลางวัน" โดยไม่ต้องมาเลือกเพิ่มเองอีกที
          try {
            await db.execute(
              'ALTER TABLE procurement_orders ADD COLUMN is_recurring_contract INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
        if (oldVersion < 30) {
          // รหัสไปรษณีย์ของผู้ขาย/ผู้รับจ้าง — ต้องใช้ในใบสำคัญรับเงินบางแบบ
          // (ที่อยู่แบบเต็มรวมรหัสไปรษณีย์) แต่เดิมไม่มีเก็บไว้ที่ order เลย
          try {
            await db.execute('ALTER TABLE procurement_orders ADD COLUMN vendor_postal_code TEXT');
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
        responsible_person TEXT,
        budget_source TEXT NOT NULL DEFAULT 'ในแผนงบโรงเรียน'
      )
    ''');

    // ── ตารางจดจำข้อมูลร้านค้า/คู่ค้าที่เคยกรอกไว้ ให้เลือกใช้ซ้ำได้ ──────
    await db.execute('''
      CREATE TABLE vendors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        owner TEXT,
        address_no TEXT,
        moo_number TEXT,
        subdistrict TEXT,
        district TEXT,
        province TEXT,
        postal_code TEXT,
        phone TEXT,
        tax_id TEXT,
        vendor_type TEXT NOT NULL DEFAULT 'บุคคลธรรมดา',
        active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT
      )
    ''');

    // ── ทำเนียบบุคลากรกลาง — ให้ทุกช่องกรอกชื่อ-ตำแหน่งทั่วแอปเลือกใช้ซ้ำได้ ──
    await db.execute('''
      CREATE TABLE personnel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        position TEXT,
        phone TEXT,
        email TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // ── กลุ่มงาน/ฝ่าย เป็นตารางจัดการได้จริง ──────────────────────────
    await db.execute('''
      CREATE TABLE work_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        head_name TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    for (final g in budgetDepartmentGroups) {
      await db.insert('work_groups', {'name': g, 'active': 1});
    }

    // ── ตารางหลัก: เอกสารการจัดซื้อจัดจ้างแต่ละใบ ────────────────────
    await db.execute('''
      CREATE TABLE procurement_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER,
        fiscal_year TEXT,
        order_type TEXT CHECK(order_type IN ('ซื้อ', 'จ้าง')),
        procurement_method TEXT, -- เช่น 'เฉพาะเจาะจง ไม่เกิน 5,000 บาท', 'ว.804 ไม่เกิน 50,000 บาท'

        -- เลขที่เอกสาร (คนละความหมายกัน อย่าทับกัน)
        procurement_number TEXT,   -- {{procurement_number}} เลขที่หนังสือพัสดุ/ใบสั่งซื้อ
        order_number TEXT,         -- {{order_number}} เลขที่คำสั่งแต่งตั้งกรรมการตรวจรับ

        project_name TEXT,
        procurement_subject TEXT,  -- {{procurement_subject}} หัวเรื่องสั้นสำหรับเอกสาร ซ. (คนละความหมายกับ project_name)
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
        vendor_postal_code TEXT,

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
        fund_type TEXT,
        project_number TEXT,

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

        -- สัญญาแบบต่อเนื่องหลายเดือน (เช่น อาหารกลางวัน) — ตั้งได้จาก Tab 1
        -- ของ wizard แล้วไปโผล่อัตโนมัติในหน้า "สัญญาต่อเนื่อง/อาหารกลางวัน"
        is_recurring_contract INTEGER NOT NULL DEFAULT 0,

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

    // ── ตารางงวดการเบิกจ่าย (สำหรับสัญญาแบบต่อเนื่องหลายเดือน เช่น
    //    จ้างเหมาประกอบอาหารกลางวัน) — 1 order มีได้หลายงวด แต่ละงวดสร้าง
    //    ชุดเอกสาร ใบส่งมอบงาน/ใบตรวจรับพัสดุ/บันทึกเบิกจ่าย/ใบสำคัญรับเงิน
    //    แยกกัน โดยใช้จำนวนเงิน+วันที่ของงวดนั้นแทนยอดรวมทั้งสัญญา
    await db.execute('''
      CREATE TABLE procurement_installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        period_no INTEGER NOT NULL,
        period_label TEXT,
        amount REAL,
        amount_th TEXT,
        date_delivery TEXT,
        date_inspection TEXT,
        date_disbursement TEXT,
        inspection_result TEXT,
        has_penalty INTEGER NOT NULL DEFAULT 0,
        penalty_amount REAL,
        control_number_inspection TEXT,
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
        school_changwat TEXT,
        school_phone TEXT,
        director_name TEXT,
        procurement_officer TEXT,
        procurement_head TEXT,
        finance_officer TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_orders_budget_id ON procurement_orders(budget_id)',
    );
    await db.execute(
      'CREATE INDEX idx_items_order_id ON procurement_items(order_id)',
    );

    // ── ตาราง TOR / ข้อมูลคุณลักษณะเฉพาะ ──────────────────────────────
    await db.execute('''
      CREATE TABLE tor_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_number TEXT,
        title TEXT NOT NULL,
        category TEXT CHECK(category IN ('ครุภัณฑ์', 'วัสดุ', 'จ้าง')),
        estimated_amount REAL,
        created_date TEXT,
        status TEXT CHECK(status IN ('ร่าง', 'อนุมัติ')) DEFAULT 'ร่าง',
        specification_text TEXT,
        order_id INTEGER,
        FOREIGN KEY (order_id) REFERENCES procurement_orders(id)
      )
    ''');

    // ── คลัง TOR Template ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE tor_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT CHECK(category IN ('ครุภัณฑ์', 'วัสดุ', 'จ้าง')),
        specification_text TEXT
      )
    ''');

    // ── บริหารสัญญา/ใบสั่งซื้อ/สั่งจ้าง ────────────────────────────────
    await db.execute('''
      CREATE TABLE contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_number TEXT,
        egp_number TEXT,
        order_id INTEGER,
        contract_type TEXT CHECK(contract_type IN ('สัญญาซื้อขาย', 'สัญญาจ้าง', 'ใบสั่งซื้อ', 'ใบสั่งจ้าง')),
        contract_amount REAL,
        vendor_name TEXT,
        start_date TEXT,
        end_date TEXT,
        installment_count INTEGER,
        status TEXT CHECK(status IN ('กำลังดำเนินการ', 'ครบกำหนดแล้ว', 'ยกเลิก')) DEFAULT 'กำลังดำเนินการ',
        FOREIGN KEY (order_id) REFERENCES procurement_orders(id)
      )
    ''');

    // ── ทะเบียนหลักประกัน ────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE guarantees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guarantee_type TEXT CHECK(guarantee_type IN ('หลักประกันซอง', 'หลักประกันสัญญา', 'เงินสด', 'หนังสือค้ำประกันธนาคาร')),
        counterparty_name TEXT,
        amount REAL,
        start_date TEXT,
        expiry_date TEXT,
        contract_id INTEGER,
        status TEXT CHECK(status IN ('ถืออยู่', 'คืนแล้ว')) DEFAULT 'ถืออยู่',
        returned_date TEXT,
        FOREIGN KEY (contract_id) REFERENCES contracts(id)
      )
    ''');

    // ── ตรวจรับพัสดุ ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_number TEXT,
        order_id INTEGER,
        due_date TEXT,
        actual_delivery_date TEXT,
        result TEXT CHECK(result IN ('ผ่าน', 'ไม่ผ่าน')),
        penalty_amount REAL,
        notes TEXT,
        FOREIGN KEY (order_id) REFERENCES procurement_orders(id)
      )
    ''');

    // ── ทะเบียนครุภัณฑ์ + ประวัติซ่อมแซม/โอนย้าย ─────────────────────
    await db.execute('''
      CREATE TABLE fixed_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_number TEXT,
        name TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price REAL,
        location TEXT,
        acquired_date TEXT,
        photo_path TEXT,
        status TEXT CHECK(status IN ('ใช้งานปกติ', 'ชำรุด', 'รอจำหน่าย')) DEFAULT 'ใช้งานปกติ',
        vendor_name TEXT,
        fund_type TEXT,
        procurement_method TEXT,
        useful_life_years INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE asset_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        event_type TEXT CHECK(event_type IN ('ซ่อมแซม', 'โอนย้าย', 'จำหน่าย')),
        event_date TEXT,
        description TEXT,
        FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
      )
    ''');

    // ── วัสดุ/คลังพัสดุ ──────────────────────────────────────────────
    // stock_in/stock_out ยังเก็บยอดรวมสะสมไว้ (คำนวณ "คงเหลือ" เร็วโดยไม่ต้อง
    // sum ตาราง material_transactions ทุกครั้ง) ส่วนประวัติรับ-จ่ายทีละรายการ
    // (บัตรคุมสต๊อก) แยกเก็บที่ material_transactions
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_code TEXT,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT,
        stock_in REAL DEFAULT 0,
        stock_out REAL DEFAULT 0,
        unit_price REAL,
        min_stock REAL,
        max_stock REAL,
        storage_location TEXT,
        size_spec TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE material_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        transaction_date TEXT,
        transaction_type TEXT CHECK(transaction_type IN ('รับเข้า', 'เบิกจ่าย')),
        quantity REAL NOT NULL,
        unit_price REAL,
        ref_document TEXT,
        counterparty TEXT,
        note TEXT,
        FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE CASCADE
      )
    ''');

    // ── ตรวจนับพัสดุประจำปี ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE annual_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fiscal_year TEXT NOT NULL,
        start_date TEXT,
        responsible_persons TEXT,
        total_items INTEGER,
        found_items INTEGER,
        damaged_lost_items INTEGER,
        status TEXT CHECK(status IN ('กำลังดำเนินการ', 'เสร็จสิ้น')) DEFAULT 'กำลังดำเนินการ',
        summary_notes TEXT
      )
    ''');

    // ── จำหน่ายพัสดุ ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE disposals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER,
        item_name TEXT,
        disposal_method TEXT CHECK(disposal_method IN ('ขายทอดตลาด', 'โอนให้หน่วยงานอื่น', 'ทำลาย')),
        approved_date TEXT,
        approver_name TEXT,
        status TEXT CHECK(status IN ('รอดำเนินการ', 'ตัดยอดแล้ว')) DEFAULT 'รอดำเนินการ',
        FOREIGN KEY (asset_id) REFERENCES fixed_assets(id)
      )
    ''');

    // ── Audit Trail ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        action TEXT CHECK(action IN ('สร้าง', 'แก้ไข', 'ลบ')),
        table_label TEXT,
        description TEXT,
        user_name TEXT
      )
    ''');
  }
}