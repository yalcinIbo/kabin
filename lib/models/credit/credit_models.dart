import '../../core/enums/enums.dart';
import '../converters.dart';

/// users/{uid}/ledger/{id}: kredi hareketi.
class LedgerEntryModel {
  const LedgerEntryModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.jobType,
    this.jobId,
    this.note,
    this.createdAt,
  });

  final String id;
  final LedgerType type;
  final int amount;
  final int balanceAfter;
  final String? jobType;
  final String? jobId;
  final String? note;
  final DateTime? createdAt;

  String get descriptionTr {
    if (note != null && note!.isNotEmpty && type != LedgerType.refund) return note!;
    final job = switch (jobType) {
      'tryon' => 'Deneme',
      'model3d' => '3D model',
      'avatar' => 'Stüdyo fotoğrafı',
      _ => null,
    };
    return job == null ? type.labelTr : '$job · ${type.labelTr.toLowerCase()}';
  }

  factory LedgerEntryModel.fromMap(Map<String, dynamic> map, String id) => LedgerEntryModel(
    id: id,
    type: LedgerType.fromValue(map['type'] as String?),
    amount: Converters.toInt(map['amount']),
    balanceAfter: Converters.toInt(map['balanceAfter']),
    jobType: map['jobType'] as String?,
    jobId: map['jobId'] as String?,
    note: map['note'] as String?,
    createdAt: Converters.toDateTime(map['createdAt']),
  );
}

/// config/flags: özellik anahtarları. Belge yoksa varsayılanlar (3D kapalı).
class FeatureFlagsModel {
  const FeatureFlagsModel({this.tryonEnabled = true, this.model3dEnabled = false, this.avatarEnabled = true});

  final bool tryonEnabled;
  final bool model3dEnabled;
  final bool avatarEnabled;

  factory FeatureFlagsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FeatureFlagsModel();
    bool read(String k, bool d) => map[k] is bool ? map[k] as bool : d;
    return FeatureFlagsModel(
      tryonEnabled: read('tryonEnabled', true),
      model3dEnabled: read('model3dEnabled', false),
      avatarEnabled: read('avatarEnabled', true),
    );
  }
}

/// config/pricing: işlem maliyetleri (kredi). Belge yoksa varsayılanlar.
class PricingModel {
  const PricingModel({this.tryon = 1, this.multiView = 1, this.model3d = 5, this.avatar = 1, this.welcome = 10});

  final int tryon;
  final int multiView;
  final int model3d;
  final int avatar;
  final int welcome;

  int tryOnCost({required bool multiView}) => tryon + (multiView ? this.multiView : 0);

  factory PricingModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PricingModel();
    int read(String k, int d) => map[k] == null ? d : Converters.toInt(map[k], d);
    return PricingModel(
      tryon: read('tryon', 1),
      multiView: read('multiView', 1),
      model3d: read('model3d', 5),
      avatar: read('avatar', 1),
      welcome: read('welcome', 10),
    );
  }
}
