// Smoke test: the app shell builds without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem_scramble/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const GemScrambleApp());

    // Network requests fail in the test environment; the app should still
    // render its shell (auth gate) without throwing.
    expect(
      find.byType(MaterialApp),
      findsOneWidget,
      reason: 'App should have a MaterialApp widget',
    );
  });
}
