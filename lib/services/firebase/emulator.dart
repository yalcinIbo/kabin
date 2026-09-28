import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` ile yerel Firebase emülatörlerine bağlanır.
/// Fiziksel cihazda: `--dart-define=EMULATOR_HOST=<bilgisayarın IP'si>`.
abstract final class FirebaseEmulators {
  static const bool enabled = bool.fromEnvironment('USE_EMULATORS');
  static const String _hostOverride = String.fromEnvironment('EMULATOR_HOST');

  static String get host {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static Future<void> connect() async {
    if (!enabled) return;
    final h = host;
    await FirebaseAuth.instance.useAuthEmulator(h, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(h, 8080);
    await FirebaseStorage.instance.useStorageEmulator(h, 9199);
    FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion).useFunctionsEmulator(h, 5001);
    debugPrint('🔧 Firebase emülatörlerine bağlanıldı: $h');
  }
}
