// Adresse du backend QR Studio, fournie au lancement :
// `flutter run --dart-define=QR_STUDIO_API_URL=https://…onrender.com`.
// Vide : les fonctions en ligne (mise en ligne de fichiers, cartes
// partagées) sont indisponibles.
const String apiBaseUrl = String.fromEnvironment('QR_STUDIO_API_URL');

// Adresse de base terminée par « / », pour résoudre les chemins relatifs.
Uri apiBaseUri(String url) {
  final uri = Uri.parse(url);
  return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
}
