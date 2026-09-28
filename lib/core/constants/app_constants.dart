/// Uygulama geneli sabitler.
abstract final class AppConstants {
  static const String appName = 'Kabin';

  /// Cloud Functions bölgesi (functions/src/index.ts ile aynı).
  static const String functionsRegion = 'europe-west1';

  /// KVKK aydınlatma/açık rıza metni sürümü. Değişirse kullanıcıdan yeniden onay istenir.
  static const String kvkkVersion = '2026-09';

  // Sayfalama
  static const int gridPageSize = 24;
  static const int historyPageSize = 15;
  static const int ledgerPageSize = 25;

  // Görsel
  static const int photoMaxDimension = 1440;
  static const int photoQuality = 88;
  static const int selfieMaxDimension = 1024;
  static const int thumbnailMaxDimension = 480;
  static const int thumbnailQuality = 72;
  static const int gridCacheWidth = 360;
  static const int detailCacheWidth = 1080;

  // Ölçü aralıkları (Firestore kuralları ve generateAvatar ile uyumlu)
  static const int minHeightCm = 120;
  static const int maxHeightCm = 230;
  static const int minWeightKg = 30;
  static const int maxWeightKg = 250;

  // Cache
  static const int imageCacheMaxObjects = 400;
  static const Duration imageCacheStalePeriod = Duration(days: 14);

  static const String supportEmail = 'destek@kabin.app';
}
