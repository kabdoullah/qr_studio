import 'dart:typed_data';

// Types de fichiers partagés par lien : le fichier est mis en ligne et le
// QR Code contient son URL (un fichier est bien trop lourd pour y tenir).
enum SharedFileKind {
  cv(
    extensions: ['pdf'],
    formatLabel: 'PDF uniquement',
    wrongFormatMessage: 'Veuillez sélectionner un fichier PDF.',
    missingMessage: 'Veuillez sélectionner votre CV au format PDF.',
    unavailableMessage:
        "La mise en ligne des CV n'est pas encore disponible.\n"
        'Votre QR Code pourra être créé dès son ouverture.',
    uploadFailedMessage:
        "Impossible d'envoyer votre CV.\n"
        'Vérifiez votre connexion et réessayez.',
  ),
  // Formats lisibles par tous les navigateurs (le HEIC ne l'est pas).
  businessCardImage(
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    formatLabel: 'JPG ou PNG',
    wrongFormatMessage: 'Veuillez sélectionner une image JPG ou PNG.',
    missingMessage: "Veuillez sélectionner l'image de votre carte de visite.",
    unavailableMessage:
        "La mise en ligne des images n'est pas encore disponible.\n"
        'Votre QR Code pourra être créé dès son ouverture.',
    uploadFailedMessage:
        "Impossible d'envoyer votre image.\n"
        'Vérifiez votre connexion et réessayez.',
  );

  const SharedFileKind({
    required this.extensions,
    required this.formatLabel,
    required this.wrongFormatMessage,
    required this.missingMessage,
    required this.unavailableMessage,
    required this.uploadFailedMessage,
  });

  // Taille maximale acceptée pour la V1.
  static const int maxSizeBytes = 10 * 1024 * 1024;

  final List<String> extensions;
  final String formatLabel;
  final String wrongFormatMessage;
  final String missingMessage;
  final String unavailableMessage;
  final String uploadFailedMessage;

  bool acceptsName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return false;
    return extensions.contains(fileName.substring(dot + 1).toLowerCase());
  }
}

// Fichier sélectionné sur l'appareil, puis mis en ligne.
class SharedFile {
  const SharedFile({
    required this.name,
    required this.size,
    this.localPath,
    this.bytes,
    this.remoteUrl,
  });

  final String name;

  // Taille en octets.
  final int size;

  final String? localPath;

  // Contenu du fichier, seulement sur le web : un navigateur ne donne pas
  // de chemin sur le disque.
  final Uint8List? bytes;

  // URL publique renvoyée par le backend après l'envoi.
  final String? remoteUrl;

  SharedFile withRemoteUrl(String url) => SharedFile(
    name: name,
    size: size,
    localPath: localPath,
    bytes: bytes,
    remoteUrl: url,
  );
}
