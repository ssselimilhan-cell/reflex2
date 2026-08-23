import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

bool firebaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'Stres',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B6E4F),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
