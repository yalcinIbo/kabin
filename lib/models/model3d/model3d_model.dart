import '../../core/enums/enums.dart';
import '../converters.dart';
import '../job_error_model.dart';

/// users/{uid}/models3d/{id}: görüntüden 3D model işi.
class Model3DModel {
  const Model3DModel({
    required this.id,
    this.status = JobStatus.queued,
    this.stage,
    this.progress = 0,
    this.tryonId = '',
    this.glbPath,
    this.previewPath,
    this.tryonThumbPath,
    this.fileSizeBytes,
    this.cost = 0,
    this.refunded = false,
    this.error,
    this.createdAt,
  });

  final String id;
  final JobStatus status;
  final JobStage? stage;
  final double progress;
  final String tryonId;
  final String? glbPath;
  final String? previewPath;
  final String? tryonThumbPath;
  final int? fileSizeBytes;
  final int cost;
  final bool refunded;
  final JobErrorModel? error;
  final DateTime? createdAt;

  bool get isDone => status == JobStatus.done && glbPath != null;

  factory Model3DModel.fromMap(Map<String, dynamic> map, String id) => Model3DModel(
    id: id,
    status: JobStatus.fromValue(map['status'] as String?),
    stage: JobStage.fromValue(map['stage'] as String?),
    progress: Converters.toDouble(map['progress']),
    tryonId: Converters.toStr(map['tryonId']),
    glbPath: map['glbPath'] as String?,
    previewPath: map['previewPath'] as String?,
    tryonThumbPath: map['tryonThumbPath'] as String?,
    fileSizeBytes: map['fileSizeBytes'] == null ? null : Converters.toInt(map['fileSizeBytes']),
    cost: Converters.toInt(map['cost']),
    refunded: Converters.toBool(map['refunded']),
    error: JobErrorModel.fromMap(map['error']),
    createdAt: Converters.toDateTime(map['createdAt']),
  );
}

/// `requestModel3D` callable yanıtı.
class Model3DRequestResult {
  const Model3DRequestResult({required this.modelId, required this.cost, required this.existing});

  final String modelId;
  final int cost;
  final bool existing;

  factory Model3DRequestResult.fromMap(Map<String, dynamic> map) => Model3DRequestResult(
    modelId: Converters.toStr(map['modelId']),
    cost: Converters.toInt(map['cost']),
    existing: Converters.toBool(map['existing']),
  );
}
