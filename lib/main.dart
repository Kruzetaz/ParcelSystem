import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/database.dart';
import 'screens/license_gate.dart';
import 'theme/app_theme.dart';
import 'services/theme_controller.dart';
import 'services/font_scale_controller.dart';
import 'widgets/toast_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await AppDatabase.instance.database;
  await ThemeController.instance.load();
  await FontScaleController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeController.instance, FontScaleController.instance]),
      builder: (context, _) {
        return MaterialApp(
          title: 'ระบบจัดซื้อจัดจ้าง',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeController.instance.mode,
          locale: const Locale('th', 'TH'),
          supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LicenseGate(),
          // ปรับขนาดตัวอักษรทั้งระบบตามที่ผู้ใช้เลือกไว้ (ปุ่ม +/- ที่ AppBar) —
          // ทำที่ MediaQuery.textScaler ตรงนี้จุดเดียว มีผลกับทุกหน้าจอทั้งแอป
          // โดยไม่ต้องไปแก้ fontSize ทีละที่ในแต่ละหน้า
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(FontScaleController.instance.scale),
            ),
            child: ToastHost(child: child ?? const SizedBox()),
          ),
        );
      },
    );
  }
}
