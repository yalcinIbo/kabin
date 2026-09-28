import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics olayları. Hata fırlatmaz; analytics ürün akışını bozmamalıdır.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics}) : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  Future<void> setUserId(String? uid) => _safe(() => _analytics.setUserId(id: uid));
  Future<void> logLogin(String method) => _safe(() => _analytics.logLogin(loginMethod: method));
  Future<void> logSignUp(String method) => _safe(() => _analytics.logSignUp(signUpMethod: method));

  Future<void> logEvent(String name, [Map<String, Object>? params]) => _safe(() => _analytics.logEvent(name: name, parameters: params));

  Future<void> logPhotoAdded(String source) => logEvent('photo_added', {'source': source});
  Future<void> logGarmentAdded(String category) => logEvent('garment_added', {'category': category});
  Future<void> logTryOnRequested({required bool multiView, required int cost}) =>
      logEvent('tryon_requested', {'multi_view': multiView ? 1 : 0, 'cost': cost});
  Future<void> logModel3DRequested() => logEvent('model3d_requested');
  Future<void> logShare(String contentType, String itemId) =>
      _safe(() => _analytics.logShare(contentType: contentType, itemId: itemId, method: 'system'));

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}
