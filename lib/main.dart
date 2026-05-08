import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    // Firebase not configured — local mode still works.
    firebaseReady = false;
  }
  runApp(LiteratureApp(firebaseReady: firebaseReady));
}

class LiteratureApp extends StatelessWidget {
  const LiteratureApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Literature',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22C55E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E2A1E),
      ),
      debugShowCheckedModeBanner: false,
      home: HomeScreen(firebaseReady: firebaseReady),
    );
  }
}
