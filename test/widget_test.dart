// Utter App Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:utter_app/main.dart';
import 'package:utter_app/core/config/app_constants.dart';

void main() {
  testWidgets('Utter App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(
        child: UtterApp(),
      ),
    );

    // Verify app name is displayed
    expect(find.text(AppConstants.appName), findsWidgets);

    // Verify splash screen elements
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
