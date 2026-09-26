import 'package:flutter/material.dart';

import 'app_colors.dart';

// Échelle d'espacement : multiples de 4, sans valeurs arbitraires.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double giant = 64;

  // Marge latérale des écrans.
  static const double gutter = lg;
}

// Échelle des arrondis.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

// Largeurs maximales du contenu (web, tablette) et points de rupture.
abstract final class AppLayout {
  // Connexion, résultat : une colonne étroite.
  static const double narrow = 480;
  // Formulaires, listes.
  static const double form = 600;
  // Accueil.
  static const double content = 960;
  // Au-delà, l'aperçu du QR Code s'affiche à côté du formulaire.
  static const double sideBySide = 840;
  static const double previewWidth = 380;

  static const double minTapTarget = 48;
  static const double buttonHeight = 52;
}

// Durées des micro-interactions.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
}

// Ombres : très discrètes, le design reste propre sans elles.
abstract final class AppShadows {
  static List<BoxShadow> raised(Brightness brightness) => [
    BoxShadow(
      color: AppColors.shadow.withValues(
        alpha: brightness == Brightness.light ? 0.06 : 0.3,
      ),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
