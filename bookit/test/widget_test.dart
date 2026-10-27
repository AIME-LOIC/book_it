import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookit/main.dart';

void main() {
  // Drive the screens with explicit pumps: splash (2.6s) + route transition +
  // an extra nudge so staggered entrance timers all fire (no pending Timers at
  // test end). The login logo repeats forever, so avoid pumpAndSettle.
  Future<void> reachLogin(WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('splash shows the animated loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.local_activity_rounded), findsOneWidget);
    expect(find.text('BookIt'), findsOneWidget);

    // Tagline fades in partway through the 2.6s sequence.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Book anything, anytime.'), findsOneWidget);
  });

  testWidgets('loading screen eventually navigates to the login form',
      (WidgetTester tester) async {
    await reachLogin(tester);

    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('entering credentials reaches the home screen',
      (WidgetTester tester) async {
    await reachLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'aime.ogutu@example.com');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));

    // Auth round-trip (1400ms) + success check (650ms) + route transition.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Popular this week'), findsOneWidget);
    expect(find.text('Hi Aime Ogutu 👋'), findsOneWidget);
  });

  testWidgets('empty sign-in shows validation errors',
      (WidgetTester tester) async {
    await reachLogin(tester);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
