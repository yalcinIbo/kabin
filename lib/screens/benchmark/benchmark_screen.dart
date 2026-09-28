import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/benchmark/benchmark_providers.dart';
import '../../providers/garment/garment_providers.dart';
import '../../providers/photo/photo_providers.dart';

/// Yönetici: FASHN × Vertex karşılaştırma koşuları.
class BenchmarkScreen extends ConsumerWidget {
  const BenchmarkScreen({super.key});

  Future<void> _newRun(BuildContext context, WidgetRef ref) async {
    final photo = ref.read(defaultPhotoProvider).value;
    if (photo == null || !photo.isReady) {
      AppFeedback.showError(context, 'Önce hazır bir varsayılan fotoğraf seç.');
      return;
    }
    final garments = ref.read(garmentsNotifierProvider).value?.items.where((g) => g.canTryOn).take(10).toList() ?? const [];
    if (garments.isEmpty) {
      AppFeedback.showError(context, 'Dolabında denenebilir kıyafet yok.');
      return;
    }
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _GarmentSelectSheet(options: {for (final g in garments) g.id: g.title}),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    final runId = await ref.read(benchmarkNotifierProvider.notifier).start(photoId: photo.id, garmentIds: selected);
    if (runId != null && context.mounted) context.push(RouteNames.benchmarkRun(runId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(benchmarkNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final busy = ref.watch(benchmarkNotifierProvider.select((s) => s.isSubmitting));
    return Scaffold(
      appBar: AppBar(title: const Text('Sağlayıcı karşılaştırması')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => _newRun(context, ref),
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.play_arrow_rounded),
        label: const Text('Yeni koşu'),
      ),
      body: ref
          .watch(benchmarkRunsProvider)
          .when(
            loading: () => const ListSkeleton(),
            error: (e, _) => const ErrorView(message: 'Koşular yüklenemedi (yönetici yetkisi gerekli).'),
            data: (runs) => runs.isEmpty
                ? const EmptyView(
                    title: 'Henüz koşu yok',
                    subtitle: 'Varsayılan fotoğrafın ile seçtiğin kıyafetler her iki sağlayıcıda denenir; kredi düşmez.',
                    icon: Icons.compare_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                    itemCount: runs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = runs[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${r.pairCount}')),
                        title: Text(r.providers.join(' × ').toUpperCase()),
                        subtitle: Text(
                          '${r.doneCount}/${r.pairCount} tamamlandı${r.createdAt == null ? '' : ' · ${AppDateUtils.timeAgoLong(r.createdAt!)}'}',
                        ),
                        trailing: r.isComplete
                            ? const Icon(Icons.check_circle_rounded)
                            : const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        onTap: () => context.push(RouteNames.benchmarkRun(r.id)),
                      );
                    },
                  ),
          ),
    );
  }
}

class _GarmentSelectSheet extends StatefulWidget {
  const _GarmentSelectSheet({required this.options});

  final Map<String, String> options;

  @override
  State<_GarmentSelectSheet> createState() => _GarmentSelectSheetState();
}

class _GarmentSelectSheetState extends State<_GarmentSelectSheet> {
  late final Set<String> _selected = widget.options.keys.toSet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Karşılaştırılacak kıyafetler', style: Theme.of(context).textTheme.titleLarge),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in widget.options.entries)
                CheckboxListTile(
                  value: _selected.contains(e.key),
                  title: Text(e.value),
                  onChanged: (v) => setState(() => v == true ? _selected.add(e.key) : _selected.remove(e.key)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: AppButton(
            label: 'Başlat (${_selected.length})',
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
          ),
        ),
      ],
    ),
  );
}
