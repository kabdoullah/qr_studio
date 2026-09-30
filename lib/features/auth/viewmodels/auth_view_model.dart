import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_token.dart';
import '../../../core/storage/installation_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/validators.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/facebook_auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/social_sign_in_exception.dart';

part 'auth_view_model.g.dart';

// L'application s'ouvre toujours sur l'accueil, quel que soit l'état ;
// aucun écran de connexion n'est imposé.
// - `unknown` : session en cours d'ouverture (démarrage, déconnexion), en
//   arrière-plan.
// - `anonymous` : utilisateur anonyme de l'installation, créé
//   automatiquement ; il a accès à toute l'application.
// - `authenticated` : compte enregistré (email, Google, Facebook).
// - `unavailable` : aucune session n'a pu être ouverte (serveur
//   injoignable…) : l'accueil reste utilisable, et le message (`notice`)
//   s'affiche là où le serveur est nécessaire (enregistrement, « Mes QR
//   Codes »), qui retentent l'ouverture (`ensureSession`).
enum AuthStatus { unknown, anonymous, authenticated, unavailable }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  // Erreur des formulaires de connexion et d'inscription.
  final String? errorMessage;
  // Raison pour laquelle aucune session n'a pu être ouverte.
  final String? notice;

  // Session ouverte, anonyme ou non : l'application est utilisable.
  bool get hasSession =>
      status == AuthStatus.anonymous || status == AuthStatus.authenticated;

  bool get isAnonymous => status == AuthStatus.anonymous;

  // Compte enregistré.
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// Session de l'utilisateur (anonymous-first) : au démarrage, la session
// enregistrée est restaurée, sinon une session anonyme est ouverte, sans
// écran de connexion. L'inscription et Google/Facebook convertissent
// ensuite l'utilisateur anonyme en compte (même `id`, mêmes QR Codes).
@Riverpod(keepAlive: true)
class AuthViewModel extends _$AuthViewModel {
  static const String unavailableMessage =
      "La connexion n'est pas encore disponible.\n"
      'Réessayez dans quelques instants.';
  static const String restoreFailedMessage =
      'Impossible de joindre QR Studio. '
      'Vérifiez votre connexion puis réessayez.';
  static const String unexpectedMessage =
      'Une erreur est survenue. Veuillez réessayer.';
  static const String accountDeletedMessage = 'Votre compte a été supprimé.';

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
      if (!state.hasSession) return;
      if (next == null) {
        // Le client HTTP efface les jetons quand le serveur refuse la
        // session (renouvellement impossible). L'utilisateur anonyme
        // retrouve son compte par l'installation, sans rien voir ; celui
        // d'un compte enregistré repart sans compte, avec un message.
        if (state.isAnonymous) {
          _startAnonymousSession();
        } else {
          _expireAccountSession();
        }
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

    Future.microtask(_open);
    return const AuthState();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  // Ouverture de session en cours (démarrage, nouvel essai) et ouverture
  // de session anonyme en cours : un seul appel à la fois.
  Future<void>? _opening;
  Future<void>? _anonymousStart;

  Future<void> _open() =>
      _opening ??= _restoreSession().whenComplete(() => _opening = null);

  // Session prête pour un appel au serveur (enregistrer un QR Code,
  // charger « Mes QR Codes ») : attend l'ouverture en cours, ou la
  // retente si elle a échoué. `false` si aucune session n'a pu être
  // ouverte (le message est alors dans `notice`).
  Future<bool> ensureSession() async {
    if (state.hasSession) return true;
    if (_opening == null && _anonymousStart == null) {
      state = const AuthState();
    }
    // Session anonyme déjà en cours d'ouverture (déconnexion…) : l'attendre.
    await (_anonymousStart ?? _open());
    return state.hasSession;
  }

  // Au démarrage : le jeton de renouvellement enregistré est échangé
  // contre une nouvelle paire, puis le compte est relu (`GET /auth/me`).
  // Sans session enregistrée, ou si le serveur la refuse, une session
  // anonyme est ouverte : aucun écran de connexion au premier lancement.
  Future<void> _restoreSession() async {
    final service = ref.read(authServiceProvider);
    if (service == null) {
      state = const AuthState(
        status: AuthStatus.unavailable,
        notice: unavailableMessage,
      );
      return;
    }
    AuthTokens? stored;
    try {
      stored = await _storage.read();
    } catch (error, stackTrace) {
      _log('Lecture des jetons impossible', error, stackTrace);
    }
    if (stored != null) {
      try {
        final tokens = await service.refresh(stored.refreshToken);
        ref.read(sessionTokenProvider.notifier).set(tokens);
        await _writeTokens(tokens);
        final user = await service.me();
        state = AuthState(status: _statusOf(user), user: user);
        return;
      } on ApiException catch (error) {
        ref.read(sessionTokenProvider.notifier).clear();
        final rejected =
            error.kind == ApiErrorKind.unauthorized ||
            error.kind == ApiErrorKind.forbidden;
        if (!rejected) {
          // Sans réponse du serveur, les jetons sont gardés pour le
          // prochain essai, mais la session n'est pas considérée comme
          // valide.
          state = const AuthState(
            status: AuthStatus.unavailable,
            notice: restoreFailedMessage,
          );
          return;
        }
        await _deleteTokens();
      }
    }
    await _startAnonymousSession();
  }

  // Session de l'utilisateur anonyme de cette installation : créé au
  // premier appel, retrouvé ensuite (même identifiant d'installation).
  Future<void> _startAnonymousSession() => _anonymousStart ??=
      _openAnonymousSession().whenComplete(() => _anonymousStart = null);

  Future<void> _openAnonymousSession() async {
    final service = ref.read(authServiceProvider);
    if (service == null) {
      state = const AuthState(
        status: AuthStatus.unavailable,
        notice: unavailableMessage,
      );
      return;
    }
    try {
      final installationId = await ref
          .read(installationStorageProvider)
          .getOrCreateInstallationId();
      await _openSession(await service.anonymous(installationId));
    } catch (error, stackTrace) {
      if (error is! ApiException) {
        _log('Session anonyme impossible', error, stackTrace);
      }
      ref.read(sessionTokenProvider.notifier).clear();
      state = AuthState(
        status: AuthStatus.unavailable,
        notice: switch (error) {
          ApiException(kind: ApiErrorKind.offline || ApiErrorKind.timeout) =>
            restoreFailedMessage,
          ApiException(:final message) => message,
          _ => unexpectedMessage,
        },
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
  // accordé à QR Studio chez eux). L'appareil repart ensuite avec
  // l'utilisateur anonyme de l'installation, jamais avec le compte quitté :
  // un compte converti ne l'est plus par l'installation, qui reçoit alors
  // un nouvel utilisateur anonyme.
  Future<void> logout() async {
    final tokens = ref.read(sessionTokenProvider);
    final service = ref.read(authServiceProvider);
    await _leaveAccount([
      if (tokens != null && service != null)
        _quietly('Fin de session serveur', service.logout(tokens.refreshToken)),
    ]);
  }

  // Suppression définitive du compte enregistré (Paramètres), puis sortie
  // comme à la déconnexion : l'appareil repart avec l'utilisateur anonyme
  // de l'installation. Renvoie le message à afficher : confirmation, ou
  // erreur (la session est alors gardée).
  Future<String> deleteAccount() async {
    final service = ref.read(authServiceProvider);
    if (!state.isAuthenticated || state.isSubmitting || service == null) {
      return unexpectedMessage;
    }
    state = AuthState(
      status: state.status,
      user: state.user,
      isSubmitting: true,
    );
    try {
      await service.deleteAccount();
    } catch (error, stackTrace) {
      if (error is! ApiException) {
        _log('Suppression du compte impossible', error, stackTrace);
      }
      // Session refusée pendant l'appel : elle a déjà été remplacée.
      if (state.isSubmitting) {
        state = AuthState(status: state.status, user: state.user);
      }
      return error is ApiException ? error.message : unexpectedMessage;
    }
    await _leaveAccount(const []);
    return accountDeletedMessage;
  }

  // Sortie d'un compte (déconnexion, suppression) : session fermée
  // localement tout de suite, nouvelle session anonyme, et déconnexion des
  // SDK Google/Facebook, avec les appels serveur de `serverCalls`.
  Future<void> _leaveAccount(List<Future<void>> serverCalls) async {
    final google = ref.read(googleAuthServiceProvider);
    final facebook = ref.read(facebookAuthServiceProvider);
    state = const AuthState();
    ref.read(sessionTokenProvider.notifier).clear();
    await _deleteTokens();
    await Future.wait([
      _startAnonymousSession(),
      ...serverCalls,
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
    state = AuthState(status: _statusOf(session.user), user: session.user);
  }

  static AuthStatus _statusOf(AppUser user) =>
      user.isAnonymous ? AuthStatus.anonymous : AuthStatus.authenticated;

  // Exécute une connexion ou une conversion ; renvoie `true` si elle a
  // réussi. `action` renvoie `null` si l'utilisateur l'a annulée (aucun
  // message). En cas d'échec, la session en cours (anonyme) est gardée.
  Future<bool> _submit(
    Future<AuthSession?> Function(AuthService) action,
  ) async {
    if (state.isSubmitting) return false;
    // Ouverture de session du démarrage encore en cours : l'attendre, pour
    // qu'elle ne remplace pas ensuite le compte ouvert ici.
    if (_opening case final opening?) {
      state = AuthState(
        status: state.status,
        user: state.user,
        isSubmitting: true,
      );
      await opening;
      state = AuthState(status: state.status, user: state.user);
    }
    final service = ref.read(authServiceProvider);
    if (service == null) {
      state = AuthState(
        status: state.status,
        user: state.user,
        errorMessage: unavailableMessage,
      );
      return false;
    }
    state = AuthState(
      status: state.status,
      user: state.user,
      isSubmitting: true,
    );
    try {
      final session = await action(service);
      if (session == null) {
        state = AuthState(status: state.status, user: state.user);
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
    if (error is! ApiException) {
      _log('Échec de la connexion', error, stackTrace);
    }
    state = AuthState(
      status: state.status,
      user: state.user,
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

  // Session d'un compte enregistré refusée par le serveur : l'application
  // repart sans compte (utilisateur anonyme de l'installation) ; la
  // connexion reste possible depuis les Paramètres.
  Future<void> _expireAccountSession() async {
    state = const AuthState();
    ref.read(sessionTokenProvider.notifier).clear();
    await _deleteTokens();
    await _startAnonymousSession();
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
