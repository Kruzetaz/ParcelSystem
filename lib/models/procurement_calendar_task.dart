// procurement_calendar_task.dart
// กำหนดชุดงานประจำที่เจ้าหน้าที่พัสดุต้องทำในแต่ละเดือนของปีงบประมาณ (ต.ค.-ก.ย.)
// อิงจากปฏิทินงานจริงที่โรงเรียนใช้ทำงาน — เป็นชุดงานทั่วไปที่พบบ่อย ไม่ใช่
// ระเบียบทางกฎหมายที่ต้องทำตามเป๊ะทุกข้อ แต่ละโรงเรียนอาจมีรายละเอียดต่างกันได้
// (คำเตือน: เป็นแนวทางเบื้องต้นเท่านั้น ไม่ใช่การรับรองทางกฎหมาย)

const thaiMonthNames = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

class ProcurementCalendarTaskDef {
  final String slug;
  final String title;
  const ProcurementCalendarTaskDef({required this.slug, required this.title});
}

/// งานประจำทุกเดือนตลอดปีงบประมาณ
const _monthlyRecurringTasks = [
  ProcurementCalendarTaskDef(
    slug: 'monthly_ledger',
    title: 'อัปเดตบัญชีวัสดุ / บัญชีครุภัณฑ์ / ทะเบียนคุมพัสดุ ให้เป็นปัจจุบัน',
  ),
  ProcurementCalendarTaskDef(
    slug: 'monthly_docs',
    title: 'จัดทำใบเบิกพัสดุ / ใบรับพัสดุ / ใบส่งของ และสรุปรายงานพัสดุประจำเดือน',
  ),
];

/// งานเฉพาะเดือน (key = เดือนปฏิทิน 1-12) เพิ่มเข้าไปนอกเหนือจากงานประจำทุกเดือน
final Map<int, List<ProcurementCalendarTaskDef>> _monthlyMilestoneTasks = {
  10: const [
    ProcurementCalendarTaskDef(
      slug: 'annual_plan',
      title: 'จัดทำแผนพัสดุ/แผนจัดหาพัสดุประจำปี ภายใน 30 วันนับจากวันเริ่มปีงบประมาณ',
    ),
  ],
  12: const [
    ProcurementCalendarTaskDef(slug: 'q1_report', title: 'ส่งรายงานผลการจัดซื้อจัดจ้าง ไตรมาสที่ 1'),
  ],
  3: const [
    ProcurementCalendarTaskDef(slug: 'q2_report', title: 'ส่งรายงานผลการจัดซื้อจัดจ้าง ไตรมาสที่ 2'),
  ],
  6: const [
    ProcurementCalendarTaskDef(slug: 'q3_report', title: 'ส่งรายงานผลการจัดซื้อจัดจ้าง ไตรมาสที่ 3'),
  ],
  9: const [
    ProcurementCalendarTaskDef(
      slug: 'appoint_committee',
      title: 'แต่งตั้งคณะกรรมการตรวจสอบพัสดุประจำปี และหัวหน้าเจ้าหน้าที่พัสดุสำหรับปีงบใหม่',
    ),
    ProcurementCalendarTaskDef(
      slug: 'annual_count',
      title: 'ตรวจนับพัสดุประจำปี (ตรวจสอบครุภัณฑ์และวัสดุคงเหลือ) จัดทำแบบตรวจสอบครุภัณฑ์/รายงานพัสดุคงเหลือ',
    ),
    ProcurementCalendarTaskDef(
      slug: 'q4_report',
      title: 'ส่งรายงานผลการจัดซื้อจัดจ้างประจำปี (รวมไตรมาส 4) ให้หน่วยงานกำกับ เช่น สตง./กรมบัญชีกลาง',
    ),
  ],
};

/// รายชื่องานทั้งหมด (ประจำ + เฉพาะเดือน) ของเดือนปฏิทิน [calendarMonth] (1-12)
List<ProcurementCalendarTaskDef> tasksForCalendarMonth(int calendarMonth) => [
      ..._monthlyRecurringTasks,
      ...?_monthlyMilestoneTasks[calendarMonth],
    ];

/// 1 เดือนในปฏิทินงานพัสดุ — พ.ศ. [buddhistYear] คือปีปฏิทินจริงของเดือนนั้น
/// (ต.ค.-ธ.ค. จะเป็น พ.ศ. ของปีงบ - 1, ม.ค.-ก.ย. เป็น พ.ศ. ของปีงบเอง)
class ProcurementCalendarMonth {
  final int calendarMonth; // 1-12
  final int buddhistYear;
  final List<ProcurementCalendarTaskDef> tasks;

  const ProcurementCalendarMonth({
    required this.calendarMonth,
    required this.buddhistYear,
    required this.tasks,
  });

  String get label => '${thaiMonthNames[calendarMonth]} $buddhistYear';
}

/// สร้างปฏิทิน 12 เดือนของปีงบประมาณ [fiscalYearBuddhist] (เช่น 2569 หมายถึง
/// ปีงบที่เริ่ม 1 ต.ค. 2568 สิ้นสุด 30 ก.ย. 2569) เรียงตามลำดับ ต.ค. -> ก.ย.
List<ProcurementCalendarMonth> buildFiscalYearCalendar(int fiscalYearBuddhist) {
  final months = <ProcurementCalendarMonth>[];
  // ต.ค.-ธ.ค. ของปีงบ อยู่ใน พ.ศ. (fiscalYearBuddhist - 1)
  for (final m in [10, 11, 12]) {
    months.add(ProcurementCalendarMonth(
      calendarMonth: m,
      buddhistYear: fiscalYearBuddhist - 1,
      tasks: tasksForCalendarMonth(m),
    ));
  }
  // ม.ค.-ก.ย. ของปีงบ อยู่ใน พ.ศ. ของปีงบเอง
  for (var m = 1; m <= 9; m++) {
    months.add(ProcurementCalendarMonth(
      calendarMonth: m,
      buddhistYear: fiscalYearBuddhist,
      tasks: tasksForCalendarMonth(m),
    ));
  }
  return months;
}

/// ปีงบประมาณ (พ.ศ.) ของวันที่ [date] — ต.ค.-ธ.ค. นับเป็นปีงบถัดไปเสมอ
/// (เช่น ต.ค. 2568 อยู่ในปีงบ 2569)
int fiscalYearOf(DateTime date) {
  final buddhistYear = date.year + 543;
  return date.month >= 10 ? buddhistYear + 1 : buddhistYear;
}
