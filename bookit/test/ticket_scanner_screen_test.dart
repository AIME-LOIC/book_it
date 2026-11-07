import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookit/screens/ticket_scanner_screen.dart';
import 'package:bookit/services/api_client.dart';

void main() {
  // Nitpick-proof camera stubbing: the scanner never touches a real camera in
  // these tests. The mocked platform calls simply report an already-authorized
  // camera so the MobileScanner widget builds without blowing up.
  Future<void> stubCamera(WidgetTester tester) async {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
      (call) async => switch (call.method) {
        'state' => 1, // MobileScannerAuthorizationState.authorized (raw value)

        'request' => true,
        'start' => <String, Object?>{'textureId': 1, 'cameraDirection': 1, 'currentTorchState': 0},
        _ => null,
      },
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    // Always unhook the stub so no other test inherits it.
    ApiClient.postOverride = null;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
      null,
    );
  });

  testWidgets('manual ticket-number entry calls the validate endpoint and shows VALID',
      (WidgetTester tester) async {
    await stubCamera(tester);

    final calls = <Map<String, Object?>>[];
    ApiClient.postOverride = (path, {body, auth = false}) async {
      calls.add({'path': path, 'body': body, 'auth': auth});
      return <String, dynamic>{
        'valid': true,
        'ticket': {
          'ticket_number': 'BK-2026-000123',
          'seat_number': '12',
          'plate_number': 'RAA 123X',
          'departure_time': '08:00',
          'boarding': 'Nyabugogo',
          'dropoff': 'Huye',
          'passenger': {'name': 'Ami Ndoli'},
        },
      };
    };

    await tester.pumpWidget(const MaterialApp(home: TicketScannerScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Driver types a ticket number instead of scanning a QR code.
    await tester.tap(find.text('Enter ticket number').last);
    await tester.pumpAndSettle();

    // Empty submit is rejected before reaching the API.
    await tester.tap(find.text('Validate'));
    await tester.pump();
    expect(find.text('Ticket number is required'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'BK-2026-000123');
    await tester.tap(find.text('Validate'));
    // Dialog close + request round-trip + result sheet entrance.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));

    expect(calls.length, 1);
    expect(calls.single['path'], 'tickets/validate/number');
    expect(calls.single['auth'], true);
    expect((calls.single['body']! as Map)['ticket_number'], 'BK-2026-000123');

    // Red → green result sheet with the ticket summary.
    expect(find.text('VALID'), findsOneWidget);
    expect(find.text('Ami Ndoli'), findsOneWidget);
    expect(find.text('Seat 12 • BK-2026-000123'), findsOneWidget);
    expect(find.text('Nyabugogo  →  Huye'), findsOneWidget);
  });

  testWidgets('invalid ticket shows the server reason and a Scan next button',
      (WidgetTester tester) async {
    await stubCamera(tester);

    ApiClient.postOverride = (path, {body, auth = false}) async => <String, dynamic>{
          'valid': false,
          'reason': 'Ticket already used — boarding denied',
        };

    await tester.pumpWidget(const MaterialApp(home: TicketScannerScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Enter ticket number').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'BK-2026-000001');
    await tester.tap(find.text('Validate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('INVALID'), findsOneWidget);
    expect(find.text('Ticket already used — boarding denied'), findsOneWidget);
    expect(find.text('Scan next'), findsOneWidget);
  });
}
