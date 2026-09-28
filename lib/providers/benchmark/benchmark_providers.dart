import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/benchmark/benchmark_models.dart';
import '../../notifiers/benchmark/benchmark_notifier.dart';
import '../../repositories/benchmark/benchmark_repository.dart';
import '../core/core_providers.dart';

final benchmarkRepositoryProvider = Provider<BenchmarkRepository>((ref) {
  return BenchmarkRepository(ref.watch(firestoreServiceProvider), ref.watch(functionsServiceProvider));
});

final benchmarkRunsProvider = StreamProvider.autoDispose<List<BenchmarkRunModel>>((ref) {
  return ref.watch(benchmarkRepositoryProvider).watchRuns();
});

final benchmarkPairsProvider = StreamProvider.autoDispose.family<List<BenchmarkPairModel>, String>((ref, runId) {
  return ref.watch(benchmarkRepositoryProvider).watchPairs(runId);
});

final benchmarkNotifierProvider = NotifierProvider.autoDispose<BenchmarkNotifier, BenchmarkState>(BenchmarkNotifier.new);
