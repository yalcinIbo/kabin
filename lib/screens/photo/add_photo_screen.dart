import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/widgets.dart';
import '../../notifiers/photo/add_photo_notifier.dart';
import '../../providers/photo/photo_providers.dart';
import '../common/pick_source_sheet.dart';
import 'widgets/qc_feedback_card.dart';

/// Boydan fotoğraf ekleme + Gemini kalite kontrolü.
class AddPhotoScreen extends ConsumerWidget {
  const AddPhotoScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final source = await showPickSourceSheet(context);
    if (source != null) await ref.read(addPhotoNotifierProvider.notifier).pick(source);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(addPhotoNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final state = ref.watch(addPhotoNotifierProvider);
    final notifier = ref.read(addPhotoNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Boydan fotoğraf')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (state.file == null) ...[
              Text('İyi bir fotoğraf için', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              const _Tip(icon: Icons.accessibility_new_rounded, text: 'Baştan ayağa tüm vücudun görünsün.'),
              const _Tip(icon: Icons.person_rounded, text: 'Kameraya karşıdan, dik dur; fotoğrafta yalnızca sen ol.'),
              const _Tip(icon: Icons.back_hand_outlined, text: 'Kolların gövdeni kapatmasın, hafifçe yana aç.'),
              const _Tip(icon: Icons.wb_sunny_outlined, text: 'Aydınlık, sade bir arka plan tercih et.'),
              const _Tip(icon: Icons.checkroom_outlined, text: 'Vücuduna oturan, sade kıyafetler en iyi sonucu verir.'),
              const SizedBox(height: 24),
              AppButton(label: 'Fotoğraf seç', icon: Icons.add_a_photo_outlined, onPressed: () => _pick(context, ref)),
            ] else ...[
              // Tüm vücut görünsün diye kırpmadan (contain) gösterilir.
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 440,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Image.file(state.file!, fit: BoxFit.contain, cacheWidth: 1080),
                ),
              ),
              const SizedBox(height: 16),
              if (state.step == AddPhotoStep.uploading) ...[
                LinearProgressIndicator(value: state.progress),
                const SizedBox(height: 8),
                const Text('Yükleniyor…', textAlign: TextAlign.center),
              ],
              if (state.step == AddPhotoStep.checking) const LoadingView(message: 'Fotoğraf kontrol ediliyor…'),
              if (state.result?.qc != null) QcFeedbackCard(qc: state.result!.qc!),
              const SizedBox(height: 16),
              if (state.step == AddPhotoStep.pick)
                Row(
                  children: [
                    Expanded(
                      child: AppButton(label: 'Değiştir', variant: AppButtonVariant.outline, onPressed: () => _pick(context, ref)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(label: 'Kontrol et', onPressed: notifier.submit),
                    ),
                  ],
                ),
              if (state.step == AddPhotoStep.result && state.result == null && state.photoId != null)
                AppButton(label: 'Kontrolü tekrar dene', onPressed: notifier.retryCheck),
              if (state.step == AddPhotoStep.result && state.result != null)
                state.passed
                    ? AppButton(label: 'Tamam', onPressed: () => context.pop())
                    : AppButton(
                        label: 'Başka fotoğraf seç',
                        onPressed: () async {
                          notifier.reset();
                          await _pick(context, ref);
                        },
                      ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
