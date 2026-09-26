import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'social_sign_in_exception.dart';

part 'facebook_auth_service.g.dart';

// Application Meta, fournie au lancement : `--dart-define=FACEBOOK_APP_ID=…`
// (et `FACEBOOK_CLIENT_TOKEN` pour Android, lu par Gradle). Le secret de
// l'application reste sur le serveur.
const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');

// Connexion Facebook : fournit un jeton d'accès, vérifié par le serveur.
abstract interface class FacebookAuthService {
  bool get isAvailable;

  // `null` si l'utilisateur annule.
  Future<String?> signIn();

  // Déconnexion locale du SDK (l'autorisation Facebook n'est pas révoquée).
  Future<void> signOut();
}

class FacebookSdkAuthService implements FacebookAuthService {
  FacebookSdkAuthService(this._appId) {
    // Sur le web, le SDK JavaScript est chargé d'avance : la fenêtre de
    // connexion doit s'ouvrir dans le geste de l'utilisateur, sans attente.
    if (kIsWeb && isAvailable) _ready();
  }

  final String _appId;
  Future<void>? _initialization;

  FacebookAuth get _facebook => FacebookAuth.instance;

  @override
  bool get isAvailable => _appId.isNotEmpty;

  Future<void> _ready() => _initialization ??= kIsWeb
      ? _facebook.webAndDesktopInitialize(
          appId: _appId,
          cookie: false,
          xfbml: false,
          version: 'v21.0',
        )
      : Future.value();

  @override
  Future<String?> signIn() async {
    await _ready();
    final result = await _facebook.login(
      permissions: const ['email', 'public_profile'],
      // Jeton classique (Graph API), vérifiable par le serveur.
      loginTracking: LoginTracking.enabled,
    );
    return switch (result.status) {
      LoginStatus.success => switch (result.accessToken) {
        ClassicToken(:final tokenString) => tokenString,
        _ => throw const SocialSignInException('facebook', 'jeton limité'),
      },
      LoginStatus.cancelled => null,
      _ => throw SocialSignInException('facebook', result.status.name),
    };
  }

  @override
  Future<void> signOut() async {
    if (!isAvailable) return;
    await _ready();
    await _facebook.logOut();
  }
}

@Riverpod(keepAlive: true)
FacebookAuthService facebookAuthService(Ref ref) =>
    FacebookSdkAuthService(facebookAppId);
