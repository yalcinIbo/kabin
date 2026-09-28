import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../models/credit/credit_models.dart';
import '../../providers/credit/credit_providers.dart';
import '../../providers/photo/photo_providers.dart';
import '../common/pick_source_sheet.dart';

/// Selfie + ölçüler → yapay zekâ ile stüdyo tipi boydan fotoğraf.
class SelfieAvatarScreen extends ConsumerWidget {
  const SelfieAvatarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(selfieAvatarNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final state = ref.watch(selfieAvatarNotifierProvider);
    final notifier = ref.read(selfieAvatarNotifierProvider.notifier);
    final pricing = ref.watch(pricingProvider).value ?? const PricingModel();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Selfie\'den stüdyo fotoğrafı'), actions: const [CreditChip()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Boydan fotoğrafın yoksa selfie\'n ve ölçülerinle senin için stüdyo tipi bir fotoğraf oluşturalım. '
              'En gerçekçi sonuç yine de gerçek boydan fotoğrafla alınır.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Center(
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: state.isSubmitting
                    ? null
                    : () async {
                        final source = await showPickSourceSheet(context);
                        if (source != null) await notifier.pickSelfie(source);
                      },
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: state.selfie == null ? null : ResizeImage(FileImage(state.selfie!), width: 400),
                  child: state.selfie == null
                      ? Icon(Icons.face_retouching_natural_rounded, size: 48, color: theme.colorScheme.onPrimaryContainer)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(state.selfie == null ? 'Selfie seç' : 'Değiştirmek için dokun', style: theme.textTheme.labelLarge)),
            const SizedBox(height: 24),
            MeasurementsForm(value: state.measurements, onChanged: notifier.setMeasurements, enabled: !state.isSubmitting),
            const SizedBox(height: 24),
            if (state.isSubmitting) ...[
              LinearProgressIndicator(value: state.progress < 1 ? state.progress : null),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: 'Oluştur · ${pricing.avatar} kredi',
              icon: Icons.auto_awesome_rounded,
              isLoading: state.isSubmitting,
              onPressed: state.canSubmit
                  ? () async {
                      final photoId = await notifier.submit();
                      if (photoId != null && context.mounted) context.pushReplacement(RouteNames.photo(photoId));
                    }
                  : null,
            ),
            if (state.needsCredits) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.push(RouteNames.credits), child: const Text('Kredilerime bak')),
            ],
          ],
        ),
      ),
    );
  }
}
