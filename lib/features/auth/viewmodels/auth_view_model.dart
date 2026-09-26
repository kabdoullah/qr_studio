import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_token.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/validators.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/facebook_auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/social_sign_in_exception.dart';

part 'auth_view_model.g.dart';

// `unknown` : session en cours de vérification au démarrage.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// Session de l'utilisateur : restauration au démarrage, connexion (email,
// Google, Facebook), inscription et déconnexion.
@Riverpod(keepAlive: true)
class AuthViewModel extends _$AuthViewModel {
  static const String unavailableMessage =
      "La connexion n'est pas encore disponible.\n"
      'Réessayez dans quelques instants.';
  static const String sessionExpiredMessage =
      'Votre session a expiré. Veuillez vous reconnecter.';
  static const String restoreFailedMessage =
      'Impossible de vérifier votre session. '
      'Vérifiez votre connexion et reconnectez-vous.';
  static const String unexpectedMessage =
      'Une erreur est survenue. Veuillez réessayer.';

  static const int minPasswordLength = 8;

  // Règles de validation, partagées par les formulaires et le ViewModel.
  static String? validateEmail(String value) =>
      Validators.required(value, 'Veuillez saisir votre email.') ??
      Validators.email(value);

  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Veuillez saisir votre mot de passe.';
    if (value.length < minPasswordLength) {
      return 'Le mot de passe doit contenir au moins '
          '$minPasswordLength caractères.';
    }
    return null;
  }

  static String? validateConfirmation(String password, String confirmation) =>
      password == confirmation
      ? null
      : 'Les mots de passe ne correspondent pas.';

  static String socialFailedMessage(String provider) =>
      'La connexion avec $provider a échoué. Veuillez réessayer.';

  @override
  AuthState build() {
    ref.listen(sessionTokenProvider, (previous, next) {
      if (!state.isAuthenticated) return;
      if (next == null) {
        // Le client HTTP efface les jetons quand le serveur refuse la
        // session (renouvellement impossible).
        _signOut(errorMessage: sessionExpiredMessage);
      } else if (next != previous) {
        // Jetons renouvelés par le client HTTP : les conserver pour le
        // prochain lancement.
        _writeTokens(next);
      }
    });

    // Sur le web, la connexion Google passe par le bouton dessiné par
    // Google : l'ID token arrive par ce flux.
    final google = ref.read(googleAuthServiceProvider);
    if (google.isAvailable && google.usesGoogleButton) {
      final subscription = google.idTokens.listen(
        (idToken) => _submit((service) => service.loginWithGoogle(idToken)),
        onError: (Object error, StackTrace stackTrace) =>
            _fail(error, stackTrace),
      );
      ref.onDispose(subscription.cancel);
    }

    Future.microtask(_restoreSession);
    return const AuthState();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  // Au démarrage : le jeton de renouvellement enregistré est échangé
  // contre une nouvelle paire, puis le compte est relu (`GET /auth/me`).
  // L'utilisateur n'a pas à se reconnecter tant que la session est valide.
  Future<void> _restoreSession() async {
    final service = ref.read(authServiceProvider);
    AuthTokens? stored;
    try {
      stored = await _storage.read();
    } catch (error, stackTrace) {
      _log('Lecture des jetons impossible', error, stackTrace);
    }
    if (stored == null || service == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final tokens = await service.refresh(stored.refreshToken);
      ref.read(sessionTokenProvider.notifier).set(tokens);
      await _writeTokens(tokens);
      final user = await service.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (error) {
      final rejected =
          error.kind == ApiErrorKind.unauthorized ||
          error.kind == ApiErrorKind.forbidden;
      // Sans réponse du serveur, les jetons sont gardés pour le prochain
      // lancement, mais la session n'est pas considérée comme valide.
      if (rejected) await _deleteTokens();
      ref.read(sessionTokenProvider.notifier).clear();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: rejected ? null : restoreFailedMessage,
      );
    }
  }

  Future<bool> login({required String email, required String password}) =>
      _submit((service) => service.login(email: email, password: password));

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => _submit(
    (service) => service.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    ),
  );

  // Connexion Google hors web (sur le web : bouton Google, voir `build`).
  Future<bool> loginWithGoogle() => _submit((service) async {
    final idToken = await ref.read(googleAuthServiceProvider).signIn();
    return idToken == null ? null : service.loginWithGoogle(idToken);
  });

  Future<bool> loginWithFacebook() => _submit((service) async {
    final accessToken = await ref.read(facebookAuthServiceProvider).signIn();
    return accessToken == null ? null : service.loginWithFacebook(accessToken);
  });

  // Déconnexion : la session est fermée localement tout de suite, puis
  // côté serveur et dans les SDK Google/Facebook (sans révoquer l'accès
  // accordé à QR Studio chez eux).
  Future<void> logout() async {
    final tokens = ref.read(sessionTokenProvider);
    final service = ref.read(authServiceProvider);
    final google = ref.read(googleAuthServiceProvider);
    final facebook = ref.read(facebookAuthServiceProvider);
    await _signOut();
    await Future.wait([
      if (tokens != null && service != null)
        _quietly('Fin de session serveur', service.logout(tokens.refreshToken)),
      _quietly('Déconnexion Google', google.signOut()),
      _quietly('Déconnexion Facebook', facebook.signOut()),
    ]);
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = AuthState(status: state.status, user: state.user);
  }

  Future<void> _openSession(AuthSession session) async {
    ref.read(sessionTokenProvider.notifier).set(session.tokens);
    await _writeTokens(session.tokens);
    state = AuthState(status: AuthStatus.authenticated, user: session.user);
  }

  // Exécute une connexion ; renvoie `true` si elle a réussi. `action`
  // renvoie `null` si l'utilisateur l'a annulée (aucun message).
  Future<bool> _submit(
    Future<AuthSession?> Function(AuthService) action,
  ) async {
    if (state.isSubmitting) return false;
    final service = ref.read(authServiceProvider);
    if (service == null) {
      state = AuthState(status: state.status, errorMessage: unavailableMessage);
      return false;
    }
    state = AuthState(status: state.status, isSubmitting: true);
    try {
      final session = await action(service);
      if (session == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return false;
      }
      await _openSession(session);
      return true;
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
      return false;
    }
  }

  void _fail(Object error, StackTrace stackTrace) {
    ref.read(sessionTokenProvider.notifier).clear();
    if (error is! ApiException) {
      _log('Échec de la connexion', error, stackTrace);
    }
    state = AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: switch (error) {
        ApiException(:final message) => message,
        SocialSignInException(provider: 'google') => socialFailedMessage(
          'Google',
        ),
        SocialSignInException(provider: 'facebook') => socialFailedMessage(
          'Facebook',
        ),
        _ => unexpectedMessage,
      },
    );
  }

  // Déconnexion locale : état, jetons en mémoire puis enregistrés. Le
  // routeur revient alors à `/login`.
  Future<void> _signOut({String? errorMessage}) async {
    state = AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: errorMessage,
    );
    ref.read(sessionTokenProvider.notifier).clear();
    await _deleteTokens();
  }

  Future<void> _writeTokens(AuthTokens tokens) async {
    try {
      await _storage.write(tokens);
    } catch (error, stackTrace) {
      _log('Enregistrement des jetons impossible', error, stackTrace);
    }
  }

  Future<void> _deleteTokens() async {
    try {
      await _storage.delete();
    } catch (error, stackTrace) {
      _log('Suppression des jetons impossible', error, stackTrace);
    }
  }

  Future<void> _quietly(String label, Future<void> action) async {
    try {
      await action;
    } catch (error, stackTrace) {
      _log(label, error, stackTrace);
    }
  }

  // Détails techniques réservés aux logs de développement (jamais le
  // mot de passe ni les jetons).
  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'AuthViewModel',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
