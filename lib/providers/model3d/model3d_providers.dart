import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/model3d/model3d_model.dart';
import '../../notifiers/model3d/model3d_request_notifier.dart';
import '../../repositories/model3d/model3d_repository.dart';
import '../auth/auth_providers.dart';
import '../core/core_providers.dart';

final model3dRepositoryProvider = Provider<Model3DRepository>((ref) {
  return Model3DRepository(ref.watch(firestoreServiceProvider), ref.watch(storageServiceProvider), ref.watch(functionsServiceProvider));
});

final model3dProvider = StreamProvider.autoDispose.family<Model3DModel?, String>((ref, modelId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(model3dRepositoryProvider).watchModel(uid, modelId);
});

/// Tamamlanmış modelin cihazdaki GLB dosyası (görüntüleyici için).
final localGlbProvider = FutureProvider.autoDispose.family<File, String>((ref, modelId) async {
  final model = await ref.watch(model3dProvider(modelId).future);
  if (model == null || !model.isDone) throw StateError('Model hazır değil');
  return ref.watch(model3dRepositoryProvider).localGlb(model);
});

final model3dRequestNotifierProvider = NotifierProvider.autoDispose.family<Model3DRequestNotifier, Model3DRequestState, String>(
  Model3DRequestNotifier.new,
);
