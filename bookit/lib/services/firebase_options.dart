import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

/// Supply these values with --dart-define. They are Firebase client identifiers,
/// not server credentials. Never put a Firebase service-account private key here.
class DefaultFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appIdAndroid = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _appIdIos = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty &&
      (_appIdAndroid.isNotEmpty || _appIdIos.isNotEmpty);

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(apiKey: _apiKey, appId: _appIdAndroid, messagingSenderId: _messagingSenderId, projectId: _projectId);
      case TargetPlatform.iOS:
        return FirebaseOptions(apiKey: _apiKey, appId: _appIdIos, messagingSenderId: _messagingSenderId, projectId: _projectId, iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId);
      default:
        throw UnsupportedError('Firebase push notifications are supported on Android and iOS.');
    }
  }
}
