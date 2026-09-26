// Échec d'une connexion Google ou Facebook côté SDK (autre qu'une
// annulation). `detail` est technique : journalisé, jamais affiché.
class SocialSignInException implements Exception {
  const SocialSignInException(this.provider, [this.detail]);

  final String provider;
  final String? detail;

  @override
  String toString() => 'SocialSignInException($provider, $detail)';
}
