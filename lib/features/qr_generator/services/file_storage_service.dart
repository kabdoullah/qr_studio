import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../models/shared_file.dart';

// Met un fichier en ligne sur le compte connecté. Le serveur est dans
// `backend/` (FastAPI).
abstract interface class FileStorageService {
  Future<RemoteFile> upload(SharedFile file, SharedFileKind kind);
}

// Levée tant qu'aucun backend de stockage n'est disponible.
class FileStorageUnavailableException implements Exception {
  const FileStorageUnavailableException();

  @override
  String toString() =>
      'FileStorageUnavailableException: aucun backend de stockage configuré.';
}

// Utilisée quand l'application est lancée sans adresse de serveur : échoue
// volontairement plutôt que de fabriquer une URL factice qui produirait un
// QR Code inutilisable.
final class BackendRequiredFileStorageService implements FileStorageService {
  const BackendRequiredFileStorageService();

  @override
  Future<RemoteFile> upload(SharedFile file, SharedFileKind kind) async {
    throw const FileStorageUnavailableException();
  }
}

// Envoi vers le backend QR Studio (compte connecté) :
// - CV : `POST /api/v1/cvs` ;
// - image de carte de visite : `POST /api/v1/cards` ;
// réponse `201 { "id": "...", "url": "..." }`.
final class HttpFileStorageService implements FileStorageService {
  const HttpFileStorageService(this._api);

  // Un fichier de 10 MB sur une connexion mobile lente.
  static const Duration timeout = Duration(minutes: 2);

  final ApiClient _api;

  @override
  Future<RemoteFile> upload(SharedFile file, SharedFileKind kind) async {
    final endpoint = _api.resolve(switch (kind) {
      SharedFileKind.cv => 'api/v1/cvs',
      SharedFileKind.businessCardImage => 'api/v1/cards',
    });

    // Sur mobile, le fichier est lu en flux depuis le disque, sans être
    // chargé en mémoire ; sur le web, son contenu est déjà en mémoire. Le
    // serveur vérifie lui-même le type réel du contenu.
    final bytes = file.bytes;
    final path = file.localPath;
    final http.MultipartFile part;
    if (bytes != null) {
      part = http.MultipartFile.fromBytes('file', bytes, filename: file.name);
    } else if (path != null) {
      part = await http.MultipartFile.fromPath(
        'file',
        path,
        filename: file.name,
      );
    } else {
      throw const ApiException(ApiErrorKind.validation);
    }
    final request = http.MultipartRequest('POST', endpoint)..files.add(part);
    final body = await _api.send(request, timeout: timeout);
    if (body case {'id': final String id, 'url': final String url}) {
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        return RemoteFile(id: id, url: url);
      }
    }
    throw const ApiException(ApiErrorKind.invalidResponse);
  }
}

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return const BackendRequiredFileStorageService();
  return HttpFileStorageService(api);
});
