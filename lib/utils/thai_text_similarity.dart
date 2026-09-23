// thai_text_similarity.dart
// จับคู่ชื่อโครงการ/กิจกรรมที่ AI อ่านมาจากไฟล์เก่า กับแผนงบประมาณที่มีอยู่แล้ว
// ในระบบแบบคร่าวๆ (fuzzy) — ข้อความภาษาไทยจากไฟล์เก่ามักสะกด/เว้นวรรคไม่ตรงกับ
// ที่กรอกไว้ในแผนงบเป๊ะๆ จึงใช้การเทียบ "คำที่ซ้อนกัน" (token overlap) แทนการ
// เทียบตรงตัวอักษร ไม่พึ่ง package ภายนอกเพิ่ม

import '../models/budget.dart';

/// ตัดช่องว่าง/เว้นวรรคซ้ำ แล้วแยกเป็นชุดคำ (2 ตัวอักษรขึ้นไป กันคำเชื่อมสั้นๆ
/// อย่าง "ที่"/"ใน" มาถ่วงคะแนนความเหมือนที่ไม่ได้สื่อความหมายจริง)
Set<String> _tokenize(String text) {
  final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.split(' ').where((t) => t.length >= 2).toSet();
}

/// คะแนนความเหมือน 0.0-1.0 แบบ Jaccard (สัดส่วนคำที่ซ้อนกันเทียบกับคำทั้งหมด)
double textSimilarity(String a, String b) {
  final ta = _tokenize(a);
  final tb = _tokenize(b);
  if (ta.isEmpty || tb.isEmpty) return 0.0;
  final intersection = ta.intersection(tb).length;
  final union = ta.union(tb).length;
  if (union == 0) return 0.0;
  return intersection / union;
}

/// หาแผนงบที่ชื่อโครงการ/กิจกรรมใกล้เคียงกับข้อความที่ให้มาที่สุด — คืน null ถ้า
/// คะแนนสูงสุดต่ำกว่า [threshold] (กันจับคู่มั่วตอนไม่เหมือนกันเลย)
Budget? bestBudgetMatch(String? text, List<Budget> budgets,
    {double threshold = 0.25}) {
  if (text == null || text.trim().isEmpty || budgets.isEmpty) return null;
  Budget? best;
  var bestScore = 0.0;
  for (final b in budgets) {
    final candidate = [b.projectName, b.activityName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ');
    if (candidate.trim().isEmpty) continue;
    final score = textSimilarity(text, candidate);
    if (score > bestScore) {
      bestScore = score;
      best = b;
    }
  }
  return bestScore >= threshold ? best : null;
}
