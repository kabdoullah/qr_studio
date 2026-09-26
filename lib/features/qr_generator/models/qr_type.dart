import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

// Types de contenu pris en charge, avec leur présentation.
enum QrType {
  businessCard(
    apiName: 'business_card',
    title: 'Carte de visite',
    description: 'Partagez vos coordonnées',
    icon: Icons.person_outline_rounded,
    accent: AppColors.indigo,
    readyMessage: 'Votre QR Code est prêt',
    fileName: 'qr-code-carte-de-visite.png',
  ),
  cv(
    apiName: 'cv',
    title: 'CV',
    description: 'Partagez votre CV en PDF',
    icon: Icons.description_outlined,
    accent: AppColors.rose,
    readyMessage: 'Votre CV est prêt',
    fileName: 'qr-code-cv.png',
    isDynamic: true,
  ),
  text(
    apiName: 'text',
    title: 'Texte',
    description: 'Transformez un texte en QR Code',
    icon: Icons.notes_rounded,
    accent: AppColors.slate,
    readyMessage: 'Votre QR Code est prêt',
    fileName: 'qr-code-texte.png',
  ),
  socialMedia(
    apiName: 'social_media',
    title: 'Réseaux sociaux',
    description: 'Tous vos réseaux au même endroit',
    icon: Icons.hub_outlined,
    accent: AppColors.violet,
    readyMessage: 'Votre page est en ligne',
    fileName: 'qr-code-reseaux-sociaux.png',
    isDynamic: true,
  ),
  website(
    apiName: 'website',
    title: 'Site Web',
    description: 'Partagez votre site',
    icon: Icons.language_rounded,
    accent: AppColors.sky,
    readyMessage: 'Votre QR Code est prêt',
    fileName: 'qr-code-site-web.png',
    isDynamic: true,
  ),
  wifi(
    apiName: 'wifi',
    title: 'Wi-Fi',
    description: 'Partagez votre connexion',
    icon: Icons.wifi_rounded,
    accent: AppColors.emerald,
    readyMessage: 'Votre QR Code Wi-Fi est prêt',
    fileName: 'qr-code-wifi.png',
  );

  const QrType({
    required this.apiName,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.readyMessage,
    required this.fileName,
    this.isDynamic = false,
  });

  // Nom du type pour l'API (`type` des QR Codes enregistrés).
  final String apiName;

  final String title;
  final String description;
  final IconData icon;

  // Couleur d'accent de l'icône (accueil, Mes QR Codes).
  final AccentColor accent;

  // Titre de l'écran résultat.
  final String readyMessage;

  // Nom du fichier PNG exporté.
  final String fileName;

  // Le QR Code contient l'adresse publique `/q/{slug}` (modifiable sans
  // réimpression) plutôt que le contenu lui-même. Le texte, le Wi-Fi et
  // les coordonnées de la carte de visite restent encodés directement :
  // le téléphone qui scanne doit les lire sans réseau.
  final bool isDynamic;

  static QrType? fromApiName(String name) {
    for (final type in values) {
      if (type.apiName == name) return type;
    }
    return null;
  }
}
