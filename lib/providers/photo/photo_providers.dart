import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/paged_state.dart';
import '../../models/photo/photo_model.dart';
import '../../notifiers/photo/add_photo_notifier.dart';
import '../../notifiers/photo/photos_notifier.dart';
import '../../notifiers/photo/selfie_avatar_notifier.dart';
import '../../repositories/photo/photo_repository.dart';
import '../auth/auth_providers.dart';
import '../core/core_providers.dart';

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(
    ref.watch(firestoreServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(functionsServiceProvider),
    ref.watch(imageServiceProvider),
  );
});

final photoProvider = StreamProvider.autoDispose.family<PhotoModel?, String>((ref, photoId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(photoRepositoryProvider).watchPhoto(uid, photoId);
});

/// Varsayılan boydan fotoğraf (Dene ekranı bununla açılır).
final defaultPhotoProvider = StreamProvider<PhotoModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(photoRepositoryProvider).watchDefaultPhoto(uid);
});

final photosNotifierProvider = AsyncNotifierProvider<PhotosNotifier, PagedState<PhotoModel>>(PhotosNotifier.new);

final addPhotoNotifierProvider = NotifierProvider.autoDispose<AddPhotoNotifier, AddPhotoState>(AddPhotoNotifier.new);

final selfieAvatarNotifierProvider = NotifierProvider.autoDispose<SelfieAvatarNotifier, SelfieAvatarState>(SelfieAvatarNotifier.new);
