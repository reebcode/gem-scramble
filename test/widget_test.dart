// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gem_scramble/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GemScrambleApp());

    // Just verify that the app builds without throwing an exception
    // We don't wait for network requests since they'll fail in test environment
    expect(
      find.byType(MaterialApp),
      findsOneWidget,
      reason: 'App should have a MaterialApp widget',
    );
  });
}
