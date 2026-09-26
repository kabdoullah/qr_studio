import 'package:flutter_riverpod/flutter_riverpod.dart';

// Jeton de la session en cours, en mémoire. Ajouté par `ApiClient` aux
// requêtes authentifiées ; effacé par lui quand le serveur répond 401, ce
// que la session (`AuthViewModel`) traite comme une déconnexion.
class SessionToken extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String token) => state = token;

  void clear() => state = null;
}

final sessionTokenProvider = NotifierProvider<SessionToken, String?>(
  SessionToken.new,
);
