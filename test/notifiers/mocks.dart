import 'package:kabin/repositories/auth/auth_repository.dart';
import 'package:kabin/repositories/garment/garment_repository.dart';
import 'package:kabin/repositories/photo/photo_repository.dart';
import 'package:kabin/repositories/tryon/tryon_repository.dart';
import 'package:kabin/repositories/user/user_repository.dart';
import 'package:kabin/services/firebase/analytics_service.dart';
import 'package:kabin/services/firebase/crashlytics_service.dart';
import 'package:kabin/services/media/image_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTryOnRepository extends Mock implements TryOnRepository {}

class MockGarmentRepository extends Mock implements GarmentRepository {}

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockImageService extends Mock implements ImageService {}

class MockCrashlytics extends Mock implements CrashlyticsService {}

class MockAnalytics extends Mock implements AnalyticsService {
  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {}
  @override
  Future<void> logTryOnRequested({required bool multiView, required int cost}) async {}
  @override
  Future<void> logGarmentAdded(String category) async {}
  @override
  Future<void> logPhotoAdded(String source) async {}
}
