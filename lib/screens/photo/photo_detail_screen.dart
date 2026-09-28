import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums/enums.dart';
import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/photo/photo_providers.dart';
import '../../providers/tryon/tryon_providers.dart';
import 'widgets/qc_feedback_card.dart';

class PhotoDetailScreen extends ConsumerWidget {
  const PhotoDetailScreen({super.key, required this.photoId});

  final String photoId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Fotoğrafı sil',
      message: 'Bu fotoğraf kalıcı olarak silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!ok) return;
    final error = await ref.read(photosNotifierProvider.notifier).delete(photoId);
    if (!context.mounted) return;
    if (error != null) return AppFeedback.showError(context, error);
    ref.read(tryOnRequestNotifierProvider.notifier).forgetPhoto(photoId);
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(photoProvider(photoId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotoğraf'),
        actions: [
          if (async.value != null && async.value!.status != PhotoStatus.processing)
            IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(context, ref)),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Fotoğraf yüklenemedi.'),
        data: (photo) {
          if (photo == null) return const EmptyView(title: 'Fotoğraf bulunamadı', icon: Icons.image_not_supported_outlined);
          if (photo.isGenerated && photo.status.isBusy) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: JobProgressView(
                  status: photo.status == PhotoStatus.pending ? JobStatus.queued : JobStatus.processing,
                  stage: photo.stage,
                  progress: photo.progress,
                  hint: 'Stüdyo fotoğrafın hazırlanıyor. Bu 30-90 saniye sürebilir.',
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: (photo.width ?? 3) / (photo.height ?? 4),
                  child: StorageImage(path: photo.storagePath ?? photo.thumbPath, cacheWidth: AppConstants.detailCacheWidth),
                ),
              ),
              const SizedBox(height: 16),
              if (photo.status == PhotoStatus.failed)
                ErrorView(message: photo.error?.messageTr ?? 'Fotoğraf oluşturulamadı. Kredin iade edildi.', compact: true),
              if (photo.qc != null) QcFeedbackCard(qc: photo.qc!),
              const SizedBox(height: 16),
              if (photo.isReady && !photo.isDefault)
                AppButton(
                  label: 'Varsayılan yap',
                  icon: Icons.star_outline_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    final error = await ref.read(photosNotifierProvider.notifier).setDefault(photo.id);
                    if (!context.mounted) return;
                    error != null
                        ? AppFeedback.showError(context, error)
                        : AppFeedback.showSuccess(context, 'Varsayılan fotoğraf güncellendi.');
                  },
                ),
              if (photo.isDefault)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    const Text('Varsayılan fotoğrafın'),
                  ],
                ),
              if (photo.isReady) ...[
                const SizedBox(height: 12),
                AppButton(
                  label: 'Bu fotoğrafla dene',
                  onPressed: () {
                    ref.read(tryOnRequestNotifierProvider.notifier).selectPhoto(photo);
                    context.go(RouteNames.tryOn);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
