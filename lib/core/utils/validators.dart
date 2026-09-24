// Règles de validation réutilisables. Chaque méthode renvoie un message
// d'erreur destiné à l'utilisateur, ou `null` si la valeur est valide.
abstract final class Validators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? required(String value, String message) {
    return value.trim().isEmpty ? message : null;
  }

  // Champ facultatif : une valeur vide est acceptée.
  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _emailPattern.hasMatch(trimmed)) return null;
    return 'Veuillez saisir une adresse email valide.';
  }
}
