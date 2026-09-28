import 'converters.dart';

/// Sunucunun işe yazdığı hata: `{code, messageTr}`.
class JobErrorModel {
  const JobErrorModel({required this.code, required this.messageTr});

  final String code;
  final String messageTr;

  static JobErrorModel? fromMap(Object? raw) {
    final map = Converters.toMap(raw);
    if (map.isEmpty) return null;
    return JobErrorModel(
      code: Converters.toStr(map['code'], 'internal'),
      messageTr: Converters.toStr(map['messageTr'], 'İşlem başarısız oldu.'),
    );
  }
}
