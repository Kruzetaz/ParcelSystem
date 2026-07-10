// current_user_service.dart
// ชื่อผู้ใช้งานปัจจุบัน — ใช้ระบบ login ร่วมเครื่องเดียว (ผ่าน license gate เดิม)
// ไม่มีรหัสผ่านแยกต่อคน แค่ให้พิมพ์ชื่อตัวเองไว้ประทับใน Audit Trail

import 'package:shared_preferences/shared_preferences.dart';

const _prefUserName = 'current_user_name';

class CurrentUserService {
  CurrentUserService._();
  static final CurrentUserService instance = CurrentUserService._();

  Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefUserName) ?? 'ไม่ระบุชื่อ';
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUserName, name.trim());
  }
}
