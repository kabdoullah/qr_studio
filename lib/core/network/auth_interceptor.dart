import 'package:dio/dio.dart';

import 'session_token.dart';

// Jetons de session des requêtes Dio.
//
// - Ajoute `Authorization: Bearer <access>` aux requêtes authentifiées.
// - Sur un 401, renouvelle une seule fois les jetons (`POST auth/refresh`,
//   partagé par les requêtes refusées en même temps) puis rejoue la requête
//   une seule fois. Le renouvellement est envoyé sans jeton et ne passe
//   jamais par cette logique : pas de boucle.
// - Renouvellement refusé (401/403) : fin de session (`onUnauthorized`).
//   Serveur injoignable : la session est gardée et l'erreur remonte.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._dio, {
    required this.refreshPath,
    required this._readTokens,
    required this._onTokensRefreshed,
    required this._onUnauthorized,
  });

  // `false` dans `Options.extra` : requête sans session (connexion,
  // inscription, renouvellement, pages publiques).
  static const String authenticatedKey = 'qr_studio.authenticated';
  static const String _usedTokensKey = 'qr_studio.tokens';
  static const String _retriedKey = 'qr_studio.retried';

  final Dio _dio;
  final String refreshPath;
  final AuthTokens? Function() _readTokens;
  final void Function(AuthTokens tokens) _onTokensRefreshed;
  final void Function() _onUnauthorized;

  // Renouvellement en cours, attendu par toutes les requêtes refusées.
  Future<AuthTokens?>? _refreshing;

  static bool _isAuthenticated(RequestOptions options) =>
      options.extra[authenticatedKey] != false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isAuthenticated(options)) {
      final tokens = _readTokens();
      options.extra[_usedTokensKey] = tokens;
      if (tokens != null && tokens.accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || !_isAuthenticated(options)) {
      return handler.next(err);
    }
    final used = options.extra[_usedTokensKey] as AuthTokens?;
    if (used == null || options.extra[_retriedKey] == true) {
      // Aucune session à renouveler, ou requête déjà rejouée : la session
      // est refusée par le serveur.
      _onUnauthorized();
      return handler.next(err);
    }

    final AuthTokens? renewed;
    try {
      renewed = await _renewAfter(used);
    } on DioException catch (refreshError) {
      return handler.next(refreshError);
    }
    if (renewed == null) return handler.next(err);

    final data = options.data;
    final retry = options.copyWith(
      // Un formulaire multipart envoyé ne peut pas l'être une seconde fois.
      data: data is FormData ? data.clone() : data,
      extra: {...options.extra, _retriedKey: true},
    );
    try {
      handler.resolve(await _dio.fetch<Object?>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  // Jetons à utiliser après un refus de `used`, ou `null` si la session
  // est terminée.
  Future<AuthTokens?> _renewAfter(AuthTokens used) {
    final current = _readTokens();
    if (current == null) return Future.value();
    // Déjà renouvelés par une autre requête : les réutiliser. Présenter à
    // nouveau l'ancien jeton de renouvellement serait pris par le serveur
    // pour un vol et révoquerait la session.
    if (current.accessToken != used.accessToken) return Future.value(current);
    return _refreshing ??= _refresh(
      current.refreshToken,
    ).whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Object?>(
        refreshPath,
        data: {'refresh_token': refreshToken},
        options: Options(extra: {authenticatedKey: false}),
      );
      final tokens = AuthTokens.fromJson(response.data);
      if (tokens == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          error: const FormatException('Jetons absents'),
        );
      }
      _onTokensRefreshed(tokens);
      return tokens;
    } on DioException catch (error) {
      // Jeton refusé (expiré, révoqué) ou compte désactivé : fin de
      // session.
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        _onUnauthorized();
        return null;
      }
      rethrow;
    }
  }
}
