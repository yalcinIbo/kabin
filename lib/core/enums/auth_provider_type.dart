/// Kimlik doğrulama sağlayıcısı. Firestore'da `value` saklanır.
enum AuthProviderType {
  email('email'),
  google('google'),
  apple('apple');

  const AuthProviderType(this.value);
  final String value;

  static AuthProviderType fromValue(String? value) =>
      AuthProviderType.values.firstWhere((e) => e.value == value, orElse: () => AuthProviderType.email);
}
