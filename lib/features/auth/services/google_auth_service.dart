import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'social_sign_in_exception.dart';

part 'google_auth_service.g.dart';

// Identifiant du client OAuth « Application Web » de Google Cloud, fourni au
// lancement : `--dart-define=GOOGLE_CLIENT_ID=…apps.googleusercontent.com`.
// Utilisé comme `clientId` sur le web et comme `serverClientId` sur Android
// (l'ID token a alors ce client pour audience, vérifiée par le serveur).
// Aucun secret n'est embarqué dans l'application.
const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

// Connexion Google : fournit un ID token, envoyé au serveur qui le vérifie.
abstract interface class GoogleAuthService {
  bool get isAvailable;

  // Sur le web, le bouton est dessiné par Google (`renderButton`) et l'ID
  // token arrive par `idTokens` ; ailleurs, `signIn()` ouvre la connexion.
  bool get usesGoogleButton;

  // Initialisation du SDK, à attendre avant d'afficher le bouton web.
  Future<void> get ready;

  // `null` si l'utilisateur annule.
  Future<String?> signIn();

  // ID tokens obtenus par le bouton web ; erreurs : `SocialSignInException`.
  Stream<String> get idTokens;

  // Déconnexion locale du SDK (le compte Google n'est pas révoqué).
  Future<void> signOut();
}

class GoogleSignInAuthService implements GoogleAuthService {
  GoogleSignInAuthService(this._clientId);

  final String _clientId;
  Future<void>? _initialization;

  GoogleSignIn get _google => GoogleSignIn.instance;

  @override
  bool get isAvailable => _clientId.isNotEmpty;

  @override
  bool get usesGoogleButton => kIsWeb;

  @override
  Future<void> get ready => _initialization ??= _google.initialize(
    clientId: kIsWeb ? _clientId : null,
    serverClientId: kIsWeb ? null : _clientId,
  );

  @override
  Future<String?> signIn() async {
    await ready;
    try {
      final account = await _google.authenticate();
      return account.authentication.idToken ??
          (throw const SocialSignInException('google', 'ID token absent'));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw SocialSignInException('google', error.code.name);
    }
  }

  @override
  Stream<String> get idTokens => _google.authenticationEvents
      .handleError(
        (Object error) =>
            throw SocialSignInException('google', error.runtimeType.toString()),
        test: (error) =>
            !(error is GoogleSignInException &&
                error.code == GoogleSignInExceptionCode.canceled),
      )
      .map(
        (event) => switch (event) {
          GoogleSignInAuthenticationEventSignIn(:final user) =>
            user.authentication.idToken,
          _ => null,
        },
      )
      .where((token) => token != null)
      .cast<String>();

  @override
  Future<void> signOut() async {
    if (_initialization == null) return;
    await _google.signOut();
  }
}

@Riverpod(keepAlive: true)
GoogleAuthService googleAuthService(Ref ref) =>
    GoogleSignInAuthService(googleClientId);
