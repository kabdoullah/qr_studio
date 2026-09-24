import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/shared_file.dart';

// Met un fichier en ligne et renvoie l'URL publique encodée dans le QR Code.
// Le serveur est dans `backend/` (FastAPI).
abstract interface class FileStorageService {
  Future<String> upload(SharedFile file, SharedFileKind kind);
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
  Future<String> upload(SharedFile file, SharedFileKind kind) async {
    throw const FileStorageUnavailableException();
  }
}

// Réponse inattendue du serveur (statut d'erreur ou réponse invalide).
class FileUploadException implements Exception {
  const FileUploadException(this.message);

  final String message;

  @override
  String toString() => 'FileUploadException: $message';
}

// Envoi vers le backend QR Studio :
// - CV : `POST /api/v1/cvs` ;
// - image de carte de visite : `POST /api/v1/cards` ;
// réponse `201 { "id": "...", "url": "..." }`.
final class HttpFileStorageService implements FileStorageService {
  HttpFileStorageService(Uri baseUrl, {http.Client? client})
    : _baseUrl = baseUrl.path.endsWith('/')
          ? baseUrl
          : baseUrl.replace(path: '${baseUrl.path}/'),
      _client = client ?? http.Client();

  // Un fichier de 10 MB sur une connexion mobile lente.
  static const Duration timeout = Duration(minutes: 2);

  final Uri _baseUrl;
  final http.Client _client;

  @override
  Future<String> upload(SharedFile file, SharedFileKind kind) async {
    final path = file.localPath;
    if (path == null) {
      throw FileUploadException('Fichier local introuvable : ${file.name}');
    }
    final endpoint = _baseUrl.resolve(switch (kind) {
      SharedFileKind.cv => 'api/v1/cvs',
      SharedFileKind.businessCardImage => 'api/v1/cards',
    });

    // Le fichier est lu en flux depuis le disque, sans être chargé en
    // mémoire. Le serveur vérifie lui-même le type réel du contenu.
    final request = http.MultipartRequest('POST', endpoint)
      ..files.add(
        await http.MultipartFile.fromPath('file', path, filename: file.name),
      );
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(timeout),
    ).timeout(timeout);

    if (response.statusCode != 201) {
      throw FileUploadException(
        'Statut ${response.statusCode} : ${response.body}',
      );
    }
    final body = jsonDecode(response.body);
    final url = body is Map<String, dynamic> ? body['url'] : null;
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw FileUploadException('Réponse invalide : ${response.body}');
    }
    return uri.toString();
  }
}

// Adresse du backend, fournie au lancement :
// `flutter run --dart-define=QR_STUDIO_API_URL=http://192.168.1.10:8000`.
const String _apiUrl = String.fromEnvironment('QR_STUDIO_API_URL');

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  if (_apiUrl.isEmpty) return const BackendRequiredFileStorageService();
  return HttpFileStorageService(Uri.parse(_apiUrl));
});
