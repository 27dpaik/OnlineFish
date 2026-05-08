import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/screens/home_screen.dart';

void main() {
  testWidgets('Home screen renders the title', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(firebaseReady: false),
    ));
    expect(find.text('Literature'), findsOneWidget);
  });
}
