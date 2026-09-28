import '../../core/enums/enums.dart';
import '../converters.dart';
import '../job_error_model.dart';

/// Gemini fotoğraf kalite kontrolü sonucu.
class PhotoQcModel {
  const PhotoQcModel({required this.passed, required this.blocked, this.issues = const [], this.hintTr = ''});

  final bool passed;
  final bool blocked;
  final List<String> issues;
  final String hintTr;

  static PhotoQcModel? fromMap(Object? raw) {
    final map = Converters.toMap(raw);
    if (map.isEmpty) return null;
    return PhotoQcModel(
      passed: Converters.toBool(map['passed']),
      blocked: Converters.toBool(map['blocked']),
      issues: Converters.toStringList(map['issues']),
      hintTr: Converters.toStr(map['hintTr']),
    );
  }
}

/// users/{uid}/photos/{id}: kullanıcının boydan fotoğrafı (yüklenen veya selfie'den üretilen).
class PhotoModel {
  const PhotoModel({
    required this.id,
    this.source = PhotoSource.upload,
    this.status = PhotoStatus.pending,
    this.storagePath,
    this.thumbPath,
    this.width,
    this.height,
    this.qc,
    this.isDefault = false,
    this.stage,
    this.progress = 0,
    this.error,
    this.createdAt,
  });

  final String id;
  final PhotoSource source;
  final PhotoStatus status;
  final String? storagePath;
  final String? thumbPath;
  final int? width;
  final int? height;
  final PhotoQcModel? qc;
  final bool isDefault;
  final JobStage? stage;
  final double progress;
  final JobErrorModel? error;
  final DateTime? createdAt;

  bool get isReady => status == PhotoStatus.ready && storagePath != null;
  bool get isGenerated => source == PhotoSource.generated;
  String? get displayPath => thumbPath ?? storagePath;

  factory PhotoModel.fromMap(Map<String, dynamic> map, String id) => PhotoModel(
    id: id,
    source: PhotoSource.fromValue(map['source'] as String?),
    status: PhotoStatus.fromValue(map['status'] as String?),
    storagePath: map['storagePath'] as String?,
    thumbPath: map['thumbPath'] as String?,
    width: map['width'] == null ? null : Converters.toInt(map['width']),
    height: map['height'] == null ? null : Converters.toInt(map['height']),
    qc: PhotoQcModel.fromMap(map['qc']),
    isDefault: Converters.toBool(map['isDefault']),
    stage: JobStage.fromValue(map['stage'] as String?),
    progress: Converters.toDouble(map['progress']),
    error: JobErrorModel.fromMap(map['error']),
    createdAt: Converters.toDateTime(map['createdAt']),
  );
}
