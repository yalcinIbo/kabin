/// Tüm rota yolları.
abstract final class RouteNames {
  static const splash = '/splash';

  // Auth
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // Onboarding (KVKK + ölçüler)
  static const consent = '/onboarding/consent';
  static const onboardingMeasurements = '/onboarding/measurements';

  // Sekmeler
  static const tryOn = '/try';
  static const wardrobe = '/wardrobe';
  static const history = '/history';
  static const profile = '/profile';

  // Dolap
  static const addPhoto = '/photos/add';
  static const selfieAvatar = '/photos/avatar';
  static String photo(String id) => '/photos/$id';
  static const addGarment = '/garments/add';
  static String garment(String id) => '/garments/$id';

  // Sonuçlar
  static String tryOnJob(String id) => '/tryon/$id';
  static String model3d(String id) => '/models3d/$id';

  // Hesap
  static const credits = '/credits';
  static const settings = '/settings';
  static const measurements = '/settings/measurements';
  static const legal = '/settings/legal';
  static const deleteAccount = '/settings/delete';

  // Yönetici
  static const benchmark = '/benchmark';
  static String benchmarkRun(String runId) => '/benchmark/$runId';

  static const authRoutes = {login, register, forgotPassword};
  static const onboardingRoutes = {consent, onboardingMeasurements, legal};
}
