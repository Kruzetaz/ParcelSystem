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
import '../models/material_item.dart';
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

  Future<List<TorDocument>> getAllTorDocuments() async {
    final db = await _db.database;
    final rows = await db.query('tor_documents', orderBy: 'id DESC');
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

  Future<List<Contract>> getAllContracts() async {
    final db = await _db.database;
    final rows = await db.query('contracts', orderBy: 'id DESC');
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

  Future<List<Guarantee>> getAllGuarantees() async {
    final db = await _db.database;
    final rows = await db.query('guarantees', orderBy: 'id DESC');
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

  Future<List<Inspection>> getAllInspections() async {
    final db = await _db.database;
    final rows = await db.query('inspections', orderBy: 'id DESC');
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
          'procurement_number LIKE ? OR order_number LIKE ? OR project_name LIKE ? OR activity_name LIKE ? OR vendor_name LIKE ?',
      whereArgs: List.filled(5, '%$query%'),
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
}