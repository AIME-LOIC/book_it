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
    // Allow the login route and staggered form entrance animations to finish.
    // The floating logo loops forever, so use a bounded pump instead of pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 1200));
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
    // Use a tall phone-sized viewport so the complete login form, including
    // its InkWell submit target, is inside the visible hit-test area.
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await reachLogin(tester);

    // Target the actual InkWell rather than its animated text child. The
    // label's transformed render position can fall outside the hit-test path.
    final submitButton = find.byKey(const ValueKey('login-submit-button'));
    expect(submitButton, findsOneWidget);
    await tester.ensureVisible(submitButton);
    await tester.pump();
    expect(tester.hitTestOnBinding(tester.getCenter(submitButton)).path,
        isNotEmpty);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
