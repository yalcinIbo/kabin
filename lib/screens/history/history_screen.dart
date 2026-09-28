import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/enums.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../models/tryon/tryon_job_model.dart';
import '../../providers/tryon/tryon_providers.dart';
import '../home/app_shell.dart';
import '../home/tab_page.dart';

/// Geçmiş denemeler: dergi ızgarası.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tryOnHistoryNotifierProvider.notifier);
    return TabPage(
      overline: 'Arşiv',
      title: 'Kabin {geçmişin}',
      child: ref
          .watch(tryOnHistoryNotifierProvider)
          .when(
            loading: () => const GridSkeleton(aspectRatio: 0.6),
            error: (e, _) => ErrorView(message: 'Geçmiş yüklenemedi.', onRetry: notifier.refresh),
            data: (state) => PagedGridView<TryOnJobModel>(
              state: state,
              childAspectRatio: 0.6,
              padding: EdgeInsets.fromLTRB(20, 14, 20, AppShell.bottomInset(context)),
              onLoadMore: notifier.loadMore,
              onRefresh: notifier.refresh,
              emptyBuilder: (_) => EmptyView(
                icon: Icons.history_rounded,
                title: 'Henüz deneme yapmadın',
                subtitle: 'İlk denemeni yap; sonuçlar burada saklanır.',
                action: FilledButton(onPressed: () => context.go(RouteNames.tryOn), child: const Text('Kabine gir')),
              ),
              itemBuilder: (context, job) => _HistoryCard(job: job),
            ),
          ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.job});

  final TryOnJobModel job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = job.status.isActive ? ref.watch(tryOnJobProvider(job.id)).value ?? job : job;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = live.status == JobStatus.failed;
    return Semantics(
      button: true,
      label: '${live.title}, ${live.status.labelTr}',
      child: GestureDetector(
        onTap: () => context.push(RouteNames.tryOnJob(live.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.surfaceContainer,
                      child: ColorFiltered(
                        colorFilter: failed
                            ? const ColorFilter.matrix([
                                0.33,
                                0.33,
                                0.33,
                                0,
                                0,
                                0.33,
                                0.33,
                                0.33,
                                0,
                                0,
                                0.33,
                                0.33,
                                0.33,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ])
                            : const ColorFilter.mode(AppColors.transparent, BlendMode.dst),
                        child: StorageImage(
                          path: live.thumbPath ?? live.garmentThumbPath,
                          fit: live.thumbPath == null ? BoxFit.contain : BoxFit.cover,
                        ),
                      ),
                    ),
                    if (live.status != JobStatus.done)
                      Positioned(
                        left: 10,
                        top: 10,
                        right: 10,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            StatusBadge(label: live.status.labelTr, tone: failed ? BadgeTone.negative : BadgeTone.warning, onImage: true),
                            if (live.refunded) const StatusBadge(label: 'İade', icon: Icons.undo_rounded, onImage: true),
                          ],
                        ),
                      ),
                    if (live.multiView && live.status == JobStatus.done)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: StatusBadge(label: '${live.results.length} açı', icon: Icons.threed_rotation_rounded, onImage: true),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              live.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.serif(size: 16, weight: FontWeight.w600, color: scheme.onSurface, height: 1.2),
            ),
            const SizedBox(height: 2),
            if (live.createdAt != null)
              Text(AppDateUtils.timeAgoLong(live.createdAt!), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
