import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/core/router/app_router.dart';
import 'package:kabin/core/router/route_names.dart';
import 'package:kabin/providers/auth/session_provider.dart';

void main() {
  const onboarding = AppSession(status: SessionStatus.needsOnboarding, uid: 'u1');
  const authed = AppSession(status: SessionStatus.authenticated, uid: 'u1');

  test('yüklenirken splash', () {
    expect(appRedirect(AppSession.loading, RouteNames.tryOn), RouteNames.splash);
    expect(appRedirect(AppSession.loading, RouteNames.splash), isNull);
  });

  test('oturum yoksa giriş; auth rotaları serbest', () {
    expect(appRedirect(AppSession.unauthenticated, RouteNames.tryOn), RouteNames.login);
    expect(appRedirect(AppSession.unauthenticated, RouteNames.register), isNull);
  });

  test('onboarding: KVKK ekranına zorlanır, aydınlatma metni açılabilir', () {
    expect(appRedirect(onboarding, RouteNames.tryOn), RouteNames.consent);
    expect(appRedirect(onboarding, RouteNames.onboardingMeasurements), isNull);
    expect(appRedirect(onboarding, RouteNames.legal), isNull);
  });

  test('giriş yapmış kullanıcı auth/onboarding rotalarından Dene\'ye', () {
    expect(appRedirect(authed, RouteNames.login), RouteNames.tryOn);
    expect(appRedirect(authed, RouteNames.consent), RouteNames.tryOn);
    expect(appRedirect(authed, RouteNames.splash), RouteNames.tryOn);
    expect(appRedirect(authed, RouteNames.credits), isNull);
    expect(appRedirect(authed, RouteNames.legal), isNull);
  });
}
