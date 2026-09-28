import '../../core/enums/enums.dart';
import '../converters.dart';
import '../job_error_model.dart';

class TryOnResultModel {
  const TryOnResultModel({required this.provider, required this.angle, required this.storagePath, this.width = 0, this.height = 0});

  final String provider;
  final ViewAngle angle;
  final String storagePath;
  final int width;
  final int height;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 3 / 4;

  factory TryOnResultModel.fromMap(Map<String, dynamic> map) => TryOnResultModel(
    provider: Converters.toStr(map['provider'], 'bilinmiyor'),
    angle: ViewAngle.fromValue(map['angle'] as String?),
    storagePath: Converters.toStr(map['storagePath']),
    width: Converters.toInt(map['width']),
    height: Converters.toInt(map['height']),
  );
}

class StyleAdviceModel {
  const StyleAdviceModel({this.fitTr = '', this.sizeAdviceTr = '', this.tipsTr = const [], this.occasionTr = ''});

  final String fitTr;
  final String sizeAdviceTr;
  final List<String> tipsTr;
  final String occasionTr;

  static StyleAdviceModel? fromMap(Object? raw) {
    final map = Converters.toMap(raw);
    if (map.isEmpty) return null;
    return StyleAdviceModel(
      fitTr: Converters.toStr(map['fitTr']),
      sizeAdviceTr: Converters.toStr(map['sizeAdviceTr']),
      tipsTr: Converters.toStringList(map['tipsTr']),
      occasionTr: Converters.toStr(map['occasionTr']),
    );
  }
}

/// users/{uid}/tryons/{jobId}: sunucunun yazdığı deneme işi.
class TryOnJobModel {
  const TryOnJobModel({
    required this.id,
    this.status = JobStatus.queued,
    this.stage,
    this.progress = 0,
    this.photoId = '',
    this.garmentId = '',
    this.photoThumbPath,
    this.garmentThumbPath,
    this.garmentTitle,
    this.provider = '',
    this.multiView = false,
    this.cost = 0,
    this.refundedAmount = 0,
    this.refunded = false,
    this.results = const [],
    this.thumbPath,
    this.styleAdvice,
    this.error,
    this.model3dId,
    this.model3dRequestId,
    this.multiViewFailed = false,
    this.createdAt,
    this.finishedAt,
  });

  final String id;
  final JobStatus status;
  final JobStage? stage;
  final double progress;
  final String photoId;
  final String garmentId;
  final String? photoThumbPath;
  final String? garmentThumbPath;
  final String? garmentTitle;
  final String provider;
  final bool multiView;
  final int cost;
  final int refundedAmount;
  final bool refunded;
  final List<TryOnResultModel> results;
  final String? thumbPath;
  final StyleAdviceModel? styleAdvice;
  final JobErrorModel? error;
  final String? model3dId;
  final String? model3dRequestId;
  final bool multiViewFailed;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  bool get isDone => status == JobStatus.done;
  TryOnResultModel? get front => results.where((r) => r.angle == ViewAngle.front).firstOrNull;
  String get title => (garmentTitle?.isNotEmpty ?? false) ? garmentTitle! : 'Deneme';

  /// 3D işi başlatılmış (veya tamamlanmış) model kimliği.
  String? get activeModel3dId => model3dId ?? model3dRequestId;

  factory TryOnJobModel.fromMap(Map<String, dynamic> map, String id) {
    final options = Converters.toMap(map['options']);
    final garmentInfo = Converters.toMap(map['garmentInfo']);
    return TryOnJobModel(
      id: id,
      status: JobStatus.fromValue(map['status'] as String?),
      stage: JobStage.fromValue(map['stage'] as String?),
      progress: Converters.toDouble(map['progress']),
      photoId: Converters.toStr(map['photoId']),
      garmentId: Converters.toStr(map['garmentId']),
      photoThumbPath: map['photoThumbPath'] as String?,
      garmentThumbPath: map['garmentThumbPath'] as String?,
      garmentTitle: garmentInfo['titleTr'] as String?,
      provider: Converters.toStr(map['provider']),
      multiView: Converters.toBool(options['multiView']),
      cost: Converters.toInt(map['cost']),
      refundedAmount: Converters.toInt(map['refundedAmount']),
      refunded: Converters.toBool(map['refunded']),
      results: Converters.toMapList(map['results']).map(TryOnResultModel.fromMap).toList(),
      thumbPath: map['thumbPath'] as String?,
      styleAdvice: StyleAdviceModel.fromMap(map['styleAdvice']),
      error: JobErrorModel.fromMap(map['error']),
      model3dId: map['model3dId'] as String?,
      model3dRequestId: map['model3dRequestId'] as String?,
      multiViewFailed: Converters.toBool(map['multiViewFailed']),
      createdAt: Converters.toDateTime(map['createdAt']),
      finishedAt: Converters.toDateTime(map['finishedAt']),
    );
  }
}

/// `requestTryOn` callable yanıtı.
class TryOnRequestResult {
  const TryOnRequestResult({required this.jobId, required this.cost, required this.creditsLeft});

  final String jobId;
  final int cost;
  final int creditsLeft;

  factory TryOnRequestResult.fromMap(Map<String, dynamic> map) => TryOnRequestResult(
    jobId: Converters.toStr(map['jobId']),
    cost: Converters.toInt(map['cost']),
    creditsLeft: Converters.toInt(map['creditsLeft']),
  );
}
