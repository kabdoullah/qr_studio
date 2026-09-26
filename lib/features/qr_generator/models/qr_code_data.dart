import 'qr_style.dart';
import 'shared_file.dart';
import 'qr_type.dart';

// Résultat final : le contenu encodé et son style de rendu.
class QrCodeData {
  const QrCodeData({
    required this.type,
    required this.payload,
    this.style = const QrStyle(),
    this.file,
  });

  final QrType type;
  final String payload;
  final QrStyle style;

  // Fichier en ligne présenté par le QR Code (CV, image de carte de
  // visite), ou `null` s'il n'y en a pas.
  final SharedFile? file;

  // Le QR Code mène à une adresse en ligne (`/q/{slug}`) : le lien est
  // alors affiché et joint au partage.
  bool get isOnlineLink => type.isDynamic || file != null;
}
