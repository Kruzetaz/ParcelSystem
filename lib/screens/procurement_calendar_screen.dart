// procurement_calendar_screen.dart
// "ปฏิทินงานพัสดุประจำปี" — รวมงานประจำที่เจ้าหน้าที่พัสดุต้องทำในแต่ละเดือนของ
// ปีงบประมาณ (ต.ค.-ก.ย.) ไว้ที่เดียว ติ๊กเครื่องหมายว่าทำแล้วได้ (บันทึกไว้ในเครื่อง
// ต่อปีงบ ไม่ผูกกับข้อมูลอื่นในระบบ) — เป็นแนวทางเบื้องต้นทั่วไป ไม่ใช่ระเบียบ
// ทางกฎหมายที่ต้องทำตามเป๊ะทุกข้อ แต่ละโรงเรียนอาจมีรายละเอียดต่างกันได้

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/procurement_calendar_task.dart';
import '../widgets/guide_panel.dart';

class ProcurementCalendarScreen extends StatefulWidget {
  const ProcurementCalendarScreen({super.key});
  @override
  State<ProcurementCalendarScreen> createState() => _ProcurementCalendarScreenState();
}

class _ProcurementCalendarScreenState extends State<ProcurementCalendarScreen> {
  late int _fiscalYear;
  late final int _currentFiscalYear;
  Set<String> _checkedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentFiscalYear = fiscalYearOf(DateTime.now());
    _fiscalYear = _currentFiscalYear;
    _loadChecked();
  }

  String get _prefsKey => 'procurement_calendar_checked_$_fiscalYear';

  Future<void> _loadChecked() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _checkedIds = (prefs.getStringList(_prefsKey) ?? []).toSet();
      _loading = false;
    });
  }

  Future<void> _toggleTask(String taskId) async {
    setState(() {
      if (_checkedIds.contains(taskId)) {
        _checkedIds.remove(taskId);
      } else {
        _checkedIds.add(taskId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _checkedIds.toList());
  }

  void _changeFiscalYear(int delta) {
    setState(() => _fiscalYear += delta);
    _loadChecked();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final months = buildFiscalYearCalendar(_fiscalYear);
    final now = DateTime.now();

    return GuideFabOverlay(
      title: 'วิธีใช้ปฏิทินงานพัสดุประจำปี',
      icon: Icons.event_note_outlined,
      // แถบหัวข้อ + ลูกศรเปลี่ยนปีงบอยู่ชิดขวาบนพอดี ชนกับปุ่มไกด์มุมขวาบน
      // (ค่า default) — หน้านี้ไม่มีปุ่มลอยอื่นเลย ย้ายไปมุมขวาล่างแทน
      corner: Alignment.bottomRight,
      steps: const [
        'รวมงานประจำที่เจ้าหน้าที่พัสดุมักต้องทำในแต่ละเดือนของปีงบประมาณ (ต.ค.-ก.ย.) ไว้ที่เดียว เพื่อกันลืมกำหนดส่งรายงาน/ตรวจนับพัสดุ',
        'ติ๊กเครื่องหมายหน้ารายการที่ทำเสร็จแล้วได้ ระบบจะจำไว้ในเครื่องนี้แยกตามปีงบ',
        'เดือนที่มีกรอบไฮไลต์คือเดือนปัจจุบัน เลื่อนเปลี่ยนปีงบประมาณดูล่วงหน้า/ย้อนหลังได้ที่ลูกศรด้านบน',
        'เป็นแนวทางเบื้องต้นทั่วไปเท่านั้น ไม่ใช่ระเบียบทางกฎหมายที่ต้องทำตามเป๊ะทุกข้อ แต่ละโรงเรียนอาจมีรายละเอียด/กำหนดการต่างกันได้ โปรดตรวจสอบกับระเบียบ/ผู้บังคับบัญชาของหน่วยงานอีกครั้ง',
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(colors),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: months.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final month = months[i];
                            final isCurrentMonth =
                                month.calendarMonth == now.month && month.buddhistYear == now.year + 543;
                            return _buildMonthCard(colors, month, isCurrentMonth);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Row(
      children: [
        Icon(Icons.event_note_outlined, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text('ปฏิทินงานพัสดุประจำปี',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.onSurface)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'ปีงบก่อนหน้า',
          onPressed: () => _changeFiscalYear(-1),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _fiscalYear == _currentFiscalYear ? colors.primaryContainer : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('ปีงบประมาณ $_fiscalYear',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurface)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'ปีงบถัดไป',
          onPressed: () => _changeFiscalYear(1),
        ),
      ],
    );
  }

  Widget _buildMonthCard(ColorScheme colors, ProcurementCalendarMonth month, bool isCurrentMonth) {
    final doneCount = month.tasks
        .where((t) => _checkedIds.contains('${month.calendarMonth}_${month.buddhistYear}_${t.slug}'))
        .length;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isCurrentMonth ? colors.primary : colors.outlineVariant, width: isCurrentMonth ? 1.6 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(month.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.onSurface)),
                if (isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)),
                    child: Text('เดือนนี้', style: TextStyle(fontSize: 11, color: colors.onPrimary, fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                Text('$doneCount/${month.tasks.length} เสร็จแล้ว',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              ],
            ),
            const Divider(height: 16),
            for (final task in month.tasks) _buildTaskRow(colors, month, task),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(ColorScheme colors, ProcurementCalendarMonth month, ProcurementCalendarTaskDef task) {
    final taskId = '${month.calendarMonth}_${month.buddhistYear}_${task.slug}';
    final done = _checkedIds.contains(taskId);
    return InkWell(
      onTap: () => _toggleTask(taskId),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: done, onChanged: (_) => _toggleTask(taskId)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: done ? colors.onSurfaceVariant : colors.onSurface,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
