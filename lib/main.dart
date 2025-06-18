import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/sign_up_page.dart';
import 'pages/quiz_page.dart';
import 'pages/scores_page.dart';
import 'pages/profile_page.dart';
import 'pages/complete_profile_page.dart';
import 'pages/contact_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase başlatma
  const supabaseUrl = 'https://qvoxksnfeirslohgtvfq.supabase.co';
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2b3hrc25mZWlyc2xvaGd0dmZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5OTcxMzcsImV4cCI6MjA2NTU3MzEzN30.J8WsZT0BFzavFoRNVqdr-L0BhRGMNtrx_lQEpcbKwLQ';

  try {
    // Daha gelişmiş yapılandırma ile Supabase'i başlat
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      debug: kDebugMode, // Debug modda daha fazla log
      // Supabase'in otomatik yeniden bağlanma ve yükleme stratejisi
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true, // Token'ı otomatik yenile
      ),
    );

    // Bağlantıyı test et ve log kaydet
    final client = Supabase.instance.client;
    final result = await client.from('scores').select().limit(1).maybeSingle();
    debugPrint(
      'Supabase bağlantı testi: ${result != null ? 'Başarılı' : 'Veri yok ama bağlantı çalışıyor'}',
    );
    debugPrint('Supabase başarıyla başlatıldı ve test edildi');
  } catch (e) {
    debugPrint('Supabase başlatma hatası: $e');
    // Uygulamayı çökertmeden devam et, ama kullanıcı skorları kaydedilmeyebilir
  }

  // Firebase başlatma
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('Firebase başarıyla başlatıldı');
  } catch (e) {
    debugPrint('Firebase başlatma hatası: $e');
    // Firebase başlatma hatası olsa bile uygulamayı çalıştırmaya devam et
  }

  if (!kIsWeb) {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platformları için SQLite FFI başlatma
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (e) {
      debugPrint('Platform algılama hatası: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bilgi Yarışması',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/quiz': (context) => const QuizPage(),
        '/scores': (context) => const ScoresPage(),
        '/profile': (context) => const ProfilePage(),
        '/complete_profile': (context) => const CompleteProfilePage(),
        '/contact': (context) => const ContactPage(),
      },
    );
  }
}
