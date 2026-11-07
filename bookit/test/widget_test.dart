import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookit/main.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  setUpAll(() {
    // Widget tests have no native secure-storage implementation. Return no
    // saved token so the splash follows the signed-out path deterministically.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  Future<void> reachLogin(WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());

    // The splash animation runs for 4.2 seconds. Session restoration then
    // completes asynchronously before the 450ms route transition begins.
    for (var i = 0; i < 60 && find.text('Welcome back 👋').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
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

    final signInButton = find.text('Sign in');
    expect(signInButton, findsOneWidget);

    // The full login form is taller than the default 800x600 test viewport.
    // Scroll the real ListView until the button is on-screen before tapping.
    await tester.scrollUntilVisible(
      signInButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(signInButton);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
