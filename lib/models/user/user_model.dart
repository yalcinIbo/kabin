import '../../core/enums/enums.dart';
import '../converters.dart';

/// KVKK açık rıza kaydı (sürümlü).
class ConsentModel {
  const ConsentModel({required this.kvkkVersion, required this.kvkkAccepted, required this.aiTransferAccepted, this.acceptedAt});

  final String kvkkVersion;
  final bool kvkkAccepted;
  final bool aiTransferAccepted;
  final DateTime? acceptedAt;

  bool isValidFor(String version) => kvkkAccepted && aiTransferAccepted && kvkkVersion == version;

  factory ConsentModel.fromMap(Map<String, dynamic> map) => ConsentModel(
    kvkkVersion: Converters.toStr(map['kvkkVersion']),
    kvkkAccepted: Converters.toBool(map['kvkkAccepted']),
    aiTransferAccepted: Converters.toBool(map['aiTransferAccepted']),
    acceptedAt: Converters.toDateTime(map['acceptedAt']),
  );

  Map<String, dynamic> toMap() => {
    'kvkkVersion': kvkkVersion,
    'kvkkAccepted': kvkkAccepted,
    'aiTransferAccepted': aiTransferAccepted,
    'acceptedAt': Converters.toTimestamp(acceptedAt),
  };
}

/// Vücut ölçüleri (hepsi isteğe bağlı).
class Measurements {
  const Measurements({this.heightCm, this.weightKg, this.bodyType, this.gender = Gender.unspecified});

  final int? heightCm;
  final int? weightKg;
  final BodyType? bodyType;
  final Gender gender;

  bool get isComplete => heightCm != null && weightKg != null && bodyType != null;

  Map<String, dynamic> toMap() => {'heightCm': heightCm, 'weightKg': weightKg, 'bodyType': bodyType?.value, 'gender': gender.value};

  Measurements copyWith({int? heightCm, int? weightKg, BodyType? bodyType, Gender? gender}) => Measurements(
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    bodyType: bodyType ?? this.bodyType,
    gender: gender ?? this.gender,
  );
}

/// users/{uid}. `credits` yalnızca sunucu tarafından yazılır.
class UserModel {
  const UserModel({
    required this.id,
    this.displayName = '',
    this.email,
    this.credits = 0,
    this.measurements = const Measurements(),
    this.consent,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final String? email;
  final int credits;
  final Measurements measurements;
  final ConsentModel? consent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final consentMap = Converters.toMap(map['consent']);
    return UserModel(
      id: id,
      displayName: Converters.toStr(map['displayName']),
      email: map['email'] as String?,
      credits: Converters.toInt(map['credits']),
      measurements: Measurements(
        heightCm: map['heightCm'] == null ? null : Converters.toInt(map['heightCm']),
        weightKg: map['weightKg'] == null ? null : Converters.toInt(map['weightKg']),
        bodyType: BodyType.fromValue(map['bodyType'] as String?),
        gender: Gender.fromValue(map['gender'] as String?),
      ),
      consent: consentMap.isEmpty ? null : ConsentModel.fromMap(consentMap),
      createdAt: Converters.toDateTime(map['createdAt']),
      updatedAt: Converters.toDateTime(map['updatedAt']),
    );
  }

  /// Profil oluşturma verisi (kurallar `credits == 0` bekler).
  Map<String, dynamic> toCreateMap() => {
    'displayName': displayName,
    'email': email,
    'credits': 0,
    ...measurements.toMap(),
    'consent': consent?.toMap(),
  };

  UserModel copyWith({String? displayName, int? credits, Measurements? measurements, ConsentModel? consent}) => UserModel(
    id: id,
    displayName: displayName ?? this.displayName,
    email: email,
    credits: credits ?? this.credits,
    measurements: measurements ?? this.measurements,
    consent: consent ?? this.consent,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
