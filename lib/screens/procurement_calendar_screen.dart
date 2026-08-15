// procurement_calendar_screen.dart
// "ปฏิทินงานพัสดุประจำปี" — รวมงานประจำที่เจ้าหน้าที่พัสดุต้องทำในแต่ละเดือนของ
// ปีงบประมาณ (ต.ค.-ก.ย.) ไว้ที่เดียว ติ๊กเครื่องหมายว่าทำแล้วได้ (บันทึกไว้ในเครื่อง
// ต่อปีงบ ไม่ผูกกับข้อมูลอื่นในระบบ) — เป็นแนวทางเบื้องต้นทั่วไป ไม่ใช่ระเบียบ
// ทางกฎหมายที่ต้องทำตามเป๊ะทุกข้อ แต่ละโรงเรียนอาจมีรายละเอียดต่างกันได้

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/procurement_calendar_task.dart';
import '../widgets/guide_panel.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/app_card.dart';
import '../widgets/design_system/data_table_shell.dart' show DsCheckbox;
import '../widgets/design_system/progress_indicators.dart' show ProgressBar;

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
                _buildHeader(context, colors),
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
                            return _buildMonthCard(context, colors, month, isCurrentMonth);
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

  Widget _buildHeader(BuildContext context, ColorScheme colors) {
    final isCurrentYear = _fiscalYear == _currentFiscalYear;
    return Row(
      children: [
        Icon(Icons.event_note_outlined, color: BrandAccent.tealOn(context), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text('ปฏิทินงานพัสดุประจำปี',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppTypography.heading2, fontWeight: AppTypography.weightExtraBold, color: colors.onSurface)),
        ),
        _navIconButton(context, icon: Icons.chevron_left, tooltip: 'ปีงบก่อนหน้า', onTap: () => _changeFiscalYear(-1)),
        const SizedBox(width: 8),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrentYear ? BrandAccent.teal(context) : BrandAccent.surface2(context),
            borderRadius: BorderRadius.circular(RadiusSize.md),
            border: Border.all(color: isCurrentYear ? BrandAccent.teal(context) : colors.outline),
          ),
          child: Text('ปีงบประมาณ $_fiscalYear',
              style: TextStyle(
                fontSize: AppTypography.bodyMedium,
                fontWeight: AppTypography.weightBold,
                color: isCurrentYear ? Colors.white : colors.onSurface,
              )),
        ),
        const SizedBox(width: 8),
        _navIconButton(context, icon: Icons.chevron_right, tooltip: 'ปีงบถัดไป', onTap: () => _changeFiscalYear(1)),
      ],
    );
  }

  Widget _navIconButton(BuildContext context, {required IconData icon, required String tooltip, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RadiusSize.md),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RadiusSize.md),
              border: Border.all(color: colors.outline),
            ),
            child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCard(BuildContext context, ColorScheme colors, ProcurementCalendarMonth month, bool isCurrentMonth) {
    final doneCount = month.tasks
        .where((t) => _checkedIds.contains('${month.calendarMonth}_${month.buddhistYear}_${t.slug}'))
        .length;
    final total = month.tasks.length;
    return Container(
      // [แก้บั๊ก border ซ้อนกันจนมองไม่เห็น]: เดิมไม่มี padding คั่น ทำให้กรอบ
      // ไฮไลต์ teal ของเดือนปัจจุบันวาดทับกันพอดีกับกรอบ colorScheme.outline
      // เริ่มต้นของ AppCard เอง (ขนาดกล่องเท่ากันเป๊ะ) เส้นสีเทาบางๆ ของ AppCard
      // จะวาดทีหลังทับเส้น teal เกือบมิด เหลือให้เห็นแค่ริ้วบางๆ แทบสังเกตไม่ออก
      // ว่าเดือนนี้ถูกไฮไลต์อยู่ — ใส่ padding เล็กน้อยให้เกิดช่องว่างจริงระหว่าง
      // กรอบไฮไลต์ด้านนอกกับกรอบการ์ดด้านใน เห็นเป็นวงแหวนไฮไลต์ชัดเจน
      padding: isCurrentMonth ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RadiusSize.card),
        border: isCurrentMonth ? Border.all(color: BrandAccent.teal(context), width: 1.6) : null,
      ),
      child: AppCard(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(month.label, style: TextStyle(fontWeight: AppTypography.weightExtraBold, fontSize: AppTypography.heading4, color: colors.onSurface)),
            if (isCurrentMonth) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: BrandAccent.teal(context), borderRadius: BorderRadius.circular(RadiusSize.full)),
                child: const Text('เดือนนี้', style: TextStyle(fontSize: AppTypography.caption, color: Colors.white, fontWeight: AppTypography.weightBold)),
              ),
            ],
          ],
        ),
        titleAction: SizedBox(
          width: 140,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 90, child: ProgressBar(progress: total == 0 ? 0 : doneCount / total, height: 6)),
              const SizedBox(width: 8),
              Text('$doneCount/$total',
                  style: TextStyle(fontSize: AppTypography.caption, fontWeight: AppTypography.weightBold, color: colors.onSurfaceVariant)),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final task in month.tasks) _buildTaskRow(context, colors, month, task),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, ColorScheme colors, ProcurementCalendarMonth month, ProcurementCalendarTaskDef task) {
    final taskId = '${month.calendarMonth}_${month.buddhistYear}_${task.slug}';
    final done = _checkedIds.contains(taskId);
    return InkWell(
      onTap: () => _toggleTask(taskId),
      borderRadius: BorderRadius.circular(RadiusSize.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: DsCheckbox(value: done, onChanged: (_) => _toggleTask(taskId)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: AppTypography.bodyMedium,
                  color: done ? colors.onSurfaceVariant : colors.onSurface,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
