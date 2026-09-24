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

  // Fichier en ligne vers lequel pointe le QR Code (CV, image de carte de
  // visite), ou `null` si le contenu est encodé directement.
  final SharedFile? file;
}
