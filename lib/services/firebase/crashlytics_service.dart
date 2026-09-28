import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crashlytics kurulumu ve manuel hata kaydı.
class CrashlyticsService {
  CrashlyticsService({FirebaseCrashlytics? crashlytics}) : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  /// Flutter ve platform hatalarını Crashlytics'e bağlar. Debug'da toplama kapalıdır.
  Future<void> init() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  Future<void> setUserId(String? uid) => _crashlytics.setUserIdentifier(uid ?? '');

  Future<void> recordError(Object error, StackTrace? stack, {String? reason, bool fatal = false}) =>
      _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);

  Future<void> log(String message) => _crashlytics.log(message);
}
