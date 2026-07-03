// settings_screen.dart
// หน้ากรอกข้อมูลโรงเรียน — กรอกครั้งเดียว บันทึกลง DB (แถวเดียวเสมอ id = 1)
// ใช้ค่าจากตรงนี้ไปเติม {{school_name}}, {{school_amphoe}} ฯลฯ ในเอกสารทุกใบ

import 'package:flutter/material.dart';
import '../data/procurement_repository.dart';
import '../models/school_settings.dart';

const _brandColor = Color(0xFF1A3A5C);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = ProcurementRepository();

  late final TextEditingController _schoolNameCtrl;
  late final TextEditingController _schoolAddressNoCtrl;
  late final TextEditingController _schoolSubdistrictCtrl;
  late final TextEditingController _schoolAmphoeCtrl;
  late final TextEditingController _schoolChangwatCtrl;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schoolNameCtrl = TextEditingController();
    _schoolAddressNoCtrl = TextEditingController();
    _schoolSubdistrictCtrl = TextEditingController();
    _schoolAmphoeCtrl = TextEditingController();
    _schoolChangwatCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repo.getSchoolSettings();
    if (!mounted) return;
    if (settings != null) {
      _schoolNameCtrl.text = settings.schoolName ?? '';
      _schoolAddressNoCtrl.text = settings.schoolAddressNo ?? '';
      _schoolSubdistrictCtrl.text = settings.schoolSubdistrict ?? '';
      _schoolAmphoeCtrl.text = settings.schoolAmphoe ?? '';
      _schoolChangwatCtrl.text = settings.schoolChangwat ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _schoolAddressNoCtrl.dispose();
    _schoolSubdistrictCtrl.dispose();
    _schoolAmphoeCtrl.dispose();
    _schoolChangwatCtrl.dispose();
    super.dispose();
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
      );
      await _repo.saveSchoolSettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลโรงเรียนสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('ข้อมูลโรงเรียน'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ข้อมูลนี้จะถูกใช้เติมในเอกสารทุกใบที่สร้าง '
                            '(กรอกครั้งเดียว ไม่ต้องกรอกซ้ำทุกครั้ง)',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _schoolNameCtrl,
                            decoration: _inputDecoration('ชื่อโรงเรียน'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _schoolAddressNoCtrl,
                            decoration: _inputDecoration('เลขที่ตั้ง/ที่อยู่'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _schoolSubdistrictCtrl,
                                  decoration: _inputDecoration('ตำบล/แขวง'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _schoolAmphoeCtrl,
                                  decoration: _inputDecoration('อำเภอ/เขต'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _schoolChangwatCtrl,
                            decoration: _inputDecoration('จังหวัด'),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _brandColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}