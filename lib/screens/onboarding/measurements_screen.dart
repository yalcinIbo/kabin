import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/widgets.dart';
import '../../providers/user/user_providers.dart';

/// Onboarding 2. adım: ad + (isteğe bağlı) ölçüler. Beden tavsiyesi ve avatar için kullanılır.
class OnboardingMeasurementsScreen extends ConsumerStatefulWidget {
  const OnboardingMeasurementsScreen({super.key});

  @override
  ConsumerState<OnboardingMeasurementsScreen> createState() => _OnboardingMeasurementsScreenState();
}

class _OnboardingMeasurementsScreenState extends ConsumerState<OnboardingMeasurementsScreen> {
  late final TextEditingController _name = TextEditingController(text: ref.read(onboardingNotifierProvider).displayName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) AppFeedback.showError(context, error);
    });
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seni tanıyalım'),
        actions: [
          TextButton(onPressed: state.isSaving ? null : () => notifier.complete(skipMeasurements: true), child: const Text('Atla')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Ölçülerin beden tavsiyesi ve selfie\'den stüdyo fotoğrafı üretmek için kullanılır. Sonra profilden değiştirebilirsin.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _name,
              label: 'Adın (isteğe bağlı)',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              onChanged: notifier.setDisplayName,
            ),
            const SizedBox(height: 20),
            MeasurementsForm(value: state.measurements, onChanged: notifier.setMeasurements, enabled: !state.isSaving),
            const SizedBox(height: 28),
            AppButton(label: 'Tamamla', isLoading: state.isSaving, onPressed: () => notifier.complete()),
          ],
        ),
      ),
    );
  }
}
