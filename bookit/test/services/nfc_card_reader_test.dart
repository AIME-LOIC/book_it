import 'package:flutter_test/flutter_test.dart';
import 'package:bookit/services/nfc_card_reader.dart';

void main() {
  group('NfcCardReader.formatUid', () {
    test('formats four-byte UIDs as uppercase hexadecimal', () {
      expect(NfcCardReader.formatUid([0x04, 0xA1, 0x0B, 0xFF]), '04A10BFF');
    });

    test('preserves leading zero bytes', () {
      expect(NfcCardReader.formatUid([0x00, 0x01, 0x0A, 0x10]), '00010A10');
    });

    test('supports seven-byte card identifiers', () {
      expect(
        NfcCardReader.formatUid([0x04, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66]),
        '04112233445566',
      );
    });

    test('rejects an empty identifier', () {
      expect(() => NfcCardReader.formatUid([]), throwsArgumentError);
    });

    test('rejects values outside the byte range', () {
      expect(() => NfcCardReader.formatUid([256]), throwsArgumentError);
      expect(() => NfcCardReader.formatUid([-1]), throwsArgumentError);
    });
  });
}
