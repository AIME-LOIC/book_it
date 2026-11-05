import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookit/screens/rfid_cards_screen.dart';
import 'package:bookit/services/api_client.dart';

void main() {
  setUp(() {
    ApiClient.getOverride = (path, {query, auth = false}) async {
      if (path == 'auth/me') {
        return {'user': {'role': 'user'}};
      }
      if (path == 'rfid-cards') {
        return {'cards': <Map<String, dynamic>>[]};
      }
      throw StateError('Unexpected GET in RFID screen test: $path');
    };
  });

  tearDown(() {
    ApiClient.getOverride = null;
    ApiClient.postOverride = null;
  });

  testWidgets('offers phone NFC scanning and keeps external reader fallback',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RfidCardsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan with this phone'), findsOneWidget);
    expect(find.text('Use a BookIt reader instead'), findsOneWidget);
    expect(find.textContaining('If your Android phone has NFC'), findsOneWidget);
  });
}
