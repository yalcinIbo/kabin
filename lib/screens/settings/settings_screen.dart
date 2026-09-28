import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/auth/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          const _Header('Hesap'),
          ListTile(
            leading: const Icon(Icons.straighten_rounded),
            title: const Text('Ölçülerim ve adım'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(RouteNames.measurements),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Kredilerim'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(RouteNames.credits),
          ),
          const Divider(),
          const _Header('Gizlilik'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('KVKK aydınlatma metni'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(RouteNames.legal),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Destek'),
            subtitle: const Text(AppConstants.supportEmail),
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: AppConstants.supportEmail, query: 'subject=Kabin destek')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Çıkış yap'),
            onTap: () async {
              final ok = await AppFeedback.confirm(
                context,
                title: 'Çıkış yap',
                message: 'Hesabından çıkış yapmak istiyor musun?',
                confirmLabel: 'Çıkış yap',
              );
              if (ok) await ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text('Hesabımı ve verilerimi sil', style: TextStyle(color: scheme.error)),
            onTap: () => context.push(RouteNames.deleteAccount),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}
