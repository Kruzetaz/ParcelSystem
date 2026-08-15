// settings_screen.dart
// หน้ากรอกข้อมูลโรงเรียน — กรอกครั้งเดียว บันทึกลง DB (แถวเดียวเสมอ id = 1)
// ใช้ค่าจากตรงนี้ไปเติม {{school_name}}, {{school_amphoe}} ฯลฯ ในเอกสารทุกใบ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/school_settings.dart';
import '../services/current_user_service.dart';
import '../services/toast_service.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/app_card.dart';
import 'personnel_tab.dart';
import 'work_groups_tab.dart';
import 'vendor_management_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final _repo = ProcurementRepository();
  late final TabController _tabController;

  late final TextEditingController _schoolNameCtrl;
  late final TextEditingController _schoolAddressNoCtrl;
  late final TextEditingController _schoolSubdistrictCtrl;
  late final TextEditingController _schoolAmphoeCtrl;
  late final TextEditingController _schoolChangwatCtrl;
  late final TextEditingController _schoolPhoneCtrl;
  late final TextEditingController _directorNameCtrl;
  late final TextEditingController _procurementOfficerCtrl;
  late final TextEditingController _procurementHeadCtrl;
  late final TextEditingController _financeOfficerCtrl;
  late final TextEditingController _currentUserCtrl;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserCtrl = TextEditingController();
    _schoolNameCtrl = TextEditingController();
    _schoolAddressNoCtrl = TextEditingController();
    _schoolSubdistrictCtrl = TextEditingController();
    _schoolAmphoeCtrl = TextEditingController();
    _schoolChangwatCtrl = TextEditingController();
    _schoolPhoneCtrl = TextEditingController();
    _directorNameCtrl = TextEditingController();
    _procurementOfficerCtrl = TextEditingController();
    _procurementHeadCtrl = TextEditingController();
    _financeOfficerCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repo.getSchoolSettings();
    final userName = await CurrentUserService.instance.getName();
    if (!mounted) return;
    if (userName != 'ไม่ระบุชื่อ') _currentUserCtrl.text = userName;
    if (settings != null) {
      _schoolNameCtrl.text = settings.schoolName ?? '';
      _schoolAddressNoCtrl.text = settings.schoolAddressNo ?? '';
      _schoolSubdistrictCtrl.text = settings.schoolSubdistrict ?? '';
      _schoolAmphoeCtrl.text = settings.schoolAmphoe ?? '';
      _schoolChangwatCtrl.text = settings.schoolChangwat ?? '';
      _schoolPhoneCtrl.text = settings.schoolPhone ?? '';
      _directorNameCtrl.text = settings.directorName ?? '';
      _procurementOfficerCtrl.text = settings.procurementOfficer ?? '';
      _procurementHeadCtrl.text = settings.procurementHead ?? '';
      _financeOfficerCtrl.text = settings.financeOfficer ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _currentUserCtrl.dispose();
    _schoolNameCtrl.dispose();
    _schoolAddressNoCtrl.dispose();
    _schoolSubdistrictCtrl.dispose();
    _schoolAmphoeCtrl.dispose();
    _schoolChangwatCtrl.dispose();
    _schoolPhoneCtrl.dispose();
    _directorNameCtrl.dispose();
    _procurementOfficerCtrl.dispose();
    _procurementHeadCtrl.dispose();
    _financeOfficerCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentUser() async {
    await CurrentUserService.instance.setName(_currentUserCtrl.text);
    showAppToast('บันทึกชื่อผู้ใช้งานแล้ว');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = SchoolSettings(
        schoolName: _schoolNameCtrl.text.trim(),
        schoolAddressNo: _schoolAddressNoCtrl.text.trim(),
        schoolSubdistrict: _schoolSubdistrictCtrl.text.trim(),
        schoolAmphoe: _schoolAmphoeCtrl.text.trim(),
        schoolChangwat: _schoolChangwatCtrl.text.trim(),
        schoolPhone: _schoolPhoneCtrl.text.trim(),
        directorName: _directorNameCtrl.text.trim(),
        procurementOfficer: _procurementOfficerCtrl.text.trim(),
        procurementHead: _procurementHeadCtrl.text.trim(),
        financeOfficer: _financeOfficerCtrl.text.trim(),
      );
      await _repo.saveSchoolSettings(settings);
      if (!mounted) return;
      showAppToast('บันทึกข้อมูลโรงเรียนสำเร็จ');
    } catch (e) {
      if (!mounted) return;
      showAppToast('บันทึกไม่สำเร็จ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.weightSemiBold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md), borderSide: BorderSide(color: colors.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md), borderSide: BorderSide(color: colors.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RadiusSize.md), borderSide: BorderSide(color: BrandAccent.teal(context), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : GuideFabOverlay(
            title: 'ตั้งค่าโรงเรียนไว้ทำไม',
            icon: Icons.school_outlined,
            // ปุ่มไกด์ปกติอยู่มุมบนขวา แต่หน้านี้มี TabBar เต็มความกว้างด้านบน
            // (4 แท็บ) ชนกันพอดี — ย้ายไปมุมล่างซ้ายแทน (แท็บ บุคลากร/กลุ่มงาน/
            // ร้านค้า มีปุ่ม + ลอยอยู่มุมล่างขวาของตัวเองอยู่แล้ว ต้องเลี่ยงมุมนั้นด้วย)
            corner: Alignment.bottomLeft,
            steps: const [
              'ข้อมูลทั้งหมดในหน้านี้ถูกใช้เติมลงในเอกสารราชการทุกใบที่สร้างโดยอัตโนมัติ ไม่ต้องพิมพ์ซ้ำทีละใบ',
              'แนะนำให้กรอกให้ครบก่อนเริ่มสร้างคำสั่งซื้อ/สั่งจ้างใบแรก จะได้ไม่ต้องย้อนมาแก้เอกสารที่สร้างไปแล้ว',
              'ชื่อผู้ใช้งาน (ด้านบน) ใช้แค่ประทับชื่อในประวัติการใช้งาน (Audit Trail) เท่านั้น ไม่ใช่รหัสผ่านหรือบัญชีเข้าระบบ',
              'ชื่อผู้อำนวยการ/เจ้าหน้าที่พัสดุ/หัวหน้าเจ้าหน้าที่พัสดุ/เจ้าหน้าที่การเงิน จะไปเป็นค่าเริ่มต้นในทุกเอกสาร แก้ที่นี่ที่เดียวจบ',
              'ชื่อโรงเรียนที่กรอกในนี้ยังใช้เป็นชื่อโฟลเดอร์เก็บไฟล์เอกสาร/รูป/ไฟล์ backup ของระบบด้วย',
              'แท็บ "บุคลากร" คือทำเนียบครู/เจ้าหน้าที่กลาง — เพิ่มไว้ที่นี่แล้วช่องกรอกชื่อ-ตำแหน่งในหน้าสร้างเอกสารจะเลือกใช้ซ้ำได้ทันที',
            ],
            child: Column(
              children: [
                Container(
                  color: colors.primary,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: colors.onPrimary,
                    indicatorWeight: 3,
                    labelColor: colors.onPrimary,
                    unselectedLabelColor: colors.onPrimary.withValues(alpha: 0.7),
                    labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'ข้อมูลโรงเรียน'),
                      Tab(text: 'บุคลากร'),
                      Tab(text: 'กลุ่มงาน'),
                      Tab(text: 'ผู้รับจ้าง/ร้านค้า'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSchoolInfoTab(colors),
                      const PersonnelTab(),
                      const WorkGroupsTab(),
                      const VendorManagementTab(),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildSchoolInfoTab(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              AppCard(
                title: 'ผู้ใช้งานปัจจุบัน',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ใช้ประทับชื่อในบันทึกประวัติการใช้งาน (Audit Trail) เท่านั้น ไม่ใช่รหัสผ่าน',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _currentUserCtrl,
                            style: const TextStyle(fontSize: 17),
                            decoration: _inputDecoration('ชื่อผู้ใช้งาน'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: BrandAccent.teal(context),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                            textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _saveCurrentUser,
                          child: const Text('บันทึก'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                title: 'ข้อมูลโรงเรียน',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ข้อมูลนี้จะถูกใช้เติมในเอกสารทุกใบที่สร้าง (กรอกครั้งเดียว ไม่ต้องกรอกซ้ำทุกครั้ง)',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _schoolNameCtrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: _inputDecoration('ชื่อโรงเรียน'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _schoolAddressNoCtrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: _inputDecoration('เลขที่ตั้ง/ที่อยู่'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _schoolSubdistrictCtrl,
                            style: const TextStyle(fontSize: 17),
                            decoration: _inputDecoration('ตำบล/แขวง'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _schoolAmphoeCtrl,
                            style: const TextStyle(fontSize: 17),
                            decoration: _inputDecoration('อำเภอ/เขต'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _schoolChangwatCtrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: _inputDecoration('จังหวัด'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _schoolPhoneCtrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: _inputDecoration('เบอร์โทรโรงเรียน'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 28),
                    Divider(color: colors.outline),
                    const SizedBox(height: 18),
                    Text(
                      'ผู้บริหารและเจ้าหน้าที่ประจำโรงเรียน',
                      style: TextStyle(
                        fontWeight: AppTypography.weightExtraBold,
                        fontSize: AppTypography.heading4,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ใช้เป็นค่าเริ่มต้นในทุกเอกสารที่สร้าง ไม่ต้องกรอกซ้ำในแต่ละใบ',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: AppTypography.bodyMedium),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _directorNameCtrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: _inputDecoration('ผู้อำนวยการโรงเรียน'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _procurementOfficerCtrl,
                            style: const TextStyle(fontSize: 17),
                            decoration: _inputDecoration('เจ้าหน้าที่พัสดุ'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _procurementHeadCtrl,
                            style: const TextStyle(fontSize: 17),
                            decoration: _inputDecoration('หัวหน้าเจ้าหน้าที่พัสดุ'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _financeOfficerCtrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: _inputDecoration('เจ้าหน้าที่การเงิน'),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandAccent.teal(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusSize.md)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

