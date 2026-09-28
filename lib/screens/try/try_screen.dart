import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/enums.dart';
import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../models/credit/credit_models.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/credit/credit_providers.dart';
import '../../providers/photo/photo_providers.dart';
import '../../providers/tryon/tryon_providers.dart';
import '../home/app_shell.dart';
import 'widgets/fitting_stage.dart';
import 'widgets/picker_sheets.dart';

/// Ana ekran: fotoğrafını ve kıyafeti seç → dene.
class TryScreen extends ConsumerStatefulWidget {
  const TryScreen({super.key});

  @override
  ConsumerState<TryScreen> createState() => _TryScreenState();
}

class _TryScreenState extends ConsumerState<TryScreen> {
  @override
  void initState() {
    super.initState();
    // Kullanıcı henüz seçim yapmadıysa varsayılan fotoğrafı seç.
    ref.listenManual(defaultPhotoProvider, (_, next) {
      final photo = next.value;
      if (photo != null && photo.isReady && ref.read(tryOnRequestNotifierProvider).photo == null) {
        ref.read(tryOnRequestNotifierProvider.notifier).selectPhoto(photo);
      }
    }, fireImmediately: true);
  }

  Future<void> _submit() async {
    final jobId = await ref.read(tryOnRequestNotifierProvider.notifier).submit();
    if (jobId != null && mounted) context.push(RouteNames.tryOnJob(jobId));
  }

  Future<void> _showNoCredits(String message) async {
    final go = await AppFeedback.confirm(context, title: 'Kredin yetersiz', message: message, confirmLabel: 'Kredilerim');
    ref.read(tryOnRequestNotifierProvider.notifier).clearError();
    if (go && mounted) context.push(RouteNames.credits);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tryOnRequestNotifierProvider.select((s) => (s.error, s.needsCredits)), (_, next) {
      final (error, needsCredits) = next;
      if (error == null) return;
      if (needsCredits) {
        _showNoCredits(error);
      } else {
        AppFeedback.showError(context, error);
        ref.read(tryOnRequestNotifierProvider.notifier).clearError();
      }
    });
    final state = ref.watch(tryOnRequestNotifierProvider);
    final notifier = ref.read(tryOnRequestNotifierProvider.notifier);
    final pricing = ref.watch(pricingProvider).value ?? const PricingModel();
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final theme = Theme.of(context);
    final cost = pricing.tryOnCost(multiView: state.multiView);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, AppShell.bottomInset(context)),
          children: [
            Row(children: [const Wordmark(size: 26), const Spacer(), const CreditChip(padRight: false)]),
            const SizedBox(height: 26),
            const EditorialHeader(
              overline: 'Sanal kabin',
              title: 'Üstünde {nasıl}\ndurur?',
              size: 44,
              subtitle: 'Fotoğrafını ve kıyafeti seç; yapay zekâ seni kabinde giydirsin.',
            ),
            const SizedBox(height: 26),
            FittingStage(
              photoPath: state.photo?.displayPath,
              garmentPath: state.garment?.displayPath,
              garmentTitle: state.garment?.title,
              onPickPhoto: () async {
                final picked = await showPhotoPickerSheet(context, selectedId: state.photo?.id);
                if (picked != null) notifier.selectPhoto(picked);
              },
              onPickGarment: () async {
                final picked = await showGarmentPickerSheet(context, selectedId: state.garment?.id);
                if (picked != null) notifier.selectGarment(picked);
              },
            ),
            const SizedBox(height: 22),
            AngleOptionTile(
              value: state.multiView,
              onChanged: state.isSubmitting ? null : notifier.setMultiView,
              extraCost: pricing.multiView,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              const Overline('Sağlayıcı · yönetici'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Varsayılan'),
                    selected: state.provider == null,
                    onSelected: (_) => notifier.setProvider(null),
                  ),
                  for (final c in TryOnProviderChoice.values)
                    ChoiceChip(label: Text(c.labelTr), selected: state.provider == c, onSelected: (_) => notifier.setProvider(c)),
                ],
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              label: 'Kabine gir · $cost kredi',
              icon: Icons.auto_awesome_rounded,
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: state.isSubmitting,
              onPressed: state.canSubmit ? _submit : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Görsel yapay zekâ ile üretilir; gerçek duruş ve beden farklı olabilir.\nBaşarısız denemede kredin iade edilir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
