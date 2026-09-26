import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/qr_type.dart';
import '../models/saved_qr_code.dart';

// QR Codes du compte connecté (`/api/v1/qr-codes`). Le serveur renvoie
// 404 pour le QR Code d'un autre compte.
class QrCodeService {
  const QrCodeService(this._api);

  static const String _path = 'api/v1/qr-codes';

  final ApiClient _api;

  Future<List<SavedQrCode>> list() async {
    final body = await _api.get(_path);
    if (body case {'items': final List items}) {
      return items.map(SavedQrCode.fromJson).nonNulls.toList();
    }
    throw const ApiException(ApiErrorKind.invalidResponse);
  }

  Future<SavedQrCode> create(
    QrType type, {
    required String title,
    required Map<String, Object?> content,
  }) async {
    return _parse(await _api.post(_path, _body(type, title, content)));
  }

  // Modification : l'adresse publique (`/q/{slug}`) reste la même.
  Future<SavedQrCode> update(
    String id,
    QrType type, {
    required String title,
    required Map<String, Object?> content,
  }) async {
    return _parse(await _api.put('$_path/$id', _body(type, title, content)));
  }

  Future<void> delete(String id) => _api.delete('$_path/$id');

  static Map<String, Object?> _body(
    QrType type,
    String title,
    Map<String, Object?> content,
  ) => {'type': type.apiName, 'title': title.trim(), 'content': content};

  static SavedQrCode _parse(Object? body) =>
      SavedQrCode.fromJson(body) ??
      (throw const ApiException(ApiErrorKind.invalidResponse));
}

// `null` sans adresse de serveur : l'enregistrement est alors indisponible.
final qrCodeServiceProvider = Provider<QrCodeService?>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : QrCodeService(api);
});
