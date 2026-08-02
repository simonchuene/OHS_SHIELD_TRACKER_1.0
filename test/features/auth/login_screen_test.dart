// path: test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('shows validation errors when submitting empty form', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    // Tagline and CTA are present.
    expect(find.text('Transforming safety metrics into operational strength'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pump();

    // Inline validation (Prompt 3 §8) fires before any network call.
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
