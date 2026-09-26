// Compte connecté.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.emailVerified = false,
  });

  final String id;
  // `null` pour un compte Facebook sans adresse email.
  final String? email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final bool emailVerified;

  // `null` si la réponse du serveur est incomplète.
  static AppUser? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'email': final String? email,
      'first_name': final String firstName,
      'last_name': final String lastName,
    }) {
      return AppUser(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: json['avatar_url'] as String?,
        emailVerified: json['email_verified'] == true,
      );
    }
    return null;
  }
}
