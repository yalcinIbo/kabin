import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/paged_state.dart';
import '../../models/garment/garment_model.dart';
import '../../notifiers/garment/add_garment_notifier.dart';
import '../../notifiers/garment/garment_edit_notifier.dart';
import '../../notifiers/garment/garments_notifier.dart';
import '../../repositories/garment/garment_repository.dart';
import '../auth/auth_providers.dart';
import '../core/core_providers.dart';

final garmentRepositoryProvider = Provider<GarmentRepository>((ref) {
  return GarmentRepository(
    ref.watch(firestoreServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(functionsServiceProvider),
    ref.watch(imageServiceProvider),
  );
});

final garmentProvider = StreamProvider.autoDispose.family<GarmentModel?, String>((ref, garmentId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(garmentRepositoryProvider).watchGarment(uid, garmentId);
});

final garmentsNotifierProvider = AsyncNotifierProvider<GarmentsNotifier, PagedState<GarmentModel>>(GarmentsNotifier.new);

final addGarmentNotifierProvider = NotifierProvider.autoDispose<AddGarmentNotifier, AddGarmentState>(AddGarmentNotifier.new);

final garmentEditNotifierProvider = NotifierProvider.autoDispose.family<GarmentEditNotifier, GarmentEditState, String>(
  GarmentEditNotifier.new,
);
