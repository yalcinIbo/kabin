import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../providers/benchmark/benchmark_providers.dart';

class BenchmarkState {
  const BenchmarkState({this.isSubmitting = false, this.createdRunId, this.error});

  final bool isSubmitting;
  final String? createdRunId;
  final String? error;

  BenchmarkState copyWith({bool? isSubmitting, String? createdRunId, String? error, bool clearError = false}) => BenchmarkState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    createdRunId: createdRunId ?? this.createdRunId,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Yönetici: FASHN × Vertex karşılaştırma koşusu başlatma ve puanlama.
class BenchmarkNotifier extends Notifier<BenchmarkState> {
  @override
  BenchmarkState build() => const BenchmarkState();

  Future<String?> start({
    required String photoId,
    required List<String> garmentIds,
    List<String> providers = const ['fashn', 'vertex'],
  }) async {
    if (garmentIds.isEmpty) {
      state = state.copyWith(error: 'En az bir kıyafet seç.');
      return null;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final runId = await ref
          .read(benchmarkRepositoryProvider)
          .runBenchmark(photoId: photoId, garmentIds: garmentIds, providers: providers);
      if (ref.mounted) state = state.copyWith(isSubmitting: false, createdRunId: runId);
      return runId;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isSubmitting: false, error: ErrorMapper.map(e).message);
      return null;
    }
  }

  Future<void> rate(String runId, String pairId, String winner) async {
    try {
      await ref.read(benchmarkRepositoryProvider).rate(runId, pairId, winner);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: ErrorMapper.map(e).message);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
