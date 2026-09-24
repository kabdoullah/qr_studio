import 'package:flutter/material.dart';

// Types de contenu pris en charge, avec leur présentation.
enum QrType {
  businessCard(
    title: 'Carte de visite',
    description: 'Partagez vos coordonnées',
    icon: Icons.person_outline_rounded,
    readyMessage: 'Votre QR Code est prêt 🎉',
    fileName: 'qr-code-carte-de-visite.png',
  ),
  cv(
    title: 'CV',
    description: 'Partagez votre CV PDF',
    icon: Icons.description_outlined,
    readyMessage: 'Votre CV est prêt 🎉',
    fileName: 'qr-code-cv.png',
  ),
  text(
    title: 'Texte',
    description: 'Partagez un message',
    icon: Icons.notes_rounded,
    readyMessage: 'Votre QR Code est prêt 🎉',
    fileName: 'qr-code-texte.png',
  ),
  socialPage(
    title: 'Réseaux sociaux',
    description: 'Regroupez vos réseaux sur une page',
    icon: Icons.hub_outlined,
    readyMessage: 'Votre page est en ligne 🎉',
    fileName: 'qr-code-reseaux-sociaux.png',
  );

  const QrType({
    required this.title,
    required this.description,
    required this.icon,
    required this.readyMessage,
    required this.fileName,
  });

  final String title;
  final String description;
  final IconData icon;

  // Titre de l'écran résultat.
  final String readyMessage;

  // Nom du fichier PNG exporté.
  final String fileName;
}
