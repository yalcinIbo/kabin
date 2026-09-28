import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/utils/provider_logger.dart';
import 'firebase_options.dart';
import 'providers/core/core_providers.dart';
import 'services/firebase/crashlytics_service.dart';
import 'services/firebase/emulator.dart';
import 'services/media/cache_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseEmulators.connect();

  final crashlytics = CrashlyticsService();
  await crashlytics.init();

  await Future.wait([
    initializeDateFormatting('tr_TR'),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]);
  CacheConfig.configureMemoryCache();

  runApp(
    ProviderScope(
      observers: [if (kDebugMode) const ProviderLogger()],
      overrides: [crashlyticsServiceProvider.overrideWithValue(crashlytics)],
      child: const KabinApp(),
    ),
  );
}
