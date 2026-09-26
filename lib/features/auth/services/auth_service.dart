import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/app_user.dart';

// Comptes : `POST /api/v1/auth/register`, `POST /api/v1/auth/login`
// (→ `{ "access_token", "token_type" }`) et `GET /api/v1/auth/me`.
class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await _api.post('api/v1/auth/register', {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'password': password,
    }, authenticated: false);
  }

  // Renvoie le jeton de session.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final body = await _api.post('api/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    }, authenticated: false);
    if (body case {'access_token': final String token}) return token;
    throw const ApiException(ApiErrorKind.invalidResponse);
  }

  // Compte du jeton en cours (vérifié par le serveur).
  Future<AppUser> me() async {
    final user = AppUser.fromJson(await _api.get('api/v1/auth/me'));
    if (user == null) throw const ApiException(ApiErrorKind.invalidResponse);
    return user;
  }
}

// `null` sans adresse de serveur : la connexion est alors indisponible.
final authServiceProvider = Provider<AuthService?>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : AuthService(api);
});
