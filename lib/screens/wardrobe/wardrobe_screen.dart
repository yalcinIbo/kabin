import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/garment/garment_providers.dart';
import '../../providers/photo/photo_providers.dart';
import '../home/app_shell.dart';
import '../home/tab_page.dart';
import 'widgets/garment_tile.dart';
import 'widgets/photo_tile.dart';

/// Dolabım: kıyafetler ve boydan fotoğraflar.
class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  int _tab = 0;

  void _add() {
    if (_tab == 0) {
      context.push(RouteNames.addGarment);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EditorialHeader(title: 'Yeni {fotoğraf}', size: 26),
              const SizedBox(height: 16),
              PaperCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.accessibility_new_rounded),
                      title: const Text('Boydan fotoğraf yükle'),
                      subtitle: const Text('En gerçekçi sonuç'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push(RouteNames.addPhoto);
                      },
                    ),
                    const Divider(height: 1, indent: 18, endIndent: 18),
                    ListTile(
                      leading: const Icon(Icons.face_retouching_natural_rounded),
                      title: const Text('Selfie\'den stüdyo fotoğrafı'),
                      subtitle: const Text('Boydan fotoğrafın yoksa'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push(RouteNames.selfieAvatar);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TabPage(
      overline: 'Koleksiyon',
      title: 'Dolab{ım}',
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Semantics(
          button: true,
          label: _tab == 0 ? 'Kıyafet ekle' : 'Fotoğraf ekle',
          child: Material(
            color: scheme.secondary,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _add,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: scheme.onSecondary),
                    const SizedBox(width: 6),
                    Text('Ekle', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      below: PillSegments(labels: const ['Kıyafetler', 'Fotoğraflarım'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _tab == 0 ? const _GarmentsTab(key: ValueKey('g')) : const _PhotosTab(key: ValueKey('p')),
      ),
    );
  }
}

class _GarmentsTab extends ConsumerWidget {
  const _GarmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(garmentsNotifierProvider);
    final notifier = ref.read(garmentsNotifierProvider.notifier);
    return async.when(
      loading: () => const GridSkeleton(aspectRatio: 0.72),
      error: (e, _) => ErrorView(message: 'Kıyafetler yüklenemedi.', onRetry: notifier.refresh),
      data: (state) => PagedGridView(
        state: state,
        childAspectRatio: 0.72,
        padding: EdgeInsets.fromLTRB(20, 14, 20, AppShell.bottomInset(context)),
        onLoadMore: notifier.loadMore,
        onRefresh: notifier.refresh,
        emptyBuilder: (_) => EmptyView(
          icon: Icons.checkroom_rounded,
          title: 'Dolabın boş',
          subtitle: 'Denemek istediğin kıyafetin fotoğrafını çek: mağazada, askıda ya da ekran görüntüsü.',
          action: FilledButton.icon(
            onPressed: () => context.push(RouteNames.addGarment),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Kıyafet ekle'),
          ),
        ),
        itemBuilder: (context, g) => GarmentTile(garment: g, onTap: () => context.push(RouteNames.garment(g.id))),
      ),
    );
  }
}

class _PhotosTab extends ConsumerWidget {
  const _PhotosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(photosNotifierProvider);
    final notifier = ref.read(photosNotifierProvider.notifier);
    return async.when(
      loading: () => const GridSkeleton(),
      error: (e, _) => ErrorView(message: 'Fotoğraflar yüklenemedi.', onRetry: notifier.refresh),
      data: (state) => PagedGridView(
        state: state,
        padding: EdgeInsets.fromLTRB(20, 14, 20, AppShell.bottomInset(context)),
        onLoadMore: notifier.loadMore,
        onRefresh: notifier.refresh,
        emptyBuilder: (_) => EmptyView(
          icon: Icons.accessibility_new_rounded,
          title: 'Henüz fotoğrafın yok',
          subtitle: 'Kıyafetleri üzerinde görmek için baştan ayağa bir fotoğrafını ekle.',
          action: FilledButton.icon(
            onPressed: () => context.push(RouteNames.addPhoto),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Fotoğraf ekle'),
          ),
        ),
        itemBuilder: (context, p) => PhotoTile(photo: p, onTap: () => context.push(RouteNames.photo(p.id))),
      ),
    );
  }
}
