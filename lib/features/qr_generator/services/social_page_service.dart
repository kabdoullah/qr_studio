import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../models/social_page_data.dart';

// Réponse d'erreur du serveur (statut HTTP ou réponse invalide).
class SocialPageException implements Exception {
  const SocialPageException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialPageException: $message';
}

// Publication d'une page de réseaux sociaux :
// `POST /api/v1/social-pages` → `201 { "id": "...", "url": ".../s/<id>" }`.
// La page n'est listée nulle part : seul son lien y mène.
class SocialPageService {
  SocialPageService(String baseUrl, {http.Client? client})
    : _endpoint = apiBaseUri(baseUrl).resolve('api/v1/social-pages'),
      _client = client ?? http.Client();

  // Laisse au serveur gratuit le temps de sortir de veille.
  static const Duration timeout = Duration(seconds: 90);

  final Uri _endpoint;
  final http.Client _client;

  // Renvoie l'URL publique de la page. Les liens doivent être valides
  // (voir `SocialNetwork.toUrl`).
  Future<String> publish(SocialPageData page) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': page.title.trim(),
            'bio': page.bio.trim(),
            'links': [
              for (final link in page.links)
                {
                  'network': link.network.name,
                  'url': link.network.toUrl(link.value),
                },
            ],
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      throw SocialPageException(
        'Statut ${response.statusCode} : ${response.body}',
        statusCode: response.statusCode,
      );
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body case {'url': final String url}) return url;
    } on FormatException {
      // Traitée ci-dessous comme toute réponse invalide.
    }
    throw const SocialPageException('Réponse invalide.');
  }
}

// `null` quand l'application est lancée sans adresse de serveur : la
// publication échoue alors avec un message honnête.
final socialPageServiceProvider = Provider<SocialPageService?>(
  (ref) => apiBaseUrl.isEmpty ? null : SocialPageService(apiBaseUrl),
);
