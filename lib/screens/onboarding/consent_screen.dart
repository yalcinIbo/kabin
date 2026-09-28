import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/user/user_providers.dart';

/// KVKK aydınlatma + açık rıza (fotoğrafların işlenmesi ve yurt dışındaki AI servislerine aktarımı).
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final theme = Theme.of(context);
    final isReconsent = ref.watch(currentUserProvider).value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik ve onay'),
        actions: [TextButton(onPressed: () => ref.read(authNotifierProvider.notifier).signOut(), child: const Text('Çıkış'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Center(child: AppLogo(size: 64)),
            const SizedBox(height: 20),
            Text(isReconsent ? 'Metinlerimiz güncellendi' : 'Başlamadan önce', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Kabin, fotoğraflarını yalnızca senin için sanal deneme görseli üretmek amacıyla işler. '
              'Fotoğrafların başka kullanıcılarla paylaşılmaz ve istediğin an hesabınla birlikte silebilirsin.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _ConsentTile(
              value: state.kvkkAccepted,
              onChanged: notifier.setKvkk,
              title: 'KVKK Aydınlatma Metni\'ni okudum; boydan fotoğraflarımın ve kıyafet fotoğraflarımın işlenmesine açık rıza veriyorum.',
            ),
            const SizedBox(height: 10),
            _ConsentTile(
              value: state.aiTransferAccepted,
              onChanged: notifier.setAiTransfer,
              title:
                  'Görsellerimin deneme görseli üretmek için yurt dışında bulunan yapay zekâ hizmet sağlayıcılarına '
                  '(Google Gemini/Vertex AI, fal.ai) aktarılmasına açık rıza veriyorum.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(RouteNames.legal),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Aydınlatma metnini oku'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '18 yaşından küçüklerin fotoğrafları işlenmez.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Devam et', onPressed: state.canContinue ? () => context.push(RouteNames.onboardingMeasurements) : null),
          ],
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.value, required this.onChanged, required this.title});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: value ? scheme.primaryContainer.withValues(alpha: 0.6) : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
