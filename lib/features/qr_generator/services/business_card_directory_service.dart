import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../models/business_card_data.dart';

part 'business_card_directory_service.g.dart';

// Annuaire des cartes de visite partagées (public, sans compte) :
// - `GET /api/v1/business-cards?q=` : recherche, plus récentes d'abord ;
// - `POST /api/v1/business-cards` : publication (visible par tous).
// Erreurs : `ApiException`.
class BusinessCardDirectoryService {
  const BusinessCardDirectoryService(this._api);

  static const String _path = 'api/v1/business-cards';

  final ApiClient _api;

  Future<List<SavedBusinessCard>> search(String query) async {
    final q = query.trim();
    final body = await _api.get(
      _path,
      query: q.isEmpty ? null : {'q': q},
      authenticated: false,
    );
    if (body case {'items': final List<Object?> items}) {
      return items.map(_parseCard).toList();
    }
    throw const ApiException(ApiErrorKind.invalidResponse);
  }

  Future<SavedBusinessCard> publish(BusinessCardData card) async =>
      _parseCard(await _api.post(_path, card.toJson(), authenticated: false));

  static SavedBusinessCard _parseCard(Object? json) {
    if (json is! Map<String, dynamic> || json['id'] is! String) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return SavedBusinessCard(
      id: json['id'] as String,
      data: BusinessCardData.fromJson(json),
    );
  }
}

// `null` quand l'application est lancée sans adresse de serveur : les
// cartes partagées sont alors masquées.
@Riverpod(keepAlive: true)
BusinessCardDirectoryService? businessCardDirectory(Ref ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : BusinessCardDirectoryService(api);
}
