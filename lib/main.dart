import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }
  // Parse `?game=…&code=…` for invite-link auto-join. Works on Flutter
  // Web; harmless on native (Uri.base has no query there).
  final params = Uri.base.queryParameters;
  final initialGameKind = _parseGameKind(params['game']);
  final initialCode = params['code']?.toUpperCase();
  runApp(OnlineFishApp(
    firebaseReady: firebaseReady,
    initialGameKind: initialGameKind,
    initialCode: initialCode,
  ));
}

GameKind? _parseGameKind(String? s) {
  switch (s) {
    case 'literature':
      return GameKind.literature;
    case 'oneCard':
    case 'one_card':
    case 'onecard':
      return GameKind.oneCard;
    case 'cambio':
      return GameKind.cambio;
    default:
      return null;
  }
}

class OnlineFishApp extends StatelessWidget {
  const OnlineFishApp({
    super.key,
    required this.firebaseReady,
    this.initialGameKind,
    this.initialCode,
  });

  final bool firebaseReady;
  final GameKind? initialGameKind;
  final String? initialCode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnlineFish',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22C55E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111827),
      ),
      debugShowCheckedModeBanner: false,
      home: HomeScreen(
        firebaseReady: firebaseReady,
        initialGameKind: initialGameKind,
        initialCode: initialCode,
      ),
    );
  }
}
