import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookit/main.dart';

void main() {
  // SplashScreen taps the platform channels (shared_preferences +
  // flutter_secure_storage) during its restore pass. Without handlers the
  // awaited plugin futures never resolve under the FakeAsync test zone, so
  // register no-op mocks: no stored token/session => the splash always ends
  // on the login screen. No real storage or network is touched.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  // Drive the screens with explicit pumps: splash (4.2s) + restore-session
  // round-trip + route transition + an extra nudge so staggered entrance
  // timers all fire (no pending Timers at test end). The splash pulse repeats
  // forever, so avoid pumpAndSettle.
  Future<void> reachLogin(WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('splash shows the animated loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BookItApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BOOKIT'), findsOneWidget);
    expect(find.text('Book anything, anytime.'), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('loading screen eventually navigates to the login form',
      (WidgetTester tester) async {
    await reachLogin(tester);

    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Email or phone number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('empty sign-in shows validation errors instead of calling the API',
      (WidgetTester tester) async {
    await reachLogin(tester);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Validation runs client-side before any AuthService.login round-trip.
    expect(find.text('Email or phone number is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    // The button still reads "Sign in": no spinner or success state fired.
    expect(find.text('Sign in'), findsOneWidget);
  });
}
