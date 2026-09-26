import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import 'session_token.dart';

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

// Client HTTP du backend QR Studio : JSON, jeton de session, délais et
// traduction des erreurs. Toutes les méthodes lèvent `ApiException`.
class ApiClient {
  ApiClient(
    String baseUrl, {
    required this._readToken,
    required this._onUnauthorized,
    http.Client? client,
  }) : _baseUrl = apiBaseUri(baseUrl),
       _client = client ?? http.Client();

  // Laisse au serveur gratuit le temps de sortir de veille.
  static const Duration timeout = Duration(seconds: 90);

  final Uri _baseUrl;
  final String? Function() _readToken;
  final void Function() _onUnauthorized;
  final http.Client _client;

  Uri resolve(String path) => _baseUrl.resolve(path);

  Future<Object?> get(String path) => _json('GET', path);

  Future<Object?> post(
    String path,
    Object? body, {
    bool authenticated = true,
  }) => _json('POST', path, body: body, authenticated: authenticated);

  Future<Object?> put(String path, Object? body) =>
      _json('PUT', path, body: body);

  Future<void> delete(String path) => _json('DELETE', path);

  // Envoi d'une requête construite par l'appelant (fichier multipart).
  Future<Object?> send(http.BaseRequest request, {Duration? timeout}) async {
    _authorize(request.headers);
    return _handle(
      () async => http.Response.fromStream(
        await _client.send(request).timeout(timeout ?? ApiClient.timeout),
      ).timeout(timeout ?? ApiClient.timeout),
      authenticated: true,
    );
  }

  Future<Object?> _json(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    final request = http.Request(method, resolve(path));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authenticated) _authorize(request.headers);
    return _handle(
      () async => http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout),
      authenticated: authenticated,
    );
  }

  void _authorize(Map<String, String> headers) {
    final token = _readToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
  }

  Future<Object?> _handle(
    Future<http.Response> Function() call, {
    required bool authenticated,
  }) async {
    final http.Response response;
    try {
      response = await call();
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.timeout);
    } on http.ClientException {
      throw const ApiException(ApiErrorKind.offline);
    }

    final status = response.statusCode;
    Object? body;
    if (response.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (status < 400) {
          throw ApiException(ApiErrorKind.invalidResponse, statusCode: status);
        }
      }
    }
    if (status >= 200 && status < 300) return body;

    // Une session refusée par le serveur est terminée ; une connexion
    // refusée (mauvais mot de passe) ne l'est pas.
    if (status == 401 && authenticated) _onUnauthorized();
    // Les messages d'erreur du serveur sont rédigés pour l'utilisateur ;
    // les erreurs de validation détaillées (liste) ne le sont pas.
    final detail = body is Map<String, dynamic> && body['detail'] is String
        ? body['detail'] as String
        : null;
    throw ApiException(
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
final apiClientProvider = Provider<ApiClient?>((ref) {
  if (apiBaseUrl.isEmpty) return null;
  return ApiClient(
    apiBaseUrl,
    readToken: () => ref.read(sessionTokenProvider),
    onUnauthorized: () => ref.read(sessionTokenProvider.notifier).clear(),
  );
});
