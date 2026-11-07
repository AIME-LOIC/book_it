import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookit/main.dart';

void main() {
  // The current splash runs for 4.2 seconds, then restores a session before
  // replacing the route. Avoid pumpAndSettle because the login logo animates
  // continuously and the splash pulse may also be active during the route.
  Future<void> reachLogin(WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('splash displays current BookIt branding', (WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BOOKIT'), findsOneWidget);
    expect(find.text('Book anything, anytime.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('loading screen eventually navigates to the login form',
      (WidgetTester tester) async {
    await reachLogin(tester);

    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('login form accepts email and password input',
      (WidgetTester tester) async {
    await reachLogin(tester);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'aime@example.com');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.pump();

    expect(find.text('Email is required'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
  });

  testWidgets('empty sign-in shows validation errors',
      (WidgetTester tester) async {
    await reachLogin(tester);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
