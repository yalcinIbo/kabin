import '../../core/constants/firestore_paths.dart';
import '../../core/errors/errors.dart';
import '../../core/utils/validators.dart';
import '../../models/user/user_model.dart';
import '../../services/firebase/firestore_service.dart';

/// users/{uid} profil belgesi. Kredi alanı istemciden yazılmaz.
class UserRepository {
  UserRepository(this._db);

  final FirestoreService _db;

  Stream<UserModel?> watchUser(String uid) => _db.watchTyped(FirestorePaths.user(uid), UserModel.fromMap);

  Future<UserModel?> getUser(String uid) => _db.getTyped(FirestorePaths.user(uid), UserModel.fromMap);

  /// Onboarding sonunda profil oluşturur. Hoş geldin kredisi sunucu tetikleyicisiyle gelir.
  Future<void> createProfile({
    required String uid,
    required String displayName,
    required String? email,
    required ConsentModel consent,
    required Measurements measurements,
  }) async {
    _validate(measurements);
    final user = UserModel(id: uid, displayName: displayName.trim(), email: email, measurements: measurements, consent: consent);
    await _db.setDoc(FirestorePaths.user(uid), {...user.toCreateMap(), 'createdAt': _db.serverTimestamp, 'updatedAt': _db.serverTimestamp});
  }

  Future<void> updateConsent(String uid, ConsentModel consent) =>
      _db.updateDoc(FirestorePaths.user(uid), {'consent': consent.toMap(), 'updatedAt': _db.serverTimestamp});

  Future<void> updateMeasurements(String uid, Measurements measurements, {String? displayName}) async {
    _validate(measurements);
    final nameError = Validators.displayName(displayName);
    if (nameError != null) throw ValidationException(nameError);
    await _db.updateDoc(FirestorePaths.user(uid), {
      ...measurements.toMap(),
      if (displayName != null) 'displayName': displayName.trim(),
      'updatedAt': _db.serverTimestamp,
    });
  }

  static void _validate(Measurements m) {
    final error = Validators.heightCm(m.heightCm) ?? Validators.weightKg(m.weightKg);
    if (error != null) throw ValidationException(error);
  }
}
