import 'dart:ui';

import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../app/theme/app_colors.dart';

// Apparence du QR Code. Point d'extension pour la personnalisation future
// (formes, logo, dégradé, correction d'erreur, marge).
class QrStyle {
  const QrStyle({
    this.foregroundColor = AppColors.qrForeground,
    this.backgroundColor = AppColors.qrBackground,
    this.size = 280,
    this.errorCorrectLevel = QrErrorCorrectLevel.M,
  });

  final Color foregroundColor;
  final Color backgroundColor;
  final double size;

  // Niveau M (~15 % de redondance) : bon compromis entre capacité et
  // robustesse à l'impression.
  final int errorCorrectLevel;

  // Rendu partagé par l'aperçu et l'export PNG. L'export inclut le fond et
  // la marge de 4 modules (« quiet zone ») indispensable à la lecture.
  PrettyQrDecoration toDecoration({bool forExport = false}) {
    return PrettyQrDecoration(
      shape: PrettyQrSmoothSymbol(color: foregroundColor),
      background: forExport ? backgroundColor : null,
      quietZone: forExport
          ? PrettyQrQuietZone.standard
          : PrettyQrQuietZone.zero,
    );
  }
}
