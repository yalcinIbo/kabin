/// Firestore yolları. `functions/src/lib/paths.ts` (FP) ile birebir aynı tutulmalı.
abstract final class FirestorePaths {
  static const String users = 'users';
  static const String photos = 'photos';
  static const String garments = 'garments';
  static const String tryons = 'tryons';
  static const String models3d = 'models3d';
  static const String ledger = 'ledger';
  static const String benchmarks = 'benchmarks';
  static const String pairs = 'pairs';

  static const String pricing = 'config/pricing';
  static const String flags = 'config/flags';

  static String user(String uid) => '$users/$uid';
  static String userPhotos(String uid) => '$users/$uid/$photos';
  static String photo(String uid, String id) => '$users/$uid/$photos/$id';
  static String userGarments(String uid) => '$users/$uid/$garments';
  static String garment(String uid, String id) => '$users/$uid/$garments/$id';
  static String userTryons(String uid) => '$users/$uid/$tryons';
  static String tryon(String uid, String id) => '$users/$uid/$tryons/$id';
  static String userModels3d(String uid) => '$users/$uid/$models3d';
  static String model3d(String uid, String id) => '$users/$uid/$models3d/$id';
  static String userLedger(String uid) => '$users/$uid/$ledger';
  static String benchmark(String runId) => '$benchmarks/$runId';
  static String benchmarkPairs(String runId) => '$benchmarks/$runId/$pairs';
  static String benchmarkPair(String runId, String pairId) => '$benchmarks/$runId/$pairs/$pairId';
}
