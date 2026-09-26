// Compte connecté.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  // `null` si la réponse du serveur est incomplète.
  static AppUser? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'email': final String email,
      'first_name': final String firstName,
      'last_name': final String lastName,
    }) {
      return AppUser(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
    }
    return null;
  }
}
