import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/home_screen.dart';

void main() {
  testWidgets('Home screen renders the title and game cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(firebaseReady: false),
    ));
    expect(find.text('OnlineFish'), findsOneWidget);
    expect(find.text('Literature'), findsOneWidget);
    expect(find.text('One Card'), findsOneWidget);
    expect(find.text('Cambio'), findsOneWidget);
    expect(find.text('Castlefall'), findsOneWidget);
    expect(find.text('Da Vinci Code'), findsOneWidget);
  });
}
