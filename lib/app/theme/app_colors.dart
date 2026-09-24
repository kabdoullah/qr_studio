import 'package:flutter/material.dart';

// Palette centralisée de l'application : aucune couleur ne doit être
// codée en dur dans les widgets.
abstract final class AppColors {
  // Couleur de marque à partir de laquelle Material 3 dérive les schémas.
  static const Color seed = Color(0xFF3949AB);

  // Couleurs du QR Code par défaut : contraste maximal pour une lecture fiable.
  static const Color qrForeground = Color(0xFF000000);
  static const Color qrBackground = Color(0xFFFFFFFF);
}
