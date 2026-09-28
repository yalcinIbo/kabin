import '../../core/utils/paged_state.dart';
import '../../models/credit/credit_models.dart';
import '../../providers/credit/credit_providers.dart';
import '../common/paged_notifier.dart';

/// Kredi hareketleri (sayfalı).
class LedgerNotifier extends PagedNotifier<LedgerEntryModel> {
  @override
  Future<PageResult<LedgerEntryModel>> fetchPage(String uid, Object? cursor) =>
      ref.read(creditRepositoryProvider).getLedger(uid, cursor: cursor);
}
