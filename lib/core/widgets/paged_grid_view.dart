import 'package:flutter/material.dart';

import '../utils/paged_state.dart';
import 'state_views.dart';

/// [PagedState] ile çalışan ızgara; sona yaklaşınca [onLoadMore] çağırır.
class PagedGridView<T> extends StatelessWidget {
  const PagedGridView({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    this.emptyBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 96),
  });

  final PagedState<T> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final WidgetBuilder? emptyBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      if (state.hasError) return ErrorView(message: state.error!, onRetry: onRefresh);
      final empty = emptyBuilder?.call(context) ?? const EmptyView(title: 'Henüz bir şey yok');
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: c.maxHeight, child: empty),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (state.hasMore && !state.isLoadingMore && n.metrics.extentAfter < 400) onLoadMore();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: padding.copyWith(bottom: 0),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: state.items.length,
                itemBuilder: (context, i) => itemBuilder(context, state.items[i]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: padding.bottom),
                child: state.isLoadingMore
                    ? const ListLoadingFooter()
                    : state.hasError
                    ? ErrorView(message: state.error!, onRetry: onLoadMore, compact: true)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
