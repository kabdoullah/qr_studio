import 'qr_style.dart';
import 'shared_file.dart';
import 'qr_type.dart';
import 'whatsapp_qr_data.dart';

// Résultat final : le contenu encodé et son style de rendu.
class QrCodeData {
  const QrCodeData({
    required this.type,
    required this.payload,
    this.style = const QrStyle(),
    this.file,
    this.whatsapp,
  });

  final QrType type;
  final String payload;
  final QrStyle style;

  // Fichier en ligne présenté par le QR Code (CV, image de carte de
  // visite), ou `null` s'il n'y en a pas.
  final SharedFile? file;

  // Discussion WhatsApp encodée (titre et numéro présentés au lieu du lien),
  // ou `null` pour les autres contenus.
  final WhatsAppQrData? whatsapp;

  // Le QR Code mène à une adresse en ligne (`/q/{slug}`, ou le site
  // lui-même) : le lien est alors affiché et joint au partage.
  bool get isOnlineLink =>
      type.isDynamic || type == QrType.website || file != null;
}
