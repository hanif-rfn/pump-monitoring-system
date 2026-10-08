import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'services/app_notification_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppNotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuMS (Pump Monitoring System)',
      debugShowCheckedModeBanner: false,
      // 2. Terapkan Font Poppins ke seluruh tema aplikasi
      theme: ThemeData.light().copyWith(
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme),
      ),
      home: const LoginPage(),
    );
  }
}