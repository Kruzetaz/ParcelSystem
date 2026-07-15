// thai_date_picker.dart
// ปฏิทินเลือกวันที่แบบไทย — มี dropdown เดือน/ปี (พ.ศ.) ให้กระโดดข้ามปีได้เร็ว
// และปุ่มสลับไปโหมด "พิมพ์เอง" กรอกเป็น วว/ดด/ปปปป (พ.ศ.) เช่น 24/01/2569
// หรือ วว เดือนย่อ ปปปป เช่น 24 มี.ค. 2569 ก็ได้ทั้งคู่

import 'package:flutter/material.dart';

const _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];
const _thaiWeekdaysShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

/// เปิดกล่องเลือกวันที่แบบไทย คืนค่า [DateTime] (ปฏิทินสากล ค.ศ. ตามปกติของ Dart)
/// หรือ null ถ้ากดยกเลิก — ใช้แทน showDatePicker ของ Flutter เดิมทุกจุดในแอป
Future<DateTime?> pickThaiDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  Color? primaryColor,
  Color? onPrimaryColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _ThaiDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      primaryColor: primaryColor ?? scheme.primary,
      onPrimaryColor: onPrimaryColor ?? scheme.onPrimary,
    ),
  );
}

class _ThaiDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? helpText;
  final Color primaryColor;
  final Color onPrimaryColor;

  const _ThaiDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    required this.primaryColor,
    required this.onPrimaryColor,
  });

  @override
  State<_ThaiDatePickerDialog> createState() => _ThaiDatePickerDialogState();
}

class _ThaiDatePickerDialogState extends State<_ThaiDatePickerDialog> {
  late DateTime _selected;
  late DateTime _viewMonth; // วันที่ 1 ของเดือนที่กำลังแสดงในปฏิทิน
  bool _manualMode = false;
  late final TextEditingController _manualCtrl;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    _selected = _clampToRange(widget.initialDate);
    _viewMonth = DateTime(_selected.year, _selected.month);
    _manualCtrl = TextEditingController(text: _formatSlash(_selected));
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  DateTime _clampToRange(DateTime d) {
    if (d.isBefore(widget.firstDate)) return widget.firstDate;
    if (d.isAfter(widget.lastDate)) return widget.lastDate;
    return d;
  }

  String _formatSlash(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';

  DateTime? _parseManual(String raw) {
    final s = raw.trim();
    // รูปแบบ วว/ดด/ปปปป (พ.ศ.)
    final slash = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(s);
    if (slash != null) {
      final day = int.parse(slash.group(1)!);
      final month = int.parse(slash.group(2)!);
      final ceYear = int.parse(slash.group(3)!) - 543;
      return _buildValidDate(ceYear, month, day);
    }
    // รูปแบบ วว เดือนย่อ/เต็ม ปปปป (พ.ศ.) เช่น "24 มี.ค. 2569" หรือ "24 มีนาคม 2569"
    final word = RegExp(r'^(\d{1,2})\s+([ก-๙\.]+)\s+(\d{4})$').firstMatch(s);
    if (word != null) {
      final day = int.parse(word.group(1)!);
      final monthText = word.group(2)!.replaceAll('.', '');
      final ceYear = int.parse(word.group(3)!) - 543;
      int? month;
      for (var i = 0; i < _thaiMonthsShort.length; i++) {
        if (_thaiMonthsShort[i].replaceAll('.', '') == monthText ||
            _thaiMonthsFull[i] == monthText) {
          month = i + 1;
          break;
        }
      }
      if (month == null) return null;
      return _buildValidDate(ceYear, month, day);
    }
    return null;
  }

  DateTime? _buildValidDate(int year, int month, int day) {
    if (month < 1 || month > 12) return null;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) return null;
    return DateTime(year, month, day);
  }

  void _applyManualInput() {
    final parsed = _parseManual(_manualCtrl.text);
    if (parsed == null) {
      setState(() => _manualError = 'รูปแบบไม่ถูกต้อง กรอกเป็น วว/ดด/ปปปป เช่น 24/01/2569');
      return;
    }
    if (parsed.isBefore(widget.firstDate) || parsed.isAfter(widget.lastDate)) {
      setState(() => _manualError =
          'วันที่ต้องอยู่ระหว่าง ${_formatSlash(widget.firstDate)} - ${_formatSlash(widget.lastDate)}');
      return;
    }
    setState(() {
      _selected = parsed;
      _viewMonth = DateTime(parsed.year, parsed.month);
      _manualError = null;
      _manualMode = false;
    });
  }

  void _toggleMode() {
    setState(() {
      if (!_manualMode) {
        _manualCtrl.text = _formatSlash(_selected);
        _manualError = null;
      }
      _manualMode = !_manualMode;
    });
  }

  List<int> get _availableYears {
    final startY = widget.firstDate.year;
    final endY = widget.lastDate.year;
    return [for (var y = startY; y <= endY; y++) y];
  }

  List<int> get _availableMonthsForViewYear {
    final isFirstYear = _viewMonth.year == widget.firstDate.year;
    final isLastYear = _viewMonth.year == widget.lastDate.year;
    final startM = isFirstYear ? widget.firstDate.month : 1;
    final endM = isLastYear ? widget.lastDate.month : 12;
    return [for (var m = startM; m <= endM; m++) m];
  }

  void _changeViewMonth(int year, int month) {
    var m = month;
    final months = () {
      final isFirstYear = year == widget.firstDate.year;
      final isLastYear = year == widget.lastDate.year;
      final startM = isFirstYear ? widget.firstDate.month : 1;
      final endM = isLastYear ? widget.lastDate.month : 12;
      return [startM, endM];
    }();
    if (m < months[0]) m = months[0];
    if (m > months[1]) m = months[1];
    setState(() => _viewMonth = DateTime(year, m));
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_viewMonth.year, _viewMonth.month + delta);
    if (next.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month))) return;
    if (next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month))) return;
    setState(() => _viewMonth = next);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.helpText ?? 'เลือกวันที่',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: widget.primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _manualMode ? 'เลือกจากปฏิทิน' : 'พิมพ์วันที่เอง',
                    icon: Icon(_manualMode ? Icons.calendar_month : Icons.edit_calendar,
                        color: widget.primaryColor),
                    onPressed: _toggleMode,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_manualMode) _buildManualEntry() else _buildCalendar(today),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: widget.primaryColor),
                    onPressed: _manualMode
                        ? _applyManualInput
                        : () => Navigator.pop(context, _selected),
                    child: Text(_manualMode ? 'ตกลง' : 'เลือกวันนี้'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _manualCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'วว/ดด/ปปปป (พ.ศ.)',
            hintText: 'เช่น 24/01/2569 หรือ 24 มี.ค. 2569',
            errorText: _manualError,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) => _applyManualInput(),
        ),
      ],
    );
  }

  Widget _buildCalendar(DateTime today) {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0=อา
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final canPrev = !DateTime(year, month).isAtSameMomentAs(
        DateTime(widget.firstDate.year, widget.firstDate.month));
    final canNext = !DateTime(year, month).isAtSameMomentAs(
        DateTime(widget.lastDate.year, widget.lastDate.month));

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: canPrev ? () => _shiftMonth(-1) : null,
            ),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: month,
                  isExpanded: true,
                  items: [
                    for (final m in _availableMonthsForViewYear)
                      DropdownMenuItem(value: m, child: Text(_thaiMonthsFull[m - 1])),
                  ],
                  onChanged: (m) {
                    if (m != null) _changeViewMonth(year, m);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: year,
                  isExpanded: true,
                  items: [
                    for (final y in _availableYears)
                      DropdownMenuItem(value: y, child: Text('${y + 543}')),
                  ],
                  onChanged: (y) {
                    if (y != null) _changeViewMonth(y, month);
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canNext ? () => _shiftMonth(1) : null,
            ),
          ],
        ),
        Row(
          children: [
            for (final w in _thaiWeekdaysShort)
              Expanded(
                child: Center(
                  child: Text(w,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox.shrink();
            final day = index - firstWeekday + 1;
            final date = DateTime(year, month, day);
            final inRange = !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
            final isSelected = date.year == _selected.year &&
                date.month == _selected.month &&
                date.day == _selected.day;
            final isToday =
                date.year == today.year && date.month == today.month && date.day == today.day;
            return Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: isSelected ? widget.primaryColor : Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: inRange ? () => setState(() => _selected = date) : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: isToday && !isSelected
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: widget.primaryColor),
                          )
                        : null,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: !inRange
                            ? Theme.of(context).disabledColor
                            : isSelected
                                ? widget.onPrimaryColor
                                : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
