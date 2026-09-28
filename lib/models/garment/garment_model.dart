import 'dart:ui';

import '../../core/enums/enums.dart';
import '../converters.dart';

/// Gemini kıyafet analizi (kullanıcı düzeltebilir).
class GarmentAnalysisModel {
  const GarmentAnalysisModel({
    this.category = GarmentCategory.other,
    this.garmentPhotoType = GarmentPhotoType.flatLay,
    this.dominantColorHex = '#808080',
    this.colorNameTr = '',
    this.fabricGuess = '',
    this.titleTr = '',
    this.descriptionTr = '',
    this.isIsolated = false,
    this.confidence = 0,
  });

  final GarmentCategory category;
  final GarmentPhotoType garmentPhotoType;
  final String dominantColorHex;
  final String colorNameTr;
  final String fabricGuess;
  final String titleTr;
  final String descriptionTr;
  final bool isIsolated;
  final double confidence;

  Color get color {
    final hex = dominantColorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    return value == null || hex.length != 6 ? const Color(0xFF808080) : Color(0xFF000000 | value);
  }

  static GarmentAnalysisModel? fromMap(Object? raw) {
    final map = Converters.toMap(raw);
    if (map.isEmpty) return null;
    return GarmentAnalysisModel(
      category: GarmentCategory.fromValue(map['category'] as String?),
      garmentPhotoType: GarmentPhotoType.fromValue(map['garmentPhotoType'] as String?),
      dominantColorHex: Converters.toStr(map['dominantColorHex'], '#808080'),
      colorNameTr: Converters.toStr(map['colorNameTr']),
      fabricGuess: Converters.toStr(map['fabricGuess']),
      titleTr: Converters.toStr(map['titleTr']),
      descriptionTr: Converters.toStr(map['descriptionTr']),
      isIsolated: Converters.toBool(map['isIsolated']),
      confidence: Converters.toDouble(map['confidence']),
    );
  }

  Map<String, dynamic> toMap() => {
    'isGarment': true,
    'category': category.value,
    'garmentPhotoType': garmentPhotoType.value,
    'dominantColorHex': dominantColorHex,
    'colorNameTr': colorNameTr,
    'fabricGuess': fabricGuess,
    'titleTr': titleTr,
    'descriptionTr': descriptionTr,
    'isIsolated': isIsolated,
    'confidence': confidence,
  };

  GarmentAnalysisModel copyWith({GarmentCategory? category, GarmentPhotoType? garmentPhotoType, String? colorNameTr, String? titleTr}) =>
      GarmentAnalysisModel(
        category: category ?? this.category,
        garmentPhotoType: garmentPhotoType ?? this.garmentPhotoType,
        dominantColorHex: dominantColorHex,
        colorNameTr: colorNameTr ?? this.colorNameTr,
        fabricGuess: fabricGuess,
        titleTr: titleTr ?? this.titleTr,
        descriptionTr: descriptionTr,
        isIsolated: isIsolated,
        confidence: confidence,
      );
}

/// users/{uid}/garments/{id}
class GarmentModel {
  const GarmentModel({
    required this.id,
    this.status = GarmentStatus.analyzing,
    required this.storagePath,
    this.thumbPath,
    this.isolatedPath,
    this.analysis,
    this.tryonSupported = false,
    this.userEdited = false,
    this.errorTr,
    this.createdAt,
  });

  final String id;
  final GarmentStatus status;
  final String storagePath;
  final String? thumbPath;
  final String? isolatedPath;
  final GarmentAnalysisModel? analysis;
  final bool tryonSupported;
  final bool userEdited;
  final String? errorTr;
  final DateTime? createdAt;

  String get displayPath => thumbPath ?? storagePath;
  String get title => (analysis?.titleTr.isNotEmpty ?? false) ? analysis!.titleTr : 'Kıyafet';
  bool get isReady => status == GarmentStatus.ready;

  /// Deneme için uygun mu? (Sunucu kategoriyi yeniden doğrular.)
  bool get canTryOn => isReady && (analysis?.category.isTryOnSupported ?? false);

  factory GarmentModel.fromMap(Map<String, dynamic> map, String id) => GarmentModel(
    id: id,
    status: GarmentStatus.fromValue(map['status'] as String?),
    storagePath: Converters.toStr(map['storagePath']),
    thumbPath: map['thumbPath'] as String?,
    isolatedPath: map['isolatedPath'] as String?,
    analysis: GarmentAnalysisModel.fromMap(map['analysis']),
    tryonSupported: Converters.toBool(map['tryonSupported']),
    userEdited: Converters.toBool(map['userEdited']),
    errorTr: map['errorTr'] as String?,
    createdAt: Converters.toDateTime(map['createdAt']),
  );
}
