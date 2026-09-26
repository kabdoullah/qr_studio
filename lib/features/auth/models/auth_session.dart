import '../../../core/network/session_token.dart';
import 'app_user.dart';

// Session ouverte par le serveur : compte et jetons.
class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final AppUser user;
  final AuthTokens tokens;

  // `null` si la réponse du serveur est incomplète.
  static AuthSession? fromJson(Object? json) {
    final tokens = AuthTokens.fromJson(json);
    final user = json is Map<String, dynamic>
        ? AppUser.fromJson(json['user'])
        : null;
    if (tokens == null || user == null) return null;
    return AuthSession(user: user, tokens: tokens);
  }
}
