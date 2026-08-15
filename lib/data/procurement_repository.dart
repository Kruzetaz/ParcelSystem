import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/budget.dart';
import '../models/vendor.dart';
import '../models/personnel.dart';
import '../models/work_group.dart';
import '../models/control_log_entry.dart';
import '../models/procurement_order.dart';
import '../models/procurement_item.dart';
import '../models/school_settings.dart';
import '../models/tor_document.dart';
import '../models/tor_template.dart';
import '../models/contract.dart';
import '../models/guarantee.dart';
import '../models/inspection.dart';
import '../models/fixed_asset.dart';
import '../models/asset_event.dart';
import '../models/asset_repair_entry.dart';
import '../models/material_item.dart';
import '../models/material_transaction.dart';
import '../models/procurement_installment.dart';
import '../models/annual_count.dart';
import '../models/disposal.dart';
import '../models/audit_log_entry.dart';
import '../services/audit_service.dart';
import 'database.dart';

class ProcurementRepository {
  final _db = AppDatabase.instance;

  // ─────────────────────────────────────────
  // VENDORS (ร้านค้า/คู่ค้าที่เคยกรอกไว้ — เลือกใช้ซ้ำได้)
  // ─────────────────────────────────────────

  /// บันทึก/อัปเดตข้อมูลร้านค้าโดยใช้ "ชื่อร้าน" เป็น key — ถ้ามีชื่อนี้อยู่แล้ว
  /// จะอัปเดตข้อมูลทับด้วยค่าล่าสุดที่กรอก (เผื่อเบอร์โทร/ที่อยู่เปลี่ยน) แต่คง
  /// ประเภท/หมู่ที่/รหัสไปรษณีย์/สถานะที่ตั้งไว้จากหน้าจัดการร้านค้าไว้เสมอ
  /// (ฟอร์มใน wizard ไม่มีช่องกรอกฟิลด์พวกนี้ ไม่ให้ auto-save ไปเขียนทับเป็นค่าว่าง)
  Future<void> upsertVendor(Vendor vendor) async {
    final name = vendor.name.trim();
    if (name.isEmpty) return;
    final existing = await getVendorByName(name);
    final db = await _db.database;
    await db.insert(
      'vendors',
      Vendor(
        name: name,
        owner: vendor.owner,
        addressNo: vendor.addressNo,
        mooNumber: existing?.mooNumber,
        subdistrict: vendor.subdistrict,
        district: vendor.district,
        province: vendor.province,
        postalCode: existing?.postalCode,
        phone: vendor.phone,
        taxId: vendor.taxId,
        vendorType: existing?.vendorType ?? vendorTypeIndividual,
        active: existing?.active ?? true,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Vendor?> getVendorByName(String name) async {
    final db = await _db.database;
    final rows = await db.query('vendors', where: 'name = ?', whereArgs: [name.trim()], limit: 1);
    if (rows.isEmpty) return null;
    return Vendor.fromMap(rows.first);
  }

  Future<List<Vendor>> getAllVendors({bool activeOnly = false}) async {
    final db = await _db.database;
    final rows = await db.query(
      'vendors',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Vendor.fromMap).toList();
  }

  /// ใช้จากหน้าจัดการร้านค้าในตั้งค่า — แก้ไขทุกฟิลด์รวมประเภท/สถานะได้เต็มรูปแบบ
  Future<void> updateVendor(Vendor vendor) async {
    final db = await _db.database;
    await db.update('vendors', vendor.toMap(), where: 'id = ?', whereArgs: [vendor.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'ร้านค้า', description: vendor.name);
  }

  Future<void> deleteVendor(int id) async {
    final db = await _db.database;
    await db.delete('vendors', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // PERSONNEL (ทำเนียบบุคลากรกลาง)
  // ─────────────────────────────────────────

  Future<int> insertPersonnel(Personnel person) async {
    final db = await _db.database;
    final id = await db.insert('personnel', person.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'บุคลากร', description: person.name);
    return id;
  }

  Future<void> updatePersonnel(Personnel person) async {
    final db = await _db.database;
    await db.update('personnel', person.toMap(), where: 'id = ?', whereArgs: [person.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'บุคลากร', description: person.name);
  }

  Future<List<Personnel>> getAllPersonnel({bool activeOnly = false}) async {
    final db = await _db.database;
    final rows = await db.query(
      'personnel',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Personnel.fromMap).toList();
  }

  Future<void> deletePersonnel(int id) async {
    final db = await _db.database;
    await db.delete('personnel', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // WORK GROUPS (กลุ่มงาน/ฝ่าย)
  // ─────────────────────────────────────────

  Future<int> insertWorkGroup(WorkGroup group) async {
    final db = await _db.database;
    final id = await db.insert('work_groups', group.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'กลุ่มงาน', description: group.name);
    return id;
  }

  Future<void> updateWorkGroup(WorkGroup group) async {
    final db = await _db.database;
    await db.update('work_groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'กลุ่มงาน', description: group.name);
  }

  Future<List<WorkGroup>> getAllWorkGroups({bool activeOnly = false}) async {
    final db = await _db.database;
    final rows = await db.query(
      'work_groups',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'id ASC',
    );
    return rows.map(WorkGroup.fromMap).toList();
  }

  Future<void> deleteWorkGroup(int id) async {
    final db = await _db.database;
    await db.delete('work_groups', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // BUDGETS (แผนงบประมาณ)
  // ─────────────────────────────────────────

  Future<int> insertBudget(Budget budget) async {
    final db = await _db.database;
    final id = await db.insert('budgets', budget.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'แผนงบประมาณ', description: budget.projectName ?? 'แผนงบ #$id');
    return id;
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await _db.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'แผนงบประมาณ', description: budget.projectName ?? 'แผนงบ #${budget.id}');
  }

  Future<List<Budget>> getAllBudgets({String? fiscalYear}) async {
    final db = await _db.database;
    final rows = await db.query(
      'budgets',
      where: fiscalYear != null ? 'fiscal_year = ?' : null,
      whereArgs: fiscalYear != null ? [fiscalYear] : null,
      orderBy: 'id ASC',
    );
    return rows.map(Budget.fromMap).toList();
  }

  Future<Budget?> getBudget(int id) async {
    final db = await _db.database;
    final rows = await db.query('budgets', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  /// ลบแผนงบ 1 รายการ — เอกสารจัดซื้อจัดจ้างที่เคยผูกกับแผนงบนี้ (budget_id) จะถูก
  /// เลิกผูกก่อนลบเสมอ ไม่งั้น FOREIGN KEY constraint จะบล็อกการลบเงียบๆ
  Future<void> deleteBudget(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('procurement_orders', {'budget_id': null}, where: 'budget_id = ?', whereArgs: [id]);
      await txn.delete('budgets', where: 'id = ?', whereArgs: [id]);
    });
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'แผนงบประมาณ', description: 'แผนงบ #$id');
  }

  /// ลบแผนงบทั้งหมดในครั้งเดียว — เลิกผูกเอกสารจัดซื้อจัดจ้างทุกใบที่เกี่ยวข้องก่อนลบ
  /// เช่นเดียวกับ deleteBudget
  Future<void> deleteAllBudgets() async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('procurement_orders', {'budget_id': null});
      await txn.delete('budgets');
    });
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'แผนงบประมาณ', description: 'ลบแผนงบประมาณทั้งหมด');
  }

  // ─────────────────────────────────────────
  // TOR / ข้อมูลคุณลักษณะเฉพาะ
  // ─────────────────────────────────────────

  Future<int> insertTorDocument(TorDocument doc) async {
    final db = await _db.database;
    final id = await db.insert('tor_documents', doc.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'TOR/คุณลักษณะเฉพาะ', description: doc.title);
    return id;
  }

  Future<void> updateTorDocument(TorDocument doc) async {
    final db = await _db.database;
    await db.update(
      'tor_documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'TOR/คุณลักษณะเฉพาะ', description: doc.title);
  }

  /// [fiscalYear] กรองเฉพาะ TOR ที่ผูกกับโครงการของปีงบนั้น (join ผ่าน
  /// order_id) — TOR ที่ยังไม่ได้ผูกกับโครงการเลย (order_id ว่าง เช่น ร่าง TOR
  /// ที่สร้างไว้ก่อนเลือกโครงการ) จะ "โชว์เสมอทุกปีงบ" ไม่ถูกกรองออก เพราะยัง
  /// ไม่ได้เป็นของปีไหนเป็นพิเศษ ซ่อนไปจะทำของหายจากสายตาโดยไม่มีเหตุผล
  Future<List<TorDocument>> getAllTorDocuments({String? fiscalYear}) async {
    final db = await _db.database;
    if (fiscalYear == null) {
      final rows = await db.query('tor_documents', orderBy: 'id DESC');
      return rows.map(TorDocument.fromMap).toList();
    }
    final rows = await db.rawQuery('''
      SELECT t.* FROM tor_documents t
      LEFT JOIN procurement_orders o ON t.order_id = o.id
      WHERE t.order_id IS NULL OR o.fiscal_year = ?
      ORDER BY t.id DESC
    ''', [fiscalYear]);
    return rows.map(TorDocument.fromMap).toList();
  }

  Future<void> deleteTorDocument(int id) async {
    final db = await _db.database;
    await db.delete('tor_documents', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'TOR/คุณลักษณะเฉพาะ', description: 'TOR #$id');
  }

  // ─────────────────────────────────────────
  // TOR TEMPLATES (สเปกมาตรฐานที่บันทึกไว้ใช้ซ้ำ)
  // ─────────────────────────────────────────

  Future<int> insertTorTemplate(TorTemplate template) async {
    final db = await _db.database;
    return db.insert('tor_templates', template.toMap());
  }

  Future<List<TorTemplate>> getAllTorTemplates() async {
    final db = await _db.database;
    final rows = await db.query('tor_templates', orderBy: 'id DESC');
    return rows.map(TorTemplate.fromMap).toList();
  }

  Future<void> deleteTorTemplate(int id) async {
    final db = await _db.database;
    await db.delete('tor_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // CONTRACTS (บริหารสัญญา/ใบสั่งซื้อ/สั่งจ้าง)
  // ─────────────────────────────────────────

  Future<int> insertContract(Contract contract) async {
    final db = await _db.database;
    final id = await db.insert('contracts', contract.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'บริหารสัญญา', description: contract.contractNumber ?? 'สัญญา #$id');
    return id;
  }

  Future<void> updateContract(Contract contract) async {
    final db = await _db.database;
    await db.update(
      'contracts',
      contract.toMap(),
      where: 'id = ?',
      whereArgs: [contract.id],
    );
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'บริหารสัญญา', description: contract.contractNumber ?? 'สัญญา #${contract.id}');
  }

  /// [fiscalYear] กรองเฉพาะสัญญาที่ผูกกับโครงการของปีงบนั้น — สัญญาที่ยังไม่ได้
  /// ผูกโครงการ (order_id ว่าง) โชว์เสมอทุกปีงบเหมือนกัน (ดูเหตุผลเดียวกับ
  /// getAllTorDocuments ด้านบน)
  Future<List<Contract>> getAllContracts({String? fiscalYear}) async {
    final db = await _db.database;
    if (fiscalYear == null) {
      final rows = await db.query('contracts', orderBy: 'id DESC');
      return rows.map(Contract.fromMap).toList();
    }
    final rows = await db.rawQuery('''
      SELECT c.* FROM contracts c
      LEFT JOIN procurement_orders o ON c.order_id = o.id
      WHERE c.order_id IS NULL OR o.fiscal_year = ?
      ORDER BY c.id DESC
    ''', [fiscalYear]);
    return rows.map(Contract.fromMap).toList();
  }

  Future<void> deleteContract(int id) async {
    final db = await _db.database;
    await db.delete('contracts', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'บริหารสัญญา', description: 'สัญญา #$id');
  }

  // ─────────────────────────────────────────
  // GUARANTEES (ทะเบียนหลักประกัน)
  // ─────────────────────────────────────────

  Future<int> insertGuarantee(Guarantee g) async {
    final db = await _db.database;
    final id = await db.insert('guarantees', g.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'หลักประกัน', description: g.counterpartyName ?? 'หลักประกัน #$id');
    return id;
  }

  Future<void> updateGuarantee(Guarantee g) async {
    final db = await _db.database;
    await db.update('guarantees', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'หลักประกัน', description: g.counterpartyName ?? 'หลักประกัน #${g.id}');
  }

  /// [fiscalYear] กรองผ่านสัญญา → โครงการ (guarantees ไม่มี order_id ตรงๆ
  /// ต้อง join ผ่าน contracts อีกที) — หลักประกันที่ยังไม่ได้ผูกสัญญา หรือผูก
  /// สัญญาที่ยังไม่ได้ผูกโครงการ โชว์เสมอทุกปีงบเหมือนกัน
  Future<List<Guarantee>> getAllGuarantees({String? fiscalYear}) async {
    final db = await _db.database;
    if (fiscalYear == null) {
      final rows = await db.query('guarantees', orderBy: 'id DESC');
      return rows.map(Guarantee.fromMap).toList();
    }
    final rows = await db.rawQuery('''
      SELECT g.* FROM guarantees g
      LEFT JOIN contracts c ON g.contract_id = c.id
      LEFT JOIN procurement_orders o ON c.order_id = o.id
      WHERE g.contract_id IS NULL OR c.order_id IS NULL OR o.fiscal_year = ?
      ORDER BY g.id DESC
    ''', [fiscalYear]);
    return rows.map(Guarantee.fromMap).toList();
  }

  Future<void> deleteGuarantee(int id) async {
    final db = await _db.database;
    await db.delete('guarantees', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'หลักประกัน', description: 'หลักประกัน #$id');
  }

  // ─────────────────────────────────────────
  // INSPECTIONS (ตรวจรับพัสดุ)
  // ─────────────────────────────────────────

  Future<int> insertInspection(Inspection i) async {
    final db = await _db.database;
    final id = await db.insert('inspections', i.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'ตรวจรับพัสดุ', description: i.inspectionNumber ?? 'ตรวจรับ #$id');
    return id;
  }

  Future<void> updateInspection(Inspection i) async {
    final db = await _db.database;
    await db.update('inspections', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'ตรวจรับพัสดุ', description: i.inspectionNumber ?? 'ตรวจรับ #${i.id}');
  }

  /// [fiscalYear] กรองเฉพาะรายการตรวจรับที่ผูกกับโครงการของปีงบนั้น — รายการ
  /// ที่ยังไม่ได้ผูกโครงการ (order_id ว่าง) โชว์เสมอทุกปีงบเหมือนกัน
  Future<List<Inspection>> getAllInspections({String? fiscalYear}) async {
    final db = await _db.database;
    if (fiscalYear == null) {
      final rows = await db.query('inspections', orderBy: 'id DESC');
      return rows.map(Inspection.fromMap).toList();
    }
    final rows = await db.rawQuery('''
      SELECT i.* FROM inspections i
      LEFT JOIN procurement_orders o ON i.order_id = o.id
      WHERE i.order_id IS NULL OR o.fiscal_year = ?
      ORDER BY i.id DESC
    ''', [fiscalYear]);
    return rows.map(Inspection.fromMap).toList();
  }

  Future<void> deleteInspection(int id) async {
    final db = await _db.database;
    await db.delete('inspections', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'ตรวจรับพัสดุ', description: 'ตรวจรับ #$id');
  }

  // ─────────────────────────────────────────
  // FIXED ASSETS (ทะเบียนครุภัณฑ์)
  // ─────────────────────────────────────────

  Future<int> insertFixedAsset(FixedAsset a) async {
    final db = await _db.database;
    final id = await db.insert('fixed_assets', a.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'ทะเบียนครุภัณฑ์', description: a.name);
    return id;
  }

  Future<void> updateFixedAsset(FixedAsset a) async {
    final db = await _db.database;
    await db.update('fixed_assets', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'ทะเบียนครุภัณฑ์', description: a.name);
  }

  Future<List<FixedAsset>> getAllFixedAssets() async {
    final db = await _db.database;
    final rows = await db.query('fixed_assets', orderBy: 'id DESC');
    return rows.map(FixedAsset.fromMap).toList();
  }

  Future<void> deleteFixedAsset(int id) async {
    final db = await _db.database;
    await db.delete('fixed_assets', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'ทะเบียนครุภัณฑ์', description: 'ครุภัณฑ์ #$id');
  }

  Future<int> insertAssetEvent(AssetEvent e) async {
    final db = await _db.database;
    return db.insert('asset_events', e.toMap());
  }

  Future<List<AssetEvent>> getAssetEvents(int assetId) async {
    final db = await _db.database;
    final rows = await db.query('asset_events', where: 'asset_id = ?', whereArgs: [assetId], orderBy: 'id DESC');
    return rows.map(AssetEvent.fromMap).toList();
  }

  Future<void> deleteAssetEvent(int id) async {
    final db = await _db.database;
    await db.delete('asset_events', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'ประวัติซ่อมครุภัณฑ์', description: 'ประวัติซ่อม #$id');
  }

  /// รวมประวัติซ่อมแซมของครุภัณฑ์ทุกชิ้นมาไว้ที่เดียว (join กับ fixed_assets เอา
  /// ชื่อ/เลขครุภัณฑ์มาแสดง) — ก่อนหน้านี้ดูได้แค่ทีละชิ้นในหน้าทะเบียนครุภัณฑ์
  Future<List<AssetRepairEntry>> getAssetRepairHistory() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT ae.id AS event_id, ae.asset_id, ae.event_date, ae.description,
             fa.asset_number, fa.name AS asset_name, fa.location AS asset_location
      FROM asset_events ae
      JOIN fixed_assets fa ON fa.id = ae.asset_id
      WHERE ae.event_type = 'ซ่อมแซม'
      ORDER BY ae.id DESC
    ''');
    return rows.map(AssetRepairEntry.fromMap).toList();
  }

  // ─────────────────────────────────────────
  // MATERIALS (วัสดุ/คลังพัสดุ)
  // ─────────────────────────────────────────

  Future<int> insertMaterial(MaterialItem m) async {
    final db = await _db.database;
    final id = await db.insert('materials', m.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'วัสดุ/คลังพัสดุ', description: m.name);
    return id;
  }

  Future<void> updateMaterial(MaterialItem m) async {
    final db = await _db.database;
    await db.update('materials', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'วัสดุ/คลังพัสดุ', description: m.name);
  }

  Future<List<MaterialItem>> getAllMaterials() async {
    final db = await _db.database;
    final rows = await db.query('materials', orderBy: 'id DESC');
    return rows.map(MaterialItem.fromMap).toList();
  }

  Future<void> deleteMaterial(int id) async {
    final db = await _db.database;
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'วัสดุ/คลังพัสดุ', description: 'วัสดุ #$id');
  }

  /// บันทึกประวัติรับเข้า/เบิกจ่ายทีละรายการ (บัตรคุมสต๊อก) — เรียกคู่กับการ
  /// อัปเดต stock_in/stock_out สะสมใน MaterialItem เสมอ ไม่ใช้แทนกัน
  Future<int> insertMaterialTransaction(MaterialTransaction t) async {
    final db = await _db.database;
    final id = await db.insert('material_transactions', t.toMap());
    await AuditService.instance.log(
      db,
      action: 'สร้าง',
      tableLabel: 'ประวัติรับ-จ่ายวัสดุ',
      description: '${t.transactionType} #$id',
    );
    return id;
  }

  Future<List<MaterialTransaction>> getMaterialTransactions(int materialId) async {
    final db = await _db.database;
    final rows = await db.query(
      'material_transactions',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'id DESC',
    );
    return rows.map(MaterialTransaction.fromMap).toList();
  }

  /// ประวัติรับ-จ่ายทั้งหมดของวัสดุ [materialId] เรียงเก่า->ใหม่ พร้อมยอดคงเหลือ
  /// สะสม ณ แต่ละแถว (running balance) — ใช้สำหรับพิมพ์บัญชีวัสดุ/บัตรคุมสต๊อก
  Future<List<MaterialTransaction>> getMaterialTransactionsChronological(int materialId) async {
    final db = await _db.database;
    final rows = await db.query(
      'material_transactions',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'id ASC',
    );
    return rows.map(MaterialTransaction.fromMap).toList();
  }

  // ─────────────────────────────────────────
  // ANNUAL COUNTS (ตรวจนับพัสดุประจำปี)
  // ─────────────────────────────────────────

  Future<int> insertAnnualCount(AnnualCount a) async {
    final db = await _db.database;
    final id = await db.insert('annual_counts', a.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'ตรวจนับพัสดุประจำปี', description: 'ปี ${a.fiscalYear}');
    return id;
  }

  Future<void> updateAnnualCount(AnnualCount a) async {
    final db = await _db.database;
    await db.update('annual_counts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'ตรวจนับพัสดุประจำปี', description: 'ปี ${a.fiscalYear}');
  }

  Future<List<AnnualCount>> getAllAnnualCounts() async {
    final db = await _db.database;
    final rows = await db.query('annual_counts', orderBy: 'id DESC');
    return rows.map(AnnualCount.fromMap).toList();
  }

  Future<void> deleteAnnualCount(int id) async {
    final db = await _db.database;
    await db.delete('annual_counts', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'ตรวจนับพัสดุประจำปี', description: 'บันทึก #$id');
  }

  // ─────────────────────────────────────────
  // DISPOSALS (จำหน่ายพัสดุ)
  // ─────────────────────────────────────────

  Future<int> insertDisposal(Disposal d) async {
    final db = await _db.database;
    final id = await db.insert('disposals', d.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'จำหน่ายพัสดุ', description: d.itemName ?? 'จำหน่าย #$id');
    return id;
  }

  Future<void> updateDisposal(Disposal d) async {
    final db = await _db.database;
    await db.update('disposals', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'จำหน่ายพัสดุ', description: d.itemName ?? 'จำหน่าย #${d.id}');
  }

  Future<List<Disposal>> getAllDisposals() async {
    final db = await _db.database;
    final rows = await db.query('disposals', orderBy: 'id DESC');
    return rows.map(Disposal.fromMap).toList();
  }

  Future<void> deleteDisposal(int id) async {
    final db = await _db.database;
    await db.delete('disposals', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'จำหน่ายพัสดุ', description: 'จำหน่าย #$id');
  }

  // ─────────────────────────────────────────
  // AUDIT LOG
  // ─────────────────────────────────────────

  Future<List<AuditLogEntry>> getAuditLog({int limit = 200}) async {
    final db = await _db.database;
    final rows = await db.query('audit_log', orderBy: 'id DESC', limit: limit);
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<int> countAllAssetsAndMaterials() async {
    final db = await _db.database;
    final assets = await db.rawQuery('SELECT COUNT(*) as c FROM fixed_assets');
    final materials = await db.rawQuery('SELECT COUNT(*) as c FROM materials');
    final assetCount = (assets.first['c'] as int?) ?? 0;
    final materialCount = (materials.first['c'] as int?) ?? 0;
    return assetCount + materialCount;
  }

  // ─────────────────────────────────────────
  // PROCUREMENT ORDERS
  // ─────────────────────────────────────────

  /// บันทึกออร์เดอร์ใหม่ คืนค่า id ที่ SQLite generate ให้ (ใช้ผูก items ต่อ)
  Future<int> insertOrder(ProcurementOrder order) async {
    final db = await _db.database;
    final id = await db.insert('procurement_orders', order.toMap());
    await AuditService.instance.log(db, action: 'สร้าง', tableLabel: 'จัดซื้อจัดจ้าง', description: order.projectName ?? 'เอกสาร #$id');
    return id;
  }

  Future<void> updateOrder(ProcurementOrder order) async {
    final db = await _db.database;
    await db.update(
      'procurement_orders',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'จัดซื้อจัดจ้าง', description: order.projectName ?? 'เอกสาร #${order.id}');
  }

  /// ดึงออร์เดอร์ทั้งหมด (สำหรับ Dashboard) เรียงล่าสุดขึ้นก่อน — ใส่
  /// [fiscalYear] เพื่อกรองเฉพาะปีงบนั้น (ใช้กับฟีเจอร์สลับดูปีงบเก่า) ไม่ใส่
  /// ก็ได้ตามปกติเพื่อดึงมาทั้งหมดทุกปี (เช่น ตอนค้นหาข้ามปี)
  Future<List<ProcurementOrder>> getAllOrders({String? fiscalYear}) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_orders',
      where: fiscalYear != null ? 'fiscal_year = ?' : null,
      whereArgs: fiscalYear != null ? [fiscalYear] : null,
      orderBy: 'id DESC',
    );
    return rows.map(ProcurementOrder.fromMap).toList();
  }

  /// รายชื่อปีงบประมาณที่มีโครงการอยู่จริงในระบบ (distinct, เรียงใหม่ไปเก่า) —
  /// ใช้ทำ dropdown สลับปีงบใน AppBar ให้เห็นเฉพาะปีที่มีข้อมูลจริงเท่านั้น
  /// (บวกปีงบปัจจุบันเสมอ แม้ยังไม่มีข้อมูลเลยก็ตาม — ทำที่ฝั่ง UI แยกอีกที)
  Future<List<String>> getDistinctOrderFiscalYears() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT fiscal_year FROM procurement_orders "
      "WHERE fiscal_year IS NOT NULL AND fiscal_year != '' "
      "ORDER BY fiscal_year DESC",
    );
    return rows.map((r) => r['fiscal_year'] as String).toList();
  }

  /// รวมปีงบที่มีข้อมูลจริงจากทั้ง "โครงการ" และ "แผนงบประมาณ" — ปีที่เพิ่งตั้ง
  /// แผนงบไว้ล่วงหน้าแต่ยังไม่มีโครงการ/จัดซื้อเลย (เช่น เพิ่งเริ่มวางแผนปีงบ
  /// ถัดไป) ก็ยังต้องโผล่เป็นตัวเลือกให้สลับกลับมาดูได้ ไม่ใช่แค่ปีที่มีการ
  /// จัดซื้อจริงแล้วเท่านั้น
  Future<List<String>> getDistinctFiscalYears() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT fiscal_year FROM procurement_orders WHERE fiscal_year IS NOT NULL AND fiscal_year != '' "
      "UNION "
      "SELECT DISTINCT fiscal_year FROM budgets WHERE fiscal_year IS NOT NULL AND fiscal_year != '' "
      "ORDER BY fiscal_year DESC",
    );
    return rows.map((r) => r['fiscal_year'] as String).toList();
  }

  /// นับจำนวนโครงการ/แผนงบที่ผูกกับปีงบนี้ — ใช้โชว์ในกล่องยืนยันก่อนลบ/แก้ไข
  /// ปีงบ ให้ผู้ใช้เห็นตัวเลขจริงว่ากระทบกี่รายการก่อนกดยืนยัน
  Future<({int orderCount, int budgetCount})> countFiscalYearData(String year) async {
    final db = await _db.database;
    final orderRows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM procurement_orders WHERE fiscal_year = ?',
      [year],
    );
    final budgetRows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM budgets WHERE fiscal_year = ?',
      [year],
    );
    return (
      orderCount: (orderRows.first['c'] as int?) ?? 0,
      budgetCount: (budgetRows.first['c'] as int?) ?? 0,
    );
  }

  /// เปลี่ยนเลขปีงบของ "โครงการ" และ "แผนงบ" ทั้งหมดที่ติดอยู่กับปีเก่า ไปเป็น
  /// ปีใหม่ — ใช้แก้ตอนพิมพ์ปีงบผิด (เช่น ตั้งใจ 2570 แต่พิมพ์เป็น 2571) โดยไม่
  /// ต้องลบแล้วสร้างใหม่ทุกรายการ ขอบเขตจงใจแค่ 2 ตารางนี้ (ไม่แตะ
  /// annual_counts ซึ่งเป็นคนละฟีเจอร์ — ตรวจนับพัสดุประจำปี ไม่เกี่ยวกับ
  /// ตัวสลับปีงบดูโครงการ/แผนงบตัวนี้)
  Future<void> renameFiscalYear(String oldYear, String newYear) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('procurement_orders', {'fiscal_year': newYear}, where: 'fiscal_year = ?', whereArgs: [oldYear]);
      await txn.update('budgets', {'fiscal_year': newYear}, where: 'fiscal_year = ?', whereArgs: [oldYear]);
    });
    await AuditService.instance.log(
      db,
      action: 'แก้ไข',
      tableLabel: 'ปีงบประมาณ',
      description: 'เปลี่ยนปีงบ $oldYear เป็น $newYear (ทุกโครงการ/แผนงบที่เกี่ยวข้อง)',
    );
  }

  /// ลบโครงการ + แผนงบทั้งหมดของปีงบนี้ทิ้งถาวร — ใช้ deleteOrder() รายตัวแทน
  /// DELETE ตรงๆ เพราะ deleteOrder() จัดการเลิกผูก contracts/inspections/
  /// tor_documents ที่เชื่อมกับ order_id ไว้ให้ก่อนแล้ว (กัน FOREIGN KEY
  /// constraint บล็อกการลบเงียบๆ) ขอบเขตเหมือน renameFiscalYear คือไม่แตะ
  /// annual_counts
  Future<void> deleteFiscalYear(String year) async {
    final db = await _db.database;
    final orderRows = await db.query('procurement_orders', columns: ['id'], where: 'fiscal_year = ?', whereArgs: [year]);
    for (final row in orderRows) {
      await deleteOrder(row['id'] as int);
    }
    await db.delete('budgets', where: 'fiscal_year = ?', whereArgs: [year]);
    await AuditService.instance.log(
      db,
      action: 'ลบ',
      tableLabel: 'ปีงบประมาณ',
      description: 'ลบปีงบ $year ทั้งหมด (${orderRows.length} โครงการ)',
    );
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
  Future<List<ProcurementOrder>> searchOrders(String query, {String? fiscalYear}) async {
    final db = await _db.database;
    // วงเล็บรอบเงื่อนไข OR ทั้งหมด — ถ้าไม่ครอบไว้ SQL จะตีความ AND ท้ายสุด
    // (fiscal_year = ?) ผูกกับแค่เงื่อนไข OR ตัวสุดท้าย (vendor_name) เท่านั้น
    // ตาม operator precedence ปกติของ SQL (AND แน่นกว่า OR) ทำให้กรองปีงบ
    // ไม่ครบทุกเงื่อนไขค้นหา
    final where = StringBuffer(
      '(procurement_number LIKE ? OR order_number LIKE ? OR project_name LIKE ? OR activity_name LIKE ? OR vendor_name LIKE ?)',
    );
    // growable:true — ของเดิมลืมใส่ ทำให้ List.filled() คืนลิสต์ขนาดตายตัว
    // พอ .add(fiscalYear) ด้านล่างเลย throw "Cannot add to a fixed-length list"
    // ทุกครั้งที่ค้นหาพร้อมระบุปีงบ (เพิ่งเจอจาก error จริงตอนทดสอบช่องค้นหา
    // omni ใหม่ — บั๊กนี้มีอยู่เดิมอยู่แล้ว แค่ไม่เคยมีจุดไหนเรียกมาเจอพอดี)
    final whereArgs = List<Object?>.filled(5, '%$query%', growable: true);
    if (fiscalYear != null) {
      where.write(' AND fiscal_year = ?');
      whereArgs.add(fiscalYear);
    }
    final rows = await db.query(
      'procurement_orders',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return rows.map(ProcurementOrder.fromMap).toList();
  }

  /// ลบออร์เดอร์ (items จะถูกลบอัตโนมัติจาก ON DELETE CASCADE)
  /// สัญญา/รายการตรวจรับ/TOR ที่เคยผูกไว้กับเอกสารนี้จะถูก "เลิกผูก" (order_id
  /// เป็น NULL) ก่อนลบเสมอ — ไม่งั้น FOREIGN KEY constraint จะบล็อกการลบเงียบๆ
  /// (throw error โดยไม่มีอะไรแจ้งผู้ใช้ ทำให้ดูเหมือนกดลบแล้วไม่มีอะไรเกิดขึ้น)
  Future<void> deleteOrder(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('contracts', {'order_id': null}, where: 'order_id = ?', whereArgs: [id]);
      await txn.update('inspections', {'order_id': null}, where: 'order_id = ?', whereArgs: [id]);
      await txn.update('tor_documents', {'order_id': null}, where: 'order_id = ?', whereArgs: [id]);
      await txn.delete('procurement_orders', where: 'id = ?', whereArgs: [id]);
    });
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'จัดซื้อจัดจ้าง', description: 'เอกสาร #$id');
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
    }).then((orderId) async {
      final db2 = await _db.database;
      final isNewOrder = order.id == null;
      await AuditService.instance.log(
        db2,
        action: isNewOrder ? 'สร้าง' : 'แก้ไข',
        tableLabel: 'จัดซื้อจัดจ้าง',
        description: order.projectName ?? 'เอกสาร #$orderId',
      );
      // auto-create TOR ที่ผูกกับเอกสารนี้ไว้เลย ถ้ายังไม่เคยมี — เช็คแบบนี้แทนที่
      // จะเช็คแค่ isNewOrder เพราะเอกสารที่เคยบันทึกไว้ก่อนฟีเจอร์นี้จะมีอยู่ (id
      // ไม่ null) แต่ก็ยังไม่เคยมี TOR ผูกไว้เหมือนกัน — กด "บันทึก" ซ้ำครั้งไหน
      // ก็ควรจะสร้าง TOR ให้ถ้ายังไม่มี ไม่ใช่แค่ตอนสร้างใหม่ครั้งแรกเท่านั้น
      final existingTor = await db2.query('tor_documents', where: 'order_id = ?', whereArgs: [orderId], limit: 1);
      if (existingTor.isEmpty) {
        final now = DateTime.now();
        const thaiMonths = [
          '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
          'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
        ];
        final createdDate = '${now.day} ${thaiMonths[now.month]} ${now.year + 543}';
        // "รายละเอียดคุณลักษณะเฉพาะ" เริ่มต้น — ใช้ข้อความเดียวกับที่กรอกไว้แล้ว
        // ในหน้าสร้างโครงการ (หัวเรื่อง + เหตุผลความจำเป็น) แทนการเว้นว่างไว้
        // ผู้ใช้ยังแก้ไขต่อได้เองที่หน้า TOR
        final specParts = <String>[
          if ((order.procurementSubject ?? '').isNotEmpty) 'จัด${order.procurementSubject}',
          if ((order.purposeReason ?? '').isNotEmpty) 'เหตุผลความจำเป็น: ${order.purposeReason}',
        ];
        final id = await db2.insert('tor_documents', TorDocument(
          documentNumber: order.procurementNumber,
          title: order.projectName ?? 'ไม่ระบุชื่อโครงการ',
          category: order.orderType == 'จ้าง' ? 'จ้าง' : null,
          estimatedAmount: order.allocatedAmount ?? order.currentOrderPrice,
          createdDate: createdDate,
          status: 'ร่าง',
          specificationText: specParts.isEmpty ? null : specParts.join('\n\n'),
          orderId: orderId,
        ).toMap());
        await AuditService.instance.log(db2, action: 'สร้าง', tableLabel: 'TOR/คุณลักษณะเฉพาะ', description: '${order.projectName ?? "ไม่ระบุชื่อโครงการ"} (สร้างอัตโนมัติ) #$id');
      } else {
        // TOR ผูกไว้อยู่แล้ว (อาจสร้างไว้ตั้งแต่ก่อนจะมี field พวกนี้) — เติมเฉพาะ
        // ช่องที่ยังว่างอยู่ให้ ไม่แตะช่องที่ผู้ใช้กรอก/แก้ไขเองไปแล้ว
        final existing = TorDocument.fromMap(existingTor.first);
        final specParts = <String>[
          if ((order.procurementSubject ?? '').isNotEmpty) 'จัด${order.procurementSubject}',
          if ((order.purposeReason ?? '').isNotEmpty) 'เหตุผลความจำเป็น: ${order.purposeReason}',
        ];
        final updates = <String, Object?>{};
        if ((existing.documentNumber ?? '').isEmpty && (order.procurementNumber ?? '').isNotEmpty) {
          updates['document_number'] = order.procurementNumber;
        }
        if ((existing.specificationText ?? '').isEmpty && specParts.isNotEmpty) {
          updates['specification_text'] = specParts.join('\n\n');
        }
        if (existing.estimatedAmount == null && (order.allocatedAmount ?? order.currentOrderPrice) != null) {
          updates['estimated_amount'] = order.allocatedAmount ?? order.currentOrderPrice;
        }
        if (updates.isNotEmpty) {
          await db2.update('tor_documents', updates, where: 'id = ?', whereArgs: [existing.id]);
        }
      }

      // auto-สร้าง/อัปเดตสัญญาในหน้า "บริหารสัญญา" ให้ตามโครงการนี้เสมอ ทุกครั้งที่
      // กดบันทึก — ผู้ใช้ยืนยันแล้วว่าไม่อยากมาเพิ่มเองซ้ำ ต่างจาก TOR ด้านบนตรงที่
      // จุดนี้ "ทับ" ค่าที่ดึงมาจากโครงการทุกครั้ง (ไม่ใช่แค่เติมช่องว่าง) เพราะ
      // ผู้ใช้เลือกให้สัญญาที่ผูกไว้อัปเดตตามโครงการเสมอเวลาแก้ผู้ขาย/วงเงิน —
      // ไม่แตะช่องที่มีแค่ในหน้าสัญญาเอง (ประเภทสัญญา/วันที่สิ้นสุด/จำนวนงวด/
      // สถานะ) เพราะโครงการไม่มีข้อมูลพวกนี้ให้ดึง
      final existingContract =
          await db2.query('contracts', where: 'order_id = ?', whereArgs: [orderId], orderBy: 'id DESC', limit: 1);
      final contractAmount = order.currentOrderPrice ?? order.netPayableAmount ?? order.allocatedAmount;
      if (existingContract.isEmpty) {
        final id = await db2.insert('contracts', Contract(
          contractNumber: order.contractControlNumber,
          egpNumber: order.egpProjectId,
          orderId: orderId,
          contractType: order.orderType == 'จ้าง' ? 'ใบสั่งจ้าง' : (order.orderType == 'ซื้อ' ? 'ใบสั่งซื้อ' : null),
          contractAmount: contractAmount,
          vendorName: order.vendorName,
          startDate: order.dateContractSigned,
        ).toMap());
        await AuditService.instance.log(
          db2,
          action: 'สร้าง',
          tableLabel: 'บริหารสัญญา',
          description: '${order.contractControlNumber ?? order.projectName ?? "ไม่มีเลขที่สัญญา"} (สร้างอัตโนมัติ) #$id',
        );
      } else {
        final existing = Contract.fromMap(existingContract.first);
        await db2.update(
          'contracts',
          {
            'contract_number': order.contractControlNumber,
            'egp_number': order.egpProjectId,
            'vendor_name': order.vendorName,
            'contract_amount': contractAmount,
            'start_date': order.dateContractSigned,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
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
    await AuditService.instance.log(db, action: 'แก้ไข', tableLabel: 'ข้อมูลโรงเรียน', description: settings.schoolName ?? 'ตั้งค่าโรงเรียน');
  }

  // ─────────────────────────────────────────
  // CONTROL LOG (ทะเบียนคุมเลขที่บันทึกข้อความ/คำสั่ง/TOR)
  // ไม่ใช่ตารางแยก — รวบรวมเลขที่ควบคุมที่มีอยู่แล้วกระจายอยู่หลายตาราง
  // (procurement_orders, tor_documents, contracts, inspections) มาแสดงที่เดียว
  // ─────────────────────────────────────────

  Future<List<ControlLogEntry>> getControlLogEntries() async {
    final orders = await getAllOrders();
    final budgets = await getAllBudgets();
    final budgetsById = {for (final b in budgets) if (b.id != null) b.id!: b};
    final ordersById = {for (final o in orders) if (o.id != null) o.id!: o};
    final tors = await getAllTorDocuments();
    final contracts = await getAllContracts();
    final inspections = await getAllInspections();

    String? deptOf(ProcurementOrder? o) => o?.budgetId != null ? budgetsById[o!.budgetId]?.groupName : null;
    String? personOf(ProcurementOrder? o) => o?.ownerName ?? (o?.budgetId != null ? budgetsById[o!.budgetId]?.responsiblePerson : null);
    String projectLabelOf(ProcurementOrder? o) =>
        o?.projectName ?? o?.procurementSubject ?? '(ไม่ระบุชื่อรายการ)';

    final entries = <ControlLogEntry>[];

    for (final o in orders) {
      if (o.procurementNumber?.trim().isNotEmpty ?? false) {
        entries.add(ControlLogEntry(
          controlNumber: o.procurementNumber!,
          docType: 'รายงานขอซื้อ/จ้าง',
          dateText: o.dateOrderCreated,
          description: projectLabelOf(o),
          amount: o.currentOrderPrice ?? o.allocatedAmount,
          department: deptOf(o),
          responsiblePerson: personOf(o),
          fiscalYear: o.fiscalYear ?? '-',
          orderId: o.id,
        ));
      }
      if (o.orderNumber?.trim().isNotEmpty ?? false) {
        entries.add(ControlLogEntry(
          controlNumber: o.orderNumber!,
          docType: 'ใบสั่งซื้อ/สั่งจ้าง',
          dateText: o.dateContractSigned,
          description: projectLabelOf(o),
          amount: o.currentOrderPrice ?? o.allocatedAmount,
          department: deptOf(o),
          responsiblePerson: personOf(o),
          fiscalYear: o.fiscalYear ?? '-',
          orderId: o.id,
        ));
      }
    }

    for (final t in tors) {
      if (!(t.documentNumber?.trim().isNotEmpty ?? false)) continue;
      final o = ordersById[t.orderId];
      entries.add(ControlLogEntry(
        controlNumber: t.documentNumber!,
        docType: 'เอกสาร TOR/รายละเอียดคุณลักษณะ',
        dateText: t.createdDate,
        description: t.title,
        amount: t.estimatedAmount,
        department: deptOf(o),
        responsiblePerson: personOf(o),
        fiscalYear: o?.fiscalYear ?? '-',
        orderId: t.orderId,
      ));
    }

    for (final c in contracts) {
      if (!(c.contractNumber?.trim().isNotEmpty ?? false)) continue;
      final o = ordersById[c.orderId];
      entries.add(ControlLogEntry(
        controlNumber: c.contractNumber!,
        docType: c.contractType ?? 'สัญญา/ใบสั่งซื้อสั่งจ้าง',
        dateText: c.startDate,
        description: c.vendorName ?? projectLabelOf(o),
        amount: c.contractAmount,
        department: deptOf(o),
        responsiblePerson: personOf(o),
        fiscalYear: o?.fiscalYear ?? '-',
        orderId: c.orderId,
      ));
    }

    for (final i in inspections) {
      if (!(i.inspectionNumber?.trim().isNotEmpty ?? false)) continue;
      final o = ordersById[i.orderId];
      entries.add(ControlLogEntry(
        controlNumber: i.inspectionNumber!,
        docType: 'ใบตรวจรับพัสดุ',
        dateText: i.actualDeliveryDate ?? i.dueDate,
        description: projectLabelOf(o),
        amount: o?.currentOrderPrice,
        department: deptOf(o),
        responsiblePerson: personOf(o),
        fiscalYear: o?.fiscalYear ?? '-',
        orderId: i.orderId,
      ));
    }

    return entries;
  }

  // ─────────────────────────────────────────
  // PROCUREMENT INSTALLMENTS (งวดการเบิกจ่าย — สัญญาต่อเนื่องหลายเดือน
  // เช่น จ้างเหมาประกอบอาหารกลางวัน)
  // ─────────────────────────────────────────

  Future<List<ProcurementInstallment>> getInstallments(int orderId) async {
    final db = await _db.database;
    final rows = await db.query(
      'procurement_installments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'period_no ASC',
    );
    return rows.map(ProcurementInstallment.fromMap).toList();
  }

  /// รายชื่อ order ที่เป็น "สัญญาต่อเนื่องหลายเดือน" — ใช้แสดงในหน้า
  /// "สัญญาต่อเนื่อง/อาหารกลางวัน" แยกต่างหากจาก order ปกติ นับทั้ง order
  /// ที่ติ๊กธง is_recurring_contract ไว้ (ทางหลัก) และ order ที่มีงวดการ
  /// เบิกจ่ายอยู่แล้วแต่ยังไม่ได้ติ๊กธง (กันข้อมูลเก่าก่อนมีธงนี้ตกหล่น)
  Future<List<ProcurementOrder>> getRecurringContractOrders() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT id FROM procurement_orders WHERE is_recurring_contract = 1
      UNION
      SELECT DISTINCT order_id AS id FROM procurement_installments
      ORDER BY id DESC
    ''');
    final orders = <ProcurementOrder>[];
    for (final row in rows) {
      final orderId = row['id'] as int;
      final orderRows = await db.query('procurement_orders', where: 'id = ?', whereArgs: [orderId]);
      if (orderRows.isNotEmpty) orders.add(ProcurementOrder.fromMap(orderRows.first));
    }
    return orders;
  }

  Future<int> saveInstallment(ProcurementInstallment installment) async {
    final db = await _db.database;
    if (installment.id == null) {
      final id = await db.insert('procurement_installments', installment.toMap());
      await AuditService.instance.log(
        db,
        action: 'สร้าง',
        tableLabel: 'งวดการเบิกจ่าย',
        description: 'งวดที่ ${installment.periodNo} (order #${installment.orderId})',
      );
      return id;
    } else {
      await db.update(
        'procurement_installments',
        installment.toMap(),
        where: 'id = ?',
        whereArgs: [installment.id],
      );
      await AuditService.instance.log(
        db,
        action: 'แก้ไข',
        tableLabel: 'งวดการเบิกจ่าย',
        description: 'งวดที่ ${installment.periodNo} (order #${installment.orderId})',
      );
      return installment.id!;
    }
  }

  Future<void> deleteInstallment(int id) async {
    final db = await _db.database;
    await db.delete('procurement_installments', where: 'id = ?', whereArgs: [id]);
    await AuditService.instance.log(db, action: 'ลบ', tableLabel: 'งวดการเบิกจ่าย', description: 'งวด #$id');
  }

  /// ตั้ง/ถอนธง "สัญญาต่อเนื่องหลายเดือน" ให้ order ที่มีอยู่แล้วโดยตรง
  /// (ไม่ต้องเปิด wizard ทั้งหน้าแค่เพื่อแก้ค่านี้ค่าเดียว)
  Future<void> setRecurringContractFlag(int orderId, bool value) async {
    final db = await _db.database;
    await db.update(
      'procurement_orders',
      {'is_recurring_contract': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}