import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth/session_provider.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/benchmark/benchmark_run_screen.dart';
import '../../screens/benchmark/benchmark_screen.dart';
import '../../screens/credits/credits_screen.dart';
import '../../screens/garment/add_garment_screen.dart';
import '../../screens/garment/garment_detail_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/home/app_shell.dart';
import '../../screens/model3d/model3d_viewer_screen.dart';
import '../../screens/onboarding/consent_screen.dart';
import '../../screens/onboarding/measurements_screen.dart';
import '../../screens/photo/add_photo_screen.dart';
import '../../screens/photo/photo_detail_screen.dart';
import '../../screens/photo/selfie_avatar_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/delete_account_screen.dart';
import '../../screens/settings/legal_screen.dart';
import '../../screens/settings/measurements_settings_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/try/try_screen.dart';
import '../../screens/tryon/tryon_job_screen.dart';
import '../../screens/wardrobe/wardrobe_screen.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Oturum durumuna göre yönlendiren GoRouter. Session değişince yeniden değerlendirilir.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AppSession>(ref.read(appSessionProvider));
  ref.listen(appSessionProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  GoRoute full(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) =>
      GoRoute(path: path, parentNavigatorKey: _rootNavigatorKey, builder: (_, s) => build(s), routes: routes);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: session,
    redirect: (context, state) => appRedirect(session.value, state.matchedLocation),
    routes: [
      GoRoute(path: RouteNames.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: RouteNames.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: RouteNames.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: RouteNames.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: RouteNames.consent, builder: (_, _) => const ConsentScreen()),
      GoRoute(path: RouteNames.onboardingMeasurements, builder: (_, _) => const OnboardingMeasurementsScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: RouteNames.tryOn, builder: (_, _) => const TryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: RouteNames.wardrobe, builder: (_, _) => const WardrobeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: RouteNames.history, builder: (_, _) => const HistoryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: RouteNames.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      full(RouteNames.addPhoto, (_) => const AddPhotoScreen()),
      full(RouteNames.selfieAvatar, (_) => const SelfieAvatarScreen()),
      full('/photos/:id', (s) => PhotoDetailScreen(photoId: s.pathParameters['id']!)),
      full(RouteNames.addGarment, (_) => const AddGarmentScreen()),
      full('/garments/:id', (s) => GarmentDetailScreen(garmentId: s.pathParameters['id']!)),
      full('/tryon/:id', (s) => TryOnJobScreen(jobId: s.pathParameters['id']!)),
      full('/models3d/:id', (s) => Model3DViewerScreen(modelId: s.pathParameters['id']!)),
      full(RouteNames.credits, (_) => const CreditsScreen()),
      full(RouteNames.settings, (_) => const SettingsScreen()),
      full(RouteNames.measurements, (_) => const MeasurementsSettingsScreen()),
      full(RouteNames.legal, (_) => const LegalScreen()),
      full(RouteNames.deleteAccount, (_) => const DeleteAccountScreen()),
      full(RouteNames.benchmark, (_) => const BenchmarkScreen()),
      full('/benchmark/:runId', (s) => BenchmarkRunScreen(runId: s.pathParameters['runId']!)),
    ],
  );
});

/// Saf yönlendirme kuralı (test edilebilir).
String? appRedirect(AppSession session, String location) {
  final isAuthRoute = RouteNames.authRoutes.contains(location);
  final isSplash = location == RouteNames.splash;
  final isOnboarding = RouteNames.onboardingRoutes.contains(location);

  switch (session.status) {
    case SessionStatus.loading:
      return isSplash ? null : RouteNames.splash;
    case SessionStatus.unauthenticated:
      return isAuthRoute ? null : RouteNames.login;
    case SessionStatus.needsOnboarding:
      return isOnboarding ? null : RouteNames.consent;
    case SessionStatus.authenticated:
      if (isAuthRoute || isSplash || location == RouteNames.consent || location == RouteNames.onboardingMeasurements) {
        return RouteNames.tryOn;
      }
      return null;
  }
}
