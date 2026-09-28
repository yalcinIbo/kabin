import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/garment/garment_model.dart';
import '../../../models/photo/photo_model.dart';
import '../../../providers/garment/garment_providers.dart';
import '../../../providers/photo/photo_providers.dart';
import '../../wardrobe/widgets/garment_tile.dart';
import '../../wardrobe/widgets/photo_tile.dart';

Future<PhotoModel?> showPhotoPickerSheet(BuildContext context, {String? selectedId}) {
  return showModalBottomSheet<PhotoModel>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _PickerFrame(
      title: 'Fotoğrafını seç',
      addLabel: 'Yeni fotoğraf',
      onAdd: (ctx) {
        Navigator.pop(ctx);
        context.push(RouteNames.addPhoto);
      },
      child: _PhotoGrid(selectedId: selectedId),
    ),
  );
}

Future<GarmentModel?> showGarmentPickerSheet(BuildContext context, {String? selectedId}) {
  return showModalBottomSheet<GarmentModel>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _PickerFrame(
      title: 'Kıyafet seç',
      addLabel: 'Yeni kıyafet',
      onAdd: (ctx) {
        Navigator.pop(ctx);
        context.push(RouteNames.addGarment);
      },
      child: _GarmentGrid(selectedId: selectedId),
    ),
  );
}

class _PickerFrame extends StatelessWidget {
  const _PickerFrame({required this.title, required this.addLabel, required this.onAdd, required this.child});

  final String title;
  final String addLabel;
  final void Function(BuildContext) onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.78,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              TextButton.icon(onPressed: () => onAdd(context), icon: const Icon(Icons.add_rounded), label: Text(addLabel)),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(photosNotifierProvider.notifier);
    return ref
        .watch(photosNotifierProvider)
        .when(
          loading: () => const GridSkeleton(),
          error: (e, _) => ErrorView(message: 'Fotoğraflar yüklenemedi.', onRetry: notifier.refresh),
          data: (state) => PagedGridView(
            state: state,
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            onLoadMore: notifier.loadMore,
            onRefresh: notifier.refresh,
            emptyBuilder: (_) => const EmptyView(title: 'Henüz fotoğrafın yok', icon: Icons.accessibility_new_rounded),
            itemBuilder: (context, p) =>
                PhotoTile(photo: p, selected: p.id == selectedId, onTap: p.isReady ? () => Navigator.pop(context, p) : null),
          ),
        );
  }
}

class _GarmentGrid extends ConsumerWidget {
  const _GarmentGrid({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(garmentsNotifierProvider.notifier);
    return ref
        .watch(garmentsNotifierProvider)
        .when(
          loading: () => const GridSkeleton(aspectRatio: 0.8),
          error: (e, _) => ErrorView(message: 'Kıyafetler yüklenemedi.', onRetry: notifier.refresh),
          data: (state) => PagedGridView(
            state: state,
            crossAxisCount: 3,
            childAspectRatio: 0.72,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            onLoadMore: notifier.loadMore,
            onRefresh: notifier.refresh,
            emptyBuilder: (_) => const EmptyView(title: 'Dolabın boş', icon: Icons.checkroom_rounded),
            itemBuilder: (context, g) => GarmentTile(
              garment: g,
              selected: g.id == selectedId,
              dimUnsupported: true,
              onTap: g.canTryOn ? () => Navigator.pop(context, g) : null,
            ),
          ),
        );
  }
}
