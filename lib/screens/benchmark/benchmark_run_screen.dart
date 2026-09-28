import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/widgets.dart';
import '../../models/benchmark/benchmark_models.dart';
import '../../providers/benchmark/benchmark_providers.dart';

/// Bir koşunun çiftleri: kişi + kıyafet ve her sağlayıcının sonucu yan yana; yönetici kazananı işaretler.
class BenchmarkRunScreen extends ConsumerWidget {
  const BenchmarkRunScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karşılaştırma')),
      body: ref
          .watch(benchmarkPairsProvider(runId))
          .when(
            loading: () => const ListSkeleton(),
            error: (e, _) => const ErrorView(message: 'Sonuçlar yüklenemedi.'),
            data: (pairs) => pairs.isEmpty
                ? const EmptyView(title: 'Çift bulunamadı', icon: Icons.compare_rounded)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: pairs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _PairCard(runId: runId, pair: pairs[i]),
                  ),
          ),
    );
  }
}

class _PairCard extends ConsumerWidget {
  const _PairCard({required this.runId, required this.pair});

  final String runId;
  final BenchmarkPairModel pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providers = pair.results.keys.toList()..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 58,
                  child: StorageImage(path: pair.photoThumbPath, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 58,
                  child: StorageImage(path: pair.garmentThumbPath, fit: BoxFit.contain, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(pair.garmentTitle ?? pair.id, style: theme.textTheme.titleSmall)),
                if (!pair.isDone) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            if (pair.isDone) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in providers) ...[
                    Expanded(
                      child: _ResultColumn(provider: p, result: pair.results[p]!, winner: pair.winner == p),
                    ),
                    if (p != providers.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in [...providers, 'esit'])
                    ChoiceChip(
                      label: Text(p == 'esit' ? 'Eşit' : '${p.toUpperCase()} daha iyi'),
                      selected: pair.winner == p,
                      onSelected: (_) => ref.read(benchmarkNotifierProvider.notifier).rate(runId, pair.id, p),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultColumn extends StatelessWidget {
  const _ResultColumn({required this.provider, required this.result, required this.winner});

  final String provider;
  final BenchmarkResultModel result;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(provider.toUpperCase(), style: theme.textTheme.labelLarge),
            if (winner) ...[const SizedBox(width: 4), Icon(Icons.emoji_events_rounded, size: 16, color: theme.colorScheme.secondary)],
          ],
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: result.storagePath == null
              ? Container(
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(result.error ?? 'Hata', maxLines: 6, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
                )
              : StorageImage(
                  path: result.storagePath,
                  cacheWidth: AppConstants.gridCacheWidth * 2,
                  borderRadius: BorderRadius.circular(12),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(result.ms / 1000).toStringAsFixed(1)} sn · \$${result.costUsd.toStringAsFixed(3)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
