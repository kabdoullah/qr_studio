import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_token.g.dart';

// Jetons d'une session : `accessToken` (JWT court, envoyé à chaque requête)
// et `refreshToken` (opaque, échangé contre une nouvelle paire). Jamais
// affichés ni écrits dans les logs.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  // `null` si la réponse du serveur est incomplète.
  static AuthTokens? fromJson(Object? json) {
    if (json case {
      'access_token': final String access,
      'refresh_token': final String refresh,
    } when access.isNotEmpty && refresh.isNotEmpty) {
      return AuthTokens(accessToken: access, refreshToken: refresh);
    }
    return null;
  }

  @override
  String toString() => 'AuthTokens(…)';
}

// Jetons de la session en cours, en mémoire. `ApiClient` les ajoute aux
// requêtes, les remplace après un renouvellement et les efface quand le
// serveur refuse la session, ce que `AuthViewModel` traite comme une
// déconnexion.
@Riverpod(keepAlive: true)
class SessionToken extends _$SessionToken {
  @override
  AuthTokens? build() => null;

  void set(AuthTokens tokens) => state = tokens;

  void clear() => state = null;
}
