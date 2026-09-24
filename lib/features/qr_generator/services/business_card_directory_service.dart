import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../models/business_card_data.dart';

// Réponse d'erreur du serveur de cartes (statut HTTP ou réponse invalide).
class BusinessCardDirectoryException implements Exception {
  const BusinessCardDirectoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BusinessCardDirectoryException: $message';
}

// Annuaire des cartes de visite partagées :
// - `GET /api/v1/business-cards?q=` : recherche, plus récentes d'abord ;
// - `POST /api/v1/business-cards` : publication (visible par tous).
class BusinessCardDirectoryService {
  BusinessCardDirectoryService(String baseUrl, {http.Client? client})
    : _endpoint = apiBaseUri(baseUrl).resolve('api/v1/business-cards'),
      _client = client ?? http.Client();

  static const Duration timeout = Duration(seconds: 90);

  final Uri _endpoint;
  final http.Client _client;

  Future<List<SavedBusinessCard>> search(String query) async {
    final q = query.trim();
    final uri = q.isEmpty
        ? _endpoint
        : _endpoint.replace(queryParameters: {'q': q});
    final body = _decode(await _client.get(uri).timeout(timeout), 200);
    final items = body is Map<String, dynamic> ? body['items'] : null;
    if (items is! List) {
      throw const BusinessCardDirectoryException('Réponse invalide.');
    }
    return items.map(_parseCard).toList();
  }

  Future<SavedBusinessCard> publish(BusinessCardData card) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(_toJson(card)),
        )
        .timeout(timeout);
    return _parseCard(_decode(response, 201));
  }

  static Object? _decode(http.Response response, int expectedStatus) {
    if (response.statusCode != expectedStatus) {
      throw BusinessCardDirectoryException(
        'Statut ${response.statusCode} : ${response.body}',
        statusCode: response.statusCode,
      );
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const BusinessCardDirectoryException('Réponse invalide.');
    }
  }

  static SavedBusinessCard _parseCard(Object? json) {
    if (json is! Map<String, dynamic> || json['id'] is! String) {
      throw const BusinessCardDirectoryException('Carte invalide.');
    }
    String field(String name) =>
        json[name] is String ? json[name] as String : '';
    return SavedBusinessCard(
      id: json['id'] as String,
      data: BusinessCardData(
        firstName: field('first_name'),
        lastName: field('last_name'),
        jobTitle: field('job_title'),
        company: field('company'),
        phone: field('phone'),
        email: field('email'),
        website: field('website'),
        address: field('address'),
        city: field('city'),
        country: field('country'),
        linkedin: field('linkedin'),
        instagram: field('instagram'),
        whatsapp: field('whatsapp'),
      ),
    );
  }

  static Map<String, String> _toJson(BusinessCardData c) => {
    'first_name': c.firstName.trim(),
    'last_name': c.lastName.trim(),
    'job_title': c.jobTitle.trim(),
    'company': c.company.trim(),
    'phone': c.phone.trim(),
    'email': c.email.trim(),
    'website': c.website.trim(),
    'address': c.address.trim(),
    'city': c.city.trim(),
    'country': c.country.trim(),
    'linkedin': c.linkedin.trim(),
    'instagram': c.instagram.trim(),
    'whatsapp': c.whatsapp.trim(),
  };
}

// `null` quand l'application est lancée sans adresse de serveur : les
// cartes partagées sont alors masquées.
final businessCardDirectoryProvider = Provider<BusinessCardDirectoryService?>(
  (ref) => apiBaseUrl.isEmpty ? null : BusinessCardDirectoryService(apiBaseUrl),
);
