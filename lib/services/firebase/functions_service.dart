import 'package:cloud_functions/cloud_functions.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/errors.dart';

/// Callable Cloud Functions çağrıları. Sunucunun Türkçe hata mesajları [ErrorMapper] ile eşlenir.
class FunctionsService {
  FunctionsService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 70),
  ]) async {
    try {
      final result = await _functions.httpsCallable(name, options: HttpsCallableOptions(timeout: timeout)).call<Object?>(data);
      final raw = result.data;
      return raw is Map ? deepCastMap(raw) : <String, dynamic>{};
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Platform kanalından gelen `Map<Object?, Object?>` yapılarını `Map<String, dynamic>`'e çevirir.
  static Map<String, dynamic> deepCastMap(Map<dynamic, dynamic> map) => map.map((k, v) => MapEntry(k.toString(), _deepCast(v)));

  static Object? _deepCast(Object? v) {
    if (v is Map) return deepCastMap(v);
    if (v is List) return v.map(_deepCast).toList();
    return v;
  }
}
