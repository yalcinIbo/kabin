import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/utils/paged_state.dart';
import '../../models/credit/credit_models.dart';
import '../../services/firebase/firestore_service.dart';

class CreditRepository {
  CreditRepository(this._db);

  final FirestoreService _db;

  Stream<PricingModel> watchPricing() =>
      _db.watchTyped(FirestorePaths.pricing, (data, _) => PricingModel.fromMap(data)).map((p) => p ?? const PricingModel());

  Stream<FeatureFlagsModel> watchFlags() =>
      _db.watchTyped(FirestorePaths.flags, (data, _) => FeatureFlagsModel.fromMap(data)).map((f) => f ?? const FeatureFlagsModel());

  Future<PageResult<LedgerEntryModel>> getLedger(String uid, {Object? cursor, int limit = AppConstants.ledgerPageSize}) => _db.getPage(
    _db.collection(FirestorePaths.userLedger(uid)).orderBy('createdAt', descending: true),
    limit: limit,
    cursor: cursor,
    mapper: LedgerEntryModel.fromMap,
  );
}
