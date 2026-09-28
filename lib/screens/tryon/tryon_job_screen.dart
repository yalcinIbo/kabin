import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/enums.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../models/credit/credit_models.dart';
import '../../models/tryon/tryon_job_model.dart';
import '../../providers/credit/credit_providers.dart';
import '../../providers/model3d/model3d_providers.dart';
import '../../providers/tryon/tryon_providers.dart';
import 'widgets/fitting_progress.dart';
import 'widgets/result_carousel.dart';
import 'widgets/style_advice_card.dart';

/// Deneme işinin canlı durumu ve sonucu. İş bu ekrandayken biterse sonuç perde açılarak gösterilir.
class TryOnJobScreen extends ConsumerStatefulWidget {
  const TryOnJobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<TryOnJobScreen> createState() => _TryOnJobScreenState();
}

class _TryOnJobScreenState extends ConsumerState<TryOnJobScreen> {
  TryOnResultModel? _current;

  /// İşin sürdüğünü bu ekranda gördük mü? Gördüysek bitişte perde açılışı oynatılır.
  bool _sawActive = false;

  Future<void> _delete() async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Denemeyi sil',
      message: 'Sonuç görselleri kalıcı olarak silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await ref.read(tryOnResultActionsNotifierProvider(widget.jobId).notifier).delete();
    if (deleted && mounted) context.pop();
  }

  /// Açılabilir 3D modelin kimliği. Başarısız model açılmaz; kullanıcı yeniden isteyebilir (sunucu buna izin verir).
  String? _openable3dId(TryOnJobModel job) {
    final id = job.activeModel3dId;
    if (id == null) return null;
    final model = ref.watch(model3dProvider(id)).value;
    return model?.status == JobStatus.failed ? null : id;
  }

  Future<void> _request3D(TryOnJobModel job, int cost, String? existing) async {
    if (existing != null) {
      context.push(RouteNames.model3d(existing));
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: '3D model oluştur',
      message:
          'Bu denemeden döndürülebilir bir 3D model oluşturulacak ($cost kredi, 1-3 dakika). '
          'Model yapay zekâ ile tek bir görselden tahmin edilir; ayrıntılar yaklaşık olabilir.',
      confirmLabel: 'Oluştur',
    );
    if (!ok) return;
    final modelId = await ref.read(model3dRequestNotifierProvider(job.id).notifier).request();
    if (modelId != null && mounted) context.push(RouteNames.model3d(modelId));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tryOnResultActionsNotifierProvider(widget.jobId).select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    ref.listen(model3dRequestNotifierProvider(widget.jobId).select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final async = ref.watch(tryOnJobProvider(widget.jobId));
    final actions = ref.watch(tryOnResultActionsNotifierProvider(widget.jobId));
    final job = async.value;
    if (job != null && job.status.isActive) _sawActive = true;

    return Scaffold(
      appBar: AppBar(
        title: job != null && job.status.isActive ? const Text('Kabindesin') : null,
        actions: [
          if (job != null && job.status.isTerminal)
            IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded), onPressed: actions.isDeleting ? null : _delete),
          const SizedBox(width: 6),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Deneme yüklenemedi.'),
        data: (job) {
          if (job == null) return const EmptyView(title: 'Deneme bulunamadı', icon: Icons.search_off_rounded);
          if (job.status.isActive) return FittingProgress(job: job);
          if (job.status == JobStatus.failed) return _Failed(job: job);
          return _Result(
            job: job,
            reveal: _sawActive,
            current: _current ?? job.front,
            onAngleChanged: (r) => setState(() => _current = r),
            open3dId: _openable3dId(job),
            on3d: _request3D,
          );
        },
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({
    required this.job,
    required this.reveal,
    required this.current,
    required this.onAngleChanged,
    required this.open3dId,
    required this.on3d,
  });

  final TryOnJobModel job;
  final bool reveal;
  final TryOnResultModel? current;
  final ValueChanged<TryOnResultModel> onAngleChanged;
  final String? open3dId;
  final Future<void> Function(TryOnJobModel job, int cost, String? existing) on3d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = ref.watch(tryOnResultActionsNotifierProvider(job.id));
    final request3d = ref.watch(model3dRequestNotifierProvider(job.id));
    final pricing = ref.watch(pricingProvider).value ?? const PricingModel();
    final flags = ref.watch(featureFlagsProvider).value ?? const FeatureFlagsModel();
    final show3d = flags.model3dEnabled || open3dId != null;
    final meta = [if (job.createdAt != null) AppDateUtils.timeAgoLong(job.createdAt!), '${job.results.length} açı'].join('  ·  ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        Overline(meta),
        const SizedBox(height: 10),
        Text(job.title, style: AppType.serif(size: 30, color: scheme.onSurface)),
        const SizedBox(height: 18),
        CurtainReveal(
          animate: reveal,
          child: ResultCarousel(results: job.results, onPageChanged: onAngleChanged),
        ),
        if (job.multiViewFailed) ...[
          const SizedBox(height: 12),
          const Center(
            child: StatusBadge(label: 'Yan/arka üretilemedi · o kısmın kredisi iade edildi', icon: Icons.info_outline_rounded),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Paylaş',
                icon: Icons.ios_share_rounded,
                variant: AppButtonVariant.outline,
                height: 54,
                isLoading: actions.isSharing,
                onPressed: current == null
                    ? null
                    : () => ref.read(tryOnResultActionsNotifierProvider(job.id).notifier).share(current!, title: job.garmentTitle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Yeni deneme',
                icon: Icons.checkroom_rounded,
                height: 54,
                onPressed: () => context.go(RouteNames.tryOn),
              ),
            ),
          ],
        ),
        if (show3d) ...[
          const SizedBox(height: 10),
          AppButton(
            label: open3dId != null ? '3D modeli aç' : '3D model · ${pricing.model3d} kredi',
            icon: Icons.view_in_ar_rounded,
            variant: AppButtonVariant.secondary,
            height: 50,
            isLoading: request3d.isSubmitting,
            onPressed: () => on3d(job, pricing.model3d, open3dId),
          ),
          if (request3d.needsCredits) TextButton(onPressed: () => context.push(RouteNames.credits), child: const Text('Kredilerime bak')),
        ],
        if (job.styleAdvice != null) ...[const SizedBox(height: 24), StyleAdviceCard(advice: job.styleAdvice!)],
        const SizedBox(height: 16),
        Text(
          'Yapay zekâ ile üretilmiş görseldir; gerçek duruş ve beden farklı olabilir.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.job});

  final TryOnJobModel job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: scheme.errorContainer, shape: BoxShape.circle),
              child: Icon(Icons.dry_cleaning_outlined, size: 34, color: scheme.error),
            ),
            const SizedBox(height: 20),
            EditorialHeader(
              title: 'Bu sefer {olmadı}',
              size: 30,
              align: CrossAxisAlignment.center,
              subtitle: job.error?.messageTr ?? 'Beklenmeyen bir hata oluştu.',
            ),
            if (job.refunded) ...[
              const SizedBox(height: 14),
              const StatusBadge(label: 'Kredin iade edildi', tone: BadgeTone.positive, icon: Icons.undo_rounded),
            ],
            const SizedBox(height: 26),
            AppButton(label: 'Tekrar dene', icon: Icons.refresh_rounded, expanded: false, onPressed: () => context.go(RouteNames.tryOn)),
          ],
        ),
      ),
    );
  }
}
