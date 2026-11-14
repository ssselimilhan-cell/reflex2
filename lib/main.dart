import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'settings/app_settings.dart';
import 'settings/user_profile.dart';
import 'settings/auth_service.dart';
import 'settings/moderation.dart';
import 'settings/progress.dart';
import 'settings/ladder.dart';
import 'settings/telemetry.dart';

/// Firebase kurulumu henüz yapılmadıysa (firebase_options.dart placeholder
/// haldeyse) uygulamanın çökmesini engellemek için bu bayrak kullanılır.
bool firebaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yakalanmayan hatalar anonim hata kaydına gider (Telemetry hazır değilse yok sayılır).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Telemetry.error(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Telemetry.error(error, stack);
    return true;
  };
  await AppSettings.instance.load();
  try {
    // Android'de google-services.json, build varyantına ait paket kimliğine
    // göre doğru Firebase App ID'yi seçer (debug ve mağaza paketi farklı).
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseAvailable = true;
    Telemetry.ready = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    firebaseAvailable = false;
  }
  // Profil yüklemesi Firebase'den bağımsız çalışır (yerel veriler her
  // zaman okunur; Firestore senkronizasyonu sadece profil varsa denenir).
  await UserProfile.instance.load();
  await Moderation.instance.load();
  await Progress.instance.load();
  await LadderProgress.instance.load();
  if (AuthService.instance.currentUser != null) {
    await UserProfile.instance.activateAccountProfile();
    AuthService.instance.syncProgressForCurrentUser().catchError((_) {});
  }
  Telemetry.log('app_open');
  runApp(const StresApp());
}

class StresApp extends StatelessWidget {
  const StresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Stres',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootMessengerKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFB000),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFFFFD23F),
              onPrimary: const Color(0xFF1A1208),
              secondary: const Color(0xFFFFE08A),
              onSecondary: const Color(0xFF1A1208),
              surface: const Color(0xFF1B293D),
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontSize: 16, height: 1.35),
              bodyMedium: TextStyle(fontSize: 15, height: 1.35),
              bodySmall: TextStyle(fontSize: 13, height: 1.3),
              labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            // Ortak kontrast kuralı: dolu düğmeler altın zeminde koyu yazı;
            // yükseltilmiş/çerçeveli düğmeler koyu yüzeyde açık-altın yazı.
            // Ekrana özel açık renkli zemin kullanan düğmeler ayrıca koyu
            // foregroundColor belirtir.
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD23F),
                foregroundColor: const Color(0xFF1A1208),
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.black54,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B293D),
                foregroundColor: const Color(0xFFFFD23F),
                disabledBackgroundColor: const Color(0xFF344256),
                disabledForegroundColor: Colors.white54,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFD23F),
                disabledForegroundColor: Colors.white38,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD23F),
                disabledForegroundColor: Colors.white38,
              ),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF713116),
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              titleTextStyle: const TextStyle(
                fontFamily: 'RussoOne',
                fontSize: 19,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(AppSettings.instance.fontScale),
              ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
