import '../../core/constants/firestore_paths.dart';
import '../../core/constants/functions_names.dart';
import '../../models/benchmark/benchmark_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/functions_service.dart';

/// Yönetici sağlayıcı karşılaştırması (FASHN vs Vertex).
class BenchmarkRepository {
  BenchmarkRepository(this._db, this._functions);

  final FirestoreService _db;
  final FunctionsService _functions;

  Future<String> runBenchmark({required String photoId, required List<String> garmentIds, required List<String> providers}) async {
    final res = await _functions.call(FunctionNames.runBenchmark, {'photoId': photoId, 'garmentIds': garmentIds, 'providers': providers});
    return res['runId'] as String;
  }

  Stream<List<BenchmarkRunModel>> watchRuns({int limit = 20}) => _db.watchList(
    _db.collection(FirestorePaths.benchmarks).orderBy('createdAt', descending: true).limit(limit),
    BenchmarkRunModel.fromMap,
  );

  Stream<List<BenchmarkPairModel>> watchPairs(String runId) =>
      _db.watchList(_db.collection(FirestorePaths.benchmarkPairs(runId)).limit(20), BenchmarkPairModel.fromMap);

  Future<void> rate(String runId, String pairId, String winner) => _db.updateDoc(FirestorePaths.benchmarkPair(runId, pairId), {
    'rating': {'winner': winner},
    'updatedAt': _db.serverTimestamp,
  });
}
