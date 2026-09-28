import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/paged_state.dart';
import '../../models/credit/credit_models.dart';
import '../../notifiers/credit/ledger_notifier.dart';
import '../../repositories/credit/credit_repository.dart';
import '../core/core_providers.dart';

final creditRepositoryProvider = Provider<CreditRepository>((ref) => CreditRepository(ref.watch(firestoreServiceProvider)));

/// İşlem maliyetleri (config/pricing). Okunamazsa varsayılanlar kullanılır.
final pricingProvider = StreamProvider<PricingModel>((ref) {
  return ref
      .watch(creditRepositoryProvider)
      .watchPricing()
      .transform(StreamTransformer.fromHandlers(handleError: (_, _, sink) => sink.add(const PricingModel())));
});

/// Özellik anahtarları; okunamazsa varsayılanlar (3D kapalı).
final featureFlagsProvider = StreamProvider<FeatureFlagsModel>((ref) {
  return ref
      .watch(creditRepositoryProvider)
      .watchFlags()
      .transform(StreamTransformer.fromHandlers(handleError: (_, _, sink) => sink.add(const FeatureFlagsModel())));
});

final ledgerNotifierProvider = AsyncNotifierProvider.autoDispose<LedgerNotifier, PagedState<LedgerEntryModel>>(LedgerNotifier.new);
