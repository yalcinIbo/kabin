/// Cursor tabanlı sayfalama için jenerik state.
/// Tüm liste notifier'ları (feed, comments, followers, messages...) bunu kullanır.
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.cursor,
  });

  const PagedState.initial() : this();

  final List<T> items;

  /// İlk yükleme.
  final bool isLoading;

  /// Sonraki sayfa yükleniyor.
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  /// Repository'nin ürettiği opak imleç (ör. son DocumentSnapshot). UI yorumlamaz.
  final Object? cursor;

  bool get isEmpty => items.isEmpty && !isLoading;
  bool get hasError => error != null;

  PagedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    Object? cursor,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
    );
  }
}

/// Repository'lerin döndürdüğü sayfa sonucu.
class PageResult<T> {
  const PageResult({required this.items, this.cursor, required this.hasMore});

  final List<T> items;
  final Object? cursor;
  final bool hasMore;

  static PageResult<T> empty<T>() => PageResult<T>(items: const [], hasMore: false);
}
