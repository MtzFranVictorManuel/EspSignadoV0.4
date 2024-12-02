// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:traductor_espanol_signado/main.dart';

void main() {
  testWidgets('HomeView has a title and a button', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Find the title
    final titleFinder = find.text('Español - Español signado');
    expect(titleFinder, findsOneWidget);

    // Find the button
    final buttonFinder = find.text('Translate');
    expect(buttonFinder, findsOneWidget);
  });
}
