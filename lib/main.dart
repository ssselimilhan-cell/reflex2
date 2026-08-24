import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'settings/app_settings.dart';

/// Firebase kurulumu henüz yapılmadıysa (firebase_options.dart placeholder
/// haldeyse) uygulamanın çökmesini engellemek için bu bayrak kullanılır.
bool firebaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseAvailable = true;
  } catch (e) {
    firebaseAvailable = false;
  }
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
          theme: ThemeData(
            colorSchemeSeed: AppSettings.instance.themeColor,
            useMaterial3: true,
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
