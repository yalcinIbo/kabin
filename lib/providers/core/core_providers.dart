import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firebase/analytics_service.dart';
import '../../services/firebase/crashlytics_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/functions_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/media/image_service.dart';
import '../../services/media/share_service.dart';
import '../auth/auth_providers.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final functionsServiceProvider = Provider<FunctionsService>((ref) => FunctionsService());
final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

/// main.dart içinde başlatılmış örnekle override edilir.
final crashlyticsServiceProvider = Provider<CrashlyticsService>((ref) => CrashlyticsService());
final imageServiceProvider = Provider<ImageService>((ref) => ImageService());
final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

/// Storage yolu → indirme URL'si. Oturum boyunca önbellekte kalır (belgeler URL değil yol saklar);
/// oturum değişince tüm önbellek düşer, böylece bir hesabın URL'leri diğerine sızmaz.
final storageUrlProvider = FutureProvider.family<String, String>((ref, path) {
  ref.watch(currentUidProvider);
  return ref.watch(storageServiceProvider).getDownloadUrl(path);
});
