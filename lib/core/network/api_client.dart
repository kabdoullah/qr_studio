import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/api_config.dart';
import 'auth_interceptor.dart';
import 'session_token.dart';

part 'api_client.g.dart';

// Catégories d'échec d'un appel au serveur, chacune avec son message.
enum ApiErrorKind {
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  tooManyRequests,
  server,
  timeout,
  offline,
  invalidResponse,
}

// Échec d'un appel au serveur. `message` est destiné à l'utilisateur ; le
// corps de la réponse n'est jamais conservé (il peut contenir des données
// saisies, comme un mot de passe Wi-Fi).
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this._serverMessage});

  final ApiErrorKind kind;
  final int? statusCode;
  final String? _serverMessage;

  String get message =>
      _serverMessage ??
      switch (kind) {
        ApiErrorKind.unauthorized =>
          'Votre session a expiré. Veuillez vous reconnecter.',
        ApiErrorKind.forbidden => 'Cette action ne vous est pas autorisée.',
        ApiErrorKind.notFound => 'Élément introuvable.',
        ApiErrorKind.conflict => 'Cet élément existe déjà.',
        ApiErrorKind.validation =>
          'Certaines informations sont invalides. Vérifiez votre saisie.',
        ApiErrorKind.tooManyRequests => "Trop d'envois. Réessayez plus tard.",
        ApiErrorKind.server =>
          'Le serveur rencontre un problème. Réessayez plus tard.',
        ApiErrorKind.timeout =>
          'Le serveur ne répond pas. Vérifiez votre connexion et réessayez.',
        ApiErrorKind.offline =>
          'Connexion impossible. Vérifiez votre connexion internet.',
        ApiErrorKind.invalidResponse =>
          'Réponse inattendue du serveur. Réessayez plus tard.',
      };

  @override
  String toString() => 'ApiException(${kind.name}, statut $statusCode)';
}

// Client HTTP (Dio) du backend QR Studio : JSON, jetons de session
// (`AuthInterceptor`), délai total et traduction des erreurs. Toutes les
// méthodes lèvent `ApiException`.
class ApiClient {
  ApiClient(
    String baseUrl, {
    required AuthTokens? Function() readTokens,
    required void Function(AuthTokens tokens) onTokensRefreshed,
    required void Function() onUnauthorized,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(BaseOptions(baseUrl: apiBaseUri(baseUrl).toString())) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(
      AuthInterceptor(
        _dio,
        refreshPath: refreshPath,
        readTokens: readTokens,
        onTokensRefreshed: onTokensRefreshed,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  // Laisse au serveur gratuit le temps de sortir de veille. Délai total de
  // la requête (renouvellement de session et nouvel essai compris).
  static const Duration timeout = Duration(seconds: 90);
  static const String refreshPath = 'api/v1/auth/refresh';

  final Dio _dio;

  Future<Object?> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => _request('GET', path, query: query, authenticated: authenticated);

  Future<Object?> post(
    String path,
    Object? body, {
    bool authenticated = true,
  }) => _request('POST', path, data: body, authenticated: authenticated);

  Future<Object?> put(String path, Object? body) =>
      _request('PUT', path, data: body);

  Future<void> delete(String path) => _request('DELETE', path);

  // Envoi d'un fichier (multipart), toujours authentifié.
  Future<Object?> postForm(String path, FormData form, {Duration? timeout}) =>
      _request('POST', path, data: form, timeout: timeout);

  Future<Object?> _request(
    String method,
    String path, {
    Object? data,
    Map<String, String>? query,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    final cancel = CancelToken();
    try {
      final response = await _dio
          .request<Object?>(
            path,
            data: data,
            queryParameters: query,
            cancelToken: cancel,
            options: Options(
              method: method,
              extra: {AuthInterceptor.authenticatedKey: authenticated},
            ),
          )
          .timeout(
            timeout ?? ApiClient.timeout,
            onTimeout: () {
              cancel.cancel();
              throw const ApiException(ApiErrorKind.timeout);
            },
          );
      final body = response.data;
      // Réponse qui n'est pas du JSON (page d'erreur d'un proxy…).
      if (body is String && body.isNotEmpty) {
        throw ApiException(
          ApiErrorKind.invalidResponse,
          statusCode: response.statusCode,
        );
      }
      return body;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  // Seuls le statut et le message `detail` sont gardés : le corps de la
  // réponse peut contenir des données saisies.
  static ApiException _toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.transformTimeout ||
          DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.timeout);
      case DioExceptionType.connectionError || DioExceptionType.badCertificate:
        return const ApiException(ApiErrorKind.offline);
      case DioExceptionType.unknown:
        return error.error is FormatException
            ? const ApiException(ApiErrorKind.invalidResponse)
            : const ApiException(ApiErrorKind.offline);
      case DioExceptionType.badResponse:
        break;
    }
    final status = error.response?.statusCode ?? 0;
    final body = error.response?.data;
    // Les messages d'erreur du serveur sont rédigés pour l'utilisateur ;
    // les erreurs de validation détaillées (liste) ne le sont pas.
    final detail = body is Map && body['detail'] is String
        ? body['detail'] as String
        : null;
    return ApiException(
      switch (status) {
        401 => ApiErrorKind.unauthorized,
        403 => ApiErrorKind.forbidden,
        404 => ApiErrorKind.notFound,
        409 => ApiErrorKind.conflict,
        422 || 400 || 413 || 415 => ApiErrorKind.validation,
        429 => ApiErrorKind.tooManyRequests,
        _ => ApiErrorKind.server,
      },
      statusCode: status,
      serverMessage: status >= 500 && status != 507 ? null : detail,
    );
  }
}

// `null` quand l'application est lancée sans adresse de serveur.
@Riverpod(keepAlive: true)
ApiClient? apiClient(Ref ref) {
  if (apiBaseUrl.isEmpty) return null;
  final session = ref.read(sessionTokenProvider.notifier);
  return ApiClient(
    apiBaseUrl,
    readTokens: () => ref.read(sessionTokenProvider),
    onTokensRefreshed: session.set,
    onUnauthorized: session.clear,
  );
}
