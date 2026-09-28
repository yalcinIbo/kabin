import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/enums.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/widgets.dart';
import '../../models/credit/credit_models.dart';
import '../../providers/credit/credit_providers.dart';
import '../../providers/user/user_providers.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(creditsProvider);
    final pricing = ref.watch(pricingProvider).value ?? const PricingModel();
    final notifier = ref.read(ledgerNotifierProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$credits kredi', style: theme.textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Başarısız işlemlerde kredin otomatik iade edilir.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _PriceRow(icon: Icons.checkroom_rounded, label: 'Deneme (ön görünüm)', cost: pricing.tryon),
                  _PriceRow(icon: Icons.threed_rotation_rounded, label: 'Yan + arka görünüm', cost: pricing.multiView, plus: true),
                  if (ref.watch(featureFlagsProvider).value?.model3dEnabled ?? false)
                    _PriceRow(icon: Icons.view_in_ar_rounded, label: '3D model', cost: pricing.model3d),
                  _PriceRow(icon: Icons.face_retouching_natural_rounded, label: 'Selfie\'den stüdyo fotoğrafı', cost: pricing.avatar),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kredi paketleri yakında. Şimdilik hoş geldin kredisiyle deneyebilirsin.',
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Hareketler', style: theme.textTheme.titleMedium),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Kredilerim')),
      body: ref
          .watch(ledgerNotifierProvider)
          .when(
            loading: () => ListView(children: [header, const LoadingView()]),
            error: (e, _) => ListView(
              children: [
                header,
                ErrorView(message: 'Hareketler yüklenemedi.', onRetry: notifier.refresh, compact: true),
              ],
            ),
            data: (state) => PagedListView<LedgerEntryModel>(
              state: state,
              header: header,
              padding: const EdgeInsets.only(bottom: 24),
              onLoadMore: notifier.loadMore,
              onRefresh: notifier.refresh,
              emptyBuilder: (_) => ListView(
                children: [
                  header,
                  const EmptyView(title: 'Henüz hareket yok', icon: Icons.receipt_long_outlined),
                ],
              ),
              itemBuilder: (context, e, _) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: e.amount >= 0 ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                  child: Icon(switch (e.type) {
                    LedgerType.refund => Icons.undo_rounded,
                    LedgerType.debit => Icons.remove_rounded,
                    _ => Icons.card_giftcard_rounded,
                  }, color: e.amount >= 0 ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                ),
                title: Text(e.descriptionTr),
                subtitle: e.createdAt == null ? null : Text(AppDateUtils.formatDateTime(e.createdAt!)),
                trailing: Text(
                  '${e.amount > 0 ? '+' : ''}${e.amount}',
                  style: theme.textTheme.titleMedium?.copyWith(color: e.amount >= 0 ? scheme.primary : scheme.onSurface),
                ),
              ),
            ),
          ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.icon, required this.label, required this.cost, this.plus = false});

  final IconData icon;
  final String label;
  final int cost;
  final bool plus;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon),
    title: Text(label),
    trailing: Text('${plus ? '+' : ''}$cost kredi', style: Theme.of(context).textTheme.labelLarge),
  );
}
