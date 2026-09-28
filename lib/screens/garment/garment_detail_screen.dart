import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums/enums.dart';
import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../models/garment/garment_model.dart';
import '../../providers/garment/garment_providers.dart';
import '../../providers/tryon/tryon_providers.dart';
import 'widgets/analysis_edit_form.dart';

class GarmentDetailScreen extends ConsumerStatefulWidget {
  const GarmentDetailScreen({super.key, required this.garmentId});

  final String garmentId;

  @override
  ConsumerState<GarmentDetailScreen> createState() => _GarmentDetailScreenState();
}

class _GarmentDetailScreenState extends ConsumerState<GarmentDetailScreen> {
  GarmentAnalysisModel? _draft;
  bool _editing = false;

  Future<void> _delete() async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Kıyafeti sil',
      message: 'Bu kıyafet dolabından kalıcı olarak silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await ref.read(garmentEditNotifierProvider(widget.garmentId).notifier).delete();
    if (!mounted || !deleted) return;
    ref.read(tryOnRequestNotifierProvider.notifier).forgetGarment(widget.garmentId);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(garmentEditNotifierProvider(widget.garmentId).select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final async = ref.watch(garmentProvider(widget.garmentId));
    final edit = ref.watch(garmentEditNotifierProvider(widget.garmentId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kıyafet'),
        actions: [
          if (async.value?.isReady ?? false)
            IconButton(
              tooltip: _editing ? 'Vazgeç' : 'Düzenle',
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined),
              onPressed: () => setState(() {
                _editing = !_editing;
                _draft = async.value?.analysis;
              }),
            ),
          IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded), onPressed: edit.isDeleting ? null : _delete),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Kıyafet yüklenemedi.'),
        data: (garment) {
          if (garment == null) return const EmptyView(title: 'Kıyafet bulunamadı', icon: Icons.checkroom_outlined);
          final analysis = garment.analysis;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 320,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: StorageImage(path: garment.storagePath, fit: BoxFit.contain, cacheWidth: AppConstants.detailCacheWidth),
                ),
              ),
              const SizedBox(height: 16),
              if (garment.status == GarmentStatus.analyzing) const LoadingView(message: 'Analiz ediliyor…'),
              if (garment.status == GarmentStatus.failed)
                ErrorView(message: garment.errorTr ?? 'Bu fotoğrafta kıyafet algılanamadı.', compact: true),
              if (analysis != null && !_editing) ...[
                Text(garment.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(analysis.category.labelTr)),
                    Chip(
                      avatar: CircleAvatar(backgroundColor: analysis.color, radius: 8),
                      label: Text(analysis.colorNameTr.isEmpty ? 'Renk' : analysis.colorNameTr),
                    ),
                    if (analysis.fabricGuess.isNotEmpty) Chip(label: Text(analysis.fabricGuess)),
                    Chip(label: Text(analysis.garmentPhotoType.labelTr)),
                  ],
                ),
                if (analysis.descriptionTr.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(analysis.descriptionTr, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 20),
                if (garment.canTryOn)
                  AppButton(
                    label: 'Bu kıyafeti dene',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () {
                      ref.read(tryOnRequestNotifierProvider.notifier).selectGarment(garment);
                      context.go(RouteNames.tryOn);
                    },
                  )
                else
                  Text(
                    'Bu kıyafet türü henüz denenemiyor. Kategori yanlışsa düzenleyebilirsin.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
              if (_editing && _draft != null) ...[
                AnalysisEditForm(analysis: _draft!, onChanged: (a) => setState(() => _draft = a), enabled: !edit.isSaving),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Kaydet',
                  isLoading: edit.isSaving,
                  onPressed: () async {
                    final ok = await ref.read(garmentEditNotifierProvider(widget.garmentId).notifier).save(_draft!);
                    if (ok && mounted) setState(() => _editing = false);
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
