import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug modda başarısız provider'ları konsola yazar (Riverpod hataları aksi hâlde sessizce yeniden denenir).
final class ProviderLogger extends ProviderObserver {
  const ProviderLogger();

  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    debugPrint('⚠️ Provider hatası [${context.provider.name ?? context.provider.runtimeType}]: $error');
  }
}
