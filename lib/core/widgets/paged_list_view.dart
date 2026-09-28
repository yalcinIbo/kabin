import 'package:flutter/material.dart';

import '../utils/paged_state.dart';
import 'state_views.dart';

/// [PagedState] ile çalışan, sona yaklaşınca [onLoadMore] çağıran liste.
/// Lazy render için ListView.builder kullanır.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.onRetry,
    this.emptyBuilder,
    this.separatorBuilder,
    this.padding,
    this.controller,
    this.header,
    this.loadMoreThreshold = 3,
    this.physics,
    this.shrinkWrap = false,
  });

  final PagedState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onRetry;
  final WidgetBuilder? emptyBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final Widget? header;

  /// Sona bu kadar öğe kala sonraki sayfa istenir.
  final int loadMoreThreshold;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) return const LoadingView();
    if (state.hasError && state.items.isEmpty) {
      return ErrorView(message: state.error!, onRetry: onRetry);
    }
    if (state.items.isEmpty) {
      final empty = emptyBuilder?.call(context) ?? const EmptyView(title: 'Henüz içerik yok');
      if (onRefresh == null) return empty;
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: constraints.maxHeight, child: empty),
          ),
        ),
      );
    }

    final headerCount = header == null ? 0 : 1;
    final footerCount = state.hasMore || state.isLoadingMore ? 1 : 0;
    final total = headerCount + state.items.length + footerCount;

    final list = ListView.builder(
      controller: controller,
      padding: padding,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
      itemCount: total,
      itemBuilder: (context, index) {
        if (headerCount == 1 && index == 0) return header!;
        final itemIndex = index - headerCount;
        if (itemIndex >= state.items.length) {
          if (state.hasMore && !state.isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          }
          return const ListLoadingFooter();
        }
        if (state.hasMore && !state.isLoadingMore && itemIndex >= state.items.length - loadMoreThreshold) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
        }
        final item = itemBuilder(context, state.items[itemIndex], itemIndex);
        if (separatorBuilder != null && itemIndex < state.items.length - 1) {
          return Column(mainAxisSize: MainAxisSize.min, children: [item, separatorBuilder!(context, itemIndex)]);
        }
        return item;
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
