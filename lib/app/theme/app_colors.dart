import 'package:flutter/material.dart';

// Palette centralisée de l'application : aucune couleur ne doit être
// codée en dur dans les widgets. Les écrans lisent les couleurs via
// `Theme.of(context).colorScheme` ; ces constantes ne servent qu'à
// construire les thèmes (et aux couleurs d'accent des types de QR Code).
abstract final class AppColors {
  // Marque : indigo moderne.
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primarySoft = Color(0xFFEEF2FF);

  // Thème clair.
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  // Légèrement plus foncé que le gris ardoise habituel : reste lisible
  // (contraste ≥ 4,5:1) sur les surfaces teintées.
  static const Color textSecondary = Color(0xFF526077);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color onErrorSoft = Color(0xFF991B1B);
  static const Color warning = Color(0xFFD97706);

  // Thème sombre.
  static const Color darkPrimary = Color(0xFF818CF8);
  static const Color darkOnPrimary = Color(0xFF1E1B4B);
  static const Color darkPrimarySoft = Color(0xFF2B2A63);
  static const Color darkOnPrimarySoft = Color(0xFFE0E7FF);
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF121A2B);
  static const Color darkSurfaceMuted = Color(0xFF1A2336);
  static const Color darkSurfaceRaised = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF9AA8BD);
  static const Color darkBorder = Color(0xFF243044);
  static const Color darkBorderStrong = Color(0xFF334155);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkOnError = Color(0xFF450A0A);
  static const Color darkErrorSoft = Color(0xFF3B1219);
  static const Color darkOnErrorSoft = Color(0xFFFECACA);
  static const Color darkWarning = Color(0xFFFBBF24);

  // Ombre très discrète (survol des cartes).
  static const Color shadow = Color(0xFF0F172A);

  // Accents des types de QR Code : utilisés avec parcimonie (icônes).
  static const AccentColor indigo = AccentColor(
    Color(0xFF4F46E5),
    Color(0xFFA5B4FC),
  );
  static const AccentColor rose = AccentColor(
    Color(0xFFE11D48),
    Color(0xFFFDA4AF),
  );
  static const AccentColor slate = AccentColor(
    Color(0xFF475569),
    Color(0xFFCBD5E1),
  );
  static const AccentColor violet = AccentColor(
    Color(0xFF7C3AED),
    Color(0xFFC4B5FD),
  );
  static const AccentColor sky = AccentColor(
    Color(0xFF0284C7),
    Color(0xFF7DD3FC),
  );
  static const AccentColor emerald = AccentColor(
    Color(0xFF059669),
    Color(0xFF6EE7B7),
  );

  // Marque Facebook, pour son bouton de connexion uniquement.
  static const Color facebook = Color(0xFF1877F2);

  // Couleurs du QR Code par défaut : contraste maximal pour une lecture fiable.
  static const Color qrForeground = Color(0xFF000000);
  static const Color qrBackground = Color(0xFFFFFFFF);
}

// Couleur d'accent déclinée pour les thèmes clair et sombre.
class AccentColor {
  const AccentColor(this.light, this.dark);

  final Color light;
  final Color dark;

  Color foreground(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  // Fond teinté derrière l'icône.
  Color container(Brightness brightness) => brightness == Brightness.light
      ? light.withValues(alpha: 0.10)
      : dark.withValues(alpha: 0.16);
}
