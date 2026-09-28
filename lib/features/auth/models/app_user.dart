// Utilisateur de la session : anonyme (créé au premier lancement, sans
// email ni nom) ou compte enregistré.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.emailVerified = false,
    this.isAnonymous = false,
  });

  final String id;
  // `null` pour un utilisateur anonyme ou un compte Facebook sans email.
  final String? email;
  // `null` pour un utilisateur anonyme.
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final bool emailVerified;
  final bool isAnonymous;

  // Prénom et nom, vide si inconnus.
  String get displayName =>
      [firstName, lastName].whereType<String>().join(' ').trim();

  // `null` si la réponse du serveur est incomplète.
  static AppUser? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'email': final String? email,
      'first_name': final String? firstName,
      'last_name': final String? lastName,
    }) {
      return AppUser(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: json['avatar_url'] as String?,
        emailVerified: json['email_verified'] == true,
        isAnonymous: json['is_anonymous'] == true,
      );
    }
    return null;
  }
}
