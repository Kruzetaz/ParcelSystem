// tor_template.dart
// สเปกมาตรฐานที่บันทึกไว้ใช้ซ้ำ (เช่นสเปก สพฐ.) — ดึงมาเติมในฟอร์ม TOR ได้
// โดยไม่ต้องพิมพ์ข้อกำหนดยาวๆ ใหม่ทุกครั้ง

class TorTemplate {
  final int? id;
  final String name;
  final String? category; // 'ครุภัณฑ์' | 'วัสดุ' | 'จ้าง'
  final String? specificationText;

  const TorTemplate({
    this.id,
    required this.name,
    this.category,
    this.specificationText,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'specification_text': specificationText,
      };

  factory TorTemplate.fromMap(Map<String, dynamic> m) => TorTemplate(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: m['category'] as String?,
        specificationText: m['specification_text'] as String?,
      );
}
