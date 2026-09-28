import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/widgets.dart';
import '../../notifiers/garment/add_garment_notifier.dart';
import '../../providers/garment/garment_providers.dart';
import '../common/pick_source_sheet.dart';
import 'widgets/analysis_edit_form.dart';

/// Kıyafet ekleme: fotoğraf → yapay zekâ analizi → düzelt → kaydet.
class AddGarmentScreen extends ConsumerWidget {
  const AddGarmentScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final source = await showPickSourceSheet(context);
    if (source != null) await ref.read(addGarmentNotifierProvider.notifier).pick(source);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(addGarmentNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final state = ref.watch(addGarmentNotifierProvider);
    final notifier = ref.read(addGarmentNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kıyafet ekle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (state.file == null) ...[
              Text('Denemek istediğin kıyafetin fotoğrafı', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Askıda, yere serili, mankende ya da bir mağaza ekran görüntüsü olabilir. '
                'Kıyafet tek başına ve net görünsün.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Fotoğraf seç', icon: Icons.add_a_photo_outlined, onPressed: () => _pick(context, ref)),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: theme.colorScheme.surfaceContainerLow,
                  height: 280,
                  child: Image.file(state.file!, fit: BoxFit.contain, cacheWidth: 900),
                ),
              ),
              const SizedBox(height: 16),
              switch (state.step) {
                AddGarmentStep.pick => Row(
                  children: [
                    Expanded(
                      child: AppButton(label: 'Değiştir', variant: AppButtonVariant.outline, onPressed: () => _pick(context, ref)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(label: 'Analiz et', onPressed: notifier.submit),
                    ),
                  ],
                ),
                AddGarmentStep.uploading => Column(
                  children: [
                    LinearProgressIndicator(value: state.progress),
                    const SizedBox(height: 8),
                    const Text('Yükleniyor…'),
                  ],
                ),
                AddGarmentStep.analyzing => const LoadingView(message: 'Yapay zekâ kıyafeti inceliyor…'),
                AddGarmentStep.review =>
                  state.analysis == null
                      ? AppButton(label: 'Analizi tekrar dene', onPressed: notifier.retryAnalyze)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnalysisEditForm(analysis: state.analysis!, onChanged: notifier.updateAnalysis, enabled: !state.isSaving),
                            const SizedBox(height: 20),
                            AppButton(
                              label: 'Dolabıma kaydet',
                              isLoading: state.isSaving,
                              onPressed: () async {
                                if (await notifier.save() && context.mounted) context.pop();
                              },
                            ),
                            if (!state.analysisFailed && (state.analysis?.category.isTryOnSupported ?? false)) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () async {
                                  if (await notifier.saveAndSelectForTryOn() && context.mounted) context.pop();
                                },
                                child: const Text('Kaydet ve dene'),
                              ),
                            ],
                          ],
                        ),
              },
            ],
          ],
        ),
      ),
    );
  }
}
