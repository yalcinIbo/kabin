import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/errors.dart';
import '../../core/utils/paged_state.dart';
import '../../providers/auth/auth_providers.dart';
import '../../providers/core/core_providers.dart';

/// Cursor tabanlı sayfalı listeler için ortak AsyncNotifier.
/// Oturum değişince (uid) liste baştan yüklenir.
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  String? get uid => ref.read(currentUidProvider);

  Future<PageResult<T>> fetchPage(String uid, Object? cursor);

  @override
  Future<PagedState<T>> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const PagedState(hasMore: false);
    final page = await fetchPage(uid, null);
    return PagedState<T>(items: page.items, hasMore: page.hasMore, cursor: page.cursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final id = uid;
    if (current == null || id == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearError: true));
    try {
      final page = await fetchPage(id, current.cursor);
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(items: [...current.items, ...page.items], hasMore: page.hasMore, cursor: page.cursor, isLoadingMore: false),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(isLoadingMore: false, error: ErrorMapper.map(e).message));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Yerel listeden öğe kaldırır (silme sonrası anında güncelleme).
  void removeWhere(bool Function(T item) test) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: current.items.where((i) => !test(i)).toList()));
  }

  void replaceWhere(bool Function(T item) test, T Function(T item) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: [for (final i in current.items) test(i) ? update(i) : i]));
  }

  /// Aksiyon çalıştırır; hata olursa Türkçe mesajı döner (ekran snackbar gösterir).
  Future<String?> runAction(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e, st) {
      if (e is! AppException) ref.read(crashlyticsServiceProvider).recordError(e, st);
      return ErrorMapper.map(e).message;
    }
  }
}
