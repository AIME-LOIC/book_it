import 'dart:async';
import 'dart:io';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// Reads ISO 14443 NFC card UIDs on Android devices with NFC hardware enabled.
///
/// This reads the tag identifier only. It does not authenticate the card or
/// prove that the card is genuine; the BookIt API must authorize registration.
class NfcCardReader {
  NfcCardReader._();

  static Future<NfcAvailability> checkAvailability() async {
    if (!Platform.isAndroid) return NfcAvailability.unsupported;
    return NfcManager.instance.checkAvailability();
  }

  static Future<String> readCardUid({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Phone NFC card registration is currently available on Android only.');
    }

    final availability = await checkAvailability();
    if (availability == NfcAvailability.unsupported) {
      throw UnsupportedError('This phone does not have NFC hardware.');
    }
    if (availability == NfcAvailability.disabled) {
      throw StateError('NFC is turned off. Enable NFC in Android Settings and try again.');
    }

    final result = Completer<String>();
    var sessionStarted = false;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (tag) {
          if (result.isCompleted) return;

          try {
            final androidTag = NfcTagAndroid.from(tag);
            final identifier = androidTag?.id;
            if (identifier == null || identifier.isEmpty) {
              result.completeError(
                StateError('The NFC tag did not expose a readable card identifier.'),
              );
              return;
            }
            result.complete(formatUid(identifier));
          } catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        },
      );
      sessionStarted = true;
      return await result.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'No card detected. Hold the card against the back of your phone and try again.',
        ),
      );
    } finally {
      if (sessionStarted) {
        try {
          await NfcManager.instance.stopSession();
        } catch (_) {
          // The Android NFC session may already have stopped after discovery.
        }
      }
    }
  }

  /// Formats a tag identifier as uppercase, separator-free hexadecimal.
  static String formatUid(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'A card UID cannot be empty.');
    }
    if (bytes.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError.value(bytes, 'bytes', 'UID bytes must be between 0 and 255.');
    }
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }
}
